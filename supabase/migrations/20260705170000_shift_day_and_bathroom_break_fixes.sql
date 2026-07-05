-- =============================================================================
-- Sunday AM+PM overlap fixes + bathroom-cover self-break fix.
--
-- Context: Mon–Sat the center runs only PM (overnight) shifts, but Sundays add a
-- daytime AM shift, so the SAME operator can have TWO active roster rows at once
-- (Saturday's PM row, whose after-midnight tail lands on Sunday, and Sunday's AM
-- row). Several routines scanned `schedule_date >= CURRENT_DATE - 1` without
-- deciding WHICH shift is the live one, so yesterday's PM data bled into today.
--
-- All three functions below are redefined using the existing operational-day
-- helpers (shift_resolve_datetime / shift_is_overnight). No new tables, no
-- change to the cover/session data model.
-- =============================================================================

-- ── 1. "My break today" must follow the operational day ──────────────────────
-- Was: newest row that HAS a break → on Sunday it returned Saturday-night's
-- break (Sunday AM row has none yet). Now: resolve each candidate break to its
-- real Bogotá instant and return only the soonest one that hasn't already passed
-- (15-min grace so a break in progress still shows). A stale overnight break
-- from the previous shift is hours in the past → excluded.
CREATE OR REPLACE FUNCTION public.dailyops_my_break_today()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT s.break_time
  FROM public.daily_ops_schedule s
  WHERE s."ID_user" = public.current_daily_user_id()
    AND s.break_time IS NOT NULL
    AND s.schedule_date >= CURRENT_DATE - 1
    AND s.schedule_date <= CURRENT_DATE
    AND public.shift_resolve_datetime(s.schedule_date, s.break_time, s.shift_in, s.shift_out)
        >= (now() AT TIME ZONE 'America/Bogota') - interval '15 minutes'
  ORDER BY public.shift_resolve_datetime(s.schedule_date, s.break_time, s.shift_in, s.shift_out) ASC
  LIMIT 1;
$function$;
GRANT EXECUTE ON FUNCTION public.dailyops_my_break_today() TO authenticated;

-- ── 2. Auto-activate breaks: bound to the shift + bathroom-cover self-break ───
-- Two changes vs 20260703100000:
--   (a) Shift-end guard: never fire a break once its OWN shift is over. This
--       stops a Saturday PM break (unfired because the op was busy/offline) from
--       triggering on Sunday morning.
--   (b) Bathroom-cover people (is_bathroom_cover=1) are roaming relievers with NO
--       fixed station — same shape as break-cover people. Route them through the
--       self-break branch (self-break once they're free, NO station cover
--       created) instead of creating a break cover against a borrowed station,
--       which stranded the reliever on someone else's machine. Fixes the
--       "operador solo de cover de baño se bugea al ser cubierto" report.
CREATE OR REPLACE FUNCTION public.dailyops_activate_due_breaks()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_now        timestamp;
  v_break_ts   timestamp;
  v_shift_end  timestamp;
  v_station    integer;
  v_station_no varchar;
  v_cover_user integer;
  n integer := 0;
