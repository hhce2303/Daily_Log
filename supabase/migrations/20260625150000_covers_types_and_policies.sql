-- =============================================================================
-- Covers: seed types and fix RLS so the completion flow works (same class of
-- bug as the specials pipeline).
--
--   * daily_covers_types was empty -> coverTime showed "Cover" for every row.
--   * daily_covers_completed had no INSERT policy -> a cover could never be
--     recorded as completed (the whole coverTime view stayed empty).
--   * daily_covers_solicitudes had no UPDATE policy -> a fulfilled request could
--     not be marked inactive (desktop: insertar_cover sets active = 0).
-- =============================================================================

-- 1. Seed cover types (from legacy MySQL daily_covers_types).
INSERT INTO public.daily_covers_types ("ID_cover_type", cover_type)
SELECT * FROM (VALUES
    (1, 'Cover Baño'),
    (2, 'Cover Training'),
    (3, 'Otro'),
    (4, 'Break')
) AS v("ID_cover_type", cover_type)
WHERE NOT EXISTS (SELECT 1 FROM public.daily_covers_types);

-- 2. Allow recording a completed cover (the person covering, or a supervisor).
DROP POLICY IF EXISTS covers_comp_insert ON public.daily_covers_completed;
CREATE POLICY covers_comp_insert ON public.daily_covers_completed
    FOR INSERT TO authenticated
    WITH CHECK (public.current_daily_user_id() IS NOT NULL);

-- 3. Allow marking a request fulfilled/cancelled (active = 0).
DROP POLICY IF EXISTS covers_sol_update ON public.daily_covers_solicitudes;
CREATE POLICY covers_sol_update ON public.daily_covers_solicitudes
    FOR UPDATE TO authenticated
    USING (public.current_daily_user_id() IS NOT NULL)
    WITH CHECK (public.current_daily_user_id() IS NOT NULL);
