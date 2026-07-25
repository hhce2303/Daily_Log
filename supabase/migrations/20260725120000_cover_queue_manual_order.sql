-- =============================================================================
-- Cola de covers: orden MANUAL (arrastrar y soltar) respetado en todo el flujo.
--
-- Antes: el orden de los pendientes era FIFO puro por cover_time_request. El
-- supervisor no podía priorizar a alguien (p.ej. quien lleva más rato aguantando
-- o una urgencia) sin borrar y recrear solicitudes.
--
-- Ahora: columna queue_order. El supervisor reordena arrastrando y el orden se
-- guarda; TODAS las vistas y el flujo real de asignación lo respetan con el
-- mismo criterio:
--
--     ORDER BY COALESCE(queue_order, 2147483647) ASC,  -- manual primero
--              cover_time_request ASC,                 -- luego FIFO
--              "ID_cover" ASC                          -- desempate estable
--
-- Las solicitudes nuevas entran con queue_order NULL, así que caen al FINAL de
-- las ordenadas a mano y entre ellas siguen en orden de llegada -- comportamiento
-- predecible: "lo que ordené queda como lo dejé; lo nuevo se forma detrás".
-- =============================================================================

ALTER TABLE public.daily_covers_solicitudes
  ADD COLUMN IF NOT EXISTS queue_order integer;

COMMENT ON COLUMN public.daily_covers_solicitudes.queue_order IS
  'Orden manual de la cola (arrastrar y soltar). NULL = sin orden manual, va después de los ordenados, por hora de solicitud.';

-- Índice para el orden de la cola de pendientes.
CREATE INDEX IF NOT EXISTS daily_covers_sol_queue_order_idx
  ON public.daily_covers_solicitudes (queue_order, cover_time_request, "ID_cover")
  WHERE active = 1 AND approved = 0;

