-- PRIVATE storage bucket for distribution-map report images. Images are uploaded
-- by the authenticated user; the client then creates a time-limited SIGNED URL to
-- hand to the Teams webhook. Nothing is world-readable.
INSERT INTO storage.buckets (id, name, public)
VALUES ('reports', 'reports', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Authenticated users may upload and read (needed to mint signed URLs); no anon access.
DROP POLICY IF EXISTS reports_auth_insert ON storage.objects;
CREATE POLICY reports_auth_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'reports');

DROP POLICY IF EXISTS reports_auth_update ON storage.objects;
CREATE POLICY reports_auth_update ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'reports') WITH CHECK (bucket_id = 'reports');

DROP POLICY IF EXISTS reports_auth_read ON storage.objects;
CREATE POLICY reports_auth_read ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'reports');
