-- Ascend Arena Database Schema & RLS Policies

-- Enable uuid-ossp extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users (Extends auth.users)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  role TEXT NOT NULL CHECK (role IN ('admin', 'user')),
  display_name TEXT NOT NULL
);

-- 2. Scoring Presets
CREATE TABLE public.scoring_presets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  criteria JSONB NOT NULL, -- e.g., {"content": 40, "delivery": 30, "handwriting": 10, "timing": 20}
  scale INT NOT NULL DEFAULT 100
);

-- 3. Tasks
CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL CHECK (type IN ('speech', 'writing', 'reading')),
  title TEXT NOT NULL,
  instructions TEXT,
  attachment_urls TEXT[],
  assigned_user_id UUID REFERENCES public.users(id) NOT NULL,
  window_start TIMESTAMPTZ,
  window_end TIMESTAMPTZ,
  grace_seconds INT NOT NULL DEFAULT 30,
  preset_id UUID REFERENCES public.scoring_presets(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Submissions
CREATE TABLE public.submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID REFERENCES public.tasks(id) NOT NULL,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  file_url TEXT,
  text_content TEXT,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  status TEXT NOT NULL CHECK (status IN ('on_time', 'grace', 'late', 'missed'))
);

-- 5. Scores
CREATE TABLE public.scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  submission_id UUID REFERENCES public.submissions(id) UNIQUE NOT NULL,
  criteria_scores JSONB NOT NULL,
  total_score NUMERIC NOT NULL,
  scored_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Seasons
CREATE TABLE public.seasons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  label TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL
);

-- 7. Trophies
CREATE TABLE public.trophies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) NOT NULL,
  period_type TEXT NOT NULL CHECK (period_type IN ('season', 'month', 'year')),
  period_label TEXT NOT NULL,
  awarded_score NUMERIC NOT NULL,
  awarded_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Visibility Settings
CREATE TABLE public.visibility_settings (
  user_id UUID REFERENCES public.users(id) PRIMARY KEY,
  hide_alltime BOOLEAN DEFAULT false,
  hide_monthly BOOLEAN DEFAULT false,
  hide_yearly BOOLEAN DEFAULT false,
  hide_seasonal BOOLEAN DEFAULT false
);

-- RPC for Submitting Tasks Server-Side (Server authoritative timing)
CREATE OR REPLACE FUNCTION submit_task(p_task_id UUID, p_file_url TEXT, p_text_content TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_status TEXT;
  v_now TIMESTAMPTZ := now();
  v_submission_id UUID;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  -- Calculate status based on v_now
  IF v_task.window_end IS NULL THEN
    v_status := 'on_time';
  ELSIF v_now <= v_task.window_end THEN
    v_status := 'on_time';
  ELSIF v_now <= (v_task.window_end + (v_task.grace_seconds || ' seconds')::INTERVAL) THEN
    v_status := 'grace';
  ELSE
    v_status := 'late'; -- Admin can manually mark 'missed' later if needed
  END IF;

  INSERT INTO submissions (task_id, user_id, file_url, text_content, submitted_at, status)
  VALUES (p_task_id, auth.uid(), p_file_url, p_text_content, v_now, v_status)
  RETURNING id INTO v_submission_id;

  RETURN v_submission_id;
END;
$$;


-- Row Level Security (RLS) Setup

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scoring_presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trophies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visibility_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Admin Policies: Admin has full access to everything
CREATE POLICY "Admin full access users" ON public.users FOR ALL USING (is_admin());
CREATE POLICY "Admin full access presets" ON public.scoring_presets FOR ALL USING (is_admin());
CREATE POLICY "Admin full access tasks" ON public.tasks FOR ALL USING (is_admin());
CREATE POLICY "Admin full access submissions" ON public.submissions FOR ALL USING (is_admin());
CREATE POLICY "Admin full access scores" ON public.scores FOR ALL USING (is_admin());
CREATE POLICY "Admin full access seasons" ON public.seasons FOR ALL USING (is_admin());
CREATE POLICY "Admin full access trophies" ON public.trophies FOR ALL USING (is_admin());
CREATE POLICY "Admin full access visibility" ON public.visibility_settings FOR ALL USING (is_admin());


-- User Policies:

-- Users: Can read their own profile and siblings' profiles (if we want them to see names)
CREATE POLICY "Users can view all users" ON public.users FOR SELECT USING (auth.role() = 'authenticated');

-- Tasks: Can view tasks assigned to them
CREATE POLICY "Users can view own tasks" ON public.tasks FOR SELECT USING (assigned_user_id = auth.uid());

-- Submissions: Can view own submissions (insert is handled by RPC, but we allow update/select for their own)
CREATE POLICY "Users can view own submissions" ON public.submissions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update own submissions" ON public.submissions FOR UPDATE USING (user_id = auth.uid());

-- Scores: Can view their own scores. (Sibling visibility handled via view/RPC later)
CREATE POLICY "Users can view own scores" ON public.scores FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.submissions s 
    WHERE s.id = submission_id AND s.user_id = auth.uid()
  )
);

-- Trophies: Can view own trophies
CREATE POLICY "Users can view own trophies" ON public.trophies FOR SELECT USING (user_id = auth.uid());

-- Visibility: Can view own visibility settings
CREATE POLICY "Users can view own visibility" ON public.visibility_settings FOR SELECT USING (user_id = auth.uid());
