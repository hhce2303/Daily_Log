-- Camera Health Check: el supervisor debe poder asignar el chequeo a
-- CUALQUIER usuario activo (no solo a quien esté programado/trabajando hoy).
-- list_supervisors() ya existe pero solo trae roles 1/3/4 (admin/sup/lead);
-- esta trae TODOS los usuarios activos, cualquier rol, para el selector de
-- Daily Ops. Mismo patrón (SECURITY DEFINER, sin filtro de auth ya que solo
-- expone nombres, igual que list_supervisors).

CREATE OR REPLACE FUNCTION public.list_all_operators()
RETURNS TABLE(id integer, name text, role_id integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT u."ID_user", COALESCE(MIN(n.user_name), '(sin nombre)')::text, u."ID_user_rol"
  FROM public.daily_users u
  LEFT JOIN public.daily_users_names n ON n."ID_user" = u."ID_user"
  WHERE u.active = 1
  GROUP BY u."ID_user", u."ID_user_rol"
  ORDER BY MIN(n.user_name);
$function$;

GRANT EXECUTE ON FUNCTION public.list_all_operators() TO anon, authenticated;
