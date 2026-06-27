-- =============================================================================
-- DailyOps: paste-based daily schedule (this app has no schedule DB, so a
-- supervisor pastes the shift block and we parse + store it). Breaks derived
-- here feed the existing cover queue (operator no longer requests break covers).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_ops_schedule (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  schedule_date date NOT NULL,
  team          varchar NOT NULL,            -- C, A, E1, E2, SUP, ...
  operator_name varchar NOT NULL,
  "ID_user"     integer,                     -- matched daily user (nullable)
  shift_in      varchar,
  shift_out     varchar,
  break_time    varchar,                     -- e.g. "1:00 AM" (nullable)
  is_off        smallint NOT NULL DEFAULT 0,
  sort_order    integer NOT NULL DEFAULT 0,
  created_at    timestamp NOT NULL DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS idx_dailyops_schedule_date ON public.daily_ops_schedule (schedule_date);

CREATE TABLE IF NOT EXISTS public.daily_ops_notes (
  schedule_date date PRIMARY KEY,
  notes         text,
  updated_at    timestamp NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.daily_ops_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_ops_notes    ENABLE ROW LEVEL SECURITY;
-- Everyone authenticated can read the schedule; writes go through RPCs only.
DROP POLICY IF EXISTS dops_sched_read ON public.daily_ops_schedule;
CREATE POLICY dops_sched_read ON public.daily_ops_schedule FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS dops_notes_read ON public.daily_ops_notes;
CREATE POLICY dops_notes_read ON public.daily_ops_notes FOR SELECT TO authenticated USING (true);

-- Best-effort match of a pasted name to a daily user (exact, case-insensitive).
CREATE OR REPLACE FUNCTION public.dailyops_match_user(p_name text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT n."ID_user"
  FROM public.daily_users_names n
  WHERE lower(trim(n.user_name)) = lower(trim(p_name))
  LIMIT 1;
$$;

-- Replace the whole schedule for a date with the parsed rows (+ notes).
CREATE OR REPLACE FUNCTION public.dailyops_save_schedule(
  p_date  date,
  p_rows  jsonb,      -- [{team,name,shift_in,shift_out,break_time,is_off,sort}]
  p_notes text
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
  n integer := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden subir horarios';
  END IF;

  DELETE FROM public.daily_ops_schedule WHERE schedule_date = p_date;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows)
  LOOP
    INSERT INTO public.daily_ops_schedule
      (schedule_date, team, operator_name, "ID_user", shift_in, shift_out, break_time, is_off, sort_order)
    VALUES (
      p_date,
      COALESCE(r->>'team',''),
      COALESCE(r->>'name',''),
      public.dailyops_match_user(r->>'name'),
      NULLIF(r->>'shift_in',''),
      NULLIF(r->>'shift_out',''),
      NULLIF(r->>'break_time',''),
      COALESCE((r->>'is_off')::int, 0),
      COALESCE((r->>'sort')::int, n)
    );
    n := n + 1;
  END LOOP;

  INSERT INTO public.daily_ops_notes (schedule_date, notes, updated_at)
  VALUES (p_date, p_notes, timezone('utc', now()))
  ON CONFLICT (schedule_date) DO UPDATE SET notes = EXCLUDED.notes, updated_at = timezone('utc', now());

  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_save_schedule(date, jsonb, text) TO authenticated;

-- Read a day's roster, with match + live session/cover status per operator.
CREATE OR REPLACE FUNCTION public.dailyops_get_schedule(p_date date)
RETURNS TABLE(
  id bigint, team text, operator_name text, id_user integer, matched_name text,
  shift_in text, shift_out text, break_time text, is_off smallint, sort_order integer,
  has_active_session boolean, active_cover boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    s.id, s.team::text, s.operator_name::text, s."ID_user",
    un.user_name::text,
    s.shift_in::text, s.shift_out::text, s.break_time::text, s.is_off, s.sort_order,
    EXISTS (SELECT 1 FROM public.daily_sesions ses WHERE ses."ID_user" = s."ID_user" AND ses.sesion_active = 1),
    EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c WHERE c."ID_user" = s."ID_user" AND c.active = 1)
  FROM public.daily_ops_schedule s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  WHERE s.schedule_date = p_date
  ORDER BY s.sort_order;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_schedule(date) TO authenticated;

CREATE OR REPLACE FUNCTION public.dailyops_get_notes(p_date date)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT notes FROM public.daily_ops_notes WHERE schedule_date = p_date; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_notes(date) TO authenticated;

-- Edit a single operator's break time.
CREATE OR REPLACE FUNCTION public.dailyops_set_break(p_id bigint, p_break text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden editar breaks';
  END IF;
  UPDATE public.daily_ops_schedule SET break_time = NULLIF(p_break,'') WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_set_break(bigint, text) TO authenticated;

-- Turn a scheduled break into a cover request so it shows in the cover queue.
-- (cover_type 4 = "Break"). No-op-safe if one is already active.
CREATE OR REPLACE FUNCTION public.dailyops_request_break_cover(p_schedule_id bigint)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id    integer;
  v_station_id integer;
  v_cover_id   integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden iniciar el break';
  END IF;

  SELECT "ID_user" INTO v_user_id FROM public.daily_ops_schedule WHERE id = p_schedule_id;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Este operador no está vinculado a un usuario (nombre no coincide)';
  END IF;

  -- Already an active cover for this operator?
  SELECT "ID_cover" INTO v_cover_id
  FROM public.daily_covers_solicitudes WHERE "ID_user" = v_user_id AND active = 1 LIMIT 1;
  IF v_cover_id IS NOT NULL THEN RETURN v_cover_id; END IF;

  -- Operator must be at a station (active session).
  SELECT "ID_station" INTO v_station_id
  FROM public.daily_sesions WHERE "ID_user" = v_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC LIMIT 1;
  IF v_station_id IS NULL THEN
    RAISE EXCEPTION 'El operador no tiene una sesión activa';
  END IF;

  INSERT INTO public.daily_covers_solicitudes
    ("ID_user", "ID_station", cover_time_request, approved, active, cover_type)
  VALUES (v_user_id, v_station_id, timezone('utc', now()), 0, 1, 4)
  RETURNING "ID_cover" INTO v_cover_id;

  RETURN v_cover_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_request_break_cover(bigint) TO authenticated;
