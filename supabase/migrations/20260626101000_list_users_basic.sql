-- Lightweight user list (id + name) for the notification recipient picker.
CREATE OR REPLACE FUNCTION public.list_users_basic()
RETURNS TABLE(id integer, name text, role_id integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT u."ID_user", COALESCE(MIN(n.user_name),'(sin nombre)')::text, u."ID_user_rol"
  FROM public.daily_users u
  LEFT JOIN public.daily_users_names n ON n."ID_user" = u."ID_user"
  WHERE u.active = 1
  GROUP BY u."ID_user", u."ID_user_rol"
  ORDER BY MIN(n.user_name);
$$;
GRANT EXECUTE ON FUNCTION public.list_users_basic() TO authenticated;
