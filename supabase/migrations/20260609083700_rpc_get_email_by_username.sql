CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT AS $$
DECLARE
    v_auth_id UUID;
    v_email TEXT;
BEGIN
    SELECT u.supabase_auth_id INTO v_auth_id 
    FROM public.daily_users_names n
    JOIN public.daily_users u ON n."ID_user" = u."ID_user"
    WHERE LOWER(TRIM(n.user_name)) = LOWER(TRIM(p_username))
    LIMIT 1;
    
    IF v_auth_id IS NULL THEN 
        RETURN NULL; 
    END IF;
    
    SELECT email INTO v_email FROM auth.users WHERE id = v_auth_id;
    
    RETURN v_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
