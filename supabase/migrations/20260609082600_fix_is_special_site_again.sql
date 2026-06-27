CREATE OR REPLACE FUNCTION public.is_special_site(p_site_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_group_id VARCHAR;
    v_is_special BOOLEAN;
BEGIN
    SELECT "ID_group" INTO v_group_id FROM public.daily_sites WHERE "ID_site" = p_site_id;
    IF v_group_id IS NULL THEN RETURN FALSE; END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM public.daily_special_groups WHERE "site_group_special" = v_group_id
    ) INTO v_is_special;
    
    RETURN COALESCE(v_is_special, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
