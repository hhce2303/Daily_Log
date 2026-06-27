-- Add the live tables to the realtime publication so the app can rely on
-- WebSocket (postgres_changes) instead of polling.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'daily_events','daily_specials','daily_covers_solicitudes',
    'daily_covers_completed','daily_ops_schedule'
  ]
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname='supabase_realtime' AND tablename=t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
