CREATE POLICY "Authenticated users can insert events" 
ON public.daily_events 
FOR INSERT TO authenticated 
WITH CHECK (true);

CREATE POLICY "Authenticated users can update events" 
ON public.daily_events 
FOR UPDATE TO authenticated 
USING (true);
