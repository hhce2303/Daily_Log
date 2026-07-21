-- =============================================================================
-- Bug: un coverer que se reubica FÍSICAMENTE a un puesto nuevo mientras sigue
-- cubriendo se vuelve invisible en ese puesto nuevo.
--
-- Caso real: Victoria cubre a Aramis (puesto 1). Por necesidad física, Victoria
-- se cambia al puesto 31 y hace un login normal ahí (rpc_login_claim_station
-- crea una sesión nueva y activa para ella en 31 — el dato es correcto). Pero:
--   • rpc_station_map excluye su sesión de CUALQUIER puesto que no sea el que
--     cubre (guard "no mostrar al coverer en su propio puesto"), así que el
--     puesto 31 le sale vacío.
--   • rpc_heartbeat, en cada latido, ve que ella cubre en otro lado y BORRA
--     station_user del puesto 31 activamente — refuerza la invisibilidad.
--   • rpc_login_claim_station tiene la falla simétrica: si un tercero intenta
--     loguearse en un puesto donde el coverer está genuinamente sentado (recién
--     re-logueado), lo trata como "puesto abandonado" y lo desaloja.
--
-- Causa raíz: el guard original ("no mostrar al coverer en su propio puesto
-- mientras cubre en otro") se escribió para el caso de un puesto VIEJO
-- abandonado (el coverer nunca cerró sesión ahí antes de autenticarse en el
-- navegador de la persona cubierta) — pero se aplicaba a CUALQUIER puesto
-- distinto al cubierto, sin distinguir "viejo abandonado" de "nuevo real".
--
-- Fix: el guard ahora solo excluye una sesión si es MÁS VIEJA que el cover que
-- la excluye (sesion_in < cover_in) -- es decir, si la sesión existía ANTES de
-- empezar a cubrir (el puesto de origen, abandonado sin cerrar sesión). Una
-- sesión creada DESPUÉS de iniciar el cover (un re-login legítimo a un puesto
-- físico nuevo) nunca se excluye: es la ubicación real actual del coverer.
-- =============================================================================

-- 1) Mapa: solo ocultar al coverer en un puesto cuya sesión sea ANTERIOR al
--    cover que está realizando (puesto viejo abandonado), no en un puesto nuevo
--    donde ya se re-logueó legítimamente.
CREATE OR REPLACE FUNCTION public.rpc_station_map()
 RETURNS TABLE(station_id integer, station_number text, is_active integer, station_alert integer,
   operator_id integer, operator_name text, sesion_status integer, cover_reason text,
   map_x numeric, map_y numeric)
 LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT
    m."station_ID",
    COALESCE(si.station_number, m."station_ID"::text),
    COALESCE(m.is_active, 0)::int,
    COALESCE(m.station_alert, 0)::int,
    ses."ID_user",
    un.user_name,
    ses.sesion_status::int,
    act_cov.cover_type_name,
    m.map_x, m.map_y
  FROM public.daily_stations_map m
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = m."station_ID"
  LEFT JOIN LATERAL (
    SELECT s."ID_user", s.sesion_status
    FROM public.daily_sesions s
    WHERE s."ID_station" = m."station_ID" AND s.sesion_active = 1
      -- No mostrar al coverer en un puesto VIEJO abandonado (la sesión es más
      -- vieja que el cover que realiza en otro lado). Si desde entonces hizo un
      -- login legítimo aquí (sesión más nueva que el cover), es su puesto real
      -- actual: no se excluye.
      AND NOT EXISTS (
        SELECT 1 FROM public.daily_covers_completed cc
        JOIN public.daily_covers_solicitudes so ON so."ID_cover" = cc."ID_cover_solicitude"
        WHERE cc."ID_cover_by" = s."ID_user" AND cc.cover_out IS NULL
          AND so."ID_station" <> m."station_ID"
          AND s.sesion_in < cc.cover_in
      )
    ORDER BY s.sesion_in DESC LIMIT 1
  ) ses ON true
  LEFT JOIN LATERAL (
    SELECT t.cover_type as cover_type_name
    FROM public.daily_covers_solicitudes c
    LEFT JOIN public.daily_covers_types t ON t."ID_cover_type" = c.cover_type
    WHERE c."ID_station" = m."station_ID" AND c.active = 1 AND c.approved = 1
    ORDER BY c.cover_time_request DESC LIMIT 1
  ) act_cov ON ses.sesion_status = 2
  LEFT JOIN public.daily_users_names un ON un."ID_user" = ses."ID_user"
  ORDER BY m."station_ID";
