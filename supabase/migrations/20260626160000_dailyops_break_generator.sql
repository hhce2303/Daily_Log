-- Bulk break assignment for the DailyOps break generator (the draw runs client-side).
CREATE OR REPLACE FUNCTION public.dailyops_set_breaks(p_assignments jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a jsonb; n int := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  FOR a IN SELECT * FROM jsonb_array_elements(p_assignments) LOOP
    UPDATE public.daily_ops_schedule SET break_time = NULLIF(a->>'break','')
    WHERE id = (a->>'id')::bigint;
    n := n + 1;
  END LOOP;
  RETURN n;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_set_breaks(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.dailyops_clear_breaks(p_date date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  UPDATE public.daily_ops_schedule SET break_time = NULL WHERE schedule_date = p_date;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_clear_breaks(date) TO authenticated;
