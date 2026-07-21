-- =============================================================================
-- EOS: separar cambio ESTRUCTURAL de split (nueva foto) de ajustes operativos
-- MENORES (reasignar operador, mover una estación, repartir un sitio) que solo
-- deben quedar documentados como eventos/notas, sin generar un nuevo bloque en
-- el Operation Report. Antes, CUALQUIER cambio en la distribución (incluidas
-- reasignaciones) generaba una foto nueva → se creaban muchas filas en
-- eos_op_snapshots por ajustes menores del día a día.
--
-- eos_op_events: log de eventos menores, uno por acción (fijar/quitar puesto,
-- asignar/quitar dinámico, mover/deshacer un sitio), con su hora y descripción.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.eos_op_events (
  id serial PRIMARY KEY,
  report_date date NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  description text NOT NULL,
  logged_by integer
);

CREATE INDEX IF NOT EXISTS eos_op_events_date_idx
  ON public.eos_op_events (report_date, occurred_at);

ALTER TABLE public.eos_op_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.eos_log_event(
  p_report_date date,
  p_description text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden registrar eventos EOS';
  END IF;
  INSERT INTO public.eos_op_events (report_date, description, logged_by)
  VALUES (p_report_date, p_description, public.current_daily_user_id());
END;
$$;

CREATE OR REPLACE FUNCTION public.eos_get_events(p_date date)
RETURNS SETOF public.eos_op_events
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM public.eos_op_events WHERE report_date = p_date ORDER BY occurred_at;
$$;

GRANT EXECUTE ON FUNCTION public.eos_log_event(date, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.eos_get_events(date) TO anon, authenticated;
