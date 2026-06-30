-- =============================================================================
-- Free a station when the operator just CLOSES the window (no logout). The app
-- sends a heartbeat every ~30s; a cron expires sessions with no heartbeat for
-- >90s and frees their station — so the map goes "disponible" within ~1-2 min.
-- =============================================================================

ALTER TABLE public.daily_sesions ADD COLUMN IF NOT EXISTS last_seen timestamp;
-- New sessions auto-stamp last_seen (rpc_login_claim_station inserts without it).
ALTER TABLE public.daily_sesions ALTER COLUMN last_seen SET DEFAULT timezone('utc', now());
-- Backfill currently-active sessions so they aren't expired before their first beat.
UPDATE public.daily_sesions SET last_seen = timezone('utc', now())
WHERE sesion_active = 1 AND last_seen IS NULL;

-- Client calls this periodically while the app is open.
CREATE OR REPLACE FUNCTION public.rpc_heartbeat()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user integer;
BEGIN
  v_user := public.current_daily_user_id();
  IF v_user IS NULL THEN RETURN; END IF;
  UPDATE public.daily_sesions
  SET last_seen = timezone('utc', now())
  WHERE "ID_user" = v_user AND sesion_active = 1;
END; $$;
GRANT EXECUTE ON FUNCTION public.rpc_heartbeat() TO authenticated;

-- Close stale sessions and free their stations. Runs every minute via cron.
CREATE OR REPLACE FUNCTION public.expire_stale_sessions()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN
    SELECT "ID_sesion", "ID_station"
    FROM public.daily_sesions
    WHERE sesion_active = 1
      AND last_seen IS NOT NULL
      AND last_seen < timezone('utc', now()) - interval '120 seconds'
  LOOP
    UPDATE public.daily_sesions
    SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
    WHERE "ID_sesion" = r."ID_sesion";

    IF r."ID_station" IS NOT NULL THEN
      UPDATE public.daily_stations_map
      SET station_user = NULL, is_active = 1
      WHERE "station_ID" = r."ID_station";
    END IF;
    n := n + 1;
  END LOOP;
  RETURN n;
END; $$;

-- Schedule it (idempotent: unschedule a prior copy first).
DO $$
BEGIN
  PERFORM cron.unschedule('expire-stale-sessions');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule('expire-stale-sessions', '* * * * *', 'SELECT public.expire_stale_sessions();');
