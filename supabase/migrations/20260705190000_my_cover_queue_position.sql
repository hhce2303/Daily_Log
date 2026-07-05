-- Let operators see their position ("turno") in the cover queue.
--
-- my_cover_requests() returns only the CALLER's covers, so the frontend can't
-- rank them against the global line. Add a queue_position column computed here
-- (SECURITY DEFINER sees the whole queue): the 1-based rank of each PENDING
-- cover (active=1, approved=0) across ALL operators, ordered by request time
-- (earliest = #1) — the same ordering the supervisor "Turno" column uses.
-- NULL for covers no longer waiting (in progress / done / cancelled).

-- Return type changes (new queue_position column) ⇒ must drop first.
DROP FUNCTION IF EXISTS public.my_cover_requests();

CREATE OR REPLACE FUNCTION public.my_cover_requests()
 RETURNS TABLE(
   cover_id integer, operator_name text, station_number text,
   cover_type_id integer, cover_type_name text,
   requested_at timestamp without time zone, approved smallint, active smallint,
   coverer_name text, cover_in timestamp without time zone, cover_out timestamp without time zone,
   queue_position integer
 )
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH pending_rank AS (
    SELECT "ID_cover",
           row_number() OVER (ORDER BY cover_time_request ASC, "ID_cover" ASC)::integer AS pos
    FROM public.daily_covers_solicitudes
    WHERE active = 1 AND approved = 0
  )
  SELECT
    s."ID_cover",
    opn.user_name,
    si.station_number,
    COALESCE(s.cover_type, cc.cover_type)::integer,
    ct.cover_type,
    s.cover_time_request,
    s.approved,
    s.active,
    cun.user_name,          -- coverer name
    cc.cover_in,
    cc.cover_out,
    pr.pos                  -- position in the pending line (NULL if not waiting)
  FROM public.daily_covers_solicitudes s
  LEFT JOIN public.daily_users_names opn ON opn."ID_user" = s."ID_user"
  LEFT JOIN public.daily_stations_info si ON si."ID_station" = s."ID_station"
  LEFT JOIN LATERAL (
    SELECT c.* FROM public.daily_covers_completed c
    WHERE c."ID_cover_solicitude" = s."ID_cover"
    ORDER BY c.cover_in DESC LIMIT 1
  ) cc ON true
  LEFT JOIN public.daily_users_names cun ON cun."ID_user" = cc."ID_cover_by"
  LEFT JOIN public.daily_covers_types ct ON ct."ID_cover_type" = COALESCE(s.cover_type, cc.cover_type)
  LEFT JOIN pending_rank pr ON pr."ID_cover" = s."ID_cover"
  WHERE s."ID_user" = public.current_daily_user_id()
    AND (s.active = 1 OR s.approved = 1)
  ORDER BY s.cover_time_request DESC;
$function$;

-- DROP removed the prior grant; re-grant.
GRANT EXECUTE ON FUNCTION public.my_cover_requests() TO authenticated;

NOTIFY pgrst, 'reload schema';
