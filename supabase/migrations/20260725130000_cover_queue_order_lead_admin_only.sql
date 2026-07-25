-- =============================================================================
-- Reordenar la cola de covers: SOLO lead supervisor (rol 4) y admin (rol 1).
--
-- Antes usaba current_user_is_supervisor(), que incluye también al supervisor
-- normal (roles 1, 3, 4). El orden de atención es una decisión de mando, así que
-- se restringe a lead/admin. Un supervisor normal sigue viendo la cola y puede
-- iniciar/terminar covers -- solo no puede cambiar el ORDEN.
--
-- Nota: el rol 5 (IT) queda fuera a propósito; no es un rol de operación.
-- =============================================================================

-- Helper reutilizable (mismo patrón que current_user_is_supervisor).
CREATE OR REPLACE FUNCTION public.current_user_is_lead_or_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.daily_users
    WHERE supabase_auth_id = auth.uid()
      AND "ID_user_rol" IN (1, 4)   -- 1 = Admin, 4 = Lead Supervisor
  )
$$;
GRANT EXECUTE ON FUNCTION public.current_user_is_lead_or_admin() TO authenticated;

-- La guarda del reorden pasa a lead/admin. Se hace cumplir en el SERVIDOR, no
-- solo escondiendo el asa en la UI.
CREATE OR REPLACE FUNCTION public.rpc_set_cover_queue_order(p_cover_ids integer[])
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_n integer := 0;
BEGIN
  IF NOT public.current_user_is_lead_or_admin() THEN
    RAISE EXCEPTION 'Solo lead supervisor o admin pueden reordenar la cola de covers'
      USING ERRCODE = 'P0004';
  END IF;

  IF p_cover_ids IS NULL OR array_length(p_cover_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  WITH wanted AS (
    SELECT id AS cover_id, ord AS pos
    FROM unnest(p_cover_ids) WITH ORDINALITY AS t(id, ord)
  )
  UPDATE public.daily_covers_solicitudes s
     SET queue_order = w.pos
    FROM wanted w
   WHERE s."ID_cover" = w.cover_id
     AND s.active = 1
     AND s.approved = 0;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_set_cover_queue_order(integer[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_set_cover_queue_order(integer[]) TO authenticated;
