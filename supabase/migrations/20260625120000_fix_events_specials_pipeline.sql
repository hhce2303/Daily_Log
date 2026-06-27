-- =============================================================================
-- Fix the daily_events -> daily_specials pipeline to match the desktop app
-- (SLC v5.0.95: create_event 'draft' -> pipeline -> confirm_event 'confirmed').
--
-- Two bugs fixed:
--   1. after_insert_daily_events was NOT security definer, but daily_specials
--      has RLS enabled with no INSERT policy. Result: inserting an event on a
--      "special site" tried to insert a special, RLS denied it, and the whole
--      event insert failed. (That is why daily_specials was empty.)
--   2. The draft -> confirmed lifecycle was never completed: special-site
--      events stayed 'draft' forever. The desktop only shows 'confirmed'
--      events, so once the special is created we now confirm the event.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.after_insert_daily_events()
RETURNS trigger AS $$
DECLARE
    v_site_timezone VARCHAR;
    v_offset NUMERIC;
    v_spec_datetime TIMESTAMP;
    v_supervisor_id INTEGER;
BEGIN
    IF NEW.event_status = 'draft' THEN
        SELECT "site_timezone" INTO v_site_timezone
        FROM public.daily_sites WHERE "ID_site" = NEW."ID_site";

        v_offset := public.get_timezone_offset(v_site_timezone);
        -- Formula matches the desktop: UTC + (offset - 5) hours
        v_spec_datetime := NEW.event_datetime + ((v_offset - 5) || ' hours')::interval;
        v_supervisor_id := public.get_on_duty_supervisor();

        INSERT INTO public.daily_specials (
            "ID_event", "ID_site", "ID_activity", "ID_user",
            "spec_datetime", "spec_quantity", "spec_camera",
            "spec_description", "ID_supervisor"
        ) VALUES (
            NEW."ID_event", NEW."ID_site", NEW."ID_activity", NEW."ID_user",
            v_spec_datetime, NEW.event_quantity, NEW.event_camera,
            NEW.event_description, COALESCE(v_supervisor_id, 1)
        );

        -- Pipeline succeeded -> confirm the event (desktop: confirm_event()).
        UPDATE public.daily_events
        SET event_status = 'confirmed'
        WHERE "ID_event" = NEW."ID_event";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Safety net mirroring the desktop's cleanup_orphaned_drafts(): any draft event
-- older than N minutes (pipeline never completed) is marked 'failed' so it does
-- not linger or show up. Call manually or from a scheduled job.
CREATE OR REPLACE FUNCTION public.cleanup_orphaned_drafts(p_minutes INTEGER DEFAULT 10)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE public.daily_events
    SET event_status = 'failed'
    WHERE event_status = 'draft'
      AND event_datetime < (timezone('utc', now()) - (p_minutes || ' minutes')::interval);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
