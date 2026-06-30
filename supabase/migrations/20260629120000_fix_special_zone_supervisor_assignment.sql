-- =============================================================================
-- FIX: a special's ID_supervisor must be the SAME person the zone notification
-- goes to (the occupant of the zone's supervisor seat), not get_on_duty_supervisor().
--
-- Bug: the trigger inserted the special with ID_supervisor = get_on_duty_supervisor()
-- (the first supervisor found in the DB) BEFORE the zone was even computed, while the
-- notification correctly routed by station -> zone -> supervisor seat -> occupant.
-- An operator at a station in zone S1 therefore got their notification to S1 but the
-- special assigned to whichever supervisor get_on_duty_supervisor() returned (S3).
--
-- Fix: resolve the zone's supervisor occupant FIRST, use it for both the special's
-- ID_supervisor and the notification. Fall back to get_on_duty_supervisor() only when
-- the seat is empty / the station isn't mapped to a zone.
-- =============================================================================

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

        -- ── Resolve the zone's supervisor FIRST (station -> zone -> seat -> occupant) ──
        -- This same occupant is used for the special's ID_supervisor AND the notification,
        -- so the person who is notified is exactly the person the special is assigned to.
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
            END IF;
        END IF;

        -- Assign the special to the zone supervisor; fall back to on-duty / id 1.
        v_supervisor_id := COALESCE(v_target, public.get_on_duty_supervisor(), 1);

        INSERT INTO public.daily_specials (
            "ID_event", "ID_site", "ID_activity", "ID_user",
            "spec_datetime", "spec_quantity", "spec_camera",
            "spec_description", "ID_supervisor"
        ) VALUES (
            NEW."ID_event", NEW."ID_site", NEW."ID_activity", NEW."ID_user",
            v_spec_datetime, NEW.event_quantity, NEW.event_camera,
            NEW.event_description, v_supervisor_id
        );

        UPDATE public.daily_events SET event_status = 'confirmed'
        WHERE "ID_event" = NEW."ID_event";

        -- Notify the zone supervisor occupant (same person the special is assigned to).
        IF v_target IS NOT NULL THEN
            INSERT INTO public.daily_station_messages
              ("ID_sender_user","ID_target_user",message_type,message_title,message_body,created_at,is_active)
            VALUES (NEW."ID_user", v_target, 'info', '📋 Special en tu zona',
                    'Nuevo special (' || COALESCE(v_site_name,'sitio') || ') desde el puesto ' ||
                    COALESCE(v_station_no, v_station::text) || ' · zona ' || COALESCE(v_zone_name,'') ||
                    ' (' || v_sup_station || ').', timezone('utc', now()), 1);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
