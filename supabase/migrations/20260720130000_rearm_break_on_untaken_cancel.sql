-- =============================================================================
-- Banner de break auto-sanable: re-armar break_started_at cuando el cover de
-- break pendiente desaparece sin tomarse.
--
-- Problema: dailyops_activate_due_breaks() (cron por-minuto) crea el cover de
-- break pendiente y marca daily_ops_schedule.break_started_at = now() como
-- "fire-once". Si ese pendiente luego se desactiva o se borra SIN que nadie lo
-- tome (cancelación, limpieza, sesión perdida/re-login, etc.), la marca queda
-- puesta y el cron NUNCA lo vuelve a crear → el banner "☕ Tomar Control" no
-- reaparece. Hoy el único arreglo es que un supervisor edite la hora del break,
-- que justamente resetea break_started_at = NULL (via dailyops_set_break).
--
-- Solución (event-driven, sin polling de cliente): un trigger que automatiza ese
-- mismo reseteo. Cuando un cover de break (cover_type = 4) que estaba PENDIENTE
-- (approved = 0) deja de estar activo (active 1→0) o se borra, se resetea
-- break_started_at = NULL en la fila de horario de ese operador. El cron ya
-- existente lo recrea en el minuto siguiente sobre el puesto donde esté conectado
-- (respetando sus mismas puertas: hora del break, fin de turno, conectado, sin
-- otro cover activo). Un break realmente TOMADO queda approved = 1, así que el
-- trigger no dispara y no se recrea.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.rearm_break_on_untaken_cancel()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_local_date date;
BEGIN
  -- Solo covers de break (tipo 4) que estaban pendientes (nunca aprobados) y que
  -- dejan de estar vivos sin haberse tomado.
  IF OLD.cover_type = 4
     AND OLD.approved = 0
     AND OLD.active = 1
     AND (TG_OP = 'DELETE' OR NEW.active = 0) THEN
    -- Fecha operativa (Bogota) del cover, para acotar el horario a re-armar.
    v_local_date := (OLD.cover_time_request AT TIME ZONE 'UTC' AT TIME ZONE 'America/Bogota')::date;
    UPDATE public.daily_ops_schedule
       SET break_started_at = NULL
     WHERE "ID_user" = OLD."ID_user"
       AND schedule_date IN (v_local_date, v_local_date - 1)
       AND break_started_at IS NOT NULL;
  END IF;
  RETURN NULL;  -- AFTER trigger: el valor de retorno se ignora.
END;
$$;

DROP TRIGGER IF EXISTS trg_rearm_break_on_untaken ON public.daily_covers_solicitudes;
CREATE TRIGGER trg_rearm_break_on_untaken
AFTER UPDATE OR DELETE ON public.daily_covers_solicitudes
FOR EACH ROW EXECUTE FUNCTION public.rearm_break_on_untaken_cancel();
