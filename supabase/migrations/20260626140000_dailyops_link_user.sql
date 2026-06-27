-- =============================================================================
-- DailyOps: manual name -> user linking, and preserve manual links across
-- re-uploads (so re-pasting the schedule doesn't wipe the mappings).
-- =============================================================================

-- Manually link (or unlink) a schedule row to a daily user.
CREATE OR REPLACE FUNCTION public.dailyops_link_user(p_schedule_id bigint, p_user_id integer)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden vincular usuarios';
  END IF;
  UPDATE public.daily_ops_schedule SET "ID_user" = p_user_id WHERE id = p_schedule_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_link_user(bigint, integer) TO authenticated;

-- Save schedule, preserving prior manual links by operator name.
CREATE OR REPLACE FUNCTION public.dailyops_save_schedule(
  p_date  date,
  p_rows  jsonb,
  p_notes text
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
  n integer := 0;
  v_prior jsonb;
  v_name text;
  v_uid integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden subir horarios';
  END IF;

  -- Snapshot existing links (name -> ID_user) before replacing.
  SELECT jsonb_object_agg(k, v) INTO v_prior FROM (
    SELECT DISTINCT ON (lower(trim(operator_name)))
           lower(trim(operator_name)) AS k, "ID_user" AS v
    FROM public.daily_ops_schedule
    WHERE schedule_date = p_date AND "ID_user" IS NOT NULL
  ) t;

  DELETE FROM public.daily_ops_schedule WHERE schedule_date = p_date;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows)
  LOOP
    v_name := r->>'name';
    -- 1) exact auto-match, 2) prior manual link by name
    v_uid := public.dailyops_match_user(v_name);
    IF v_uid IS NULL AND v_prior IS NOT NULL THEN
      v_uid := (v_prior->>lower(trim(v_name)))::int;
    END IF;

    INSERT INTO public.daily_ops_schedule
      (schedule_date, team, operator_name, "ID_user", shift_in, shift_out, break_time, is_off, sort_order)
    VALUES (
      p_date, COALESCE(r->>'team',''), COALESCE(v_name,''), v_uid,
      NULLIF(r->>'shift_in',''), NULLIF(r->>'shift_out',''), NULLIF(r->>'break_time',''),
      COALESCE((r->>'is_off')::int, 0), COALESCE((r->>'sort')::int, n)
    );
    n := n + 1;
  END LOOP;

  INSERT INTO public.daily_ops_notes (schedule_date, notes, updated_at)
  VALUES (p_date, p_notes, timezone('utc', now()))
  ON CONFLICT (schedule_date) DO UPDATE SET notes = EXCLUDED.notes, updated_at = timezone('utc', now());

  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_save_schedule(date, jsonb, text) TO authenticated;
