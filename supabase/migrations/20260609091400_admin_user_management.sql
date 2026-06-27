-- =============================================================================
-- Admin User Management RPCs
-- Requires: pgcrypto (available by default in Supabase)
-- =============================================================================

-- Grant pre-login display-name resolution to unauthenticated clients
GRANT EXECUTE ON FUNCTION public.get_email_by_username(text) TO anon;

-- ---------------------------------------------------------------------------
-- 1. List all users (admin only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_list_users()
RETURNS TABLE(
  id            INTEGER,
  display_name  TEXT,
  role_id       INTEGER,
  role_name     TEXT,
  active        INTEGER
) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  RETURN QUERY
  SELECT
    u."ID_user",
    COALESCE(n.user_name, '(sin nombre)'),
    u."ID_user_rol",
    COALESCE(r.user_rol_name, 'Desconocido'),
    u.active
  FROM public.daily_users u
  LEFT JOIN public.daily_users_names n ON n."ID_user" = u."ID_user"
  LEFT JOIN public.daily_user_rol    r ON r."ID_user_rol" = u."ID_user_rol"
  ORDER BY u."ID_user";
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 2. Create user (admin only)
--    Inserts into auth.users → handle_new_user trigger creates daily_users
--    row with role=2 (Operador); we then correct the role and add the name.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_create_user(
  p_display_name TEXT,
  p_password     TEXT,
  p_role_id      INTEGER
)
RETURNS INTEGER AS $$
DECLARE
  v_auth_id UUID;
  v_user_id INTEGER;
  v_email   TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  -- Sanitize display name → internal email
  v_email := lower(regexp_replace(p_display_name, '[^a-zA-Z0-9]', '_', 'g')) || '@daily.local';

  IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
    RAISE EXCEPTION 'Ya existe un usuario con un nombre similar (email interno: %)', v_email;
  END IF;

  v_auth_id := gen_random_uuid();

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    is_sso_user
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_auth_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt(p_password, gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    false,
    now(),
    now(),
    '', '', '', '',
    false
  );
  -- handle_new_user trigger fires, creating daily_users with role=2 (Operador)

  -- Correct role
  UPDATE public.daily_users
    SET "ID_user_rol" = p_role_id
    WHERE supabase_auth_id = v_auth_id;

  -- Get generated ID_user
  SELECT "ID_user" INTO v_user_id
    FROM public.daily_users WHERE supabase_auth_id = v_auth_id;

  -- Insert display name
  INSERT INTO public.daily_users_names ("ID_user", user_name)
    VALUES (v_user_id, p_display_name);

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 3. Update user: name, role, active status, optional password reset
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_update_user(
  p_user_id      INTEGER,
  p_display_name TEXT,
  p_role_id      INTEGER,
  p_active       INTEGER DEFAULT 1,
  p_new_password TEXT    DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_auth_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  -- Update or insert display name
  UPDATE public.daily_users_names
    SET user_name = p_display_name
    WHERE "ID_user" = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.daily_users_names ("ID_user", user_name)
      VALUES (p_user_id, p_display_name);
  END IF;

  -- Update role and active status
  UPDATE public.daily_users
    SET "ID_user_rol" = p_role_id,
        active = p_active
    WHERE "ID_user" = p_user_id;

  -- Optional password reset
  IF p_new_password IS NOT NULL AND length(trim(p_new_password)) > 0 THEN
    SELECT supabase_auth_id INTO v_auth_id
      FROM public.daily_users WHERE "ID_user" = p_user_id;

    IF v_auth_id IS NOT NULL THEN
      UPDATE auth.users
        SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
            updated_at = now()
        WHERE id = v_auth_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 4. Delete user: removes auth access (deactivates + removes from auth.users)
--    Historical data (events, sessions) is preserved in daily_users.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_admin_delete_user(p_user_id INTEGER)
RETURNS VOID AS $$
DECLARE
  v_auth_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid() AND "ID_user_rol" = 1
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  SELECT supabase_auth_id INTO v_auth_id
    FROM public.daily_users WHERE "ID_user" = p_user_id;

  -- Deactivate in daily_users (preserves historical data)
  UPDATE public.daily_users
    SET active = 0, supabase_auth_id = NULL
    WHERE "ID_user" = p_user_id;

  -- Remove from auth.users (cascades to auth.sessions → revokes all active logins)
  IF v_auth_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = v_auth_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution to authenticated role (functions check admin internally)
GRANT EXECUTE ON FUNCTION public.rpc_admin_list_users()                                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_admin_create_user(text, text, integer)               TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_admin_update_user(integer, text, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_admin_delete_user(integer)                           TO authenticated;

NOTIFY pgrst, 'reload schema';
