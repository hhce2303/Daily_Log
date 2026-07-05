-- =============================================================================
-- Editable break-cover plan ("Quién cubre a quién"):
--   • Supervisors can reassign who covers whom and change the break hour inline
--     from the Daily Ops panel (cell-style editing).
--   • "ID_cover" becomes nullable: NULL = "buscar supervisor" — the operator must
--     find a supervisor, who decides their next station. Every existing consumer
--     (generate / notify / activate / manual start) resolves the cover with an
--     INNER JOIN on "ID_cover", so a NULL row simply behaves as "no assigned
--     cover": the break still fires into the general queue (advisory fallback).
--     No behavioral logic is modified.
-- =============================================================================

ALTER TABLE public.daily_ops_cover_plan ALTER COLUMN "ID_cover" DROP NOT NULL;

-- ── Read the plan: LEFT JOIN so "buscar supervisor" (NULL cover) rows show ────
CREATE OR REPLACE FUNCTION public.dailyops_get_cover_plan(p_date date)
RETURNS TABLE (
  break_time varchar,
  id_cover bigint, cover_name varchar,
  id_covered bigint, covered_name varchar
) LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT p.break_time,
         p."ID_cover", sc.operator_name,
         p."ID_covered", sv.operator_name
  FROM public.daily_ops_cover_plan p
  LEFT JOIN public.daily_ops_schedule sc ON sc.id = p."ID_cover"
  JOIN public.daily_ops_schedule sv ON sv.id = p."ID_covered"
  WHERE p.schedule_date = p_date
  ORDER BY p.break_time, sc.operator_name NULLS LAST;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_cover_plan(date) TO authenticated;

-- ── Edit one plan entry (cell edit) ──────────────────────────────────────────
-- p_id_cover NULL      → "buscar supervisor".
-- p_break_time         → new hour for the entry. The roster row's break_time is
--                        kept in sync because THAT is what fires the auto-break
--                        (same data path as the existing break editor).
CREATE OR REPLACE FUNCTION public.dailyops_update_cover_plan(
  p_date date, p_id_covered bigint, p_id_cover bigint, p_break_time varchar
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_break_time IS NULL OR btrim(p_break_time) = '' THEN
    RAISE EXCEPTION 'La hora del break es obligatoria';
  END IF;

  IF p_id_cover IS NOT NULL THEN
    IF p_id_cover = p_id_covered THEN
      RAISE EXCEPTION 'Un operador no puede cubrirse a sí mismo';
    END IF;
    PERFORM 1 FROM public.daily_ops_schedule
    WHERE id = p_id_cover AND schedule_date = p_date AND is_off = 0;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El cover elegido no está en el horario de esta fecha';
    END IF;
  END IF;

  UPDATE public.daily_ops_cover_plan
  SET "ID_cover" = p_id_cover, break_time = p_break_time
  WHERE schedule_date = p_date AND "ID_covered" = p_id_covered;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No existe esa asignación en el plan';
  END IF;

  UPDATE public.daily_ops_schedule
  SET break_time = p_break_time
  WHERE id = p_id_covered AND break_time IS DISTINCT FROM p_break_time;
END; $$;
GRANT EXECUTE ON FUNCTION public.dailyops_update_cover_plan(date, bigint, bigint, varchar) TO authenticated;
