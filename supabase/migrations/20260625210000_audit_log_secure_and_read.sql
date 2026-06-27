-- =============================================================================
-- Secure the audit log and expose a read RPC.
--
-- daily_audit_log had RLS OFF and granted anon+authenticated full DML
-- (incl. DELETE/TRUNCATE) — anyone could wipe the audit trail. Lock it down:
-- writes only via the SECURITY DEFINER trigger; reads only for supervisors/admins.
-- =============================================================================

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.daily_audit_log FROM anon, authenticated;
REVOKE SELECT ON public.daily_audit_log FROM anon;

ALTER TABLE public.daily_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_select_supervisor ON public.daily_audit_log;
CREATE POLICY audit_select_supervisor ON public.daily_audit_log
  FOR SELECT TO authenticated
  USING (public.current_user_is_supervisor());

-- Read the action log joined with the actor's display name (supervisor/admin only).
CREATE OR REPLACE FUNCTION public.fetch_audit_log(p_limit integer DEFAULT 200)
RETURNS TABLE(
  id          bigint,
  created_at  timestamp,
  user_name   text,
  action      text,
  resource    text,
  resource_id integer,
  detail      text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RETURN;  -- non-supervisors get nothing
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.created_at,
    COALESCE(MIN(n.user_name), '(sistema)')::text,
    a.action::text,
    a.resource::text,
    a.resource_id,
    a.detail
  FROM public.daily_audit_log a
  LEFT JOIN public.daily_users_names n ON n."ID_user" = a.user_id
  GROUP BY a.id, a.created_at, a.action, a.resource, a.resource_id, a.detail
  ORDER BY a.id DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_audit_log(integer) TO authenticated;
