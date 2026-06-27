-- =============================================================================
-- Reset stale occupancy data in daily_stations_map.
-- The imported data has station_user set from the old Django database state.
-- Since no real active sessions exist, every station should start unoccupied.
-- Also ensure every station in daily_stations_info has a map row.
-- =============================================================================

-- 1. Clear stale occupancy from the old import
UPDATE public.daily_stations_map
SET station_user = NULL,
    is_active    = 0
WHERE station_user IS NOT NULL;

-- 2. Insert map rows for any station in daily_stations_info that lacks one
INSERT INTO public.daily_stations_map ("station_ID", station_user, is_active)
SELECT si."ID_station", NULL, 0
FROM   public.daily_stations_info si
WHERE  NOT EXISTS (
  SELECT 1 FROM public.daily_stations_map sm WHERE sm."station_ID" = si."ID_station"
);
