-- =============================================================================
-- Record special status changes in daily_audit_log (nothing was writing to it).
-- Gives an audit trail of who approved/flagged/reset each special and when.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_special_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.spec_status IS DISTINCT FROM OLD.spec_status THEN
    INSERT INTO public.daily_audit_log
      (user_id, action, resource, resource_id, detail, created_at)
    VALUES (
      public.current_daily_user_id(),
      COALESCE(NEW.spec_status, 'pending'),
      'special',
      NEW."ID_special",
      'Special ' || NEW."ID_special" || ' estado: '
        || COALESCE(OLD.spec_status, 'pendiente') || ' -> '
        || COALESCE(NEW.spec_status, 'pendiente'),
      timezone('utc', now())
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_special_status ON public.daily_specials;
CREATE TRIGGER trg_log_special_status
  AFTER UPDATE ON public.daily_specials
  FOR EACH ROW EXECUTE PROCEDURE public.log_special_status_change();
