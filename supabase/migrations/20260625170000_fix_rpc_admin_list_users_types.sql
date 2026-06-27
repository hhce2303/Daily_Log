-- =============================================================================
-- Fix rpc_admin_list_users: "structure of query does not match function result
-- type". daily_users.active is smallint (declared integer) and the name/role
-- columns are varchar (declared text); plpgsql RETURN QUERY is strict about
-- this. Cast the columns to the declared types. Also DISTINCT-guard against
-- users that have more than one row in daily_users_names.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_admin_list_users()
RETURNS TABLE(
  id            INTEGER,
  display_name  TEXT,
  role_id       INTEGER,
  role_name     TEXT,
  active         INTEGER
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
    COALESCE(MIN(n.user_name), '(sin nombre)')::text,
    u."ID_user_rol",
    COALESCE(MIN(r.user_rol_name), 'Desconocido')::text,
    u.active::int
  FROM public.daily_users u
  LEFT JOIN public.daily_users_names n ON n."ID_user" = u."ID_user"
  LEFT JOIN public.daily_user_rol    r ON r."ID_user_rol" = u."ID_user_rol"
  GROUP BY u."ID_user", u."ID_user_rol", u.active
  ORDER BY u."ID_user";
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
