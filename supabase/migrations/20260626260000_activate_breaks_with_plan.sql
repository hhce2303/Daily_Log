-- Auto-send break covers, now plan-aware: when a break fires, look up the
-- assigned cover from daily_ops_cover_plan, tag the request with that cover,
-- and notify them specifically ("es hora: cubre a X en el puesto N").
-- The request still lands in the general queue as a fallback (advisory model).

CREATE OR REPLACE FUNCTION public.dailyops_activate_due_breaks()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r record;
  v_now_min   integer;
  v_break_min integer;
  v_break_t   time;
  v_station   integer;
  v_station_no varchar;
  v_cover_user integer;
  v_covered_name varchar;
  n integer := 0;
BEGIN
  v_now_min := EXTRACT(HOUR   FROM (now() AT TIME ZONE 'America/Bogota'))::int * 60
             + EXTRACT(MINUTE FROM (now() AT TIME ZONE 'America/Bogota'))::int;

  FOR r IN
    SELECT s.id, s."ID_user", s.break_time, s.schedule_date, s.operator_name
    FROM public.daily_ops_schedule s
    WHERE s.break_time IS NOT NULL
      AND s."ID_user" IS NOT NULL
      AND s.is_off = 0
      AND s.schedule_date >= CURRENT_DATE - 1
  LOOP
    BEGIN
      v_break_t := to_timestamp(r.break_time, 'HH12:MI AM')::time;
    EXCEPTION WHEN OTHERS THEN CONTINUE; END;

    v_break_min := EXTRACT(HOUR FROM v_break_t)::int * 60 + EXTRACT(MINUTE FROM v_break_t)::int;
    CONTINUE WHEN v_now_min < v_break_min - 1 OR v_now_min > v_break_min;

    CONTINUE WHEN EXISTS (
      SELECT 1 FROM public.daily_covers_solicitudes c
      WHERE c."ID_user" = r."ID_user" AND c.active = 1
    );

    SELECT "ID_station" INTO v_station
    FROM public.daily_sesions
    WHERE "ID_user" = r."ID_user" AND sesion_active = 1
    ORDER BY sesion_in DESC LIMIT 1;
    CONTINUE WHEN v_station IS NULL;

    -- Assigned cover (if a plan exists for this covered operator).
    SELECT sc."ID_user" INTO v_cover_user
    FROM public.daily_ops_cover_plan p
    JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
    WHERE p.schedule_date = r.schedule_date AND p."ID_covered" = r.id
    LIMIT 1;

    INSERT INTO public.daily_covers_solicitudes
      ("ID_user", "ID_station", cover_time_request, approved, active, cover_type, assigned_cover_user)
    VALUES (r."ID_user", v_station, timezone('utc', now()), 0, 1, 4, v_cover_user);
    n := n + 1;

    -- Notify the assigned cover that it's time.
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
END; $$;
