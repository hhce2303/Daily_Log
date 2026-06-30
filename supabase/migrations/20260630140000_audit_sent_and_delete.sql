-- =============================================================================
-- Audit: track which records were already sent (PDF downloaded), let supervisors
-- toggle that flag, and permanently delete records.
-- =============================================================================

-- "Sent" tracking columns on both audit sources.
ALTER TABLE public.daily_events   ADD COLUMN IF NOT EXISTS sent_at timestamp;
ALTER TABLE public.daily_events   ADD COLUMN IF NOT EXISTS sent_by integer;
ALTER TABLE public.daily_specials ADD COLUMN IF NOT EXISTS sent_at timestamp;
ALTER TABLE public.daily_specials ADD COLUMN IF NOT EXISTS sent_by integer;

-- Mark / unmark a single record as sent (supervisors & admins).
CREATE OR REPLACE FUNCTION public.audit_set_sent(
  p_id integer, p_is_special boolean, p_sent boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ts timestamp; v_by integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden marcar registros como enviados';
  END IF;
  v_ts := CASE WHEN p_sent THEN timezone('utc', now()) ELSE NULL END;
  v_by := CASE WHEN p_sent THEN public.current_daily_user_id() ELSE NULL END;
  IF p_is_special THEN
    UPDATE public.daily_specials SET sent_at = v_ts, sent_by = v_by WHERE "ID_special" = p_id;
  ELSE
    UPDATE public.daily_events   SET sent_at = v_ts, sent_by = v_by WHERE "ID_event"   = p_id;
  END IF;
END; $$;

-- Bulk-mark records sent (called after a group PDF is downloaded).
CREATE OR REPLACE FUNCTION public.audit_mark_sent_bulk(
  p_ids integer[], p_is_special boolean)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_by integer; n integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores';
  END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN 0; END IF;
  v_by := public.current_daily_user_id();
  IF p_is_special THEN
    UPDATE public.daily_specials SET sent_at = timezone('utc', now()), sent_by = v_by
    WHERE "ID_special" = ANY(p_ids);
  ELSE
    UPDATE public.daily_events   SET sent_at = timezone('utc', now()), sent_by = v_by
    WHERE "ID_event"   = ANY(p_ids);
  END IF;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $$;

-- Permanently delete a record (supervisors & admins). No FK enforces the
-- special<->event link, so we clean both sides manually:
--   special -> also delete its source event
--   event   -> also delete any specials derived from it
CREATE OR REPLACE FUNCTION public.audit_delete_record(
  p_id integer, p_is_special boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_event integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden eliminar registros';
  END IF;
  IF p_is_special THEN
    SELECT "ID_event" INTO v_event FROM public.daily_specials WHERE "ID_special" = p_id;
    DELETE FROM public.daily_specials WHERE "ID_special" = p_id;
    IF v_event IS NOT NULL THEN
      DELETE FROM public.daily_events WHERE "ID_event" = v_event;
    END IF;
  ELSE
    DELETE FROM public.daily_specials WHERE "ID_event" = p_id;
    DELETE FROM public.daily_events   WHERE "ID_event" = p_id;
  END IF;
END; $$;

GRANT EXECUTE ON FUNCTION public.audit_set_sent(integer, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_mark_sent_bulk(integer[], boolean)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_delete_record(integer, boolean)     TO authenticated;
