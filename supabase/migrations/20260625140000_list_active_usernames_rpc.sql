-- =============================================================================
-- Allow logging in by display name (e.g. "Juan R") instead of the internal
-- "daily_xx" email handle.
--
-- get_email_by_username() already resolves a display name -> auth email, but
-- the login screen could not list names because daily_users_names is RLS-locked
-- to authenticated users only (anon can't read it pre-login).
--
-- This SECURITY DEFINER function exposes ONLY the list of active display names
-- (no emails, ids or passwords) to the anon role so the login can offer
-- type-ahead suggestions.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.list_active_usernames()
RETURNS text[]
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(user_name ORDER BY user_name), ARRAY[]::text[])
  FROM (
    SELECT DISTINCT un.user_name
    FROM public.daily_users_names un
    JOIN public.daily_users u ON u."ID_user" = un."ID_user"
    WHERE u.active = 1
      AND un.user_name IS NOT NULL
      AND TRIM(un.user_name) <> ''
  ) s;
$$;

GRANT EXECUTE ON FUNCTION public.list_active_usernames() TO anon, authenticated;
