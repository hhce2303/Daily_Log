-- "Limpiar breaks" must also cancel the auto-created (pending) break covers so the
-- operator's banner / "en cover" state / Mis Covers entry are fully cleared.
CREATE OR REPLACE FUNCTION public.dailyops_clear_breaks(p_date date)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores';
  END IF;

  -- Cancel pending break covers (type 4, not yet taken over) for these operators.
  UPDATE public.daily_covers_solicitudes c
  SET active = 0
  WHERE c.cover_type = 4 AND c.active = 1 AND COALESCE(c.approved,0) = 0
    AND c."ID_user" IN (
      SELECT "ID_user" FROM public.daily_ops_schedule
      WHERE schedule_date = p_date AND "ID_user" IS NOT NULL
    );

  UPDATE public.daily_ops_schedule SET break_time = NULL WHERE schedule_date = p_date;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_clear_breaks(date) TO authenticated;
