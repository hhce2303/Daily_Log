-- Update RLS policy so coverers can see active cover requests
DROP POLICY IF EXISTS "covers_sol_select" ON public.daily_covers_solicitudes;
CREATE POLICY "covers_sol_select"
ON public.daily_covers_solicitudes FOR SELECT TO authenticated
USING (
  "ID_user" = public.current_daily_user_id()
  OR public.current_user_is_supervisor()
  OR active = 1
  OR EXISTS (
      -- Or if the user is the one who took over the cover
      SELECT 1 FROM public.daily_covers_completed c
      WHERE c."ID_cover_solicitude" = "ID_cover"
      AND c."ID_cover_by" = public.current_daily_user_id()
  )
);
