-- Target song requests at ALL operators or a specific subset.
-- daily_song_round.target_all = true → every connected operator; false → only
-- the users listed in daily_song_targets.

ALTER TABLE public.daily_song_round
  ADD COLUMN IF NOT EXISTS target_all boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS public.daily_song_targets (
  "ID_user" integer PRIMARY KEY
);
ALTER TABLE public.daily_song_targets ENABLE ROW LEVEL SECURITY;
-- Read/written only through SECURITY DEFINER RPCs; no direct policy needed.

-- ── Open a round: all operators, or a specific set of user ids ────────────────
CREATE OR REPLACE FUNCTION public.song_open(p_all boolean, p_user_ids integer[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;

  UPDATE public.daily_song_requests SET active = 0 WHERE active = 1; -- fresh round
  DELETE FROM public.daily_song_targets;

  IF NOT COALESCE(p_all, false) THEN
    IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
      RAISE EXCEPTION 'Selecciona al menos un operador';
    END IF;
    INSERT INTO public.daily_song_targets ("ID_user")
      SELECT DISTINCT unnest(p_user_ids);
  END IF;

  UPDATE public.daily_song_round
  SET enabled = true, target_all = COALESCE(p_all, false), opened_at = timezone('utc', now())
  WHERE id = 1;
END; $$;
GRANT EXECUTE ON FUNCTION public.song_open(boolean, integer[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.song_close()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  UPDATE public.daily_song_round SET enabled = false WHERE id = 1;
END; $$;
GRANT EXECUTE ON FUNCTION public.song_close() TO authenticated;

-- ── State: counts scoped to the round's target set ───────────────────────────
CREATE OR REPLACE FUNCTION public.song_state()
RETURNS json LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_enabled boolean;
  v_all boolean;
  v_total int;
  v_submitted int;
  v_me int;
  v_targeted boolean;
BEGIN
  SELECT enabled, target_all INTO v_enabled, v_all FROM public.daily_song_round WHERE id = 1;
  v_me := public.current_daily_user_id();

  -- Connected operators (role 2, active session) within the target set.
  SELECT count(DISTINCT s."ID_user") INTO v_total
  FROM public.daily_sesions s
  JOIN public.daily_users u ON u."ID_user" = s."ID_user"
  WHERE s.sesion_active = 1 AND u."ID_user_rol" = 2
    AND (COALESCE(v_all, true) OR s."ID_user" IN (SELECT "ID_user" FROM public.daily_song_targets));

  SELECT count(DISTINCT r."ID_user") INTO v_submitted
  FROM public.daily_song_requests r
  JOIN public.daily_sesions s ON s."ID_user" = r."ID_user" AND s.sesion_active = 1
  JOIN public.daily_users u ON u."ID_user" = r."ID_user" AND u."ID_user_rol" = 2
  WHERE r.active = 1
    AND (COALESCE(v_all, true) OR r."ID_user" IN (SELECT "ID_user" FROM public.daily_song_targets));

  v_targeted := COALESCE(v_all, true)
    OR EXISTS (SELECT 1 FROM public.daily_song_targets WHERE "ID_user" = v_me);

  RETURN json_build_object(
    'enabled', COALESCE(v_enabled, false),
    'target_all', COALESCE(v_all, true),
    'total', v_total,
    'submitted', v_submitted,
    'pending', GREATEST(v_total - v_submitted, 0),
    'i_submitted', EXISTS (SELECT 1 FROM public.daily_song_requests WHERE active = 1 AND "ID_user" = v_me),
    'i_targeted', v_targeted,
    'is_supervisor', public.current_user_is_supervisor()
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.song_state() TO authenticated;

NOTIFY pgrst, 'reload schema';
