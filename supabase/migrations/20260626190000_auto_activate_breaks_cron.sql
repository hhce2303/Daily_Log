-- =============================================================================
-- Auto-send break covers ~1 minute before each operator's break — server-side,
-- so no supervisor/operator action is needed. Runs every minute via pg_cron.
-- Break times are local to the monitoring center (America/Bogota, UTC-5).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

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
  n integer := 0;
BEGIN
  v_now_min := EXTRACT(HOUR   FROM (now() AT TIME ZONE 'America/Bogota'))::int * 60
             + EXTRACT(MINUTE FROM (now() AT TIME ZONE 'America/Bogota'))::int;

  FOR r IN
    SELECT s.id, s."ID_user", s.break_time
    FROM public.daily_ops_schedule s
    WHERE s.break_time IS NOT NULL
      AND s."ID_user" IS NOT NULL
      AND s.schedule_date >= CURRENT_DATE - 1
  LOOP
    BEGIN
      v_break_t := to_timestamp(r.break_time, 'HH12:MI AM')::time;
    EXCEPTION WHEN OTHERS THEN CONTINUE; END;

    v_break_min := EXTRACT(HOUR FROM v_break_t)::int * 60 + EXTRACT(MINUTE FROM v_break_t)::int;

    -- Fire from 1 minute before up to the break minute.
    CONTINUE WHEN v_now_min < v_break_min - 1 OR v_now_min > v_break_min;

    -- Skip if the operator already has an active cover.
    CONTINUE WHEN EXISTS (
      SELECT 1 FROM public.daily_covers_solicitudes c
      WHERE c."ID_user" = r."ID_user" AND c.active = 1
    );

    -- Operator must be at a station (active session).
    SELECT "ID_station" INTO v_station
    FROM public.daily_sesions
    WHERE "ID_user" = r."ID_user" AND sesion_active = 1
    ORDER BY sesion_in DESC LIMIT 1;
    CONTINUE WHEN v_station IS NULL;

    INSERT INTO public.daily_covers_solicitudes
      ("ID_user", "ID_station", cover_time_request, approved, active, cover_type)
    VALUES (r."ID_user", v_station, timezone('utc', now()), 0, 1, 4);
    n := n + 1;
  END LOOP;

  RETURN n;
END;
$$;

-- (Re)schedule the per-minute job.
DO $$
BEGIN
  PERFORM cron.unschedule('dailyops-activate-breaks');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule('dailyops-activate-breaks', '* * * * *',
  $$ SELECT public.dailyops_activate_due_breaks(); $$);
