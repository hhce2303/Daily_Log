-- Fix 1: song_open's DELETE had no WHERE clause (rejected under safe-update
--        mode). Fix 2: expose the connected operators from the SAME source the
--        state counts use (daily_sesions), so the target picker matches the
--        pending count instead of deriving from the roster's is_current gate.

CREATE OR REPLACE FUNCTION public.song_open(p_all boolean, p_user_ids integer[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;

  UPDATE public.daily_song_requests SET active = 0 WHERE active = 1;   -- fresh round
  DELETE FROM public.daily_song_targets WHERE true;                    -- clear targets

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

-- Connected operators (role 2, active session) a supervisor can target — the
-- same set song_state() counts, deduped and named.
CREATE OR REPLACE FUNCTION public.song_connected_operators()
RETURNS TABLE(id integer, name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT u."ID_user", COALESCE(un.user_name, 'Usuario ' || u."ID_user")
  FROM public.daily_sesions s
  JOIN public.daily_users u ON u."ID_user" = s."ID_user"
  LEFT JOIN public.daily_users_names un ON un."ID_user" = u."ID_user"
  WHERE s.sesion_active = 1 AND u."ID_user_rol" = 2
    AND public.current_user_is_supervisor()
  ORDER BY 2;
$$;
GRANT EXECUTE ON FUNCTION public.song_connected_operators() TO authenticated;

NOTIFY pgrst, 'reload schema';
