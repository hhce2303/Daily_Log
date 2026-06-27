-- =============================================================================
-- Fix infinite recursion in RLS policies.
--
-- Root cause: policies on daily_users contain EXISTS (SELECT 1 FROM daily_users)
-- which triggers the same policy again. Any other table whose policy also
-- queries daily_users (events, specials, covers, sesions) hits the same loop.
--
-- Fix: SECURITY DEFINER helper that reads daily_users bypassing RLS.
--      Replace all inline EXISTS(daily_users) supervisor checks with it.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.current_user_is_supervisor()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid()
      AND "ID_user_rol" IN (1, 3, 4)
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── daily_users ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_select_own_or_supervisor" ON public.daily_users;
CREATE POLICY "users_select_own_or_supervisor"
ON public.daily_users FOR SELECT TO authenticated
USING (
  supabase_auth_id = auth.uid()
  OR public.current_user_is_supervisor()
);

-- ── daily_events ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "events_select_own" ON public.daily_events;
CREATE POLICY "events_select_own"
ON public.daily_events FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

DROP POLICY IF EXISTS "events_update_own_or_supervisor" ON public.daily_events;
CREATE POLICY "events_update_own_or_supervisor"
ON public.daily_events FOR UPDATE TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

-- ── daily_specials ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "specials_select_supervisor" ON public.daily_specials;
CREATE POLICY "specials_select_supervisor"
ON public.daily_specials FOR SELECT TO authenticated
USING (
  "ID_supervisor" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

DROP POLICY IF EXISTS "specials_update_supervisor" ON public.daily_specials;
CREATE POLICY "specials_update_supervisor"
ON public.daily_specials FOR UPDATE TO authenticated
USING (
  "ID_supervisor" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

-- ── daily_sesions ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "sesions_select_own_or_supervisor" ON public.daily_sesions;
CREATE POLICY "sesions_select_own_or_supervisor"
ON public.daily_sesions FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

-- ── daily_covers_solicitudes ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "covers_sol_select" ON public.daily_covers_solicitudes;
CREATE POLICY "covers_sol_select"
ON public.daily_covers_solicitudes FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);

-- ── daily_covers_completed ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "covers_comp_select" ON public.daily_covers_completed;
CREATE POLICY "covers_comp_select"
ON public.daily_covers_completed FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR "ID_cover_by" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
);
