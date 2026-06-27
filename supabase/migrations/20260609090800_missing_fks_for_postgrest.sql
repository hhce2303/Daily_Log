-- =============================================================================
-- Add missing FK constraints so PostgREST can resolve table relationships
-- for embedded resource queries.
-- NOT VALID skips re-checking existing rows (safe for imported data with
-- potential orphan references).
-- =============================================================================

-- daily_users_names → daily_users (needed by audit, covers, coverTime, specials)
ALTER TABLE public.daily_users_names
  ADD CONSTRAINT fk_users_names_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
    NOT VALID;

-- daily_covers_completed.cover_type → daily_covers_types (needed by coverTime)
ALTER TABLE public.daily_covers_completed
  ADD CONSTRAINT fk_covers_comp_type
    FOREIGN KEY (cover_type) REFERENCES public.daily_covers_types("ID_cover_type")
    NOT VALID;

-- daily_specials.ID_user → daily_users (needed by specials operator name)
ALTER TABLE public.daily_specials
  ADD CONSTRAINT fk_specials_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
    NOT VALID;

-- daily_specials.ID_supervisor → daily_users (needed by specials supervisor name)
ALTER TABLE public.daily_specials
  ADD CONSTRAINT fk_specials_supervisor
    FOREIGN KEY ("ID_supervisor") REFERENCES public.daily_users("ID_user")
    NOT VALID;

-- daily_events.ID_user → daily_users (needed by audit user name embed)
ALTER TABLE public.daily_events
  ADD CONSTRAINT fk_events_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user")
    NOT VALID;

-- daily_events.ID_site → daily_sites (needed by logs/audit site name embed)
ALTER TABLE public.daily_events
  ADD CONSTRAINT fk_events_site
    FOREIGN KEY ("ID_site") REFERENCES public.daily_sites("ID_site")
    NOT VALID;

-- daily_events.ID_activity → daily_activities (needed by logs/audit activity embed)
-- NOTE: daily_activities uses "ID_Activity" (capital A)
ALTER TABLE public.daily_events
  ADD CONSTRAINT fk_events_activity
    FOREIGN KEY ("ID_activity") REFERENCES public.daily_activities("ID_Activity")
    NOT VALID;
