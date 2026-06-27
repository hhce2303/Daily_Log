-- =============================================================================
-- RLS: Políticas coherentes para todas las tablas del alcance
--
-- Convención de roles:
--   operador     → ID_user_rol = 2
--   supervisor   → ID_user_rol = 3
--   lead_sup     → ID_user_rol = 4
--   admin        → ID_user_rol = 1
--   "supervisor+" = ID_user_rol IN (1, 3, 4)
-- =============================================================================

-- ── daily_events ─────────────────────────────────────────────────────────────
-- Eliminar políticas previas permisivas
DROP POLICY IF EXISTS "Authenticated users can read events" ON public.daily_events;
DROP POLICY IF EXISTS "Authenticated users can insert events" ON public.daily_events;
DROP POLICY IF EXISTS "Authenticated users can update events" ON public.daily_events;

-- Operadores: solo ven sus propios eventos
CREATE POLICY "events_select_own"
ON public.daily_events FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR
  -- Supervisores y admins ven todos (para audit)
  EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" IN (1, 3, 4)
  )
);

-- Cualquier autenticado puede insertar (el trigger valida lógica de negocio)
CREATE POLICY "events_insert_authenticated"
ON public.daily_events FOR INSERT TO authenticated
WITH CHECK (
  "ID_user" = public.current_daily_user_id()
);

-- Solo el propio operador o supervisores pueden actualizar
CREATE POLICY "events_update_own_or_supervisor"
ON public.daily_events FOR UPDATE TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" IN (1, 3, 4)
  )
);

-- ── daily_activities ──────────────────────────────────────────────────────────
-- Todos los autenticados leen (catálogo público)
DROP POLICY IF EXISTS "Authenticated users can read activities" ON public.daily_activities;
CREATE POLICY "activities_select_all"
ON public.daily_activities FOR SELECT TO authenticated
USING (true);

-- ── daily_users ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view own profile" ON public.daily_users;

-- Cada usuario lee su propio perfil; supervisores leen todos (para asignar covers, etc.)
CREATE POLICY "users_select_own_or_supervisor"
ON public.daily_users FOR SELECT TO authenticated
USING (
  supabase_auth_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u2
    WHERE u2.supabase_auth_id = auth.uid()
      AND u2."ID_user_rol" IN (1, 3, 4)
  )
);

-- ── daily_users_names ─────────────────────────────────────────────────────────
ALTER TABLE public.daily_users_names ENABLE ROW LEVEL SECURITY;

CREATE POLICY "names_select_authenticated"
ON public.daily_users_names FOR SELECT TO authenticated
USING (true);

-- ── daily_user_rol ────────────────────────────────────────────────────────────
ALTER TABLE public.daily_user_rol ENABLE ROW LEVEL SECURITY;

CREATE POLICY "roles_select_authenticated"
ON public.daily_user_rol FOR SELECT TO authenticated
USING (true);

-- ── daily_sites ───────────────────────────────────────────────────────────────
ALTER TABLE public.daily_sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sites_select_authenticated"
ON public.daily_sites FOR SELECT TO authenticated
USING (true);

-- ── daily_specials ────────────────────────────────────────────────────────────
ALTER TABLE public.daily_specials ENABLE ROW LEVEL SECURITY;

-- Supervisor asignado ve sus propios specials; admin ve todos
CREATE POLICY "specials_select_supervisor"
ON public.daily_specials FOR SELECT TO authenticated
USING (
  "ID_supervisor" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" = 1 -- Admin
  )
);

-- Actualizaciones: solo el supervisor asignado o admin
CREATE POLICY "specials_update_supervisor"
ON public.daily_specials FOR UPDATE TO authenticated
USING (
  "ID_supervisor" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" = 1
  )
);

-- Inserts solo vía trigger (SECURITY DEFINER), no directamente desde clientes
-- No se crea política INSERT para evitar inserciones directas accidentales.

-- ── daily_sesions ─────────────────────────────────────────────────────────────
ALTER TABLE public.daily_sesions ENABLE ROW LEVEL SECURITY;

-- Lectura: propio usuario ve sus sesiones; supervisores ven todas
CREATE POLICY "sesions_select_own_or_supervisor"
ON public.daily_sesions FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" IN (1, 3, 4)
  )
);

-- Escritura solo vía RPC (SECURITY DEFINER) — no se expone directamente
-- INSERT/UPDATE se deja sin política → solo service_role y SECURITY DEFINER pueden hacerlo

-- ── daily_stations_info ───────────────────────────────────────────────────────
ALTER TABLE public.daily_stations_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stations_info_select_authenticated"
ON public.daily_stations_info FOR SELECT TO authenticated
USING (true);

-- ── daily_stations_map ────────────────────────────────────────────────────────
ALTER TABLE public.daily_stations_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stations_map_select_authenticated"
ON public.daily_stations_map FOR SELECT TO authenticated
USING (true);

-- ── daily_covers_solicitudes ──────────────────────────────────────────────────
ALTER TABLE public.daily_covers_solicitudes ENABLE ROW LEVEL SECURITY;

-- Operador ve/crea solo las suyas; supervisores ven todas
CREATE POLICY "covers_sol_select"
ON public.daily_covers_solicitudes FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" IN (1, 3, 4)
  )
);

CREATE POLICY "covers_sol_insert_own"
ON public.daily_covers_solicitudes FOR INSERT TO authenticated
WITH CHECK ("ID_user" = public.current_daily_user_id());

-- ── daily_covers_completed ────────────────────────────────────────────────────
ALTER TABLE public.daily_covers_completed ENABLE ROW LEVEL SECURITY;

-- Operador ve los covers donde fue cubierto o cubrió; supervisores ven todo
CREATE POLICY "covers_comp_select"
ON public.daily_covers_completed FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR "ID_cover_by" = public.current_daily_user_id()
  OR EXISTS (
    SELECT 1 FROM public.daily_users u
    WHERE u."ID_user" = public.current_daily_user_id()
      AND u."ID_user_rol" IN (1, 3, 4)
  )
);

-- ── daily_special_groups ──────────────────────────────────────────────────────
ALTER TABLE public.daily_special_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "special_groups_select_authenticated"
ON public.daily_special_groups FOR SELECT TO authenticated
USING (true);

-- ── daily_season_offsets / daily_winter_offsets / daily_summer_offsets ────────
ALTER TABLE public.daily_season_offsets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_winter_offsets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_summer_offsets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "season_offsets_select_authenticated"
ON public.daily_season_offsets FOR SELECT TO authenticated
USING (true);

CREATE POLICY "winter_offsets_select_authenticated"
ON public.daily_winter_offsets FOR SELECT TO authenticated
USING (true);

CREATE POLICY "summer_offsets_select_authenticated"
ON public.daily_summer_offsets FOR SELECT TO authenticated
USING (true);

-- ── daily_stations_visual_config ──────────────────────────────────────────────
ALTER TABLE public.daily_stations_visual_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stations_visual_config_select_authenticated"
ON public.daily_stations_visual_config FOR SELECT TO authenticated
USING (true);

-- ── daily_covers_types ────────────────────────────────────────────────────────
ALTER TABLE public.daily_covers_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "covers_types_select_authenticated"
ON public.daily_covers_types FOR SELECT TO authenticated
USING (true);
