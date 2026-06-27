-- =============================================================================
-- Persistent name -> user mapping: once a supervisor links a schedule name to a
-- user, that name resolves to the same user on ANY future date upload.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_ops_user_map (
  name_norm  text PRIMARY KEY,         -- lower(trim(operator_name))
  "ID_user"  integer NOT NULL,
  updated_at timestamp NOT NULL DEFAULT timezone('utc', now())
);

-- Match: persistent map first, then exact name match against daily users.
CREATE OR REPLACE FUNCTION public.dailyops_match_user(p_name text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT m."ID_user" FROM public.daily_ops_user_map m WHERE m.name_norm = lower(trim(p_name))),
    (SELECT n."ID_user" FROM public.daily_users_names n
       WHERE lower(trim(n.user_name)) = lower(trim(p_name)) LIMIT 1)
  );
$$;

-- Link a schedule row AND remember the mapping for all future uploads.
CREATE OR REPLACE FUNCTION public.dailyops_link_user(p_schedule_id bigint, p_user_id integer)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden vincular usuarios';
  END IF;

  UPDATE public.daily_ops_schedule SET "ID_user" = p_user_id WHERE id = p_schedule_id
  RETURNING operator_name INTO v_name;

  IF v_name IS NULL THEN RETURN; END IF;

  IF p_user_id IS NULL THEN
    DELETE FROM public.daily_ops_user_map WHERE name_norm = lower(trim(v_name));
  ELSE
    INSERT INTO public.daily_ops_user_map (name_norm, "ID_user", updated_at)
    VALUES (lower(trim(v_name)), p_user_id, timezone('utc', now()))
    ON CONFLICT (name_norm) DO UPDATE SET "ID_user" = EXCLUDED."ID_user", updated_at = timezone('utc', now());

    -- Apply the new mapping to any other rows with the same name (current dates).
    UPDATE public.daily_ops_schedule
    SET "ID_user" = p_user_id
    WHERE lower(trim(operator_name)) = lower(trim(v_name)) AND "ID_user" IS DISTINCT FROM p_user_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.dailyops_link_user(bigint, integer) TO authenticated;
