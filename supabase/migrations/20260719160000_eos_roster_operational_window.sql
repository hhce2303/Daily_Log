-- EOS: el In/Out (login/logout real) y el break de cada persona deben anclarse a
-- SU turno del día p_date, no a una ventana fija [p_date, p_date+2). Los turnos
-- aquí cruzan medianoche: la MADRUGADA de p_date pertenece al turno de p_date-1,
-- así que no debe contarse para p_date. Se resuelve el inicio del turno de cada
-- persona (shift_resolve_datetime, hora local + 5h = UTC) y se buscan sesiones/
-- break en una ventana alrededor de ese inicio; la ocurrencia del día anterior
-- (24h antes) queda fuera.

CREATE OR REPLACE FUNCTION public.eos_get_roster(p_date date)
RETURNS TABLE(
  id_user integer, operator_name text, team text, role_id integer,
  shift_in text, shift_out text, break_time text,
  is_break_cover integer, is_bathroom_cover integer,
  login_in timestamp, login_out timestamp, break_in timestamp, break_out timestamp
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $func$
  WITH base AS (
    SELECT s.*, u."ID_user_rol" AS role_id,
      (public.shift_resolve_datetime(p_date, s.shift_in, s.shift_in, s.shift_out) + interval '5 hours') AS start_utc
    FROM public.daily_ops_schedule s
    JOIN public.daily_users u ON u."ID_user" = s."ID_user"
    WHERE s.schedule_date = p_date AND s.is_off = 0 AND s."ID_user" IS NOT NULL
  )
  SELECT
    b."ID_user", b.operator_name, b.team, b.role_id,
    b.shift_in, b.shift_out, b.break_time, b.is_break_cover, b.is_bathroom_cover,
    (SELECT min(se.sesion_in) FROM public.daily_sesions se
       WHERE se."ID_user" = b."ID_user" AND b.start_utc IS NOT NULL
         AND se.sesion_in >= b.start_utc - interval '2 hours'
         AND se.sesion_in <  b.start_utc + interval '13 hours'),
    (SELECT max(se.sesion_out) FROM public.daily_sesions se
       WHERE se."ID_user" = b."ID_user" AND b.start_utc IS NOT NULL
         AND se.sesion_in >= b.start_utc - interval '2 hours'
         AND se.sesion_in <  b.start_utc + interval '13 hours'),
    brk.cover_in, brk.cover_out
  FROM base b
  LEFT JOIN LATERAL (
    SELECT cc.cover_in, cc.cover_out
    FROM public.daily_covers_completed cc
    JOIN public.daily_covers_solicitudes so ON so."ID_cover" = cc."ID_cover_solicitude"
    WHERE so."ID_user" = b."ID_user" AND cc.cover_type = 4 AND b.start_utc IS NOT NULL
      AND cc.cover_in >= b.start_utc - interval '1 hour'
      AND cc.cover_in <  b.start_utc + interval '13 hours'
    ORDER BY cc.cover_in ASC LIMIT 1
  ) brk ON true
  ORDER BY b.role_id, b.sort_order, b.operator_name;
$func$;
