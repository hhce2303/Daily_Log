-- =============================================================================
-- 1. Keep a special in sync with its source event (desktop:
--    update_special_from_event). When the operator edits the event after the
--    special was created/approved, the supervisor was seeing stale data.
--    On a content change we re-derive the special and reset it to PENDING so the
--    supervisor re-reviews the change.
-- 2. Prevent an operator from having more than one open cover request at a time.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sync_special_from_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_site_timezone varchar;
  v_offset        numeric;
  v_spec_datetime timestamp;
BEGIN
  -- React only to content changes, not status-only updates (e.g. draft->confirmed).
  IF NEW."ID_site"        IS DISTINCT FROM OLD."ID_site"
     OR NEW."ID_activity" IS DISTINCT FROM OLD."ID_activity"
     OR NEW.event_quantity    IS DISTINCT FROM OLD.event_quantity
     OR NEW.event_camera      IS DISTINCT FROM OLD.event_camera
     OR NEW.event_description IS DISTINCT FROM OLD.event_description
     OR NEW.event_datetime    IS DISTINCT FROM OLD.event_datetime
  THEN
    SELECT site_timezone INTO v_site_timezone FROM public.daily_sites WHERE "ID_site" = NEW."ID_site";
    v_offset := public.get_timezone_offset(v_site_timezone);
    v_spec_datetime := NEW.event_datetime + ((v_offset - 5) || ' hours')::interval;

    UPDATE public.daily_specials
    SET "ID_site"      = NEW."ID_site",
        "ID_activity"  = NEW."ID_activity",
        spec_quantity    = NEW.event_quantity,
        spec_camera      = NEW.event_camera,
        spec_description = NEW.event_description,
        spec_datetime    = v_spec_datetime,
        spec_status   = NULL,   -- resurfaces as pending for re-review
        spec_marked_at = NULL,
        spec_marked_by = NULL
    WHERE "ID_event" = NEW."ID_event";
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_special_from_event ON public.daily_events;
CREATE TRIGGER trg_sync_special_from_event
  AFTER UPDATE ON public.daily_events
  FOR EACH ROW EXECUTE PROCEDURE public.sync_special_from_event();

-- Block a second open cover request while one is still active.
CREATE OR REPLACE FUNCTION public.prevent_duplicate_cover_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.daily_covers_solicitudes
    WHERE "ID_user" = NEW."ID_user" AND active = 1
  ) THEN
    RAISE EXCEPTION 'Ya tienes una solicitud de cover pendiente. Espera a que se complete antes de pedir otra.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_cover ON public.daily_covers_solicitudes;
CREATE TRIGGER trg_prevent_duplicate_cover
  BEFORE INSERT ON public.daily_covers_solicitudes
  FOR EACH ROW EXECUTE PROCEDURE public.prevent_duplicate_cover_request();
