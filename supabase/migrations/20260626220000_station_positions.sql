-- =============================================================================
-- Editable station positions on the map: store map_x/map_y (% of the map),
-- seeded from the floor-plan layout. Supervisors can drag & save.
-- =============================================================================

ALTER TABLE public.daily_stations_map ADD COLUMN IF NOT EXISTS map_x numeric;
ALTER TABLE public.daily_stations_map ADD COLUMN IF NOT EXISTS map_y numeric;

-- Seed from the floor-plan coordinates (by station_number), only where unset.
WITH coords(num, x, y) AS (
  VALUES
    ('1',14.81,80.63),('4',42.99,80.84),('5',78.06,24.69),('7',56.30,75.21),
    ('8',14.81,72.40),('9',78.49,33.69),('10',78.54,41.43),('11',20.46,60.94),
    ('12',20.45,69.59),('13',20.68,77.13),('14',20.60,85.05),('15',14.84,56.24),
    ('16',78.40,77.27),('17',78.31,16.57),('19',20.57,45.99),('25',37.00,59.59),
    ('26',36.82,67.31),('27',36.84,75.26),('28',42.95,73.08),('30',20.55,37.85),
    ('31',56.47,59.40),('32',56.48,67.35),('33',14.80,64.56),('34',62.62,81.26),
    ('35',62.57,73.13),('36',62.58,65.00),('37',78.36,61.38),('38',78.35,69.29),
    ('39',42.96,65.24),('40',78.45,85.19),('41',84.28,79.44),('42',84.30,71.53),
    ('43',84.25,63.54),('44',84.13,55.63)
)
UPDATE public.daily_stations_map m
SET map_x = c.x, map_y = c.y
FROM public.daily_stations_info si, coords c
WHERE si."ID_station" = m."station_ID"
  AND si.station_number = c.num
  AND m.map_x IS NULL;

-- rpc_station_map now also returns the saved position.
DROP FUNCTION IF EXISTS public.rpc_station_map();
CREATE OR REPLACE FUNCTION public.rpc_station_map()
RETURNS TABLE(
  station_id integer, station_number text, is_active integer, station_alert integer,
  operator_id integer, operator_name text, sesion_status integer, cover_reason text,
  map_x numeric, map_y numeric
)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT
    m."station_ID",
    COALESCE(si.station_number, m."station_ID"::text),
    COALESCE(m.is_active, 0)::int,
    COALESCE(m.station_alert, 0)::int,
    ses."ID_user",
    un.user_name,
    ses.sesion_status::int,
    act_cov.cover_type_name,
    m.map_x, m.map_y
  FROM public.daily_stations_map m
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = m."station_ID"
  LEFT JOIN LATERAL (
    SELECT s."ID_user", s.sesion_status
    FROM public.daily_sesions s
    WHERE s."ID_station" = m."station_ID" AND s.sesion_active = 1
    ORDER BY s.sesion_in DESC LIMIT 1
  ) ses ON true
  LEFT JOIN LATERAL (
    SELECT t.cover_type as cover_type_name
    FROM public.daily_covers_solicitudes c
    LEFT JOIN public.daily_covers_types t ON t."ID_cover_type" = c.cover_type
    WHERE c."ID_station" = m."station_ID" AND c.active = 1 AND c.approved = 1
    ORDER BY c.cover_time_request DESC LIMIT 1
  ) act_cov ON ses.sesion_status = 2
  LEFT JOIN public.daily_users_names un ON un."ID_user" = ses."ID_user"
  ORDER BY m."station_ID";
$function$;

-- Bulk-save positions (supervisor/admin only).
CREATE OR REPLACE FUNCTION public.station_save_positions(p_positions jsonb)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE p jsonb; n int := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden editar el mapa';
  END IF;
  FOR p IN SELECT * FROM jsonb_array_elements(p_positions) LOOP
    UPDATE public.daily_stations_map
    SET map_x = (p->>'x')::numeric, map_y = (p->>'y')::numeric
    WHERE "station_ID" = (p->>'id')::int;
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.station_save_positions(jsonb) TO authenticated;
