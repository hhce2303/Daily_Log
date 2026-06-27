-- =============================================================================
-- Add all missing FK constraints for PostgREST embedded resource queries.
-- Replaces the failed 20260609090800 migration (wrong column name: ID_activity
-- vs ID_Activity in daily_activities).
-- Uses DO/IF NOT EXISTS blocks so the migration is idempotent.
-- NOT VALID skips re-checking existing rows (safe for imported data).
-- =============================================================================

-- 1. daily_users_names → daily_users (audit, covers, coverTime, specials)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_names_user') THEN
    ALTER TABLE public.daily_users_names
      ADD CONSTRAINT fk_users_names_user
        FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 2. daily_covers_completed.cover_type → daily_covers_types (coverTime: type name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_covers_comp_type') THEN
    ALTER TABLE public.daily_covers_completed
      ADD CONSTRAINT fk_covers_comp_type
        FOREIGN KEY (cover_type) REFERENCES public.daily_covers_types("ID_cover_type")
        NOT VALID;
  END IF;
END $$;

-- 3. daily_covers_completed.ID_user → daily_users (coverTime: covered user)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_covers_comp_user') THEN
    ALTER TABLE public.daily_covers_completed
      ADD CONSTRAINT fk_covers_comp_user
        FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 4. daily_covers_completed.ID_cover_by → daily_users (coverTime: covering user)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_covers_comp_cover_by') THEN
    ALTER TABLE public.daily_covers_completed
      ADD CONSTRAINT fk_covers_comp_cover_by
        FOREIGN KEY ("ID_cover_by") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 5. daily_covers_solicitudes.ID_user → daily_users (covers: user name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_covers_sol_user') THEN
    ALTER TABLE public.daily_covers_solicitudes
      ADD CONSTRAINT fk_covers_sol_user
        FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 6. daily_covers_solicitudes.ID_station → daily_stations_info (covers: station number)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_covers_sol_station') THEN
    ALTER TABLE public.daily_covers_solicitudes
      ADD CONSTRAINT fk_covers_sol_station
        FOREIGN KEY ("ID_station") REFERENCES public.daily_stations_info("ID_station")
        NOT VALID;
  END IF;
END $$;

-- 7. daily_specials.ID_user → daily_users (specials: operator name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_user') THEN
    ALTER TABLE public.daily_specials
      ADD CONSTRAINT fk_specials_user
        FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 8. daily_specials.ID_supervisor → daily_users (specials: supervisor)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_supervisor') THEN
    ALTER TABLE public.daily_specials
      ADD CONSTRAINT fk_specials_supervisor
        FOREIGN KEY ("ID_supervisor") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 9. daily_specials.ID_site → daily_sites (specials: site name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_site') THEN
    ALTER TABLE public.daily_specials
      ADD CONSTRAINT fk_specials_site
        FOREIGN KEY ("ID_site") REFERENCES public.daily_sites("ID_site")
        NOT VALID;
  END IF;
END $$;

-- 10. daily_specials.ID_activity → daily_activities
--     NOTE: daily_activities.ID_Activity uses capital A
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_specials_activity') THEN
    ALTER TABLE public.daily_specials
      ADD CONSTRAINT fk_specials_activity
        FOREIGN KEY ("ID_activity") REFERENCES public.daily_activities("ID_Activity")
        NOT VALID;
  END IF;
END $$;

-- 11. daily_events.ID_user → daily_users (audit: user name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_user') THEN
    ALTER TABLE public.daily_events
      ADD CONSTRAINT fk_events_user
        FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
        NOT VALID;
  END IF;
END $$;

-- 12. daily_events.ID_site → daily_sites (audit/logs: site name)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_site') THEN
    ALTER TABLE public.daily_events
      ADD CONSTRAINT fk_events_site
        FOREIGN KEY ("ID_site") REFERENCES public.daily_sites("ID_site")
        NOT VALID;
  END IF;
END $$;

-- 13. daily_events.ID_activity → daily_activities
--     NOTE: daily_activities uses "ID_Activity" (capital A),
--           daily_events uses "ID_activity" (lowercase a)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_events_activity') THEN
    ALTER TABLE public.daily_events
      ADD CONSTRAINT fk_events_activity
        FOREIGN KEY ("ID_activity") REFERENCES public.daily_activities("ID_Activity")
        NOT VALID;
  END IF;
END $$;
