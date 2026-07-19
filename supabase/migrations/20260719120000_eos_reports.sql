-- =============================================================================
-- EOS (End Of Shift) report — Fase 1: Shift Report.
-- Genera el archivo EOS desde el aplicativo. Partes AUTOMÁTICAS (roster,
-- horarios reales de login/logout como prellenado, breaks) + partes MANUALES
-- que el supervisor llena en el módulo EOS (shift notes, late arrivals &
-- absences, incidents history, notas, y ajustes del In/Out).
--
-- eos_reports: una fila por (fecha, turno) con todo lo manual. El roster
-- automático se arma en eos_get_roster() y NO se guarda aquí (se recalcula).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.eos_reports (
  id serial PRIMARY KEY,
  report_date date NOT NULL,
  shift text NOT NULL CHECK (shift IN ('day','night')),
  shift_notes text,
  late_arrivals text,
  general_notes text,
  -- [{supervisor, operator, code, site, local_time}]
  incidents jsonb NOT NULL DEFAULT '[]'::jsonb,
  -- { "<ID_user>": {"in": "07:30", "out": "16:30"} } — override editable del In/Out
  schedule_overrides jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_by integer,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (report_date, shift)
);

ALTER TABLE public.eos_reports ENABLE ROW LEVEL SECURITY;

-- Roster automático de una fecha: cada persona programada (no OFF) con su rol,
-- grupo, horario programado, login/logout REAL (prellenado del In/Out) y break.
-- El frontend clasifica day/night con la lógica de turnos existente.
CREATE OR REPLACE FUNCTION public.eos_get_roster(p_date date)
RETURNS TABLE(
  id_user integer,
  operator_name text,
  team text,
  role_id integer,
  shift_in text,
  shift_out text,
  break_time text,
  is_break_cover integer,
  is_bathroom_cover integer,
  login_in timestamp,
  login_out timestamp,
  break_in timestamp,
  break_out timestamp
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    s."ID_user",
    s.operator_name,
    s.team,
    u."ID_user_rol",
    s.shift_in,
    s.shift_out,
    s.break_time,
    s.is_break_cover,
    s.is_bathroom_cover,
    -- login/logout real: primera entrada y última salida alrededor de la fecha
    -- (cubre turnos que cruzan medianoche). Prellenado editable del In/Out.
    (SELECT min(se.sesion_in) FROM public.daily_sesions se
       WHERE se."ID_user" = s."ID_user"
         AND se.sesion_in >= p_date::timestamp
         AND se.sesion_in <  (p_date + 2)::timestamp),
    (SELECT max(se.sesion_out) FROM public.daily_sesions se
       WHERE se."ID_user" = s."ID_user"
         AND se.sesion_in >= p_date::timestamp
         AND se.sesion_in <  (p_date + 2)::timestamp),
    -- break del operador (su propio break: type 4), In/Out
    (SELECT min(cc.cover_in) FROM public.daily_covers_completed cc
       JOIN public.daily_covers_solicitudes so ON so."ID_cover" = cc."ID_cover_solicitude"
       WHERE so."ID_user" = s."ID_user" AND cc.cover_type = 4
         AND cc.cover_in >= p_date::timestamp AND cc.cover_in < (p_date + 2)::timestamp),
    (SELECT max(cc.cover_out) FROM public.daily_covers_completed cc
       JOIN public.daily_covers_solicitudes so ON so."ID_cover" = cc."ID_cover_solicitude"
       WHERE so."ID_user" = s."ID_user" AND cc.cover_type = 4
         AND cc.cover_in >= p_date::timestamp AND cc.cover_in < (p_date + 2)::timestamp)
  FROM public.daily_ops_schedule s
  JOIN public.daily_users u ON u."ID_user" = s."ID_user"
  WHERE s.schedule_date = p_date AND s.is_off = 0 AND s."ID_user" IS NOT NULL
  ORDER BY u."ID_user_rol", s.sort_order, s.operator_name;
$$;

CREATE OR REPLACE FUNCTION public.eos_get_report(p_date date, p_shift text)
RETURNS SETOF public.eos_reports
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM public.eos_reports WHERE report_date = p_date AND shift = p_shift;
$$;

CREATE OR REPLACE FUNCTION public.eos_upsert_report(
  p_date date,
  p_shift text,
  p_shift_notes text,
  p_late_arrivals text,
  p_general_notes text,
  p_incidents jsonb,
  p_schedule_overrides jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden editar el EOS';
  END IF;
  INSERT INTO public.eos_reports (
    report_date, shift, shift_notes, late_arrivals, general_notes,
    incidents, schedule_overrides, updated_by, updated_at
  ) VALUES (
    p_date, p_shift, p_shift_notes, p_late_arrivals, p_general_notes,
    COALESCE(p_incidents, '[]'::jsonb), COALESCE(p_schedule_overrides, '{}'::jsonb),
    public.current_daily_user_id(), timezone('utc', now())
  )
  ON CONFLICT (report_date, shift) DO UPDATE SET
    shift_notes = EXCLUDED.shift_notes,
    late_arrivals = EXCLUDED.late_arrivals,
    general_notes = EXCLUDED.general_notes,
    incidents = EXCLUDED.incidents,
    schedule_overrides = EXCLUDED.schedule_overrides,
    updated_by = EXCLUDED.updated_by,
    updated_at = EXCLUDED.updated_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.eos_get_roster(date) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.eos_get_report(date, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.eos_upsert_report(date, text, text, text, text, jsonb, jsonb) TO anon, authenticated;