$function$;

-- 2) Heartbeat: mismo criterio -- solo liberar (station_user = NULL) el puesto
--    si la sesión actual del coverer es más vieja que el cover (puesto viejo
--    abandonado). Nunca liberar un puesto donde ya se re-logueó después.
CREATE OR REPLACE FUNCTION public.rpc_heartbeat()
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user integer; v_sesion integer; v_station integer; v_active smallint; v_sesion_in timestamp;
  r record; v_cs integer; v_cstation integer; v_cactive smallint;
BEGIN
  v_user := public.current_daily_user_id();
  IF v_user IS NULL THEN RETURN; END IF;

  SELECT "ID_sesion", "ID_station", sesion_active, sesion_in
    INTO v_sesion, v_station, v_active, v_sesion_in
  FROM public.daily_sesions WHERE "ID_user" = v_user ORDER BY sesion_in DESC LIMIT 1;

  IF v_sesion IS NOT NULL THEN
    -- Cubriendo en OTRO puesto Y este puesto es más viejo que ese cover
    -- (abandonado sin cerrar sesión) → liberarlo para que otros lo reclamen.
    IF v_station IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.daily_covers_completed cc
      JOIN public.daily_covers_solicitudes s ON s."ID_cover" = cc."ID_cover_solicitude"
      WHERE cc."ID_cover_by" = v_user AND cc.cover_out IS NULL AND s."ID_station" <> v_station
        AND v_sesion_in < cc.cover_in
    ) THEN
      UPDATE public.daily_stations_map
      SET station_user = NULL, is_active = 1
      WHERE "station_ID" = v_station AND station_user = v_user;
      -- do NOT revive/refresh/close the own-seat session

    ELSIF v_station IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.daily_stations_map m
      WHERE m."station_ID" = v_station AND m.station_user IS NOT NULL AND m.station_user <> v_user
    ) THEN
      IF v_active = 1 THEN
        UPDATE public.daily_sesions
        SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
        WHERE "ID_sesion" = v_sesion;
      END IF;
    ELSE
      IF v_active IS DISTINCT FROM 1 THEN
        UPDATE public.daily_sesions
        SET sesion_active = 1, sesion_status = 1, sesion_out = NULL WHERE "ID_sesion" = v_sesion;
        IF v_station IS NOT NULL THEN
          UPDATE public.daily_stations_map
          SET station_user = v_user, is_active = 1
          WHERE "station_ID" = v_station AND (station_user IS NULL OR station_user = v_user);
        END IF;
      END IF;
      INSERT INTO public.daily_session_heartbeat ("ID_sesion", last_seen)
      VALUES (v_sesion, timezone('utc', now()))
      ON CONFLICT ("ID_sesion") DO UPDATE SET last_seen = EXCLUDED.last_seen;
    END IF;
  END IF;

  FOR r IN
    SELECT sol."ID_user" AS covered_user
    FROM public.daily_covers_completed cc
    JOIN public.daily_covers_solicitudes sol ON sol."ID_cover" = cc."ID_cover_solicitude"
    WHERE cc."ID_cover_by" = v_user AND cc.cover_out IS NULL
  LOOP
    SELECT "ID_sesion", "ID_station", sesion_active INTO v_cs, v_cstation, v_cactive
    FROM public.daily_sesions WHERE "ID_user" = r.covered_user ORDER BY sesion_in DESC LIMIT 1;
    IF v_cs IS NULL THEN CONTINUE; END IF;
    IF v_cactive IS DISTINCT FROM 1 THEN
      UPDATE public.daily_sesions
      SET sesion_active = 1, sesion_status = 2, sesion_out = NULL WHERE "ID_sesion" = v_cs;
      IF v_cstation IS NOT NULL THEN
        UPDATE public.daily_stations_map
        SET station_user = r.covered_user, is_active = 1
        WHERE "station_ID" = v_cstation AND (station_user IS NULL OR station_user = r.covered_user);
      END IF;
    END IF;
    INSERT INTO public.daily_session_heartbeat ("ID_sesion", last_seen)
    VALUES (v_cs, timezone('utc', now()))
    ON CONFLICT ("ID_sesion") DO UPDATE SET last_seen = EXCLUDED.last_seen;
  END LOOP;
