-- =============================================================================
-- Restablecimiento ÚNICO de contraseña.
--
-- Flujo: el admin habilita la opción para uno o varios operadores. A cada uno le
-- llega un aviso EN TIEMPO REAL ("reinicia la app para personalizar tu
-- contraseña") pero puede seguir trabajando. Al reiniciar/re-entrar, el sistema
-- lo obliga a crear una contraseña nueva; al hacerlo, la obligación se apaga
-- SOLA y no vuelve a salir (una sola vez).
--
-- Decisiones de diseño:
--   • Tabla dedicada (no una columna en daily_users): daily_users tiene
--     user_password/supabase_auth_id, y para el aviso en tiempo real hay que
--     publicar la tabla en supabase_realtime -- publicar daily_users mandaría
--     hashes de contraseña por el socket a los clientes suscritos. Esta tabla
--     solo tiene ids y fechas, nada sensible.
--   • "Una sola vez" se hace cumplir en el SERVIDOR (rpc_change_my_password
--     exige una solicitud abierta), no solo escondiendo el botón en la UI.
--   • El aviso inmediato reusa daily_station_messages (el sistema de
--     notificaciones ya existente: modal + beep + notificación de escritorio),
--     sin expiración porque es una obligación pendiente, no info transitoria.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_password_reset_requests (
  id serial PRIMARY KEY,
  "ID_user" integer NOT NULL UNIQUE,
  created_by integer,
  created_at timestamp NOT NULL DEFAULT timezone('utc', now()),
  completed_at timestamp  -- NULL = pendiente (debe cambiarla); con fecha = ya la cambió
);

CREATE INDEX IF NOT EXISTS daily_password_reset_pending_idx
  ON public.daily_password_reset_requests ("ID_user") WHERE completed_at IS NULL;

ALTER TABLE public.daily_password_reset_requests ENABLE ROW LEVEL SECURITY;

-- Realtime: el aviso/banner debe aparecer y desaparecer al instante. Con
-- REPLICA IDENTITY FULL el filtro por usuario se evalúa bien en UPDATE.
ALTER TABLE public.daily_password_reset_requests REPLICA IDENTITY FULL;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_password_reset_requests;
EXCEPTION
  WHEN undefined_object THEN RAISE NOTICE 'publicación supabase_realtime no existe; se omite';
  WHEN duplicate_object THEN RAISE NOTICE 'tabla ya estaba en la publicación';
END;
$$;

-- ── Admin: habilitar / quitar la obligación para uno o varios usuarios ──────

CREATE OR REPLACE FUNCTION public.rpc_admin_set_password_reset(
  p_user_ids integer[],
  p_enabled boolean DEFAULT true
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_admin integer;
  v_uid integer;
  v_n integer := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;
  v_admin := public.current_daily_user_id();

  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  FOREACH v_uid IN ARRAY p_user_ids LOOP
    IF p_enabled THEN
      -- Reabrir (o crear) la solicitud. completed_at = NULL => pendiente.
      INSERT INTO public.daily_password_reset_requests ("ID_user", created_by, created_at, completed_at)
      VALUES (v_uid, v_admin, timezone('utc', now()), NULL)
      ON CONFLICT ("ID_user") DO UPDATE
        SET created_by = EXCLUDED.created_by,
            created_at = EXCLUDED.created_at,
            completed_at = NULL;

      -- Aviso inmediato (realtime) al operador, aunque esté trabajando. Sin
      -- expiración: es una obligación pendiente, no información transitoria.
      INSERT INTO public.daily_station_messages
        ("ID_sender_user", "ID_target_user", message_type, message_title, message_body,
         created_at, is_active, expires_at)
      VALUES (v_admin, v_uid, 'warning', '🔑 Personaliza tu contraseña',
              'Por favor, reinicia la aplicación para personalizar tu contraseña.',
              timezone('utc', now()), 1, NULL);
    ELSE
      -- Quitar la obligación sin haber cambiado nada (el admin se arrepintió).
      DELETE FROM public.daily_password_reset_requests WHERE "ID_user" = v_uid;
    END IF;
    v_n := v_n + 1;
  END LOOP;

  RETURN v_n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_admin_set_password_reset(integer[], boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_set_password_reset(integer[], boolean) TO authenticated;

-- ── Operador: cambiar SU propia contraseña (una sola vez) ───────────────────

CREATE OR REPLACE FUNCTION public.rpc_change_my_password(p_new_password text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_user_id integer;
  v_auth_id uuid;
  v_pass text := COALESCE(p_new_password, '');
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  -- "Una sola vez" se hace cumplir acá, no en la UI: sin una solicitud abierta
  -- del admin, nadie puede usar este RPC.
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_password_reset_requests
    WHERE "ID_user" = v_user_id AND completed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'NO_RESET_PENDING: no tienes un restablecimiento de contraseña habilitado'
      USING ERRCODE = 'P0004';
  END IF;

  IF length(v_pass) < 6 THEN
    RAISE EXCEPTION 'PASSWORD_TOO_SHORT: la contraseña debe tener al menos 6 caracteres'
      USING ERRCODE = 'P0004';
  END IF;
  IF v_pass <> btrim(v_pass) THEN
    RAISE EXCEPTION 'PASSWORD_INVALID: la contraseña no puede empezar ni terminar con espacios'
      USING ERRCODE = 'P0004';
  END IF;

  SELECT supabase_auth_id INTO v_auth_id
  FROM public.daily_users WHERE "ID_user" = v_user_id;
  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'NO_AUTH_USER: el usuario no tiene identidad de autenticación'
      USING ERRCODE = 'P0004';
  END IF;

  -- Mismo mecanismo que rpc_admin_update_user (fuente real de la contraseña).
  UPDATE auth.users
     SET encrypted_password = crypt(v_pass, gen_salt('bf')),
         updated_at = now()
   WHERE id = v_auth_id;

  -- Apagar la obligación: no vuelve a salir (a menos que el admin la reabra).
  UPDATE public.daily_password_reset_requests
     SET completed_at = timezone('utc', now())
   WHERE "ID_user" = v_user_id AND completed_at IS NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_change_my_password(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_change_my_password(text) TO authenticated;

-- ── rpc_me expone la bandera (para forzar el flujo al reiniciar) ────────────

CREATE OR REPLACE FUNCTION public.rpc_me()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE
  v_user_id    INTEGER;
  v_role_name  TEXT;
  v_role_id    INTEGER;
  v_user_name  TEXT;
  v_session    JSON := NULL;
  v_active_row RECORD;
  v_must_reset BOOLEAN;
BEGIN
  v_user_id := public.current_daily_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001';
  END IF;

  SELECT r.user_rol_name, u."ID_user_rol"
  INTO v_role_name, v_role_id
  FROM public.daily_users u
  JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
  WHERE u."ID_user" = v_user_id;

  SELECT user_name INTO v_user_name
  FROM public.daily_users_names
  WHERE "ID_user" = v_user_id;

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

  SELECT EXISTS (
    SELECT 1 FROM public.daily_password_reset_requests
    WHERE "ID_user" = v_user_id AND completed_at IS NULL
  ) INTO v_must_reset;

  RETURN json_build_object(
    'id',       v_user_id,
    'name',     COALESCE(v_user_name, ''),
    'role_id',  v_role_id,
    'role',     LOWER(REPLACE(COALESCE(v_role_name, 'operador'), ' ', '_')),
    'session',  v_session,
    'must_reset_password', v_must_reset
  );
END;
$function$;

-- ── Bandera propia, ligera (para el banner en tiempo real) ──────────────────

CREATE OR REPLACE FUNCTION public.rpc_my_password_reset_pending()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.daily_password_reset_requests
    WHERE "ID_user" = public.current_daily_user_id() AND completed_at IS NULL
  );
$$;
GRANT EXECUTE ON FUNCTION public.rpc_my_password_reset_pending() TO authenticated;

-- ── Admin: ver quién tiene la obligación pendiente (para la UI de usuarios) ──

CREATE OR REPLACE FUNCTION public.rpc_admin_list_password_resets()
RETURNS TABLE("ID_user" integer, created_at timestamp, completed_at timestamp)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;
  RETURN QUERY
    SELECT r."ID_user", r.created_at, r.completed_at
    FROM public.daily_password_reset_requests r;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_admin_list_password_resets() TO authenticated;
