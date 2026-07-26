-- =============================================================================
-- Cola de covers: eliminar el disparador de renumeraciones completas.
--
-- Lo que segui rompiendo yo: rpc_move_cover_in_queue traia esta trampa
--
--     IF EXISTS (... queue_order IS NULL) THEN PERFORM cover_queue_respace();
--
-- Las solicitudes NUEVAS entran con queue_order NULL, y en esta operacion llegan
-- cada pocos minutos. Resultado: casi SIEMPRE habia una fila en NULL, asi que
-- casi CADA movimiento renumeraba toda la cola. Medido en produccion: 17
-- pendientes => 17 UPDATE => 17 eventos de realtime x ~140 clientes conectados
-- = ~2.400 mensajes en rafaga. El debounce del cliente agrupa las CONSULTAS,
-- pero no el volumen de mensajes del socket (limitado a 5 eventos/seg), asi que
-- a cada cliente se le acumulaba la cola y la app se congelaba.
--
-- Fix de raiz: que queue_order NUNCA sea NULL. Un trigger BEFORE INSERT le
-- asigna al entrar el siguiente valor espaciado (max + 1000), asi que la nueva
-- solicitud ya nace al final de la cola con su hueco propio -- mismo
-- comportamiento visible que antes (las nuevas van al final), pero sin NULL.
-- Con eso, la renumeracion completa deja de dispararse y mover a alguien
-- escribe UNA sola fila = UN solo evento.
-- =============================================================================

-- 1) Asignar el orden al INSERTAR, para que no existan NULL.
CREATE OR REPLACE FUNCTION public.cover_queue_assign_order()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  -- Solo a las que entran pendientes y sin orden explicito.
  IF NEW.queue_order IS NULL AND COALESCE(NEW.approved, 0) = 0 AND COALESCE(NEW.active, 0) = 1 THEN
    SELECT COALESCE(MAX(queue_order), 0) + 1000
      INTO NEW.queue_order
      FROM public.daily_covers_solicitudes
     WHERE active = 1 AND approved = 0;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cover_queue_assign_order ON public.daily_covers_solicitudes;
CREATE TRIGGER trg_cover_queue_assign_order
BEFORE INSERT ON public.daily_covers_solicitudes
FOR EACH ROW EXECUTE FUNCTION public.cover_queue_assign_order();

-- 2) Rellenar las que ya estan en NULL ahora mismo (respetando su orden actual
--    de llegada, para no alterar la cola que el supervisor ya ve).
WITH sin_orden AS (
  SELECT "ID_cover",
         row_number() OVER (ORDER BY cover_time_request, "ID_cover") AS n
  FROM public.daily_covers_solicitudes
  WHERE active = 1 AND approved = 0 AND queue_order IS NULL
), tope AS (
  SELECT COALESCE(MAX(queue_order), 0) AS maxv
  FROM public.daily_covers_solicitudes
  WHERE active = 1 AND approved = 0
)
UPDATE public.daily_covers_solicitudes s
   SET queue_order = t.maxv + (so.n * 1000)
  FROM sin_orden so, tope t
 WHERE s."ID_cover" = so."ID_cover";

-- 3) Quitar la renumeracion automatica del movimiento. Si por alguna razon un
--    vecino no tuviera orden, se manda al final en vez de renumerar todo.
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

  SELECT queue_order INTO v_prev FROM public.daily_covers_solicitudes
   WHERE "ID_cover" = p_before_id AND active = 1 AND approved = 0;
  SELECT queue_order INTO v_next FROM public.daily_covers_solicitudes
   WHERE "ID_cover" = p_after_id AND active = 1 AND approved = 0;
  SELECT COALESCE(MAX(queue_order), 0) INTO v_max
    FROM public.daily_covers_solicitudes WHERE active = 1 AND approved = 0;

  IF v_prev IS NULL AND v_next IS NULL THEN
    v_new := v_max + 1000;                       -- al final
  ELSIF v_prev IS NULL THEN
    v_new := CASE WHEN v_next > 1 THEN v_next / 2 ELSE 0 END;   -- al primer lugar
  ELSIF v_next IS NULL THEN
    v_new := v_prev + 1000;                      -- al final
  ELSE
    v_new := (v_prev + v_next) / 2;              -- punto medio
  END IF;

  -- Sin hueco entre los vecinos: se manda al final (1 fila) en vez de
  -- renumerar toda la cola (N filas => N eventos, lo que colgaba la app).
  -- Con huecos de 1000 esto es rarisimo, y el orden relativo del resto no
  -- cambia; el supervisor puede reacomodar si hiciera falta.
  IF (v_prev IS NOT NULL AND v_new <= v_prev) OR (v_next IS NOT NULL AND v_new >= v_next) THEN
    v_new := v_max + 1000;
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
