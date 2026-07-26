-- =============================================================================
-- Cola de covers: el reorden solo debe tocar las filas que REALMENTE cambian.
--
-- Problema: rpc_set_cover_queue_order asignaba la posición a TODAS las filas del
-- arreglo recibido, aunque su queue_order ya fuera ese valor. Mover una persona
-- en una cola de 5 generaba 5 UPDATE en vez de 2-3, y cada fila actualizada
-- emite un evento de realtime (la tabla está publicada con REPLICA IDENTITY
-- FULL). Con ~140 clientes conectados, cada evento dispara invalidaciones de
-- consultas en todos: el reorden saturaba el realtime y colgaba la app.
--
-- Fix: añadir `queue_order IS DISTINCT FROM w.pos`. Postgres no escribe (ni
-- emite evento WAL) para las filas que no cambian, así que un movimiento típico
-- pasa de N eventos a 2-3. El resultado final del orden es idéntico.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rpc_set_cover_queue_order(p_cover_ids integer[])
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_n integer := 0;
BEGIN
  IF NOT public.current_user_is_lead_or_admin() THEN
    RAISE EXCEPTION 'Solo lead supervisor o admin pueden reordenar la cola de covers'
      USING ERRCODE = 'P0004';
  END IF;

  IF p_cover_ids IS NULL OR array_length(p_cover_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  WITH wanted AS (
    SELECT id AS cover_id, ord AS pos
    FROM unnest(p_cover_ids) WITH ORDINALITY AS t(id, ord)
  )
  UPDATE public.daily_covers_solicitudes s
     SET queue_order = w.pos
    FROM wanted w
   WHERE s."ID_cover" = w.cover_id
     AND s.active = 1
     AND s.approved = 0
     -- Clave: no reescribir filas cuya posición ya es la correcta. Evita
     -- eventos de realtime innecesarios (ver cabecera).
     AND s.queue_order IS DISTINCT FROM w.pos;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;   -- ahora = cuántas filas CAMBIARON de verdad
END;
$$;
