-- =============================================================================
-- Fix 1: get_on_duty_supervisor — preferir supervisores con sesión activa
-- El original tomaba el "primer supervisor" sin importar si estaba en turno.
-- Ahora: supervisor con sesión activa > supervisor sin sesión (fallback).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_on_duty_supervisor()
RETURNS INTEGER AS $$
DECLARE
  v_supervisor_id INTEGER;
BEGIN
  -- Primero: supervisor con sesión activa ahora mismo
  SELECT u."ID_user" INTO v_supervisor_id
  FROM public.daily_users u
  JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
  JOIN public.daily_sesions s ON s."ID_user" = u."ID_user"
  WHERE r.user_rol_name IN ('Supervisor', 'Lead Supervisor', 'Admin')
    AND s.sesion_active = 1
  ORDER BY u."ID_user"
  LIMIT 1;

  IF v_supervisor_id IS NOT NULL THEN
    RETURN v_supervisor_id;
  END IF;

  -- Fallback: cualquier supervisor activo (active=1), aunque no esté en turno
  SELECT u."ID_user" INTO v_supervisor_id
  FROM public.daily_users u
  JOIN public.daily_user_rol r ON u."ID_user_rol" = r."ID_user_rol"
  WHERE r.user_rol_name IN ('Supervisor', 'Lead Supervisor', 'Admin')
    AND u.active = 1
  ORDER BY u."ID_user"
  LIMIT 1;

  RETURN v_supervisor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Fix 2: handle_new_user — NO sobreescribir usuarios ya existentes
-- El trigger original asignaba rol=1 (Admin) a todo usuario nuevo.
-- El script migrate_users.js ya gestiona la vinculación de usuarios existentes,
-- pero para nuevos registros mantenemos rol=2 (Operador) como default seguro.
-- ADICIONALMENTE: si ya existe una fila en daily_users con el mismo ID_user,
-- solo actualizamos supabase_auth_id (en caso de re-registro).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_existing_id INTEGER;
BEGIN
  -- Buscar si ya hay un daily_users sin supabase_auth_id que coincida por email
  -- (usuarios migrados con el script tendrán supabase_auth_id ya puesto)
  -- Para registros nuevos sin pre-existencia: crear con rol Operador

  IF NOT EXISTS (
    SELECT 1 FROM public.daily_users WHERE supabase_auth_id = new.id
  ) THEN
    INSERT INTO public.daily_users ("ID_user_rol", "user_password", "active", "supabase_auth_id")
    VALUES (
      2,               -- Operador (no Admin)
      'supabase-auth',
      1,
      new.id
    );
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
