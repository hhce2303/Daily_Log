-- =============================================================================
-- Consolidated station-map read.
--
-- The frontend was doing 3 round-trips (map, then active sessions, then names)
-- and joining in JS, and it derived occupancy from daily_stations_map.station_user.
-- The desktop app treats daily_sesions (sesion_active = 1) as the source of
-- truth for who is sitting at each station, which is more accurate (the map's
-- station_user can go stale if a client dies without logging out).
--
-- This RPC returns the whole map in one query, with the current occupant taken
-- from the active session.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_station_map()
RETURNS TABLE (
    station_id     integer,
    station_number text,
    is_active      integer,
    station_alert  integer,
    operator_id    integer,
    operator_name  text,
    sesion_status  integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        m."station_ID",
        COALESCE(si.station_number, m."station_ID"::text),
        COALESCE(m.is_active, 0)::int,
        COALESCE(m.station_alert, 0)::int,
        ses."ID_user",
        un.user_name,
        ses.sesion_status::int
    FROM public.daily_stations_map m
    LEFT JOIN public.daily_stations_info si ON si."ID_station" = m."station_ID"
    LEFT JOIN LATERAL (
        SELECT s."ID_user", s.sesion_status
        FROM public.daily_sesions s
        WHERE s."ID_station" = m."station_ID" AND s.sesion_active = 1
        ORDER BY s.sesion_in DESC
        LIMIT 1
    ) ses ON true
    LEFT JOIN public.daily_users_names un ON un."ID_user" = ses."ID_user"
    ORDER BY m."station_ID";
$$;

GRANT EXECUTE ON FUNCTION public.rpc_station_map() TO authenticated;
