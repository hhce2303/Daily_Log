-- =============================================================================
-- DailyOps "who covers whom": designate break-cover operators, auto-generate a
-- fair cover plan (which cover takes which operator's station, per break hour),
-- notify both parties, and tag the auto-sent break cover with the assigned cover.
-- Improves on the desktop/SLC logic with least-loaded (fair) balancing.
-- =============================================================================

-- 1. Flag certain roster rows as dedicated break covers.
ALTER TABLE public.daily_ops_schedule
  ADD COLUMN IF NOT EXISTS is_break_cover smallint NOT NULL DEFAULT 0;

-- 2. The computed plan: id_cover covers id_covered at break_time.
CREATE TABLE IF NOT EXISTS public.daily_ops_cover_plan (
  id            bigserial PRIMARY KEY,
  schedule_date date NOT NULL,
  break_time    varchar NOT NULL,
  "ID_cover"    bigint NOT NULL REFERENCES public.daily_ops_schedule(id) ON DELETE CASCADE,
  "ID_covered"  bigint NOT NULL REFERENCES public.daily_ops_schedule(id) ON DELETE CASCADE,
  created_at    timestamp without time zone DEFAULT now(),
  UNIQUE (schedule_date, "ID_covered")
);
ALTER TABLE public.daily_ops_cover_plan ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS daily_ops_cover_plan_read ON public.daily_ops_cover_plan;
CREATE POLICY daily_ops_cover_plan_read ON public.daily_ops_cover_plan
  FOR SELECT TO authenticated USING (true);

-- 3. Reference column on the auto-sent break cover: who is assigned to take it.
ALTER TABLE public.daily_covers_solicitudes
  ADD COLUMN IF NOT EXISTS assigned_cover_user integer;

-- ── Toggle the break-cover role ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_set_cover_role(p_id bigint, p_is_cover boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  UPDATE public.daily_ops_schedule SET is_break_cover = CASE WHEN p_is_cover THEN 1 ELSE 0 END
  WHERE id = p_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_set_cover_role(bigint, boolean) TO authenticated;

-- ── Generate the cover plan (fair, least-loaded) ─────────────────────────────
-- For each break hour, each regular operator on break is assigned to the cover
-- with the fewest assignments so far that is (a) not on their own break that hour
-- and (b) not already covering someone else that same hour.
CREATE OR REPLACE FUNCTION public.dailyops_generate_covers(p_date date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r_hour   record;
  r_reg    record;
  v_cover  bigint;
  n        integer := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;

  DELETE FROM public.daily_ops_cover_plan WHERE schedule_date = p_date;

  -- Process break hours in chronological order so balancing is stable.
  FOR r_hour IN
    SELECT DISTINCT break_time
    FROM public.daily_ops_schedule
    WHERE schedule_date = p_date AND is_off = 0 AND is_break_cover = 0 AND break_time IS NOT NULL
    ORDER BY break_time
  LOOP
    FOR r_reg IN
      SELECT id FROM public.daily_ops_schedule
      WHERE schedule_date = p_date AND is_off = 0 AND is_break_cover = 0
        AND break_time = r_hour.break_time
      ORDER BY id
    LOOP
      -- Pick the least-loaded eligible cover for this hour.
      SELECT c.id INTO v_cover
      FROM public.daily_ops_schedule c
      WHERE c.schedule_date = p_date AND c.is_off = 0 AND c.is_break_cover = 1
        AND (c.break_time IS DISTINCT FROM r_hour.break_time)          -- not on their own break now
        AND NOT EXISTS (                                               -- not already busy this hour
          SELECT 1 FROM public.daily_ops_cover_plan p
          WHERE p.schedule_date = p_date AND p.break_time = r_hour.break_time AND p."ID_cover" = c.id
        )
      ORDER BY (
        SELECT count(*) FROM public.daily_ops_cover_plan p2
        WHERE p2.schedule_date = p_date AND p2."ID_cover" = c.id
      ) ASC, c.id ASC
      LIMIT 1;

      IF v_cover IS NOT NULL THEN
        INSERT INTO public.daily_ops_cover_plan (schedule_date, break_time, "ID_cover", "ID_covered")
        VALUES (p_date, r_hour.break_time, v_cover, r_reg.id);
        n := n + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN n;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_generate_covers(date) TO authenticated;

-- ── Read the plan (for display) ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_get_cover_plan(p_date date)
RETURNS TABLE (
  break_time varchar,
  id_cover bigint, cover_name varchar,
  id_covered bigint, covered_name varchar
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT p.break_time,
         p."ID_cover", sc.operator_name,
         p."ID_covered", sv.operator_name
  FROM public.daily_ops_cover_plan p
  JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
  JOIN public.daily_ops_schedule sv ON sv.id = p."ID_covered"
  WHERE p.schedule_date = p_date
  ORDER BY p.break_time, sc.operator_name;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_cover_plan(date) TO authenticated;

-- ── Clear the plan ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_clear_cover_plan(p_date date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  DELETE FROM public.daily_ops_cover_plan WHERE schedule_date = p_date;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_clear_cover_plan(date) TO authenticated;

-- ── Notify both parties of the plan ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dailyops_notify_cover_plan(p_date date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_sender integer;
  r record;
  n integer := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  v_sender := public.current_daily_user_id();

  -- Tell each COVER who/when they cover (one consolidated message per cover).
  FOR r IN
    SELECT sc."ID_user" AS cover_user,
           string_agg(sv.operator_name || ' (' || p.break_time || ')', ', ' ORDER BY p.break_time) AS list
    FROM public.daily_ops_cover_plan p
    JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
    JOIN public.daily_ops_schedule sv ON sv.id = p."ID_covered"
    WHERE p.schedule_date = p_date AND sc."ID_user" IS NOT NULL
    GROUP BY sc."ID_user"
  LOOP
    INSERT INTO public.daily_station_messages
      ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
    VALUES (v_sender, r.cover_user, 'info', '☕ Covers asignados',
            'Hoy cubres a: ' || r.list, timezone('utc', now()), 1);
    n := n + 1;
  END LOOP;

  -- Tell each COVERED operator who covers them.
  FOR r IN
    SELECT sv."ID_user" AS covered_user, sc.operator_name AS cover_name, p.break_time
    FROM public.daily_ops_cover_plan p
    JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
    JOIN public.daily_ops_schedule sv ON sv.id = p."ID_covered"
    WHERE p.schedule_date = p_date AND sv."ID_user" IS NOT NULL
  LOOP
    INSERT INTO public.daily_station_messages
      ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
    VALUES (v_sender, r.covered_user, 'info', '☕ Tu break',
            'En tu break de ' || r.break_time || ' te cubre ' || r.cover_name || '.',
            timezone('utc', now()), 1);
    n := n + 1;
  END LOOP;

  RETURN n;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_notify_cover_plan(date) TO authenticated;

-- Stream the plan over realtime.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'daily_ops_cover_plan'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_ops_cover_plan;
  END IF;
END $$;
