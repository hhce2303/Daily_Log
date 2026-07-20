-- =============================================================================
-- EOS Operation Report — dedup real de fotos + estado de retorno.
--
-- Antes: eos_capture_snapshot solo evitaba duplicados IDÉNTICOS capturados en la
-- misma ventana de <60s. Eso dejaba pasar bloques duplicados en el Excel cuando
-- la misma distribución se re-capturaba más tarde (dos supervisores, re-aplicar
-- el mismo split, botón manual, etc.) → el Operation Report mostraba el mismo
-- bloque dos veces (p.ej. 02:12–02:46 y 02:46–02:48 idénticos).
--
-- Ahora: solo se inserta una foto si difiere de la ÚLTIMA foto del día
-- (comparando split_label Y payload completo). Si es idéntica a la última, se
-- omite sin importar el tiempo transcurrido → nunca hay dos bloques
-- consecutivos iguales. La función devuelve boolean: true = insertó,
-- false = omitida por idéntica (para que la UI avise honestamente al forzar).
-- =============================================================================

-- Cambia el tipo de retorno (void -> boolean): hay que soltar primero.
DROP FUNCTION IF EXISTS public.eos_capture_snapshot(date, text, jsonb);

CREATE FUNCTION public.eos_capture_snapshot(
  p_report_date date,
  p_split_label text,
  p_payload jsonb
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_last public.eos_op_snapshots;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden capturar fotos EOS';
  END IF;

  -- Última foto del día. Si es idéntica (mismo label + misma distribución), no
  -- se repite: así una redistribución que vuelve al estado anterior tampoco
  -- genera un bloque duplicado, y nunca hay dos bloques consecutivos iguales.
  SELECT * INTO v_last
  FROM public.eos_op_snapshots
  WHERE report_date = p_report_date
  ORDER BY captured_at DESC
  LIMIT 1;

  IF FOUND
     AND v_last.split_label IS NOT DISTINCT FROM p_split_label
     AND v_last.payload = p_payload THEN
    RETURN false;  -- idéntica a la última: omitida
  END IF;

  INSERT INTO public.eos_op_snapshots (report_date, split_label, payload, captured_by)
  VALUES (p_report_date, p_split_label, p_payload, public.current_daily_user_id());
  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.eos_capture_snapshot(date, text, jsonb) TO anon, authenticated;
