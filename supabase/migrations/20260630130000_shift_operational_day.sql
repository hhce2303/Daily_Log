-- =============================================================================
-- Operational-day (night-shift) awareness — shared, reusable primitives.
--
-- The business runs mostly NIGHT shifts that cross midnight. When a schedule row
-- carries a calendar date (schedule_date) plus a loose clock time (break_time,
-- shift_in, shift_out as text), an early-morning time like "2:00 AM" actually
-- belongs to schedule_date + 1 — UNLESS the shift is a day/AM shift that ends the
-- same day. These helpers resolve a (date, clock-time, shift) into the REAL
-- instant (center-local / America-Bogota wall clock) so every caller agrees.
--
-- Rule (anchored on shift_in, per product decision):
--   * Parse shift_in / shift_out.
--   * overnight = shift crosses midnight:
--       shift_out present  -> shift_out <= shift_in
--       shift_out absent   -> shift_in  >= 12:00 (a PM/evening start ⇒ night)
--   * If overnight AND time < shift_in  -> the time is on schedule_date + 1.
--     Otherwise it stays on schedule_date.
--   * No shift_in at all -> assume NIGHT (company default): times before noon
--     roll to the next day, noon-onward stay same day.
-- =============================================================================

-- Tolerant parse of free-form clock text ("5:30 p.m.", "2:30 a.m.", "1:00 AM",
-- "17:30") into a TIME. Returns NULL when it can't be parsed.
CREATE OR REPLACE FUNCTION public.shift_parse_time(p text)
RETURNS time
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE n text; r time;
BEGIN
  IF p IS NULL THEN RETURN NULL; END IF;
  n := lower(regexp_replace(p, '[\.\s]', '', 'g'));   -- strip dots+spaces, lowercase
  IF n = '' THEN RETURN NULL; END IF;
  BEGIN
    IF n ~ '(am|pm)$' THEN
      r := to_timestamp(upper(regexp_replace(n, '(am|pm)$', ' \1')), 'HH12:MI AM')::time;
    ELSE
      r := n::time;                                    -- 24h like "17:30"
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
  RETURN r;
END; $$;

-- Does the shift cross midnight? NULL shift_in ⇒ treated as night (TRUE).
CREATE OR REPLACE FUNCTION public.shift_is_overnight(p_shift_in text, p_shift_out text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE ti time; tout time;
BEGIN
  ti   := public.shift_parse_time(p_shift_in);
  tout := public.shift_parse_time(p_shift_out);
  IF ti IS NULL THEN RETURN true; END IF;                 -- unknown ⇒ assume night
  IF tout IS NOT NULL THEN RETURN tout <= ti; END IF;     -- end <= start ⇒ crosses midnight
  RETURN ti >= time '12:00';                              -- only a start time: PM ⇒ night
END; $$;

-- Resolve (schedule_date, clock-time, shift bounds) -> real center-local instant.
CREATE OR REPLACE FUNCTION public.shift_resolve_datetime(
  p_date date, p_time text, p_shift_in text, p_shift_out text)
RETURNS timestamp
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE t time; ti time; d date;
BEGIN
  t := public.shift_parse_time(p_time);
  IF t IS NULL THEN RETURN NULL; END IF;
  ti := public.shift_parse_time(p_shift_in);

  IF public.shift_is_overnight(p_shift_in, p_shift_out)
     AND t < COALESCE(ti, time '12:00') THEN
    d := p_date + 1;                                   -- after-midnight portion of a night shift
  ELSE
    d := p_date;
  END IF;
  RETURN d + t;
END; $$;

GRANT EXECUTE ON FUNCTION public.shift_parse_time(text)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.shift_is_overnight(text, text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.shift_resolve_datetime(date, text, text, text)  TO authenticated;

-- ── Make break activation operational-day aware ──────────────────────────────
-- Was: compared only minutes-of-day, so a night-shift break ("2:00 AM" on the
-- 29th) could fire at 2 AM of the 29th (a day early) and/or re-fire the next day.
-- Now: resolve each break to its real Bogota instant and fire within ±1 min.
CREATE OR REPLACE FUNCTION public.dailyops_activate_due_breaks()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_now        timestamp;
  v_break_ts   timestamp;
  v_station    integer;
  v_station_no varchar;
  v_cover_user integer;
  n integer := 0;
BEGIN
  v_now := now() AT TIME ZONE 'America/Bogota';        -- center-local wall clock

  FOR r IN
    SELECT s.id, s."ID_user", s.break_time, s.schedule_date, s.operator_name,
           s.shift_in, s.shift_out
    FROM public.daily_ops_schedule s
    WHERE s.break_time IS NOT NULL
      AND s."ID_user" IS NOT NULL
      AND s.is_off = 0
      AND s.schedule_date >= CURRENT_DATE - 1          -- yesterday covers tonight's after-midnight breaks
  LOOP
    v_break_ts := public.shift_resolve_datetime(r.schedule_date, r.break_time, r.shift_in, r.shift_out);
    CONTINUE WHEN v_break_ts IS NULL;
    -- Fire in a ±1 minute window around the real instant.
    CONTINUE WHEN v_now < v_break_ts - interval '1 minute'
              OR v_now > v_break_ts + interval '1 minute';

    CONTINUE WHEN EXISTS (
      SELECT 1 FROM public.daily_covers_solicitudes c
      WHERE c."ID_user" = r."ID_user" AND c.active = 1
    );

    SELECT "ID_station" INTO v_station
    FROM public.daily_sesions
    WHERE "ID_user" = r."ID_user" AND sesion_active = 1
    ORDER BY sesion_in DESC LIMIT 1;
    CONTINUE WHEN v_station IS NULL;

    SELECT sc."ID_user" INTO v_cover_user
    FROM public.daily_ops_cover_plan p
    JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
    WHERE p.schedule_date = r.schedule_date AND p."ID_covered" = r.id
    LIMIT 1;

    INSERT INTO public.daily_covers_solicitudes
      ("ID_user", "ID_station", cover_time_request, approved, active, cover_type, assigned_cover_user)
    VALUES (r."ID_user", v_station, timezone('utc', now()), 0, 1, 4, v_cover_user);
    n := n + 1;

    IF v_cover_user IS NOT NULL THEN
      SELECT station_number INTO v_station_no
      FROM public.daily_stations_info WHERE "ID_station" = v_station;

      INSERT INTO public.daily_station_messages
        ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
      VALUES (v_cover_user, v_cover_user, 'warning', '☕ Es hora de cubrir',
              'Cubre a ' || r.operator_name || ' (puesto ' || COALESCE(v_station_no, v_station::text) ||
              '). Abre la cola de covers para iniciar.', timezone('utc', now()), 1);
    END IF;
  END LOOP;

  RETURN n;
END; $function$;
