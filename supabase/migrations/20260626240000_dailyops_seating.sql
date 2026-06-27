-- DailyOps seating / distribution: assign each scheduled operator to a workstation
-- (by station_number) for a given date. Mirrors the SLC_TOOLS SeatingMap feature.

CREATE TABLE IF NOT EXISTS public.daily_ops_seating (
  id              bigserial PRIMARY KEY,
  schedule_date   date NOT NULL,
  "ID_schedule"   bigint NOT NULL REFERENCES public.daily_ops_schedule(id) ON DELETE CASCADE,
  station_number  varchar NOT NULL,
  created_at      timestamp without time zone DEFAULT now(),
  UNIQUE (schedule_date, station_number),
  UNIQUE ("ID_schedule")
);

ALTER TABLE public.daily_ops_seating ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_ops_seating_read ON public.daily_ops_seating;
CREATE POLICY daily_ops_seating_read ON public.daily_ops_seating
  FOR SELECT TO authenticated USING (true);

-- ── Read: assignments for a date ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_get_seating(p_date date)
RETURNS TABLE (id_schedule bigint, station_number varchar)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT "ID_schedule", station_number
  FROM public.daily_ops_seating
  WHERE schedule_date = p_date;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_seating(date) TO authenticated;

-- ── Assign one operator to a station (or free them when station is NULL/'') ──
-- Enforces one operator per station for the date: any other operator already on
-- that station is bumped off first.
CREATE OR REPLACE FUNCTION public.dailyops_assign_seat(p_id_schedule bigint, p_station_number text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_date date;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;

  SELECT schedule_date INTO v_date FROM public.daily_ops_schedule WHERE id = p_id_schedule;
  IF v_date IS NULL THEN RAISE EXCEPTION 'Fila de horario no encontrada'; END IF;

  IF p_station_number IS NULL OR btrim(p_station_number) = '' THEN
    DELETE FROM public.daily_ops_seating WHERE "ID_schedule" = p_id_schedule;
    RETURN;
  END IF;

  -- Free the target station if someone else holds it that day.
  DELETE FROM public.daily_ops_seating
    WHERE schedule_date = v_date AND station_number = p_station_number;

  -- Upsert this operator's seat.
  INSERT INTO public.daily_ops_seating (schedule_date, "ID_schedule", station_number)
  VALUES (v_date, p_id_schedule, p_station_number)
  ON CONFLICT ("ID_schedule")
  DO UPDATE SET station_number = EXCLUDED.station_number, schedule_date = EXCLUDED.schedule_date;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_assign_seat(bigint, text) TO authenticated;

-- ── Clear all seat assignments for a date ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_clear_seating(p_date date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  DELETE FROM public.daily_ops_seating WHERE schedule_date = p_date;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_clear_seating(date) TO authenticated;

-- Stream seat assignments over realtime (no polling).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'daily_ops_seating'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_ops_seating;
  END IF;
END $$;