BEGIN
  IF NOT COALESCE((SELECT auto_breaks_enabled FROM public.daily_ops_settings WHERE id = 1), true) THEN
    RETURN 0;
  END IF;

  v_now := now() AT TIME ZONE 'America/Bogota';

  FOR r IN
    SELECT s.id, s."ID_user", s.break_time, s.schedule_date, s.operator_name,
           s.shift_in, s.shift_out, s.is_break_cover, s.is_bathroom_cover, s.break_started_at
    FROM public.daily_ops_schedule s
    WHERE s.break_time IS NOT NULL
      AND s."ID_user" IS NOT NULL
      AND s.is_off = 0
      AND s.schedule_date >= CURRENT_DATE - 1
      AND s.break_started_at IS NULL          -- not yet activated (fire once)
  LOOP
    v_break_ts := public.shift_resolve_datetime(r.schedule_date, r.break_time, r.shift_in, r.shift_out);
    CONTINUE WHEN v_break_ts IS NULL;
    CONTINUE WHEN v_now < v_break_ts;         -- break time not reached yet

    -- Shift-end guard: once this row's shift has ended, its break is stale — skip
    -- it so yesterday's PM row can't fire on today's AM. (NULL shift_out ⇒ guard
    -- is a no-op, preserving prior behavior.)
    v_shift_end := public.shift_resolve_datetime(r.schedule_date, r.shift_out, r.shift_in, r.shift_out);
    CONTINUE WHEN v_shift_end IS NOT NULL AND v_now > v_shift_end;

    -- ── Roaming reliever (break-cover OR bathroom-cover): no fixed station, so
    --    self-break once they finish covering. Never create a station cover. ──
    IF r.is_break_cover = 1 OR r.is_bathroom_cover = 1 THEN
      CONTINUE WHEN EXISTS (
        SELECT 1 FROM public.daily_covers_completed cc
        WHERE cc."ID_cover_by" = r."ID_user" AND cc.cover_out IS NULL
      );
      UPDATE public.daily_ops_schedule SET break_started_at = timezone('utc', now()) WHERE id = r.id;
      INSERT INTO public.daily_station_messages
        ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
      VALUES (r."ID_user", r."ID_user", 'info', '☕ Es tu break',
              'Terminaste tu cover — ya puedes tomar tu break.', timezone('utc', now()), 1);
      n := n + 1;
      CONTINUE;
    END IF;

    -- ── Normal operator: create a break cover. Retry each minute within a grace
    --    window until the operator is connected & free, then fire once. ──
    CONTINUE WHEN v_now > v_break_ts + interval '30 minutes';   -- window passed → skip
    CONTINUE WHEN EXISTS (
      SELECT 1 FROM public.daily_covers_solicitudes c
      WHERE c."ID_user" = r."ID_user" AND c.active = 1
    );                                                          -- busy → retry next minute

    SELECT "ID_station" INTO v_station
    FROM public.daily_sesions
    WHERE "ID_user" = r."ID_user" AND sesion_active = 1
    ORDER BY sesion_in DESC LIMIT 1;
    CONTINUE WHEN v_station IS NULL;                            -- not connected → retry

    SELECT sc."ID_user" INTO v_cover_user
    FROM public.daily_ops_cover_plan p
    JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
    WHERE p.schedule_date = r.schedule_date AND p."ID_covered" = r.id
    LIMIT 1;

    INSERT INTO public.daily_covers_solicitudes
      ("ID_user", "ID_station", cover_time_request, approved, active, cover_type, assigned_cover_user)
    VALUES (r."ID_user", v_station, timezone('utc', now()), 0, 1, 4, v_cover_user);

    UPDATE public.daily_ops_schedule SET break_started_at = timezone('utc', now()) WHERE id = r.id;
    n := n + 1;

    SELECT station_number INTO v_station_no
    FROM public.daily_stations_info WHERE "ID_station" = v_station;

    INSERT INTO public.daily_station_messages
      ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
    VALUES (r."ID_user", r."ID_user", 'info', '☕ Es tu break',
            'Es hora de tu break' ||
            CASE WHEN v_cover_user IS NOT NULL THEN '. Un compañero va a cubrirte.' ELSE '.' END,
            timezone('utc', now()), 1);

    IF v_cover_user IS NOT NULL THEN
      INSERT INTO public.daily_station_messages
        ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
      VALUES (v_cover_user, v_cover_user, 'warning', '☕ Es hora de cubrir',
              'Cubre a ' || r.operator_name || ' (puesto ' || COALESCE(v_station_no, v_station::text) ||
              '). Abre la cola de covers para iniciar.', timezone('utc', now()), 1);
    END IF;
  END LOOP;

  RETURN n;
END;
$function$;

-- ── 3. Schedule board: attribute live status to the CURRENT shift only ────────
-- The live "connected" / "en break" flags were EXISTS(...) per user, so an
-- operator appearing in both the Saturday-PM and Sunday-AM rows lit up on BOTH.
-- Gate them by whether NOW falls inside THIS row's shift window (with grace for
-- early login / late logout). Unresolvable shift times ⇒ show status (safe
-- fallback = prior behavior). Return signature is unchanged (incl.
-- has_any_active_cover added in 20260705150000).
DROP FUNCTION IF EXISTS public.dailyops_get_schedule(date);
CREATE FUNCTION public.dailyops_get_schedule(p_date date)
 RETURNS TABLE(id bigint, team text, operator_name text, id_user integer, matched_name text, shift_in text, shift_out text, break_time text, is_off smallint, sort_order integer, has_active_session boolean, active_cover boolean, is_break_cover smallint, self_break_at timestamp without time zone, is_bathroom_cover smallint, has_any_active_cover boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    s.id, s.team::text, s.operator_name::text, s."ID_user",
    un.user_name::text,
    s.shift_in::text, s.shift_out::text, s.break_time::text, s.is_off, s.sort_order,
    (EXISTS (SELECT 1 FROM public.daily_sesions ses
             WHERE ses."ID_user" = s."ID_user" AND ses.sesion_active = 1)
       AND w.is_current),
    (EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c
             WHERE c."ID_user" = s."ID_user" AND c.active = 1
               AND c.cover_type = 4
               AND c.cover_time_request >= timezone('utc', now()) - interval '12 hours')
       AND w.is_current),
    s.is_break_cover,
    s.break_started_at,
    s.is_bathroom_cover,
    (EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c
             WHERE c."ID_user" = s."ID_user" AND c.active = 1)
       AND w.is_current)
  FROM public.daily_ops_schedule s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  LEFT JOIN LATERAL (
    SELECT CASE
      WHEN a.sstart IS NULL OR a.send IS NULL THEN true
      ELSE (now() AT TIME ZONE 'America/Bogota')
             BETWEEN a.sstart - interval '1 hour' AND a.send + interval '2 hours'
    END AS is_current
    FROM (
      SELECT public.shift_resolve_datetime(s.schedule_date, s.shift_in,  s.shift_in, s.shift_out) AS sstart,
             public.shift_resolve_datetime(s.schedule_date, s.shift_out, s.shift_in, s.shift_out) AS send
    ) a
  ) w ON true
  WHERE s.schedule_date = p_date
  ORDER BY s.sort_order;
$function$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_schedule(date) TO authenticated;

-- Refresh PostgREST's schema cache immediately (dropped/recreated function).
NOTIFY pgrst, 'reload schema';
