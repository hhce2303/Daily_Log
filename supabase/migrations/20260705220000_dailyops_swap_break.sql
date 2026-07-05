-- Swap the BREAK TIME between any two roster operators for a date — including
-- break-cover / bathroom-cover people, who self-break and so never appear in the
-- "quién cubre a quién" plan (that swap only handles covered operators). This
-- one operates at the roster level, so anyone with a break can trade it.
--
-- It exchanges daily_ops_schedule.break_time and, for whichever of the two IS a
-- covered operator in the plan, updates that plan row's break_time to match — so
-- the auto-break still fires at the (swapped) time. The cover PERSON is left
-- unchanged (this trades the hour, not who covers whom).
CREATE OR REPLACE FUNCTION public.dailyops_swap_break(
  p_date date, p_a bigint, p_b bigint
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t_a varchar; t_b varchar;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_a = p_b THEN RAISE EXCEPTION 'Selecciona dos operadores distintos'; END IF;

  SELECT break_time INTO t_a FROM public.daily_ops_schedule WHERE id = p_a AND schedule_date = p_date;
  IF NOT FOUND THEN RAISE EXCEPTION 'El primer operador no está en el horario de esta fecha'; END IF;
  SELECT break_time INTO t_b FROM public.daily_ops_schedule WHERE id = p_b AND schedule_date = p_date;
  IF NOT FOUND THEN RAISE EXCEPTION 'El segundo operador no está en el horario de esta fecha'; END IF;

  -- Exchange the roster break times.
  UPDATE public.daily_ops_schedule SET break_time = t_b WHERE id = p_a;
  UPDATE public.daily_ops_schedule SET break_time = t_a WHERE id = p_b;

  -- Keep any existing cover-plan rows aligned so the cover fires at the new hour.
  UPDATE public.daily_ops_cover_plan SET break_time = t_b
  WHERE schedule_date = p_date AND "ID_covered" = p_a;
  UPDATE public.daily_ops_cover_plan SET break_time = t_a
  WHERE schedule_date = p_date AND "ID_covered" = p_b;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_swap_break(date, bigint, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
