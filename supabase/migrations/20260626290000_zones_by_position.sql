-- =============================================================================
-- Route specials to a SUPERVISOR POSITION (seat) rather than a fixed user.
-- A zone now targets a supervisor station_number (e.g. "S1", "LS1"); when a
-- special is created, whoever is currently logged in at that seat is notified.
-- =============================================================================

ALTER TABLE public.daily_zones DROP COLUMN IF EXISTS supervisor_user;
ALTER TABLE public.daily_zones ADD COLUMN IF NOT EXISTS supervisor_station varchar;

-- ── List the available supervisor/lead positions (seats) + current occupant ──
CREATE OR REPLACE FUNCTION public.supervisor_positions()
RETURNS TABLE (station_number varchar, rol_type varchar, occupant_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT i.station_number,
         t.station_rol_type,
         (SELECT n.user_name
          FROM public.daily_sesions s
          JOIN public.daily_users_names n ON n."ID_user" = s."ID_user"
          WHERE s."ID_station" = i."ID_station" AND s.sesion_active = 1
          ORDER BY s.sesion_in DESC LIMIT 1) AS occupant_name
  FROM public.daily_stations_info i
  JOIN public.daily_stations_rol_types t ON t."ID_station_rol" = i."ID_station_rol"
  WHERE i."ID_station_rol" IN (2, 3)            -- Supervisor, Lead Supervisor
  ORDER BY i."ID_station_rol", i.station_number;
$$;
GRANT EXECUTE ON FUNCTION public.supervisor_positions() TO authenticated;

-- ── Zone upsert now takes a supervisor position (station_number) ─────────────
DROP FUNCTION IF EXISTS public.zone_upsert(integer, text, integer);
CREATE OR REPLACE FUNCTION public.zone_upsert(p_id integer, p_name text, p_supervisor_station text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.daily_zones (zone_name, supervisor_station) VALUES (p_name, NULLIF(p_supervisor_station,''))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.daily_zones SET zone_name = p_name, supervisor_station = NULLIF(p_supervisor_station,'')
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.zone_upsert(integer, text, text) TO authenticated;

-- ── zones_list now returns the supervisor position + its current occupant ────
DROP FUNCTION IF EXISTS public.zones_list();
CREATE OR REPLACE FUNCTION public.zones_list()
RETURNS TABLE (id integer, zone_name varchar, supervisor_station varchar, occupant_name text, stations text[])
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT z.id, z.zone_name, z.supervisor_station,
         (SELECT n.user_name
          FROM public.daily_stations_info si
          JOIN public.daily_sesions s ON s."ID_station" = si."ID_station" AND s.sesion_active = 1
          JOIN public.daily_users_names n ON n."ID_user" = s."ID_user"
          WHERE si.station_number = z.supervisor_station
          ORDER BY s.sesion_in DESC LIMIT 1) AS occupant_name,
         COALESCE(array_agg(zs.station_number ORDER BY zs.station_number)
                  FILTER (WHERE zs.station_number IS NOT NULL), '{}') AS stations
  FROM public.daily_zones z
  LEFT JOIN public.daily_zone_stations zs ON zs.zone_id = z.id
  GROUP BY z.id, z.zone_name, z.supervisor_station
  ORDER BY z.zone_name;
$$;
GRANT EXECUTE ON FUNCTION public.zones_list() TO authenticated;

-- ── Route specials to the occupant of the zone's supervisor seat ─────────────
CREATE OR REPLACE FUNCTION public.after_insert_daily_events()
RETURNS trigger AS $$
DECLARE
    v_site_timezone VARCHAR;
    v_offset NUMERIC;
    v_spec_datetime TIMESTAMP;
    v_supervisor_id INTEGER;
    v_station INTEGER;
    v_station_no VARCHAR;
    v_zone_name VARCHAR;
    v_sup_station VARCHAR;
    v_sup_station_id INTEGER;
    v_target INTEGER;
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

        -- Position-based routing: operator's current station -> zone -> supervisor seat -> occupant.
        SELECT "ID_station" INTO v_station
        FROM public.daily_sesions
        WHERE "ID_user" = NEW."ID_user" AND sesion_active = 1
        ORDER BY sesion_in DESC LIMIT 1;

        IF v_station IS NOT NULL THEN
            SELECT station_number INTO v_station_no
            FROM public.daily_stations_info WHERE "ID_station" = v_station;

            SELECT z.supervisor_station, z.zone_name INTO v_sup_station, v_zone_name
            FROM public.daily_zone_stations zs
            JOIN public.daily_zones z ON z.id = zs.zone_id
            WHERE zs.station_number = v_station_no;

            IF v_sup_station IS NOT NULL THEN
                SELECT "ID_station" INTO v_sup_station_id
                FROM public.daily_stations_info WHERE station_number = v_sup_station LIMIT 1;

                SELECT "ID_user" INTO v_target
                FROM public.daily_sesions
                WHERE "ID_station" = v_sup_station_id AND sesion_active = 1
                ORDER BY sesion_in DESC LIMIT 1;

                IF v_target IS NOT NULL THEN
                    INSERT INTO public.daily_station_messages
                      ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
                    VALUES (NEW."ID_user", v_target, 'info', '📋 Special en tu zona',
                            'Nuevo special (' || COALESCE(v_site_name,'sitio') || ') desde el puesto ' ||
                            COALESCE(v_station_no, v_station::text) || ' · zona ' || COALESCE(v_zone_name,'') ||
                            ' (' || v_sup_station || ').', timezone('utc', now()), 1);
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
