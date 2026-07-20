-- =============================================================================
-- Banner de break auto-sanable — versión endurecida (intent-aware).
--
-- La versión anterior (20260720130000) re-armaba break_started_at ante CUALQUIER
-- desactivación de un pendiente de break no tomado. Eso resucitaba también las
-- CANCELACIONES INTENCIONALES (cover_cancel_request): un supervisor cancelaba el
-- break y el cron lo volvía a crear al minuto → "no se quita".
--
-- Reglas correctas del re-arm (reset break_started_at = NULL para que el cron
-- recree el pendiente en el puesto actual del operador):
--   • SÍ re-armar en fallos transitorios: relogin/robo de puesto
--     (rpc_login_claim_station), desconexión (disconnect_operator), o cualquier
--     otra desactivación de un pendiente NO tomado.
--   • NO re-armar si fue una cancelación intencional (cover_cancel_request marca
--     una bandera transaccional app.skip_break_rearm).
--   • NO re-armar si el break YA se tomó hoy (existe un cover completado tipo 4)
--     — defensa extra contra estados raros con pendientes duplicados.
--   • El camino feliz (break tomado→terminado) queda approved=1 al desactivarse,
--     así que el trigger ni siquiera dispara.
-- =============================================================================

-- 1) Trigger intent-aware.
CREATE OR REPLACE FUNCTION public.rearm_break_on_untaken_cancel()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_local_date date;
BEGIN
  -- Solo covers de break (tipo 4) pendientes (nunca aprobados) que dejan de
  -- estar vivos sin haberse tomado.
  IF NOT (OLD.cover_type = 4
          AND OLD.approved = 0
          AND OLD.active = 1
          AND (TG_OP = 'DELETE' OR NEW.active = 0)) THEN
    RETURN NULL;
  END IF;

  -- Cancelación intencional: cover_cancel_request marca esta bandera
  -- transaccional para que un cancel NO resucite el break.
  IF current_setting('app.skip_break_rearm', true) = 'on' THEN
    RETURN NULL;
  END IF;

  v_local_date := (OLD.cover_time_request AT TIME ZONE 'UTC' AT TIME ZONE 'America/Bogota')::date;

  -- Ya se tomó el break hoy (hay un cover completado tipo 4 para este operador
  -- en la ventana operativa): no re-armar.
  IF EXISTS (
    SELECT 1 FROM public.daily_covers_completed cc
    WHERE cc."ID_user" = OLD."ID_user" AND cc.cover_type = 4
      AND (cc.cover_in AT TIME ZONE 'UTC' AT TIME ZONE 'America/Bogota')::date
          IN (v_local_date, v_local_date - 1)
  ) THEN
    RETURN NULL;
  END IF;

  -- Re-armar: el cron por-minuto recreará el pendiente en el puesto donde el
  -- operador esté conectado (respetando hora del break, fin de turno, conexión
  -- y "sin otro cover activo").
  UPDATE public.daily_ops_schedule
     SET break_started_at = NULL
   WHERE "ID_user" = OLD."ID_user"
     AND schedule_date IN (v_local_date, v_local_date - 1)
     AND break_started_at IS NOT NULL;
  RETURN NULL;
END;
$$;

-- 2) cover_cancel_request marca la cancelación como intencional (bandera
--    transaccional, is_local = true → se limpia al cerrar la transacción) para
--    que el trigger de arriba no la resucite. Cuerpo idéntico al vigente salvo
--    esa línea.
CREATE OR REPLACE FUNCTION public.cover_cancel_request(p_cover_id integer)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user integer; v_owner integer;
BEGIN
  v_user := public.current_daily_user_id();
  SELECT "ID_user" INTO v_owner FROM public.daily_covers_solicitudes WHERE "ID_cover" = p_cover_id;
  IF v_owner IS NULL THEN RETURN; END IF;

  IF NOT (public.current_user_is_supervisor() OR v_owner = v_user) THEN
    RAISE EXCEPTION 'No autorizado para cancelar esta solicitud';
  END IF;

  -- Cancelación intencional: que el trigger rearm_break_on_untaken_cancel NO
  -- recree el break. Transaccional; no afecta a otras sesiones ni persiste.
  PERFORM set_config('app.skip_break_rearm', 'on', true);

  -- Close any open in-progress cover for this request (unsticks "en progreso").
  UPDATE public.daily_covers_completed
  SET cover_out = timezone('utc', now())
  WHERE "ID_cover_solicitude" = p_cover_id AND cover_out IS NULL;

  -- Restore the covered operator's session state.
  UPDATE public.daily_sesions SET sesion_status = 1
  WHERE "ID_user" = v_owner AND sesion_active = 1;

  -- Deactivate the request (whether it was pending or in progress).
  UPDATE public.daily_covers_solicitudes SET active = 0
  WHERE "ID_cover" = p_cover_id AND active = 1;
END; $function$;
