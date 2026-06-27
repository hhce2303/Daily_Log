-- =============================================================================
-- Fix station-map baseline.
--
-- The frontend treats daily_stations_map.is_active as "station is IN SERVICE"
-- (0 -> shown as "Fuera de Servicio"/offline). But the earlier reset migration
-- (20260609090500) set is_active = 0 for every station, conflating it with
-- occupancy. Result: 40/44 stations rendered as out-of-service.
--
-- Occupancy now comes from daily_sesions (sesion_active = 1) via rpc_station_map,
-- so is_active should simply mean the station exists/usable. Mark every station
-- in service and clear stale alert flags (there are no real alerts in a fresh DB).
-- Admins can later flag a specific station out-of-service or alerted.
-- =============================================================================

UPDATE public.daily_stations_map
SET is_active = 1
WHERE COALESCE(is_active, 0) <> 1;

UPDATE public.daily_stations_map
SET station_alert = 0
WHERE COALESCE(station_alert, 0) <> 0;
