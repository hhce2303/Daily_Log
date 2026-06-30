-- =============================================================================
-- Make Realtime deliver UPDATE/DELETE events on RLS-protected tables.
--
-- Supabase Realtime evaluates RLS for every change it forwards. For UPDATE and
-- DELETE the policy is checked against the OLD row, but with the default
-- REPLICA IDENTITY the WAL only carries the primary key of the OLD tuple — so
-- policies that reference other columns can't be evaluated and Realtime SILENTLY
-- DROPS the event. INSERTs are unaffected (the full new row is in the WAL), which
-- is why notifications (INSERT) worked while logout (UPDATE daily_sesions) and
-- "mark special done" (UPDATE daily_specials) never reached subscribers.
--
-- REPLICA IDENTITY FULL puts the entire old row in the WAL, so RLS can be
-- evaluated and UPDATE/DELETE events are delivered. These tables are low-volume,
-- so the extra WAL is negligible.
-- =============================================================================

ALTER TABLE public.daily_sesions            REPLICA IDENTITY FULL;
ALTER TABLE public.daily_stations_map       REPLICA IDENTITY FULL;
ALTER TABLE public.daily_specials           REPLICA IDENTITY FULL;
ALTER TABLE public.daily_events             REPLICA IDENTITY FULL;
ALTER TABLE public.daily_covers_solicitudes REPLICA IDENTITY FULL;
