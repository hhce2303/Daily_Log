-- Make the special-status audit trigger best-effort: a failed audit insert
-- (e.g. NOT NULL user_id when no daily user is in context) must NEVER block the
-- status change itself.

CREATE OR REPLACE FUNCTION public.log_special_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid integer;
BEGIN
  IF NEW.spec_status IS DISTINCT FROM OLD.spec_status THEN
    v_uid := COALESCE(public.current_daily_user_id(), NEW.spec_marked_by, OLD.spec_marked_by);
    BEGIN
      INSERT INTO public.daily_audit_log
        (user_id, action, resource, resource_id, detail, created_at)
      VALUES (
        v_uid,
        COALESCE(NEW.spec_status, 'pending'),
        'special',
        NEW."ID_special",
        'Special ' || NEW."ID_special" || ' estado: '
          || COALESCE(OLD.spec_status, 'pendiente') || ' -> '
          || COALESCE(NEW.spec_status, 'pendiente'),
        timezone('utc', now())
      );
    EXCEPTION WHEN OTHERS THEN
      -- audit is best-effort; never block the status change
      NULL;
    END;
  END IF;
  RETURN NEW;
END;
$$;
