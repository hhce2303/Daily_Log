-- Migration: Business Logic Triggers
-- Translates Django business logic to PostgreSQL functions and triggers

-- 1. Ensure ID columns have auto-incrementing sequences
CREATE SEQUENCE IF NOT EXISTS daily_events_id_event_seq;
ALTER TABLE public.daily_events ALTER COLUMN "ID_event" SET DEFAULT nextval('daily_events_id_event_seq');
ALTER SEQUENCE daily_events_id_event_seq OWNED BY public.daily_events."ID_event";

CREATE SEQUENCE IF NOT EXISTS daily_specials_id_special_seq;
ALTER TABLE public.daily_specials ALTER COLUMN "ID_special" SET DEFAULT nextval('daily_specials_id_special_seq');
ALTER SEQUENCE daily_specials_id_special_seq OWNED BY public.daily_specials."ID_special";

-- 2. Helper function: is_special_site
CREATE OR REPLACE FUNCTION public.is_special_site(p_site_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_group_id INTEGER;
    v_is_special BOOLEAN;
BEGIN
    SELECT "group_id" INTO v_group_id FROM public.daily_sites WHERE "ID_site" = p_site_id;
    IF v_group_id IS NULL THEN RETURN FALSE; END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM public.daily_special_groups WHERE group_code = v_group_id
    ) INTO v_is_special;
    
    RETURN COALESCE(v_is_special, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Helper function: get_timezone_offset
CREATE OR REPLACE FUNCTION public.get_timezone_offset(p_site_timezone VARCHAR)
RETURNS NUMERIC AS $$
DECLARE
    v_season VARCHAR;
    v_offset NUMERIC := 0;
BEGIN
    IF p_site_timezone IS NULL OR p_site_timezone = '' THEN RETURN 0; END IF;
    
    SELECT LOWER(season_offsets) INTO v_season FROM public.daily_season_offsets WHERE active = 1 LIMIT 1;
    IF v_season IS NULL THEN RETURN 0; END IF;
    
    IF v_season = 'winter' THEN
        SELECT time_offset INTO v_offset FROM public.daily_winter_offsets WHERE time_zone = p_site_timezone LIMIT 1;
    ELSIF v_season = 'summer' THEN
        SELECT time_offset INTO v_offset FROM public.daily_summer_offsets WHERE time_zone = p_site_timezone LIMIT 1;
    END IF;
    
    RETURN COALESCE(v_offset, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Helper function: get_on_duty_supervisor
CREATE OR REPLACE FUNCTION public.get_on_duty_supervisor()
RETURNS INTEGER AS $$
DECLARE
    v_supervisor_id INTEGER;
BEGIN
    -- Simplified: get the first supervisor user
    SELECT u."ID_user" INTO v_supervisor_id 
    FROM public.daily_users u
    JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
    WHERE r.user_rol_name IN ('Supervisor', 'Lead Supervisor', 'Admin')
    LIMIT 1;
    
    RETURN v_supervisor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Trigger BEFORE INSERT on daily_events to set event_status
CREATE OR REPLACE FUNCTION public.before_insert_daily_events()
RETURNS trigger AS $$
BEGIN
    -- Default event_datetime if not provided
    IF NEW.event_datetime IS NULL THEN
        NEW.event_datetime := timezone('utc', now());
    END IF;
    
    IF public.is_special_site(NEW."ID_site") THEN
        NEW.event_status := 'draft';
    ELSE
        NEW.event_status := 'confirmed';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_before_insert_daily_events ON public.daily_events;
CREATE TRIGGER trg_before_insert_daily_events
    BEFORE INSERT ON public.daily_events
    FOR EACH ROW EXECUTE PROCEDURE public.before_insert_daily_events();

-- 6. Trigger AFTER INSERT on daily_events to create special
CREATE OR REPLACE FUNCTION public.after_insert_daily_events()
RETURNS trigger AS $$
DECLARE
    v_site_timezone VARCHAR;
    v_offset NUMERIC;
    v_spec_datetime TIMESTAMP;
    v_supervisor_id INTEGER;
BEGIN
    IF NEW.event_status = 'draft' THEN
        SELECT "site_timezone" INTO v_site_timezone FROM public.daily_sites WHERE "ID_site" = NEW."ID_site";
        v_offset := public.get_timezone_offset(v_site_timezone);
        -- Formula: UTC + (offset - 5) hours
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
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_insert_daily_events ON public.daily_events;
CREATE TRIGGER trg_after_insert_daily_events
    AFTER INSERT ON public.daily_events
    FOR EACH ROW EXECUTE PROCEDURE public.after_insert_daily_events();
