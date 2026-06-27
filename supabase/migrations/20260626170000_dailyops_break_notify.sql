-- =============================================================================
-- Break notifications: tell each operator their assigned break time, and let an
-- operator look up their own break (to auto-request the cover ~1 min before).
-- =============================================================================

-- Notify every assigned operator: "Tu break fue asignado a las X".
CREATE OR REPLACE FUNCTION public.dailyops_notify_breaks(p_date date)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_sender integer;
  n integer := 0;
  r record;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores';
  END IF;
  v_sender := public.current_daily_user_id();

  FOR r IN
    SELECT "ID_user", break_time FROM public.daily_ops_schedule
    WHERE schedule_date = p_date AND "ID_user" IS NOT NULL AND break_time IS NOT NULL
  LOOP
    INSERT INTO public.daily_station_messages
      ("ID_sender_user", "ID_target_user", message_type, message_title, message_body, created_at, is_active)
    VALUES (v_sender, r."ID_user", 'info', 'Break asignado',
            'Tu break fue asignado a las ' || r.break_time, timezone('utc', now()), 1);
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_notify_breaks(date) TO authenticated;

-- The current user's most recent assigned break (handles the overnight date roll).
CREATE OR REPLACE FUNCTION public.dailyops_my_break_today()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT break_time FROM public.daily_ops_schedule
  WHERE "ID_user" = public.current_daily_user_id()
    AND break_time IS NOT NULL
    AND schedule_date >= CURRENT_DATE - 1
  ORDER BY schedule_date DESC
  LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_my_break_today() TO authenticated;
