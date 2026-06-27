-- =============================================================================
-- Fix specials business logic:
-- 1. Populate daily_special_groups with all dealer site groups
--    (all groups except internal SIG office)
-- 2. Fix get_on_duty_supervisor() to prefer supervisors with active sessions
-- =============================================================================

-- 1. Populate special groups (all dealer groups — not SIG internal office)
INSERT INTO public.daily_special_groups ("ID_site_special", "site_group_special")
SELECT ROW_NUMBER() OVER () AS id, g
FROM (VALUES
  ('AS'), ('BRL'), ('BTN'), ('DT'), ('HUD'),
  ('JE'), ('KG'), ('KT'), ('LT'), ('MK'),
  ('ML'), ('PE'), ('RML'), ('RV'), ('SCH'),
  ('SL'), ('TC'), ('US27'), ('WAG')
) AS t(g)
WHERE NOT EXISTS (
  SELECT 1 FROM public.daily_special_groups
  WHERE "site_group_special" = t.g
);

-- 2. Fix get_on_duty_supervisor: prefer supervisor with active session,
--    fallback to first supervisor/admin user
CREATE OR REPLACE FUNCTION public.get_on_duty_supervisor()
RETURNS INTEGER AS $$
DECLARE
    v_supervisor_id INTEGER;
BEGIN
    -- First: supervisor or admin with an active session
    SELECT s."ID_user" INTO v_supervisor_id
    FROM public.daily_sesions s
    JOIN public.daily_users u ON u."ID_user" = s."ID_user"
    WHERE s.sesion_active = 1
      AND u."ID_user_rol" IN (1, 3, 4)   -- Admin, Supervisor, Lead Supervisor
    ORDER BY s.sesion_in DESC
    LIMIT 1;

    IF v_supervisor_id IS NOT NULL THEN
        RETURN v_supervisor_id;
    END IF;

    -- Fallback: any supervisor/admin user
    SELECT u."ID_user" INTO v_supervisor_id
    FROM public.daily_users u
    WHERE u."ID_user_rol" IN (1, 3, 4)
    ORDER BY u."ID_user"
    LIMIT 1;

    RETURN v_supervisor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
