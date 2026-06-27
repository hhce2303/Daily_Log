-- =============================================================================
-- 1. Logout must NOT mark the station out-of-service. It should just release the
--    operator; the station stays in service (available).
-- 2. Let supervisors force-disconnect an operator from the station map.
-- 3. Restrict sending notifications to supervisors/leads/admins.
-- =============================================================================

-- 1) Fix logout: keep station in service ------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_logout()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    INTEGER;
  v_station_id INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT "ID_station" INTO v_station_id
  FROM public.daily_sesions
  WHERE "ID_user" = v_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC LIMIT 1;

  UPDATE public.daily_sesions
  SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
  WHERE "ID_user" = v_user_id AND sesion_active = 1;

  IF v_station_id IS NOT NULL THEN
    UPDATE public.daily_stations_map
    SET station_user = NULL, is_active = 1   -- stays in service, just freed
    WHERE "station_ID" = v_station_id;
  END IF;
END;
$$;

-- Re-baseline: stations stuck out-of-service by the old logout bug.
UPDATE public.daily_stations_map SET is_active = 1 WHERE COALESCE(is_active,0) <> 1;

-- 2) Supervisor force-disconnect of an operator -----------------------------
CREATE OR REPLACE FUNCTION public.disconnect_operator(p_user_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_station_id INTEGER;
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
END;
$$;
GRANT EXECUTE ON FUNCTION public.disconnect_operator(integer) TO authenticated;

-- 3) Only supervisors/leads/admins may send notifications -------------------
CREATE OR REPLACE FUNCTION public.send_notification(
  p_target_user_id integer,
  p_title          text,
  p_body           text,
  p_type           text DEFAULT 'info'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden enviar notificaciones';
  END IF;
  INSERT INTO public.daily_station_messages
    ("ID_sender_user", "ID_target_user", message_type, message_title, message_body, created_at, is_active)
  VALUES
    (public.current_daily_user_id(), p_target_user_id, COALESCE(p_type,'info'),
     p_title, p_body, timezone('utc', now()), 1)
  RETURNING "ID_message" INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_notification(integer, text, text, text) TO authenticated;
