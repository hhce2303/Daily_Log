-- disconnect_operator now also revokes the operator's Supabase Auth session so
-- the forced disconnect actually logs them out (the client also reacts in
-- realtime via useSessionGuard; this makes it stick even if realtime is missed).
CREATE OR REPLACE FUNCTION public.disconnect_operator(p_user_id integer)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_station_id INTEGER;
  v_auth_id    UUID;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo un supervisor puede desconectar operadores';
  END IF;

  SELECT "ID_station" INTO v_station_id
  FROM public.daily_sesions
  WHERE "ID_user" = p_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC LIMIT 1;

  UPDATE public.daily_sesions
  SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
  WHERE "ID_user" = p_user_id AND sesion_active = 1;

  IF v_station_id IS NOT NULL THEN
    UPDATE public.daily_stations_map
    SET station_user = NULL, is_active = 1
    WHERE "station_ID" = v_station_id;
  END IF;

  SELECT supabase_auth_id INTO v_auth_id FROM public.daily_users WHERE "ID_user" = p_user_id;
  IF v_auth_id IS NOT NULL THEN
    DELETE FROM auth.sessions WHERE user_id = v_auth_id;
  END IF;
END;
$$;
