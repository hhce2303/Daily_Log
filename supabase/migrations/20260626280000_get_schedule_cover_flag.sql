-- Expose is_break_cover in the roster read so the UI can mark/show cover operators.
DROP FUNCTION IF EXISTS public.dailyops_get_schedule(date);
CREATE OR REPLACE FUNCTION public.dailyops_get_schedule(p_date date)
RETURNS TABLE(
  id bigint, team text, operator_name text, id_user integer, matched_name text,
  shift_in text, shift_out text, break_time text, is_off smallint, sort_order integer,
  has_active_session boolean, active_cover boolean, is_break_cover smallint
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    s.id, s.team::text, s.operator_name::text, s."ID_user",
    un.user_name::text,
    s.shift_in::text, s.shift_out::text, s.break_time::text, s.is_off, s.sort_order,
    EXISTS (SELECT 1 FROM public.daily_sesions ses WHERE ses."ID_user" = s."ID_user" AND ses.sesion_active = 1),
    EXISTS (SELECT 1 FROM public.daily_covers_solicitudes c WHERE c."ID_user" = s."ID_user" AND c.active = 1),
    s.is_break_cover
  FROM public.daily_ops_schedule s
  LEFT JOIN public.daily_users_names un ON un."ID_user" = s."ID_user"
  WHERE s.schedule_date = p_date
  ORDER BY s.sort_order;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_get_schedule(date) TO authenticated;
