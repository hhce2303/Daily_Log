-- =============================================================================
-- Fix column quoting in RPCs that reference daily_stations_map."station_ID".
-- PostgreSQL folds unquoted identifiers to lowercase, so station_ID → station_id
-- which does not match the actual mixed-case column name.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_login_claim_station(p_station_id INTEGER)
RETURNS JSON AS $$
DECLARE
  v_user_id     INTEGER;
  v_session_id  INTEGER;
  v_station_num VARCHAR;
  v_occupied    INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar que no hay sesión activa para este usuario
  IF EXISTS (
    SELECT 1 FROM public.daily_sesions
    WHERE "ID_user" = v_user_id AND sesion_active = 1
  ) THEN
    RAISE EXCEPTION 'Ya existe una sesión activa para este usuario' USING ERRCODE = 'P0002';
  END IF;

  -- Lockear la fila de daily_stations_map para evitar concurrencia
  SELECT station_user INTO v_occupied
  FROM public.daily_stations_map
  WHERE "station_ID" = p_station_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estación no encontrada (ID: %)', p_station_id USING ERRCODE = 'P0003';
  END IF;

  IF v_occupied IS NOT NULL THEN
    RAISE EXCEPTION 'La estación ya está ocupada' USING ERRCODE = 'P0004';
  END IF;

  -- Obtener número de estación
  SELECT station_number INTO v_station_num
  FROM public.daily_stations_info
  WHERE "ID_station" = p_station_id;

  -- Marcar estación como ocupada
  UPDATE public.daily_stations_map
  SET station_user = v_user_id, is_active = 1
  WHERE "station_ID" = p_station_id;

  -- Crear sesión
  INSERT INTO public.daily_sesions ("ID_user", "ID_station", sesion_in, sesion_active, sesion_status)
  VALUES (v_user_id, p_station_id, timezone('utc', now()), 1, 1)
  RETURNING "ID_sesion" INTO v_session_id;

  RETURN json_build_object(
    'session_id',     v_session_id,
    'station_id',     p_station_id,
    'station_number', v_station_num
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.rpc_logout()
RETURNS VOID AS $$
DECLARE
  v_user_id    INTEGER;
  v_station_id INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  -- Obtener la estación de la sesión activa
  SELECT "ID_station" INTO v_station_id
  FROM public.daily_sesions
  WHERE "ID_user" = v_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC
  LIMIT 1;

  -- Cerrar sesión activa
  UPDATE public.daily_sesions
  SET sesion_active = 0,
      sesion_out    = timezone('utc', now()),
      sesion_status = 0
  WHERE "ID_user" = v_user_id AND sesion_active = 1;

  -- Liberar estación si corresponde
  IF v_station_id IS NOT NULL THEN
    UPDATE public.daily_stations_map
    SET station_user = NULL, is_active = 0
    WHERE "station_ID" = v_station_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