-- ── Guardar el orden manual ─────────────────────────────────────────────────
-- Recibe los ids EN EL ORDEN DESEADO y les asigna 1..N. Solo supervisores.
-- Reescribe el orden completo de lo que se le pase (la UI manda toda la lista
-- de pendientes visible), así el resultado es exactamente lo que el supervisor
-- ve en pantalla -- sin huecos ni ambigüedad.
CREATE OR REPLACE FUNCTION public.rpc_set_cover_queue_order(p_cover_ids integer[])
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_n integer := 0;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores/admin pueden reordenar la cola de covers'
      USING ERRCODE = 'P0004';
  END IF;

  IF p_cover_ids IS NULL OR array_length(p_cover_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  -- Asigna la posición según el índice en el arreglo recibido. Solo toca
  -- solicitudes PENDIENTES y activas: nunca reordena algo ya en progreso.
  WITH wanted AS (
    SELECT id AS cover_id, ord AS pos
    FROM unnest(p_cover_ids) WITH ORDINALITY AS t(id, ord)
  )
  UPDATE public.daily_covers_solicitudes s
     SET queue_order = w.pos
    FROM wanted w
   WHERE s."ID_cover" = w.cover_id
     AND s.active = 1
     AND s.approved = 0;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_set_cover_queue_order(integer[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_set_cover_queue_order(integer[]) TO authenticated;

-- ── Vista del supervisor (Cola de Covers) ───────────────────────────────────
-- Se agrega queue_order al retorno, así que hay que soltarla primero (Postgres
-- no permite cambiar el tipo de retorno con CREATE OR REPLACE).
DROP FUNCTION IF EXISTS public.rpc_cover_queue();
CREATE OR REPLACE FUNCTION public.rpc_cover_queue()
 RETURNS TABLE(cover_id integer, operator_id integer, operator_name text, station_id integer,
               station_number text, cover_type_id integer, cover_type_name text,
               requested_at timestamp without time zone, approved smallint, active smallint,
               coverer_name text, cover_in timestamp without time zone,
               cover_out timestamp without time zone, queue_order integer)
 LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT
    s."ID_cover",
    s."ID_user",
    un.user_name,
    s."ID_station",
    si.station_number,
    COALESCE(s.cover_type, cc.cover_type)::INTEGER,
    ct.cover_type,
    s.cover_time_request,
    s.approved,
    s.active,
    cun.user_name,  -- coverer name
    cc.cover_in,
    cc.cover_out,
    s.queue_order
  FROM public.daily_covers_solicitudes s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  LEFT JOIN public.daily_covers_completed cc ON cc."ID_cover_solicitude" = s."ID_cover"
  LEFT JOIN public.daily_users_names cun ON cun."ID_user" = cc."ID_cover_by"
  LEFT JOIN public.daily_covers_types ct ON ct."ID_cover_type" = COALESCE(s.cover_type, cc.cover_type)
  WHERE s.active = 1
  ORDER BY COALESCE(s.queue_order, 2147483647) ASC, s.cover_time_request ASC, s."ID_cover" ASC;
$function$;

-- ── Cola del personal de cover de baño (incluye de dónde sale "el siguiente") ─
CREATE OR REPLACE FUNCTION public.bathroom_cover_queue()
 RETURNS TABLE(cover_id integer, operator_name text, station_number text,
               requested_at timestamp without time zone, approved smallint, active smallint,
               coverer_id integer, coverer_name text)
 LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT
    s."ID_cover",
    un.user_name,
    si.station_number,
    s.cover_time_request,
    s.approved,
    s.active,
    cc."ID_cover_by",
    cun.user_name
  FROM public.daily_covers_solicitudes s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  LEFT JOIN LATERAL (
    SELECT c.* FROM public.daily_covers_completed c
    WHERE c."ID_cover_solicitude" = s."ID_cover" AND c.cover_out IS NULL
    ORDER BY c.cover_in DESC LIMIT 1
  ) cc ON true
  LEFT JOIN public.daily_users_names cun ON cun."ID_user" = cc."ID_cover_by"
  WHERE s.active = 1
    AND COALESCE(s.cover_type, cc.cover_type) = 1     -- Cover Baño
    AND public.am_i_bathroom_cover()
  ORDER BY COALESCE(s.queue_order, 2147483647) ASC, s.cover_time_request ASC, s."ID_cover" ASC;
$function$;

-- ── Posición que ve el OPERADOR de su propia solicitud ──────────────────────
-- Debe coincidir con el orden que dejó el supervisor: si lo movió al primer
-- lugar, el operador tiene que ver "1", no su posición por hora de llegada.
CREATE OR REPLACE FUNCTION public.my_cover_requests()
 RETURNS TABLE(cover_id integer, operator_name text, station_number text, cover_type_id integer,
               cover_type_name text, requested_at timestamp without time zone, approved smallint,
               active smallint, coverer_name text, cover_in timestamp without time zone,
               cover_out timestamp without time zone, queue_position integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  WITH pending_rank AS (
    SELECT "ID_cover",
           row_number() OVER (
             ORDER BY COALESCE(queue_order, 2147483647) ASC, cover_time_request ASC, "ID_cover" ASC
           )::integer AS pos
    FROM public.daily_covers_solicitudes
    WHERE active = 1 AND approved = 0
  )
  SELECT
    s."ID_cover",
    opn.user_name,
    si.station_number,
    COALESCE(s.cover_type, cc.cover_type)::integer,
    ct.cover_type,
    s.cover_time_request,
    s.approved,
    s.active,
    cun.user_name,          -- coverer name
    cc.cover_in,
    cc.cover_out,
    pr.pos                  -- position in the pending line (NULL if not waiting)
  FROM public.daily_covers_solicitudes s
  LEFT JOIN public.daily_users_names opn ON opn."ID_user" = s."ID_user"
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  LEFT JOIN LATERAL (
    SELECT c.* FROM public.daily_covers_completed c
    WHERE c."ID_cover_solicitude" = s."ID_cover"
    ORDER BY c.cover_in DESC LIMIT 1
  ) cc ON true
  LEFT JOIN public.daily_users_names cun ON cun."ID_user" = cc."ID_cover_by"
  LEFT JOIN public.daily_covers_types ct ON ct."ID_cover_type" = COALESCE(s.cover_type, cc.cover_type)
  LEFT JOIN pending_rank pr ON pr."ID_cover" = s."ID_cover"
  WHERE s."ID_user" = public.current_daily_user_id()
    AND (s.active = 1 OR s.approved = 1)
  ORDER BY s.cover_time_request DESC;
$function$;
