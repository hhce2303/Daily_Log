-- =============================================================================
-- 1. Editing an event must NOT un-approve its special. Keep the special's data
--    in sync with the event, but preserve spec_status/marked_by/marked_at so a
--    supervisor's correction in Audit doesn't bounce it back to pending.
-- 2. User-targeted notifications/alerts (sent e.g. from the station map).
-- =============================================================================

-- 1) Sync special data only (no status reset) -------------------------------
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
        spec_datetime    = v_spec_datetime
        -- NOTE: spec_status / spec_marked_* intentionally preserved
    WHERE "ID_event" = NEW."ID_event";
  END IF;
  RETURN NEW;
END;
$$;

-- 2) Notifications -----------------------------------------------------------
-- Auto-increment for ID_message (had no default sequence).
CREATE SEQUENCE IF NOT EXISTS daily_station_messages_id_seq;
ALTER TABLE public.daily_station_messages
  ALTER COLUMN "ID_message" SET DEFAULT nextval('daily_station_messages_id_seq');
ALTER SEQUENCE daily_station_messages_id_seq OWNED BY public.daily_station_messages."ID_message";
SELECT setval('daily_station_messages_id_seq',
  COALESCE((SELECT MAX("ID_message") FROM public.daily_station_messages), 0) + 1, false);

-- Target a specific user (in addition to the legacy station target).
ALTER TABLE public.daily_station_messages
  ADD COLUMN IF NOT EXISTS "ID_target_user" integer;

-- RLS: a user sees notifications addressed to them (or that they sent); supervisors see all.
ALTER TABLE public.daily_station_messages ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.daily_station_messages FROM anon;
DROP POLICY IF EXISTS msg_select_own ON public.daily_station_messages;
CREATE POLICY msg_select_own ON public.daily_station_messages
  FOR SELECT TO authenticated
  USING (
    "ID_target_user" = public.current_daily_user_id()
    OR "ID_sender_user" = public.current_daily_user_id()
    OR public.current_user_is_supervisor()
  );
DROP POLICY IF EXISTS msg_update_own ON public.daily_station_messages;
CREATE POLICY msg_update_own ON public.daily_station_messages
  FOR UPDATE TO authenticated
  USING ("ID_target_user" = public.current_daily_user_id())
  WITH CHECK ("ID_target_user" = public.current_daily_user_id());

-- Realtime
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname='supabase_realtime' AND tablename='daily_station_messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_station_messages;
  END IF;
END $$;

-- Send a notification to a user.
CREATE OR REPLACE FUNCTION public.send_notification(
  p_target_user_id integer,
  p_title          text,
  p_body           text,
  p_type           text DEFAULT 'info'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id integer;
BEGIN
  IF public.current_daily_user_id() IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;
  INSERT INTO public.daily_station_messages
    ("ID_sender_user", "ID_target_user", message_type, message_title, message_body, created_at, is_active)
  VALUES
    (public.current_daily_user_id(), p_target_user_id, COALESCE(p_type,'info'),
     p_title, p_body, timezone('utc', now()), 1)
  RETURNING "ID_message" INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_notification(integer, text, text, text) TO authenticated;

-- Mark a notification as read.
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id integer)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.daily_station_messages
  SET read_at = timezone('utc', now())
  WHERE "ID_message" = p_id AND "ID_target_user" = public.current_daily_user_id();
$$;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(integer) TO authenticated;

-- Recent notifications addressed to the current user (joined with sender name).
CREATE OR REPLACE FUNCTION public.fetch_my_notifications(p_limit integer DEFAULT 30)
RETURNS TABLE(
  id integer, sender text, type text, title text, body text,
  created_at timestamp, read_at timestamp
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT m."ID_message",
         COALESCE(MIN(n.user_name), 'Sistema')::text,
         m.message_type::text, m.message_title::text, m.message_body,
         m.created_at, m.read_at
  FROM public.daily_station_messages m
  LEFT JOIN public.daily_users_names n ON n."ID_user" = m."ID_sender_user"
  WHERE m."ID_target_user" = public.current_daily_user_id()
    AND COALESCE(m.is_active, 1) = 1
  GROUP BY m."ID_message", m.message_type, m.message_title, m.message_body, m.created_at, m.read_at
  ORDER BY m."ID_message" DESC
  LIMIT p_limit;
$$;
GRANT EXECUTE ON FUNCTION public.fetch_my_notifications(integer) TO authenticated;
