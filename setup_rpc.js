const { Client } = require('pg');

const connectionString = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

const client = new Client({
  connectionString,
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase Postgres');
    
    // Create the get_leaderboard RPC
    await client.query(`
      CREATE OR REPLACE FUNCTION get_leaderboard()
      RETURNS TABLE (
        user_id UUID,
        display_name TEXT,
        total_score NUMERIC
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      AS $$
      BEGIN
        RETURN QUERY
        SELECT 
          u.id, 
          u.display_name,
          COALESCE(SUM(s.total_score), 0)::NUMERIC as total_score
        FROM public.users u
        LEFT JOIN public.submissions sub ON u.id = sub.user_id
        LEFT JOIN public.scores s ON sub.id = s.submission_id
        LEFT JOIN public.visibility_settings vs ON u.id = vs.user_id
        WHERE (vs.hide_alltime IS NULL OR vs.hide_alltime = false)
          AND u.role = 'user'
        GROUP BY u.id, u.display_name
        ORDER BY total_score DESC;
      END;
      $$;
    `);
    
    console.log('Leaderboard RPC applied successfully.');

  } catch (err) {
    console.error('Error applying RPC:', err);
  } finally {
    await client.end();
  }
}

run();
