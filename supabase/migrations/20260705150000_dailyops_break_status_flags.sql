-- =============================================================================
-- Fix the phantom "☕ en break" in Daily Ops. The old active_cover flag was
-- EXISTS(any active cover solicitud) — any type (baño/estación/break), any
-- approval state, any age — so a pending bathroom cover or a stale never-closed
-- cover from a previous day painted the operator "en break", on every schedule
-- date. Split it into two flags:
--   • active_cover         → truly on break: an active BREAK cover (type 4)
--                            requested within the last 12h (ignores orphans).
--   • has_any_active_cover → the old broad meaning; gates the "Iniciar break"
--                            button, matching the backend which reuses/blocks on
--                            ANY active cover for the user.
-- Display-only read function; no behavioral logic touched.
-- =============================================================================

DROP FUNCTION IF EXISTS public.dailyops_get_schedule(date);
CREATE FUNCTION public.dailyops_get_schedule(p_date date)
 RETURNS TABLE(id bigint, team text, operator_name text, id_user integer, matched_name text, shift_in text, shift_out text, break_time text, is_off smallint, sort_order integer, has_active_session boolean, active_cover boolean, is_break_cover smallint, self_break_at timestamp without time zone, is_bathroom_cover smallint, has_any_active_cover boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    s.id, s.team::text, s.operator_name::text, s."ID_user",
    un.user_name::text,
    s.shift_in::text, s.shift_out::text, s.break_time::text, s.is_off, s.sort_order,
    EXISTS (SELECT 1 FROM public.daily_sesions ses WHERE ses."ID_user" = s."ID_user" AND ses.sesion_active = 1),
    EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c
            WHERE c."ID_user" = s."ID_user" AND c.active = 1
              AND c.cover_type = 4
              AND c.cover_time_request >= timezone('utc', now()) - interval '12 hours'),
    s.is_break_cover,
    s.break_started_at,
    s.is_bathroom_cover,
    EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c
            WHERE c."ID_user" = s."ID_user" AND c.active = 1)
  FROM public.daily_ops_schedule s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  WHERE s.schedule_date = p_date
  ORDER BY s.sort_order;
$function$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_schedule(date) TO authenticated;

-- Force PostgREST to pick up the recreated function immediately (avoids
-- "Could not find the function ... in the schema cache" until next reload).
NOTIFY pgrst, 'reload schema';
