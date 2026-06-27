-- Notify a single operator about their assigned break (used when a supervisor
-- finishes editing the break field inline).
CREATE OR REPLACE FUNCTION public.dailyops_notify_break(p_schedule_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid    integer;
  v_break  text;
  v_sender integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores';
  END IF;
  v_sender := public.current_daily_user_id();

  SELECT "ID_user", break_time INTO v_uid, v_break
  FROM public.daily_ops_schedule WHERE id = p_schedule_id;

  IF v_uid IS NULL OR v_break IS NULL THEN RETURN; END IF;

  INSERT INTO public.daily_station_messages
    ("ID_sender_user", "ID_target_user", message_type, message_title, message_body, created_at, is_active)
  VALUES (v_sender, v_uid, 'info', 'Break asignado',
          'Tu break fue asignado a las ' || v_break, timezone('utc', now()), 1);
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_notify_break(bigint) TO authenticated;
