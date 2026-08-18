-- Recreate get_leaderboard RPC for Phase 5 (Gamification)
DROP FUNCTION IF EXISTS get_leaderboard();
CREATE OR REPLACE FUNCTION get_leaderboard()
RETURNS TABLE (
  id UUID,
  display_name TEXT,
  avatar_url TEXT,
  xp INT,
  level INT,
  current_rank TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    id,
    display_name,
    avatar_url,
    xp,
    level,
    current_rank
  FROM public.users
  WHERE role = 'user'
  ORDER BY xp DESC;
$$;
