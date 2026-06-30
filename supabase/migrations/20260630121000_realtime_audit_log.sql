-- Add the administrative action trail to Realtime so the Audit page's action
-- log updates live too. RLS already restricts SELECT to supervisors/admins, so
-- Realtime forwards rows only to authorized clients.
ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_audit_log;
ALTER TABLE public.daily_audit_log REPLICA IDENTITY FULL;
