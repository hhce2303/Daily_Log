-- =============================================================================
-- Allow anon (unauthenticated) users to read station info and map.
-- Required: the login page resolves station IDs before the user is authenticated.
-- =============================================================================

-- daily_stations_info — anon needs to look up station_id by station_number at login
DROP POLICY IF EXISTS "anon_read_stations_info" ON public.daily_stations_info;
CREATE POLICY "anon_read_stations_info"
  ON public.daily_stations_info
  FOR SELECT TO anon
  USING (true);

-- daily_stations_map — anon needs to check if a station is occupied at login
DROP POLICY IF EXISTS "anon_read_stations_map" ON public.daily_stations_map;
CREATE POLICY "anon_read_stations_map"
  ON public.daily_stations_map
  FOR SELECT TO anon
  USING (true);
