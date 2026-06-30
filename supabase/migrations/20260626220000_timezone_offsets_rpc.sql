-- Expose the active season's per-timezone offsets so the frontend can render
-- event times in each site's local timezone (matching the specials + reports).
CREATE OR REPLACE FUNCTION public.get_timezone_offsets()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_season text; v jsonb;
BEGIN
  SELECT lower(season_offsets) INTO v_season FROM public.daily_season_offsets WHERE active = 1 LIMIT 1;
  IF v_season = 'winter' THEN
    SELECT jsonb_object_agg(time_zone, time_offset) INTO v FROM public.daily_winter_offsets;
  ELSE
    SELECT jsonb_object_agg(time_zone, time_offset) INTO v FROM public.daily_summer_offsets;
  END IF;
  RETURN COALESCE(v, '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_timezone_offsets() TO authenticated;
