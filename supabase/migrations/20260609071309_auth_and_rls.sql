-- Convert ID_user to use an auto-incrementing sequence
CREATE SEQUENCE IF NOT EXISTS daily_users_id_user_seq;
ALTER TABLE public.daily_users ALTER COLUMN "ID_user" SET DEFAULT nextval('daily_users_id_user_seq');
ALTER SEQUENCE daily_users_id_user_seq OWNED BY public.daily_users."ID_user";

-- Add supabase_auth_id to daily_users
ALTER TABLE public.daily_users ADD COLUMN supabase_auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create a function to automatically insert a user into daily_users upon signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.daily_users ("ID_user_rol", "user_password", "active", "supabase_auth_id")
  VALUES (
    1, -- Default role ID
    'supabase-auth', -- Password handled by Supabase
    1, -- Active by default
    new.id
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call handle_new_user on signup
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Enable RLS on core tables
ALTER TABLE public.daily_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_users ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies
CREATE POLICY "Authenticated users can read events" 
ON public.daily_events 
FOR SELECT TO authenticated 
USING (true);

CREATE POLICY "Authenticated users can read activities" 
ON public.daily_activities 
FOR SELECT TO authenticated 
USING (true);

CREATE POLICY "Users can view own profile" 
ON public.daily_users 
FOR SELECT TO authenticated 
USING (supabase_auth_id = auth.uid());
