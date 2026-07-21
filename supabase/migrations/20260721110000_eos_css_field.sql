-- =============================================================================
-- EOS: campo CSS (Central Station Supervisor de turno). En la plantilla real
-- este campo siempre viene lleno (nombre de quien hizo/actualizó el EOS); el
-- app nunca lo llenaba porque no existía el campo. Se agrega como manual, por
-- turno, igual que shift_notes/late_arrivals/general_notes.
-- =============================================================================

ALTER TABLE public.eos_reports ADD COLUMN IF NOT EXISTS css text;

CREATE OR REPLACE FUNCTION public.eos_upsert_report(
  p_date date, p_shift text, p_shift_notes text, p_late_arrivals text, p_general_notes text,
  p_incidents jsonb, p_schedule_overrides jsonb, p_css text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden editar el EOS';
  END IF;
  INSERT INTO public.eos_reports (
    report_date, shift, shift_notes, late_arrivals, general_notes,
    incidents, schedule_overrides, css, updated_by, updated_at
  ) VALUES (
    p_date, p_shift, p_shift_notes, p_late_arrivals, p_general_notes,
    COALESCE(p_incidents, '[]'::jsonb), COALESCE(p_schedule_overrides, '{}'::jsonb), p_css,
    public.current_daily_user_id(), timezone('utc', now())
  )
  ON CONFLICT (report_date, shift) DO UPDATE SET
    shift_notes = EXCLUDED.shift_notes,
    late_arrivals = EXCLUDED.late_arrivals,
    general_notes = EXCLUDED.general_notes,
    incidents = EXCLUDED.incidents,
    schedule_overrides = EXCLUDED.schedule_overrides,
    css = EXCLUDED.css,
    updated_by = EXCLUDED.updated_by,
    updated_at = EXCLUDED.updated_at;
END;
$$;
