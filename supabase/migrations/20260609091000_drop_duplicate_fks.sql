-- =============================================================================
-- Drop duplicate FK constraints added by 20260609090800 that duplicated
-- the existing constraints from 20260609082000_restore_foreign_keys.sql.
-- =============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_user') THEN
    ALTER TABLE public.daily_events DROP CONSTRAINT fk_events_user;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_site') THEN
    ALTER TABLE public.daily_events DROP CONSTRAINT fk_events_site;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_activity') THEN
    ALTER TABLE public.daily_events DROP CONSTRAINT fk_events_activity;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_user') THEN
    ALTER TABLE public.daily_specials DROP CONSTRAINT fk_specials_user;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_supervisor') THEN
    ALTER TABLE public.daily_specials DROP CONSTRAINT fk_specials_supervisor;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_site') THEN
    ALTER TABLE public.daily_specials DROP CONSTRAINT fk_specials_site;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_activity') THEN
    ALTER TABLE public.daily_specials DROP CONSTRAINT fk_specials_activity;
  END IF;
END $$;
