-- Ascend Arena Phase 5 Schema Updates

-- 1. Modify Tasks (Remove grace_seconds)
ALTER TABLE public.tasks DROP COLUMN IF EXISTS grace_seconds;

-- 2. Modify Users (Add XP, Level, Rank, Avatar)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS xp INT DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS level INT DEFAULT 1;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS current_rank TEXT DEFAULT 'Bronze 5';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 3. Create XP Transactions Table
CREATE TABLE IF NOT EXISTS public.xp_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) NOT NULL,
  amount INT NOT NULL,
  reason TEXT NOT NULL,
  awarded_by UUID REFERENCES public.users(id), -- Null if system awarded
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS for XP Transactions
ALTER TABLE public.xp_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin full access xp_transactions" ON public.xp_transactions FOR ALL USING (is_admin());
CREATE POLICY "Users view own xp_transactions" ON public.xp_transactions FOR SELECT USING (user_id = auth.uid());

-- 4. Recreate submit_task RPC (Remove grace logic, deadlines are optional)
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
  
  -- Calculate status based on v_now (deadlines optional)
  IF v_task.window_end IS NULL THEN
    v_status := 'on_time';
  ELSIF v_now <= v_task.window_end THEN
    v_status := 'on_time';
  ELSE
    v_status := 'late';
  END IF;

  INSERT INTO submissions (task_id, user_id, file_url, text_content, submitted_at, status)
  VALUES (p_task_id, auth.uid(), p_file_url, p_text_content, v_now, v_status)
  RETURNING id INTO v_submission_id;

  RETURN v_submission_id;
END;
$$;

-- 5. Create storage bucket for avatars
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;

-- Policies for avatars bucket
CREATE POLICY "Avatar Images are publicly accessible." ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can upload their own avatars." ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid() = owner);
CREATE POLICY "Users can update their own avatars." ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid() = owner);
CREATE POLICY "Users can delete their own avatars." ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.uid() = owner);