END; $function$;

-- 3) Login: falla simétrica -- si un tercero intenta loguearse en un puesto
--    donde el ocupante actual es un coverer, solo tratarlo como "abandonado y
--    reclamable" si la sesión del ocupante ahí es más vieja que su cover. Si ya
--    se re-logueó legítimamente ahí (sesión más nueva), pasa a la verificación
--    normal de presencia (heartbeat reciente = bloqueado; sin latido = ghost).
CREATE OR REPLACE FUNCTION public.rpc_login_claim_station(p_station_id integer)
 RETURNS json LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_user_id INTEGER; v_session_id INTEGER; v_station_num VARCHAR; v_occupied INTEGER;
  v_prev_station INTEGER; v_resume_cover INTEGER; v_stale RECORD; v_other INTEGER; v_relevo INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = 'P0001'; END IF;

  SELECT "ID_station" INTO v_prev_station
  FROM public.daily_sesions WHERE "ID_user" = v_user_id AND sesion_active = 1
  ORDER BY sesion_in DESC LIMIT 1;

  IF v_prev_station IS NOT NULL THEN
    UPDATE public.daily_sesions
    SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
    WHERE "ID_user" = v_user_id AND sesion_active = 1;
    UPDATE public.daily_stations_map SET station_user = NULL, is_active = 1
    WHERE "station_ID" = v_prev_station AND station_user = v_user_id;
  END IF;

  SELECT station_user INTO v_occupied
  FROM public.daily_stations_map WHERE "station_ID" = p_station_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Estación no encontrada (ID: %)', p_station_id USING ERRCODE = 'P0003';
  END IF;

  SELECT station_number INTO v_station_num FROM public.daily_stations_info WHERE "ID_station" = p_station_id;

  IF v_occupied IS NOT NULL AND v_occupied <> v_user_id THEN
    SELECT s."ID_cover" INTO v_resume_cover
    FROM public.daily_covers_solicitudes s
    JOIN public.daily_covers_completed c ON c."ID_cover_solicitude" = s."ID_cover" AND c.cover_out IS NULL
    WHERE s."ID_station" = p_station_id AND s.active = 1 AND c."ID_cover_by" = v_user_id
    ORDER BY c.cover_in DESC LIMIT 1;
    IF v_resume_cover IS NOT NULL THEN
      RETURN json_build_object('session_id', NULL, 'station_id', p_station_id,
        'station_number', v_station_num, 'resume_cover_id', v_resume_cover);
    END IF;

    -- Ocupante cubre en OTRO lado Y su sesión aquí es más vieja que ese cover
    -- (dejó este puesto sin cerrar sesión) → abandonado, liberar y reclamar.
    IF EXISTS (
      SELECT 1 FROM public.daily_covers_completed cc
      JOIN public.daily_covers_solicitudes so ON so."ID_cover" = cc."ID_cover_solicitude"
      JOIN public.daily_sesions os ON os."ID_user" = v_occupied AND os."ID_station" = p_station_id
        AND os.sesion_active = 1
      WHERE cc."ID_cover_by" = v_occupied AND cc.cover_out IS NULL AND so."ID_station" <> p_station_id
        AND os.sesion_in < cc.cover_in
    ) THEN
      UPDATE public.daily_sesions
      SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
      WHERE "ID_user" = v_occupied AND "ID_station" = p_station_id AND sesion_active = 1;
    -- Genuinely present (fresh heartbeat) → blocked.
    ELSIF EXISTS (
      SELECT 1 FROM public.daily_sesions s
      LEFT JOIN public.daily_session_heartbeat h ON h."ID_sesion" = s."ID_sesion"
      WHERE s."ID_user" = v_occupied AND s."ID_station" = p_station_id AND s.sesion_active = 1
        AND COALESCE(h.last_seen, s.sesion_in) > timezone('utc', now()) - interval '90 seconds'
    ) THEN
      RAISE EXCEPTION 'La estación ya está ocupada' USING ERRCODE = 'P0004';
    ELSE
      -- Ghost (stale): close and claim.
      UPDATE public.daily_sesions
      SET sesion_active = 0, sesion_out = timezone('utc', now()), sesion_status = 0
      WHERE "ID_user" = v_occupied AND "ID_station" = p_station_id AND sesion_active = 1;
    END IF;
  END IF;

  UPDATE public.daily_stations_map SET station_user = v_user_id, is_active = 1 WHERE "station_ID" = p_station_id;

  UPDATE public.daily_covers_solicitudes SET "ID_station" = p_station_id
  WHERE "ID_user" = v_user_id AND active = 1 AND approved = 0;

  FOR v_stale IN
    SELECT c."ID_cover", c."ID_user" FROM public.daily_covers_solicitudes c
    WHERE c."ID_station" = p_station_id AND c.active = 1 AND c."ID_user" <> v_user_id
      AND NOT EXISTS (SELECT 1 FROM public.daily_covers_completed cc
        WHERE cc."ID_cover_solicitude" = c."ID_cover" AND cc.cover_out IS NULL)
  LOOP
    SELECT "ID_station" INTO v_other FROM public.daily_sesions
    WHERE "ID_user" = v_stale."ID_user" AND sesion_active = 1 ORDER BY sesion_in DESC LIMIT 1;
    IF v_other IS NOT NULL AND v_other <> p_station_id THEN
      UPDATE public.daily_covers_solicitudes SET "ID_station" = v_other WHERE "ID_cover" = v_stale."ID_cover";
    ELSIF EXISTS (SELECT 1 FROM public.daily_ops_schedule s
        WHERE s."ID_user" = v_stale."ID_user" AND s.is_off = 0
          AND (s.is_bathroom_cover = 1 OR s.is_break_cover = 1)
          AND s.schedule_date BETWEEN CURRENT_DATE - 1 AND CURRENT_DATE) THEN
      SELECT "ID_station" INTO v_relevo FROM public.daily_stations_info WHERE station_number = 'RELEVO' LIMIT 1;
      IF v_relevo IS NOT NULL THEN
        UPDATE public.daily_covers_solicitudes SET "ID_station" = v_relevo WHERE "ID_cover" = v_stale."ID_cover";
      ELSE
        UPDATE public.daily_covers_solicitudes SET active = 0 WHERE "ID_cover" = v_stale."ID_cover";
      END IF;
    ELSE
      UPDATE public.daily_covers_solicitudes SET active = 0 WHERE "ID_cover" = v_stale."ID_cover";
    END IF;
  END LOOP;

  INSERT INTO public.daily_sesions ("ID_user", "ID_station", sesion_in, sesion_active, sesion_status)
  VALUES (v_user_id, p_station_id, timezone('utc', now()), 1, 1)
  RETURNING "ID_sesion" INTO v_session_id;

  RETURN json_build_object('session_id', v_session_id, 'station_id', p_station_id, 'station_number', v_station_num);
END;
$function$;
