-- =============================================================================
-- RPC: Sesiones y estaciones
-- Equivalente a apps/users/services.py del backend Django
-- =============================================================================

-- Helper: obtener ID_user del usuario autenticado actualmente
CREATE OR REPLACE FUNCTION public.current_daily_user_id()
RETURNS INTEGER AS $$
DECLARE
  v_user_id INTEGER;
BEGIN
  SELECT "ID_user" INTO v_user_id
  FROM public.daily_users
  WHERE supabase_auth_id = auth.uid();
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Helper: obtener rol del usuario autenticado actualmente
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT r.user_rol_name INTO v_role
  FROM public.daily_users u
  JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
  WHERE u.supabase_auth_id = auth.uid();
  RETURN v_role;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- =============================================================================
-- RPC: rpc_login_claim_station
-- Reclama una estación y abre una sesión para el usuario autenticado.
-- Reglas:
--   1. No puede haber sesión activa del mismo usuario.
--   2. La estación debe existir y no estar ocupada.
-- Devuelve: { session_id, station_id, station_number }
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
  WHERE station_ID = p_station_id
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
  WHERE station_ID = p_station_id;

  -- Crear sesión
  INSERT INTO public.daily_sesions ("ID_user", "ID_station", sesion_in, sesion_active, sesion_status)
  VALUES (v_user_id, p_station_id, timezone('utc', now()), 1, 1)
  RETURNING "ID_sesion" INTO v_session_id;

  RETURN json_build_object(
    'session_id',    v_session_id,
    'station_id',    p_station_id,
    'station_number', v_station_num
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RPC: rpc_logout
-- Cierra la sesión activa y libera la estación del usuario autenticado.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.rpc_logout()
RETURNS VOID AS $$
DECLARE
  v_user_id    INTEGER;
  v_station_id INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RETURN; -- noop si no está autenticado
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
    WHERE station_ID = v_station_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RPC: rpc_set_status
-- Actualiza el status de la sesión activa del usuario (0=offline, 1=activo, 2=disponible para cover).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.rpc_set_status(p_status INTEGER)
RETURNS VOID AS $$
DECLARE
  v_user_id INTEGER;
BEGIN
  IF p_status NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'Estado inválido: % (válidos: 0, 1, 2)', p_status USING ERRCODE = 'P0005';
  END IF;

  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.daily_sesions
  SET sesion_status = p_status
  WHERE "ID_user" = v_user_id AND sesion_active = 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RPC: rpc_me
-- Devuelve perfil del usuario autenticado + información de sesión activa real.
-- Reemplaza el hack de localStorage.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.rpc_me()
RETURNS JSON AS $$
DECLARE
  v_user_id    INTEGER;
  v_role_name  TEXT;
  v_role_id    INTEGER;
  v_user_name  TEXT;
  v_session    JSON := NULL;
  v_active_row RECORD;
BEGIN
  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  -- Obtener rol y nombre
  SELECT r.user_rol_name, u."ID_user_rol"
  INTO v_role_name, v_role_id
  FROM public.daily_users u
  JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
  WHERE u."ID_user" = v_user_id;

  SELECT user_name INTO v_user_name
  FROM public.daily_users_names
  WHERE "ID_user" = v_user_id;

  -- Obtener sesión activa si existe
  SELECT s."ID_sesion", s."ID_station", s.sesion_in, s.sesion_status,
         si.station_number
  INTO v_active_row
  FROM public.daily_sesions s
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  WHERE s."ID_user" = v_user_id AND s.sesion_active = 1
  ORDER BY s.sesion_in DESC
  LIMIT 1;

  IF v_active_row."ID_sesion" IS NOT NULL THEN
    v_session := json_build_object(
      'id',             v_active_row."ID_sesion",
      'station_id',     v_active_row."ID_station",
      'station_number', v_active_row.station_number,
      'sesion_in',      v_active_row.sesion_in,
      'status',         v_active_row.sesion_status
    );
  END IF;

  RETURN json_build_object(
    'id',       v_user_id,
    'name',     COALESCE(v_user_name, ''),
    'role_id',  v_role_id,
    'role',     LOWER(REPLACE(COALESCE(v_role_name, 'operador'), ' ', '_')),
    'session',  v_session
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
