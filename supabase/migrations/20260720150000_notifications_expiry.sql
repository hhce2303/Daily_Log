-- =============================================================================
-- Notificaciones con vigencia ("en vivo") + frescura.
--
-- Problema: una notificación se guarda y al iniciar sesión se abre como modal
-- "en vivo" la primera no leída sin importar su antigüedad → quien llega 1 hora
-- después ve algo viejo como si fuera del momento. Además, info transitoria
-- ("esto pasa ahora") no debería resurgir como en vivo más tarde.
--
-- Cambios de datos:
--   • Nueva columna expires_at (nullable = nunca expira): a partir de cuándo la
--     notificación deja de considerarse "en vivo". El historial se conserva
--     igual (la campana la sigue mostrando con su hora real).
--   • send_notification y notify_connected_operators aceptan p_expires_minutes
--     (NULL = siempre). El cliente ofrece 15 min / 1 h / 8 h / siempre.
--   • fetch_my_notifications ahora devuelve expires_at para que el cliente
--     decida si abrir el modal en vivo (frescura/expiración) o solo historial.
-- =============================================================================

ALTER TABLE public.daily_station_messages
  ADD COLUMN IF NOT EXISTS expires_at timestamp without time zone;

-- ── send_notification (agrega p_expires_minutes) ────────────────────────────
DROP FUNCTION IF EXISTS public.send_notification(integer, text, text, text);
CREATE FUNCTION public.send_notification(
  p_target_user_id integer,
  p_title text,
  p_body text,
  p_type text DEFAULT 'info',
  p_expires_minutes integer DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_id integer;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden enviar notificaciones';
  END IF;
  INSERT INTO public.daily_station_messages
    ("ID_sender_user", "ID_target_user", message_type, message_title, message_body,
     created_at, is_active, expires_at)
  VALUES
    (public.current_daily_user_id(), p_target_user_id, COALESCE(p_type,'info'),
     p_title, p_body, timezone('utc', now()), 1,
     CASE WHEN p_expires_minutes IS NULL THEN NULL
          ELSE timezone('utc', now()) + make_interval(mins => p_expires_minutes) END)
  RETURNING "ID_message" INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_notification(integer, text, text, text, integer) TO anon, authenticated;

-- ── notify_connected_operators (agrega p_expires_minutes) ───────────────────
DROP FUNCTION IF EXISTS public.notify_connected_operators(text, text, text);
CREATE FUNCTION public.notify_connected_operators(
  p_title text,
  p_body text,
  p_type text DEFAULT 'info',
  p_expires_minutes integer DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_sender integer; v_n integer; v_expires timestamp;
BEGIN
  IF NOT public.current_user_is_supervisor() THEN
    RAISE EXCEPTION 'Solo supervisores pueden enviar notificaciones';
  END IF;
  v_sender := public.current_daily_user_id();
  v_expires := CASE WHEN p_expires_minutes IS NULL THEN NULL
                    ELSE timezone('utc', now()) + make_interval(mins => p_expires_minutes) END;

  INSERT INTO public.daily_station_messages
    ("ID_sender_user", "ID_target_user", message_type, message_title, message_body,
     created_at, is_active, expires_at)
  SELECT v_sender, s."ID_user", COALESCE(p_type,'info'), p_title, p_body,
         timezone('utc', now()), 1, v_expires
  FROM (
    SELECT DISTINCT "ID_user"
    FROM public.daily_sesions
    WHERE sesion_active = 1 AND "ID_user" IS NOT NULL
  ) s
  WHERE s."ID_user" IS DISTINCT FROM v_sender;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notify_connected_operators(text, text, text, integer) TO anon, authenticated;

-- ── fetch_my_notifications (devuelve expires_at) ────────────────────────────
DROP FUNCTION IF EXISTS public.fetch_my_notifications(integer);
CREATE FUNCTION public.fetch_my_notifications(p_limit integer DEFAULT 30)
RETURNS TABLE(
  id integer, sender text, type text, title text, body text,
  created_at timestamp without time zone, read_at timestamp without time zone,
  response boolean, expires_at timestamp without time zone
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH base AS (
    SELECT m."ID_message" AS id,
           COALESCE(MIN(n.user_name), 'Sistema')::text AS sender,
           m.message_type::text AS type,
           m.message_title::text AS title,
           m.message_body AS body,
           m.created_at,
           m.read_at,
           m.response,
           m.expires_at
    FROM public.daily_station_messages m
    LEFT JOIN public.daily_users_names n ON n."ID_user" = m."ID_sender_user"
    WHERE m."ID_target_user" = public.current_daily_user_id()
      AND COALESCE(m.is_active, 1) = 1
    GROUP BY m."ID_message", m.message_type, m.message_title, m.message_body,
             m.created_at, m.read_at, m.response, m.expires_at
  )
  SELECT * FROM (
    (SELECT * FROM base ORDER BY id DESC LIMIT p_limit)
    UNION
    (SELECT * FROM base WHERE type = 'poll' AND response IS NULL)
  ) combined
  ORDER BY id DESC;
$$;
GRANT EXECUTE ON FUNCTION public.fetch_my_notifications(integer) TO anon, authenticated;
