-- =============================================================================
-- Route specials by operator position: stations are grouped into zones, each
-- zone has an assigned supervisor/lead. When an operator creates a special, the
-- zone supervisor for the operator's current station is notified (ADDITIVE — the
-- normal on-duty pipeline assignment is unchanged).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_zones (
  id              serial PRIMARY KEY,
  zone_name       varchar NOT NULL UNIQUE,
  supervisor_user integer,                       -- daily_users.ID_user
  created_at      timestamp without time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.daily_zone_stations (
  station_number  varchar PRIMARY KEY,           -- a station belongs to at most one zone
  zone_id         integer NOT NULL REFERENCES public.daily_zones(id) ON DELETE CASCADE
);

ALTER TABLE public.daily_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_zone_stations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS daily_zones_read ON public.daily_zones;
DROP POLICY IF EXISTS daily_zone_stations_read ON public.daily_zone_stations;
CREATE POLICY daily_zones_read ON public.daily_zones FOR SELECT TO authenticated USING (true);
CREATE POLICY daily_zone_stations_read ON public.daily_zone_stations FOR SELECT TO authenticated USING (true);

-- ── Zone CRUD (supervisor/admin only) ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.zone_upsert(p_id integer, p_name text, p_supervisor integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.daily_zones (zone_name, supervisor_user) VALUES (p_name, p_supervisor)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.daily_zones SET zone_name = p_name, supervisor_user = p_supervisor
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.zone_upsert(integer, text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.zone_delete(p_id integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  DELETE FROM public.daily_zones WHERE id = p_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.zone_delete(integer) TO authenticated;

-- Replace a zone's station members in one call.
CREATE OR REPLACE FUNCTION public.zone_set_stations(p_zone_id integer, p_stations text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  -- A station can only be in one zone: detach it from any zone first.
  DELETE FROM public.daily_zone_stations WHERE station_number = ANY(p_stations);
  DELETE FROM public.daily_zone_stations WHERE zone_id = p_zone_id;
  INSERT INTO public.daily_zone_stations (station_number, zone_id)
  SELECT unnest(p_stations), p_zone_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.zone_set_stations(integer, text[]) TO authenticated;

-- List zones with supervisor name + member stations.
CREATE OR REPLACE FUNCTION public.zones_list()
RETURNS TABLE (id integer, zone_name varchar, supervisor_user integer, supervisor_name text, stations text[])
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT z.id, z.zone_name, z.supervisor_user,
         (SELECT n.user_name FROM public.daily_users_names n WHERE n."ID_user" = z.supervisor_user
          LIMIT 1) AS supervisor_name,
         COALESCE(array_agg(zs.station_number ORDER BY zs.station_number)
                  FILTER (WHERE zs.station_number IS NOT NULL), '{}') AS stations
  FROM public.daily_zones z
  LEFT JOIN public.daily_zone_stations zs ON zs.zone_id = z.id
  GROUP BY z.id, z.zone_name, z.supervisor_user
  ORDER BY z.zone_name;
$$;
GRANT EXECUTE ON FUNCTION public.zones_list() TO authenticated;

-- ── Hook: notify the zone supervisor when a special is created ───────────────
-- Re-defines the events->specials trigger to additionally route a notification
-- to the supervisor of the zone containing the operator's current station.
CREATE OR REPLACE FUNCTION public.after_insert_daily_events()
RETURNS trigger AS $$
DECLARE
    v_site_timezone VARCHAR;
    v_offset NUMERIC;
    v_spec_datetime TIMESTAMP;
    v_supervisor_id INTEGER;
    v_station INTEGER;
    v_station_no VARCHAR;
    v_zone_sup INTEGER;
    v_zone_name VARCHAR;
    v_site_name VARCHAR;
BEGIN
    IF NEW.event_status = 'draft' THEN
        SELECT "site_timezone", site_name INTO v_site_timezone, v_site_name
        FROM public.daily_sites WHERE "ID_site" = NEW."ID_site";

        v_offset := public.get_timezone_offset(v_site_timezone);
        v_spec_datetime := NEW.event_datetime + ((v_offset - 5) || ' hours')::interval;
        v_supervisor_id := public.get_on_duty_supervisor();

        INSERT INTO public.daily_specials (
            "ID_event", "ID_site", "ID_activity", "ID_user",
            "spec_datetime", "spec_quantity", "spec_camera",
            "spec_description", "ID_supervisor"
        ) VALUES (
            NEW."ID_event", NEW."ID_site", NEW."ID_activity", NEW."ID_user",
            v_spec_datetime, NEW.event_quantity, NEW.event_camera,
            NEW.event_description, COALESCE(v_supervisor_id, 1)
        );

        UPDATE public.daily_events SET event_status = 'confirmed'
        WHERE "ID_event" = NEW."ID_event";

        -- Position-based routing: find the operator's current station -> zone -> supervisor.
        SELECT "ID_station" INTO v_station
        FROM public.daily_sesions
        WHERE "ID_user" = NEW."ID_user" AND sesion_active = 1
        ORDER BY sesion_in DESC LIMIT 1;

        IF v_station IS NOT NULL THEN
            SELECT station_number INTO v_station_no
            FROM public.daily_stations_info WHERE "ID_station" = v_station;

            SELECT z.supervisor_user, z.zone_name INTO v_zone_sup, v_zone_name
            FROM public.daily_zone_stations zs
            JOIN public.daily_zones z ON z.id = zs.zone_id
            WHERE zs.station_number = v_station_no;

            IF v_zone_sup IS NOT NULL THEN
                INSERT INTO public.daily_station_messages
                  ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
                VALUES (NEW."ID_user", v_zone_sup, 'info', '📋 Special en tu zona',
                        'Nuevo special (' || COALESCE(v_site_name,'sitio') || ') desde el puesto ' ||
                        COALESCE(v_station_no, v_station::text) || ' · zona ' || COALESCE(v_zone_name,'') || '.',
                        timezone('utc', now()), 1);
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
