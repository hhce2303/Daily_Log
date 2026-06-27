-- =============================================================================
-- Populate the timezone offset tables from the legacy MySQL data
-- (sig_dailylogs_clone_20260512). These were empty in Supabase, so
-- get_timezone_offset() always returned 0 and spec_datetime was computed as
-- UTC-5 regardless of season/zone.
--
-- Formula (desktop): spec_datetime = event_datetime(UTC) + (offset - 5) hours
--   e.g. ET summer offset=1 -> UTC-4 (EDT); ET winter offset=0 -> UTC-5 (EST).
-- =============================================================================

-- Seasons: SUMMER is active for the 2026-03-09 .. 2026-10-05 window.
INSERT INTO public.daily_season_offsets
    ("ID_season", season_offsets, active, season_datetime_in, season_datetime_out)
SELECT * FROM (VALUES
    (2, 'WINTER', 0, '2025-10-05 00:00:00'::timestamp, '2026-03-09 02:00:00'::timestamp),
    (3, 'SUMMER', 1, '2026-03-09 02:00:00'::timestamp, '2026-10-05 00:00:00'::timestamp)
) AS v("ID_season", season_offsets, active, season_datetime_in, season_datetime_out)
WHERE NOT EXISTS (SELECT 1 FROM public.daily_season_offsets);

-- Summer (DST) per-zone offsets relative to the ET-standard base.
INSERT INTO public.daily_summer_offsets ("ID_time_offset", time_zone, time_offset)
SELECT * FROM (VALUES
    (1, 'ET', 1), (2, 'CT', 0), (3, 'MT', -1), (4, 'MST', -2), (5, 'PT', -2)
) AS v("ID_time_offset", time_zone, time_offset)
WHERE NOT EXISTS (SELECT 1 FROM public.daily_summer_offsets);

-- Winter (standard time) per-zone offsets.
INSERT INTO public.daily_winter_offsets ("ID_time_offset", time_zone, time_offset)
SELECT * FROM (VALUES
    (1, 'ET', 0), (2, 'CT', -1), (3, 'MT', -2), (4, 'MST', -2), (5, 'PT', -3)
) AS v("ID_time_offset", time_zone, time_offset)
WHERE NOT EXISTS (SELECT 1 FROM public.daily_winter_offsets);
