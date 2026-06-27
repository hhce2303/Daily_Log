-- =============================================================
-- Cover hand-off flow: request → approve/start → end
--
-- Lifecycle (mirrors the desktop .exe):
--   1. Operator requests cover (existing INSERT into daily_covers_solicitudes)
--   2. Coverer calls rpc_start_cover(cover_id, cover_type_id)
--      → marks solicitude approved=1
--      → sets operator session sesion_status=2 (on cover)
--      → inserts daily_covers_completed with cover_in=now()
--      → updates station_map to show coverer
--   3. Coverer calls rpc_end_cover(cover_id)
--      → sets cover_out=now() on completed record
--      → restores operator session sesion_status=1 (active)
--      → deactivates solicitude (active=0)
--      → restores station_map to show operator
-- =============================================================

-- Add cover_type to solicitudes so operator can pick the reason at request time
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'daily_covers_solicitudes'
      AND column_name = 'cover_type'
  ) THEN
    ALTER TABLE public.daily_covers_solicitudes
      ADD COLUMN cover_type INTEGER REFERENCES public.daily_covers_types("ID_cover_type");
  END IF;
END $$;

-- Add covers_solicitudes to realtime publication for live cover queue
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'daily_covers_solicitudes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_covers_solicitudes;
  END IF;
END $$;

-- Set REPLICA IDENTITY FULL on covers_solicitudes so realtime sends full row on UPDATE
ALTER TABLE public.daily_covers_solicitudes REPLICA IDENTITY FULL;

-- =============================================================
-- RPC: Start a cover (called by the coverer / supervisor)
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_start_cover(
  p_cover_id   INTEGER,
  p_cover_type INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_coverer_id    INTEGER;
  v_sol           RECORD;
  v_comp_id       INTEGER;
  v_cover_type    INTEGER;
BEGIN
  -- Who is calling (the coverer)?
  v_coverer_id := public.current_daily_user_id();
  IF v_coverer_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  -- Lock and fetch the solicitude
  SELECT * INTO v_sol
  FROM public.daily_covers_solicitudes
  WHERE "ID_cover" = p_cover_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de cover no encontrada' USING ERRCODE = 'P0002';
  END IF;

  IF v_sol.active != 1 THEN
    RAISE EXCEPTION 'Esta solicitud ya no está activa' USING ERRCODE = 'P0003';
  END IF;

  IF v_sol.approved = 1 THEN
    RAISE EXCEPTION 'Este cover ya fue iniciado' USING ERRCODE = 'P0004';
  END IF;

  -- Determine cover type: use the one from the solicitude if set, otherwise the parameter
  v_cover_type := COALESCE(p_cover_type, v_sol.cover_type, 3); -- 3 = "Otro" fallback

  -- 1. Mark solicitude as approved (in progress)
  UPDATE public.daily_covers_solicitudes
  SET approved = 1
  WHERE "ID_cover" = p_cover_id;

  -- 2. Set operator's session to "on cover" (sesion_status = 2)
  UPDATE public.daily_sesions
  SET sesion_status = 2
  WHERE "ID_user" = v_sol."ID_user"
    AND sesion_active = 1;

  -- 3. Insert cover completed record (cover_out is NULL until end)
  INSERT INTO public.daily_covers_completed
    ("ID_user", "ID_cover_solicitude", cover_in, cover_out, cover_type, "ID_cover_by")
  VALUES
    (v_sol."ID_user", p_cover_id, timezone('utc', now()), NULL, v_cover_type, v_coverer_id)
  RETURNING "ID_cover_complete" INTO v_comp_id;

  RETURN json_build_object(
    'cover_complete_id', v_comp_id,
    'operator_id',      v_sol."ID_user",
    'station_id',       v_sol."ID_station",
    'coverer_id',       v_coverer_id,
    'started_at',       timezone('utc', now())
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_start_cover(INTEGER, INTEGER) TO authenticated;

-- =============================================================
-- RPC: End a cover (called by the coverer / supervisor)
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_end_cover(
  p_cover_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_id       INTEGER;
  v_sol           RECORD;
  v_comp          RECORD;
  v_duration      INTEGER;
BEGIN
  v_user_id := public.current_daily_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  -- Lock solicitude
  SELECT * INTO v_sol
  FROM public.daily_covers_solicitudes
  WHERE "ID_cover" = p_cover_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud de cover no encontrada' USING ERRCODE = 'P0002';
  END IF;

  IF v_sol.approved != 1 THEN
    RAISE EXCEPTION 'Este cover no ha sido iniciado' USING ERRCODE = 'P0005';
  END IF;

  -- Find the active completed record (cover_out IS NULL)
  SELECT * INTO v_comp
  FROM public.daily_covers_completed
  WHERE "ID_cover_solicitude" = p_cover_id
    AND cover_out IS NULL
  ORDER BY cover_in DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontró el registro de cover activo' USING ERRCODE = 'P0006';
  END IF;

  -- 1. Close the cover (set cover_out)
  UPDATE public.daily_covers_completed
  SET cover_out = timezone('utc', now())
  WHERE "ID_cover_complete" = v_comp."ID_cover_complete";

  -- 2. Restore operator session to active (sesion_status = 1)
  UPDATE public.daily_sesions
  SET sesion_status = 1
  WHERE "ID_user" = v_sol."ID_user"
    AND sesion_active = 1;

  -- 3. Deactivate solicitude
  UPDATE public.daily_covers_solicitudes
  SET active = 0
  WHERE "ID_cover" = p_cover_id;

  -- Calculate duration
  v_duration := EXTRACT(EPOCH FROM (timezone('utc', now()) - v_comp.cover_in))::INTEGER / 60;

  RETURN json_build_object(
    'cover_complete_id', v_comp."ID_cover_complete",
    'operator_id',      v_sol."ID_user",
    'station_id',       v_sol."ID_station",
    'duration_minutes',  v_duration,
    'ended_at',         timezone('utc', now())
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_end_cover(INTEGER) TO authenticated;

-- =============================================================
-- RPC: List active cover requests (supervisor cover queue)
-- Returns all active, unapproved requests with operator info
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_cover_queue()
RETURNS TABLE(
  cover_id      INTEGER,
  operator_id   INTEGER,
  operator_name TEXT,
  station_id    INTEGER,
  station_number TEXT,
  cover_type_id INTEGER,
  cover_type_name TEXT,
  requested_at  TIMESTAMP,
  approved      SMALLINT,
  active        SMALLINT,
  coverer_name  TEXT,
  cover_in      TIMESTAMP,
  cover_out     TIMESTAMP
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
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
    cc.cover_out
  FROM public.daily_covers_solicitudes s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  LEFT JOIN public.daily_covers_completed cc ON cc."ID_cover_solicitude" = s."ID_cover"
  LEFT JOIN public.daily_users_names cun ON cun."ID_user" = cc."ID_cover_by"
  LEFT JOIN public.daily_covers_types ct ON ct."ID_cover_type" = COALESCE(s.cover_type, cc.cover_type)
  WHERE s.active = 1
  ORDER BY s.cover_time_request ASC;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_cover_queue() TO authenticated;
