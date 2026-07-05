-- =============================================================================
-- Song requests: a supervisor/lead/admin opens a "pedir canciones" round; every
-- connected operator gets a box to submit ONE song (or "no quiero canción").
-- The box disappears once they submit. The supervisor sees the requests in the
-- order they arrived, and their toggle stays disabled until every connected
-- operator has responded (pending = 0).
-- =============================================================================

-- Round state (single row).
CREATE TABLE IF NOT EXISTS public.daily_song_round (
  id smallint PRIMARY KEY DEFAULT 1,
  enabled boolean NOT NULL DEFAULT false,
  opened_at timestamptz,
  CONSTRAINT daily_song_round_single CHECK (id = 1)
);
INSERT INTO public.daily_song_round (id, enabled) VALUES (1, false) ON CONFLICT (id) DO NOTHING;

-- One request per user per round (active = 1 belongs to the current round).
CREATE TABLE IF NOT EXISTS public.daily_song_requests (
  "ID_song" bigserial PRIMARY KEY,
  "ID_user" integer NOT NULL,
  song text,
  no_song boolean NOT NULL DEFAULT false,
  active smallint NOT NULL DEFAULT 1,
  requested_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS daily_song_requests_active_idx
  ON public.daily_song_requests (active, requested_at);
CREATE UNIQUE INDEX IF NOT EXISTS daily_song_requests_one_active
  ON public.daily_song_requests ("ID_user") WHERE active = 1;

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.daily_song_round ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS song_round_read ON public.daily_song_round;
CREATE POLICY song_round_read ON public.daily_song_round FOR SELECT USING (true);
-- Writes go through SECURITY DEFINER RPCs only (no write policy).

ALTER TABLE public.daily_song_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS song_req_read ON public.daily_song_requests;
-- Owner sees their own row (to know they submitted); supervisors see all (list).
CREATE POLICY song_req_read ON public.daily_song_requests FOR SELECT
  USING ("ID_user" = public.current_daily_user_id() OR public.current_user_is_supervisor());

-- Realtime: operators must learn when the round opens/closes and when their own
-- submission lands; supervisors get every request as it arrives.
ALTER TABLE public.daily_song_round REPLICA IDENTITY FULL;
ALTER TABLE public.daily_song_requests REPLICA IDENTITY FULL;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_song_round;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.daily_song_requests;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── State for the client (counts drive the supervisor toggle + operator box) ──
CREATE OR REPLACE FUNCTION public.song_state()
RETURNS json LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_enabled boolean;
  v_total int;
  v_submitted int;
  v_me int;
BEGIN
  SELECT enabled INTO v_enabled FROM public.daily_song_round WHERE id = 1;
  v_me := public.current_daily_user_id();

  -- Connected operators (role 2, active session).
  SELECT count(DISTINCT s."ID_user") INTO v_total
  FROM public.daily_sesions s
  JOIN public.daily_users u ON u."ID_user" = s."ID_user"
  WHERE s.sesion_active = 1 AND u."ID_user_rol" = 2;

  -- ...of which have already submitted this round.
  SELECT count(DISTINCT r."ID_user") INTO v_submitted
  FROM public.daily_song_requests r
  JOIN public.daily_sesions s ON s."ID_user" = r."ID_user" AND s.sesion_active = 1
  JOIN public.daily_users u ON u."ID_user" = r."ID_user" AND u."ID_user_rol" = 2
  WHERE r.active = 1;

  RETURN json_build_object(
    'enabled', COALESCE(v_enabled, false),
    'total', v_total,
    'submitted', v_submitted,
    'pending', GREATEST(v_total - v_submitted, 0),
    'i_submitted', EXISTS (SELECT 1 FROM public.daily_song_requests WHERE active = 1 AND "ID_user" = v_me),
    'is_supervisor', public.current_user_is_supervisor()
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.song_state() TO authenticated;

-- ── Supervisor: open (fresh round) / close song requests ─────────────────────
CREATE OR REPLACE FUNCTION public.song_set_enabled(p_enabled boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN RAISE EXCEPTION 'Solo supervisores'; END IF;
  IF p_enabled THEN
    UPDATE public.daily_song_requests SET active = 0 WHERE active = 1;  -- fresh round
    UPDATE public.daily_song_round SET enabled = true, opened_at = timezone('utc', now()) WHERE id = 1;
  ELSE
    UPDATE public.daily_song_round SET enabled = false WHERE id = 1;
  END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.song_set_enabled(boolean) TO authenticated;

-- ── Operator: submit a song (or "no quiero canción") for the current round ────
CREATE OR REPLACE FUNCTION public.song_submit(p_song text, p_no_song boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me int; v_enabled boolean; v_song text;
BEGIN
  v_me := public.current_daily_user_id();
  IF v_me IS NULL THEN RAISE EXCEPTION 'No autenticado'; END IF;
  SELECT enabled INTO v_enabled FROM public.daily_song_round WHERE id = 1;
  IF NOT COALESCE(v_enabled, false) THEN RAISE EXCEPTION 'Las peticiones de canciones no están habilitadas'; END IF;

  v_song := NULLIF(btrim(COALESCE(p_song, '')), '');
  IF NOT COALESCE(p_no_song, false) AND v_song IS NULL THEN
    RAISE EXCEPTION 'Escribe una canción o elige "No quiero canción"';
  END IF;

  UPDATE public.daily_song_requests SET active = 0 WHERE "ID_user" = v_me AND active = 1;
  INSERT INTO public.daily_song_requests ("ID_user", song, no_song, active)
  VALUES (v_me, CASE WHEN COALESCE(p_no_song, false) THEN NULL ELSE v_song END, COALESCE(p_no_song, false), 1);
END; $$;
GRANT EXECUTE ON FUNCTION public.song_submit(text, boolean) TO authenticated;

-- ── Supervisor: ordered list of this round's requests ────────────────────────
CREATE OR REPLACE FUNCTION public.song_list()
RETURNS TABLE(id bigint, user_name text, song text, no_song boolean, requested_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT r."ID_song", un.user_name, r.song, r.no_song, r.requested_at
  FROM public.daily_song_requests r
  LEFT JOIN public.daily_users_names un ON un."ID_user" = r."ID_user"
  WHERE r.active = 1 AND public.current_user_is_supervisor()
  ORDER BY r.requested_at ASC;
$$;
GRANT EXECUTE ON FUNCTION public.song_list() TO authenticated;

NOTIFY pgrst, 'reload schema';
