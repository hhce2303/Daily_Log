-- Fix: stuck "Cover Solicitado" banner after a nested bathroom cover.
--
-- When a bathroom/break-cover person is manning another operator's station and
-- requests a cover for THEMSELVES, that creates a pending solicitude on that
-- station (ID_user = the coverer). If nobody takes it and the coverer then ends
-- their cover and leaves, the pending request is orphaned (active=1, approved=0)
-- and the station is left showing "Cover Solicitado" forever.
--
-- rpc_end_cover now also deactivates any PENDING request the departing coverer
-- had on that same station. Only approved=0 rows are touched, so an in-progress
-- cover of the coverer is never disturbed.
CREATE OR REPLACE FUNCTION public.rpc_end_cover(p_cover_id integer)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id  INTEGER;
  v_sol      RECORD;
  v_comp     RECORD;
  v_duration INTEGER := 0;
  v_found    BOOLEAN := false;
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_sol FROM public.daily_covers_solicitudes
  WHERE "ID_cover" = p_cover_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('already_ended', true);
  END IF;

  SELECT * INTO v_comp FROM public.daily_covers_completed
  WHERE "ID_cover_solicitude" = p_cover_id AND cover_out IS NULL
  ORDER BY cover_in DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN
    v_found := true;
    UPDATE public.daily_covers_completed
    SET cover_out = timezone('utc', now())
    WHERE "ID_cover_complete" = v_comp."ID_cover_complete";
    v_duration := EXTRACT(EPOCH FROM (timezone('utc', now()) - v_comp.cover_in))::INTEGER / 60;
  END IF;

  -- Restore the covered operator's session and deactivate the solicitude.
  UPDATE public.daily_sesions SET sesion_status = 1
    WHERE "ID_user" = v_sol."ID_user" AND sesion_active = 1;
  UPDATE public.daily_covers_solicitudes SET active = 0 WHERE "ID_cover" = p_cover_id;

  -- Clean up the departing coverer's own orphaned PENDING request on this
  -- station (see header). Guard on v_found so we know who the coverer was.
  IF v_found AND v_comp."ID_cover_by" IS NOT NULL THEN
    UPDATE public.daily_covers_solicitudes
    SET active = 0
    WHERE "ID_user" = v_comp."ID_cover_by"
      AND "ID_station" = v_sol."ID_station"
      AND "ID_cover" <> p_cover_id
      AND active = 1 AND approved = 0;
  END IF;

  RETURN json_build_object(
    'cover_complete_id', CASE WHEN v_found THEN v_comp."ID_cover_complete" ELSE NULL END,
    'operator_id',      v_sol."ID_user",
    'station_id',       v_sol."ID_station",
    'duration_minutes', v_duration,
    'ended_at',         timezone('utc', now()),
    'already_ended',    NOT v_found
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
