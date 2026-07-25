-- =============================================================================
-- Fix: daily_password_reset_requests quedó con RLS habilitado y SIN políticas.
-- Supabase Realtime evalúa RLS para decidir si entrega un cambio al suscriptor:
-- sin política de SELECT, el operador NUNCA habría recibido el evento y el
-- banner "reinicia la app para personalizar tu contraseña" no habría aparecido
-- en tiempo real (mismo patrón que daily_station_messages, que sí tiene su
-- política de fila propia y por eso su realtime funciona).
--
-- Política mínima: cada usuario ve SOLO su propia fila (la tabla no tiene datos
-- sensibles, solo ids y fechas). Las escrituras siguen siendo exclusivas de los
-- RPCs SECURITY DEFINER -- no se otorga insert/update/delete a nadie.
-- =============================================================================

DROP POLICY IF EXISTS pw_reset_select_own ON public.daily_password_reset_requests;
CREATE POLICY pw_reset_select_own ON public.daily_password_reset_requests
  FOR SELECT TO authenticated
  USING ("ID_user" = public.current_daily_user_id() OR public.current_user_is_supervisor());

REVOKE INSERT, UPDATE, DELETE ON public.daily_password_reset_requests FROM anon, authenticated;
GRANT SELECT ON public.daily_password_reset_requests TO authenticated;
