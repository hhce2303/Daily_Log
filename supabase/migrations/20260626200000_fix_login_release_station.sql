-- Re-login released the previous station with is_active = 0, leaving it stuck as
-- "out of service". A released station must stay in service (just freed).
CREATE OR REPLACE FUNCTION public.rpc_login_claim_station(p_station_id integer)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE
  v_user_id      INTEGER;
  v_session_id   INTEGER;
  v_station_num  VARCHAR;
  v_occupied     INTEGER;
  v_prev_station INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  SELECT "ID_station" INTO v_prev_station
  FROM public.daily_sesions
  WHERE "ID_user" = v_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC LIMIT 1;

  IF v_prev_station IS NOT NULL THEN
    UPDATE public.daily_sesions
    SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
    WHERE "ID_user" = v_user_id AND sesion_active = 1;

    UPDATE public.daily_stations_map
    SET station_user = NULL, is_active = 1   -- freed but stays in service
    WHERE "station_ID" = v_prev_station;
  END IF;

  SELECT station_user INTO v_occupied
  FROM public.daily_stations_map WHERE "station_ID" = p_station_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estación no encontrada (ID: %)', p_station_id USING ERRCODE = 'P0003';
  END IF;
  IF v_occupied IS NOT NULL THEN
    RAISE EXCEPTION 'La estación ya está ocupada' USING ERRCODE = 'P0004';
  END IF;

  SELECT station_number INTO v_station_num
  FROM public.daily_stations_info WHERE "ID_station" = p_station_id;

  UPDATE public.daily_stations_map
  SET station_user = v_user_id, is_active = 1 WHERE "station_ID" = p_station_id;

  INSERT INTO public.daily_sesions ("ID_user", "ID_station", sesion_in, sesion_active, sesion_status)
  VALUES (v_user_id, p_station_id, timezone('utc', now()), 1, 1)
  RETURNING "ID_sesion" INTO v_session_id;

  RETURN json_build_object('session_id', v_session_id, 'station_id', p_station_id, 'station_number', v_station_num);
END;
$function$;

-- Re-baseline any station left out of service by the old bug.
UPDATE public.daily_stations_map SET is_active = 1 WHERE COALESCE(is_active,0) <> 1;
