-- =============================================================================
-- Live counts for the supervisor dashboard (replaces hardcoded 0s / TODOs).
-- One round-trip; supervisor/admin only.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.dashboard_stats()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RETURN json_build_object(
      'specials_pending', 0, 'covers_active', 0,
      'operators_active', 0, 'events_24h', 0
    );
  END IF;

  RETURN json_build_object(
    'specials_pending', (SELECT count(*) FROM public.daily_specials WHERE spec_status IS NULL),
    'covers_active',    (SELECT count(*) FROM public.daily_covers_solicitudes WHERE active = 1),
    'operators_active', (SELECT count(*) FROM public.daily_sesions WHERE sesion_active = 1),
    'events_24h',       (SELECT count(*) FROM public.daily_events
                           WHERE event_datetime >= timezone('utc', now()) - interval '24 hours'
                             AND event_status = 'confirmed')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_stats() TO authenticated;
