-- =============================================================================
-- Cola de covers: mover a alguien debe escribir UNA SOLA fila.
--
-- Problema real (esto colgaba la app): el orden se guardaba como 1..N contiguo,
-- así que mover una persona renumeraba a casi todas. Medido en producción con 14
-- pendientes: mover el primero al final cambia LAS 14 posiciones. Cada fila
-- actualizada emite un evento de realtime (tabla publicada con REPLICA IDENTITY
-- FULL) y cada evento dispara invalidaciones de consultas en TODOS los clientes
-- conectados (~140). Una sola acción del supervisor generaba una ráfaga que
-- saturaba el realtime.
--
-- Solución: orden ESPACIADO (mismo truco que los tableros tipo Jira). Los
-- valores se guardan con huecos grandes (1000, 2000, 3000...) y al mover a
-- alguien se le asigna el PUNTO MEDIO entre sus dos nuevos vecinos: solo cambia
-- ESA fila => 1 UPDATE => 1 evento de realtime, sin importar cuántos haya en la
-- cola. Solo si se agota el hueco entre dos vecinos se renumera todo (raro).
--
-- El criterio de lectura no cambia: sigue siendo
--   ORDER BY COALESCE(queue_order, 2147483647), cover_time_request, "ID_cover"
-- así que las vistas y el flujo de asignación funcionan igual.
-- =============================================================================

-- Renumera los pendientes con huecos de 1000 respetando el orden vigente.
-- Se usa al sembrar y cuando dos vecinos quedan sin hueco entre ellos.
CREATE OR REPLACE FUNCTION public.cover_queue_respace()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  WITH ordenado AS (
    SELECT "ID_cover",
           row_number() OVER (
             ORDER BY COALESCE(queue_order, 2147483647), cover_time_request, "ID_cover"
           ) * 1000 AS nuevo
    FROM public.daily_covers_solicitudes
    WHERE active = 1 AND approved = 0
  )
  UPDATE public.daily_covers_solicitudes s
     SET queue_order = o.nuevo
    FROM ordenado o
   WHERE s."ID_cover" = o."ID_cover"
     AND s.queue_order IS DISTINCT FROM o.nuevo;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cover_queue_respace() FROM PUBLIC;

-- Mueve UNA solicitud entre dos vecinas. p_before_id = la que queda ARRIBA
-- (NULL si va al primer lugar); p_after_id = la que queda ABAJO (NULL si va al
-- último). Devuelve el queue_order asignado.
CREATE OR REPLACE FUNCTION public.rpc_move_cover_in_queue(
  p_cover_id integer,
  p_before_id integer DEFAULT NULL,
  p_after_id integer DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_prev bigint;
  v_next bigint;
  v_new  bigint;
  v_max  bigint;
BEGIN
  IF NOT public.current_user_is_lead_or_admin() THEN
    RAISE EXCEPTION 'Solo lead supervisor o admin pueden reordenar la cola de covers'
      USING ERRCODE = 'P0004';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.daily_covers_solicitudes
    WHERE "ID_cover" = p_cover_id AND active = 1 AND approved = 0
  ) THEN
    RAISE EXCEPTION 'COVER_NOT_PENDING: la solicitud ya no está pendiente (recarga la vista)'
      USING ERRCODE = 'P0004';
  END IF;

  -- Si algún pendiente aún no tiene orden (recién llegado), se siembra el
  -- espaciado una vez para poder calcular puntos medios con seguridad.
  IF EXISTS (
    SELECT 1 FROM public.daily_covers_solicitudes
    WHERE active = 1 AND approved = 0 AND queue_order IS NULL
  ) THEN
    PERFORM public.cover_queue_respace();
  END IF;

  SELECT queue_order INTO v_prev FROM public.daily_covers_solicitudes
   WHERE "ID_cover" = p_before_id AND active = 1 AND approved = 0;
  SELECT queue_order INTO v_next FROM public.daily_covers_solicitudes
   WHERE "ID_cover" = p_after_id AND active = 1 AND approved = 0;

  SELECT COALESCE(MAX(queue_order), 0) INTO v_max
    FROM public.daily_covers_solicitudes WHERE active = 1 AND approved = 0;

  -- Bordes: al primer lugar (mitad hacia 0) o al último (después del mayor).
  IF v_prev IS NULL AND v_next IS NULL THEN
    v_new := v_max + 1000;                 -- cola vacía de referencias => al final
  ELSIF v_prev IS NULL THEN
    v_new := CASE WHEN v_next > 1 THEN v_next / 2 ELSE 0 END;
  ELSIF v_next IS NULL THEN
    v_new := v_prev + 1000;
  ELSE
    v_new := (v_prev + v_next) / 2;
  END IF;

  -- ¿Se agotó el hueco? Renumerar y recalcular una sola vez.
  IF (v_prev IS NOT NULL AND v_new <= v_prev) OR (v_next IS NOT NULL AND v_new >= v_next) THEN
    PERFORM public.cover_queue_respace();
    SELECT queue_order INTO v_prev FROM public.daily_covers_solicitudes
     WHERE "ID_cover" = p_before_id AND active = 1 AND approved = 0;
    SELECT queue_order INTO v_next FROM public.daily_covers_solicitudes
     WHERE "ID_cover" = p_after_id AND active = 1 AND approved = 0;
    SELECT COALESCE(MAX(queue_order), 0) INTO v_max
      FROM public.daily_covers_solicitudes WHERE active = 1 AND approved = 0;
    IF v_prev IS NULL AND v_next IS NULL THEN v_new := v_max + 1000;
    ELSIF v_prev IS NULL THEN v_new := v_next / 2;
    ELSIF v_next IS NULL THEN v_new := v_prev + 1000;
    ELSE v_new := (v_prev + v_next) / 2;
    END IF;
  END IF;

  -- UNA sola escritura => UN solo evento de realtime.
  UPDATE public.daily_covers_solicitudes
     SET queue_order = v_new
   WHERE "ID_cover" = p_cover_id
     AND queue_order IS DISTINCT FROM v_new;

  RETURN v_new::integer;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_move_cover_in_queue(integer, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_move_cover_in_queue(integer, integer, integer) TO authenticated;

-- Sembrar el espaciado ahora, para que el primer movimiento ya sea de 1 fila.
SELECT public.cover_queue_respace();
