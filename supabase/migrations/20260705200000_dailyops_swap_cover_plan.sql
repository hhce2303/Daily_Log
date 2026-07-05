-- Swap two operators' break-cover assignments in one atomic step, for the
-- "Quién cubre a quién" panel. Exchanges BOTH the cover person (ID_cover) and
-- the break hour between the two covered operators — i.e. operator A takes B's
-- cover+hour and B takes A's. Keeps each roster row's break_time (what fires the
-- auto-break) in sync, exactly like dailyops_update_cover_plan does.
CREATE OR REPLACE FUNCTION public.dailyops_swap_cover_plan(
  p_date date, p_covered_a bigint, p_covered_b bigint
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  a_cover bigint; a_time varchar;
  b_cover bigint; b_time varchar;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_covered_a = p_covered_b THEN RAISE EXCEPTION 'Selecciona dos operadores distintos'; END IF;

  SELECT "ID_cover", break_time INTO a_cover, a_time
  FROM public.daily_ops_cover_plan
  WHERE schedule_date = p_date AND "ID_covered" = p_covered_a;
  IF NOT FOUND THEN RAISE EXCEPTION 'La primera asignación no existe en el plan'; END IF;

  SELECT "ID_cover", break_time INTO b_cover, b_time
  FROM public.daily_ops_cover_plan
  WHERE schedule_date = p_date AND "ID_covered" = p_covered_b;
  IF NOT FOUND THEN RAISE EXCEPTION 'La segunda asignación no existe en el plan'; END IF;

  -- Guard: a swap must not make someone cover themselves.
  IF b_cover = p_covered_a OR a_cover = p_covered_b THEN
    RAISE EXCEPTION 'Ese intercambio haría que un operador se cubra a sí mismo';
  END IF;

  -- Exchange cover person + hour between the two covered operators.
  UPDATE public.daily_ops_cover_plan SET "ID_cover" = b_cover, break_time = b_time
  WHERE schedule_date = p_date AND "ID_covered" = p_covered_a;
  UPDATE public.daily_ops_cover_plan SET "ID_cover" = a_cover, break_time = a_time
  WHERE schedule_date = p_date AND "ID_covered" = p_covered_b;

  -- Keep the roster break_time in sync (it's what triggers each auto-break).
  UPDATE public.daily_ops_schedule SET break_time = b_time
  WHERE id = p_covered_a AND break_time IS DISTINCT FROM b_time;
  UPDATE public.daily_ops_schedule SET break_time = a_time
  WHERE id = p_covered_b AND break_time IS DISTINCT FROM a_time;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_swap_cover_plan(date, bigint, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
