-- =============================================================================
-- Let admins reassign a special to any supervisor (desktop:
-- transfer_specials_to_supervisor), e.g. when the on-duty supervisor isn't
-- available to handle it.
-- =============================================================================

-- List active supervisors/leads/admins for the reassignment picker.
CREATE OR REPLACE FUNCTION public.list_supervisors()
RETURNS TABLE(id integer, name text, role_id integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u."ID_user", COALESCE(MIN(n.user_name), '(sin nombre)')::text, u."ID_user_rol"
  FROM public.daily_users u
  LEFT JOIN public.daily_users_names n ON n."ID_user" = u."ID_user"
  WHERE u."ID_user_rol" IN (1, 3, 4) AND u.active = 1
  GROUP BY u."ID_user", u."ID_user_rol"
  ORDER BY MIN(n.user_name);
$$;

GRANT EXECUTE ON FUNCTION public.list_supervisors() TO authenticated;

-- Reassign a special to another supervisor (admin only).
CREATE OR REPLACE FUNCTION public.admin_reassign_special(
  p_special_id   integer,
  p_supervisor_id integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_rol integer;
BEGIN
  SELECT "ID_user_rol" INTO v_caller_rol
  FROM public.daily_users WHERE supabase_auth_id = auth.uid();

  IF v_caller_rol IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'Solo un administrador puede reasignar specials';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE "ID_user" = p_supervisor_id AND "ID_user_rol" IN (1, 3, 4) AND active = 1
  ) THEN
    RAISE EXCEPTION 'El usuario destino no es un supervisor activo';
  END IF;

  UPDATE public.daily_specials
  SET "ID_supervisor" = p_supervisor_id
  WHERE "ID_special" = p_special_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reassign_special(integer, integer) TO authenticated;
