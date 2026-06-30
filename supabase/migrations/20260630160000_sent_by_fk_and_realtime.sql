-- =============================================================================
-- Add FK constraints on sent_by so PostgREST can resolve embedded joins for
-- the "who marked this as sent?" feature. Also ensure both tables publish
-- realtime events for UPDATE (needed so the "sent" status propagates live
-- across all open audit tabs via WebSocket).
-- =============================================================================

-- FK: daily_events.sent_by → daily_users.ID_user
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'daily_events_sent_by_fkey'
      AND table_name = 'daily_events'
  ) THEN
    ALTER TABLE public.daily_events
      ADD CONSTRAINT daily_events_sent_by_fkey
      FOREIGN KEY (sent_by) REFERENCES public.daily_users("ID_user");
  END IF;
END $$;

-- FK: daily_specials.sent_by → daily_users.ID_user
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'daily_specials_sent_by_fkey'
      AND table_name = 'daily_specials'
  ) THEN
    ALTER TABLE public.daily_specials
      ADD CONSTRAINT daily_specials_sent_by_fkey
      FOREIGN KEY (sent_by) REFERENCES public.daily_users("ID_user");
  END IF;
END $$;
