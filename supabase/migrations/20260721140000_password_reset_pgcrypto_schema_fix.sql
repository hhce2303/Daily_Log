-- =============================================================================
-- Fix: rpc_change_my_password fallaba con "function gen_salt(unknown) does not
-- exist" al intentar cambiar la contraseña.
--
-- Causa: crypt()/gen_salt() son de pgcrypto, que en Supabase vive en el schema
-- "extensions" -- NO en "public". La función declara
-- `SET search_path TO 'public'` (buena práctica anti-inyección de search_path),
-- así que esas dos funciones quedaban fuera de alcance. rpc_admin_update_user
-- nunca tuvo el problema porque no declara search_path (hereda el del llamante,
-- que sí incluye extensions).
--
-- Fix: calificar el schema explícitamente (extensions.crypt / extensions.gen_salt)
-- en vez de aflojar el search_path -- así se conserva el endurecimiento y se
-- resuelven las funciones sin ambigüedad. Reproducido y verificado en aislado.
-- =============================================================================

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

  -- pgcrypto vive en "extensions": calificar el schema (ver cabecera).
  UPDATE auth.users
     SET encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
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

-- Limpieza de las funciones temporales de diagnóstico.
DROP FUNCTION IF EXISTS public._tmp_test_searchpath();
DROP FUNCTION IF EXISTS public._tmp_test_searchpath_fixed();
