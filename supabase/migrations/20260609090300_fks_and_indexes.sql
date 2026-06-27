-- =============================================================================
-- FKs e índices faltantes
-- =============================================================================

-- ── Secuencias para tablas que las necesitan ─────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS daily_sesions_id_sesion_seq;
ALTER TABLE public.daily_sesions
  ALTER COLUMN "ID_sesion" SET DEFAULT nextval('daily_sesions_id_sesion_seq');
ALTER SEQUENCE daily_sesions_id_sesion_seq OWNED BY public.daily_sesions."ID_sesion";

CREATE SEQUENCE IF NOT EXISTS daily_covers_solicitudes_id_cover_seq;
ALTER TABLE public.daily_covers_solicitudes
  ALTER COLUMN "ID_cover" SET DEFAULT nextval('daily_covers_solicitudes_id_cover_seq');
ALTER SEQUENCE daily_covers_solicitudes_id_cover_seq OWNED BY public.daily_covers_solicitudes."ID_cover";

CREATE SEQUENCE IF NOT EXISTS daily_covers_completed_id_cover_complete_seq;
ALTER TABLE public.daily_covers_completed
  ALTER COLUMN "ID_cover_complete" SET DEFAULT nextval('daily_covers_completed_id_cover_complete_seq');
ALTER SEQUENCE daily_covers_completed_id_cover_complete_seq OWNED BY public.daily_covers_completed."ID_cover_complete";

-- ── FKs: daily_sesions ────────────────────────────────────────────────────────
ALTER TABLE public.daily_sesions
  ADD CONSTRAINT fk_sesions_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user") ON DELETE CASCADE;

ALTER TABLE public.daily_sesions
  ADD CONSTRAINT fk_sesions_station
    FOREIGN KEY ("ID_station") REFERENCES public.daily_stations_info("ID_station");

-- ── FKs: daily_stations_map ───────────────────────────────────────────────────
ALTER TABLE public.daily_stations_map
  ADD CONSTRAINT fk_stations_map_station
    FOREIGN KEY ("station_ID") REFERENCES public.daily_stations_info("ID_station");

-- ── FKs: daily_covers_solicitudes ────────────────────────────────────────────
ALTER TABLE public.daily_covers_solicitudes
  ADD CONSTRAINT fk_covers_sol_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user");

ALTER TABLE public.daily_covers_solicitudes
  ADD CONSTRAINT fk_covers_sol_station
    FOREIGN KEY ("ID_station") REFERENCES public.daily_stations_info("ID_station");

-- ── FKs: daily_covers_completed ──────────────────────────────────────────────
ALTER TABLE public.daily_covers_completed
  ADD CONSTRAINT fk_covers_comp_user
    FOREIGN KEY ("ID_user") REFERENCES public.daily_users("ID_user");

ALTER TABLE public.daily_covers_completed
  ADD CONSTRAINT fk_covers_comp_cover_by
    FOREIGN KEY ("ID_cover_by") REFERENCES public.daily_users("ID_user");

ALTER TABLE public.daily_covers_completed
  ADD CONSTRAINT fk_covers_comp_solicitude
    FOREIGN KEY ("ID_cover_solicitude") REFERENCES public.daily_covers_solicitudes("ID_cover");

-- ── FKs: daily_breaks ────────────────────────────────────────────────────────
ALTER TABLE public.daily_breaks
  ADD CONSTRAINT fk_breaks_covering
    FOREIGN KEY ("ID_user_covering") REFERENCES public.daily_users("ID_user");

ALTER TABLE public.daily_breaks
  ADD CONSTRAINT fk_breaks_covered
    FOREIGN KEY ("ID_user_covered") REFERENCES public.daily_users("ID_user");

ALTER TABLE public.daily_breaks
  ADD CONSTRAINT fk_breaks_supervisor
    FOREIGN KEY ("ID_supervisor") REFERENCES public.daily_users("ID_user");

-- ── FKs: daily_stations_visual_config ────────────────────────────────────────
ALTER TABLE public.daily_stations_visual_config
  ADD CONSTRAINT fk_stations_visual_station
    FOREIGN KEY ("ID_station") REFERENCES public.daily_stations_info("ID_station");

-- ── Índices: daily_events ─────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_events_user_datetime
  ON public.daily_events("ID_user", event_datetime DESC);

CREATE INDEX IF NOT EXISTS idx_events_site
  ON public.daily_events("ID_site");

CREATE INDEX IF NOT EXISTS idx_events_activity
  ON public.daily_events("ID_activity");

CREATE INDEX IF NOT EXISTS idx_events_status
  ON public.daily_events(event_status);

-- ── Índices: daily_specials ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_specials_supervisor
  ON public.daily_specials("ID_supervisor");

CREATE INDEX IF NOT EXISTS idx_specials_status
  ON public.daily_specials(spec_status);

CREATE INDEX IF NOT EXISTS idx_specials_datetime
  ON public.daily_specials(spec_datetime DESC);

-- ── Índices: daily_sesions ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sesions_user_active
  ON public.daily_sesions("ID_user", sesion_active);

CREATE INDEX IF NOT EXISTS idx_sesions_user_datetime
  ON public.daily_sesions("ID_user", sesion_in DESC);

-- ── Índices: daily_covers_solicitudes ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_covers_sol_user
  ON public.daily_covers_solicitudes("ID_user");

CREATE INDEX IF NOT EXISTS idx_covers_sol_active
  ON public.daily_covers_solicitudes(active);

-- ── Índices: daily_covers_completed ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_covers_comp_user
  ON public.daily_covers_completed("ID_user");

CREATE INDEX IF NOT EXISTS idx_covers_comp_cover_by
  ON public.daily_covers_completed("ID_cover_by");

CREATE INDEX IF NOT EXISTS idx_covers_comp_cover_in
  ON public.daily_covers_completed(cover_in DESC);
