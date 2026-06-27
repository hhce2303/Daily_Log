-- Drop any lingering duplicate FK constraints on daily_specials that duplicate
-- the original specials_id_* constraints from 20260609082000_restore_foreign_keys.sql.
-- Also issues a NOTIFY to force PostgREST schema cache reload.

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

-- Force PostgREST to reload its schema cache immediately
NOTIFY pgrst, 'reload schema';
