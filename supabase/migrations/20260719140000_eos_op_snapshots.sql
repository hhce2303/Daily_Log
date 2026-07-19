-- =============================================================================
-- EOS Fase 2: Operation Report — "fotos" del split + distribución en cada
-- cambio de split. El cliente (pestaña Live de splits) arma la foto uniendo el
-- estado de splits (proyecto separado) con la ocupación del mapa (proyecto
-- principal) y la guarda aquí como JSON. Cada foto = un bloque del Operation
-- Report. Se captura automáticamente al aplicar un split (manual o ⚡Auto) y
-- también con un botón manual.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.eos_op_snapshots (
  id serial PRIMARY KEY,
  report_date date NOT NULL,           -- fecha operacional de la captura
  captured_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  split_label text,                    -- "Omnia 11 / Kamee 2 / Luxriot 10"
  -- payload: { apps: [ { app, split_number, rows: [ {split_station, map_station,
  --            operator_name, operator_id} ] } ] }
  payload jsonb NOT NULL,
  captured_by integer,
  UNIQUE (report_date, split_label, captured_at)
);

CREATE INDEX IF NOT EXISTS eos_op_snapshots_date_idx
  ON public.eos_op_snapshots (report_date, captured_at);

ALTER TABLE public.eos_op_snapshots ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.eos_capture_snapshot(
  p_report_date date,
  p_split_label text,
  p_payload jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden capturar fotos EOS';
  END IF;
  -- Evita duplicados consecutivos idénticos (mismo label en <60s): si la última
  -- foto del día tiene el mismo split_label y fue hace menos de 1 min, no repite.
  IF EXISTS (
    SELECT 1 FROM public.eos_op_snapshots
    WHERE report_date = p_report_date
      AND split_label IS NOT DISTINCT FROM p_split_label
      AND captured_at > timezone('utc', now()) - interval '60 seconds'
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.eos_op_snapshots (report_date, split_label, payload, captured_by)
  VALUES (p_report_date, p_split_label, p_payload, public.current_daily_user_id());
END;
$$;

CREATE OR REPLACE FUNCTION public.eos_get_snapshots(p_date date)
RETURNS SETOF public.eos_op_snapshots
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM public.eos_op_snapshots WHERE report_date = p_date ORDER BY captured_at;
$$;

GRANT EXECUTE ON FUNCTION public.eos_capture_snapshot(date, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.eos_get_snapshots(date) TO anon, authenticated;
