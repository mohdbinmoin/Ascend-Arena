const { Client } = require('pg');

const connectionString = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

const client = new Client({
  connectionString,
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase Postgres');
    
    // Create the trigger function
    await client.query(`
      CREATE OR REPLACE FUNCTION public.handle_new_user() 
      RETURNS trigger AS $$
      BEGIN
        INSERT INTO public.users (id, role, display_name)
        VALUES (
          new.id, 
          COALESCE((new.raw_user_meta_data->>'role'), 'user'), -- default to user
          COALESCE((new.raw_user_meta_data->>'display_name'), split_part(new.email, '@', 1))
        );
        
        -- Also initialize visibility settings
        INSERT INTO public.visibility_settings (user_id)
        VALUES (new.id);
        
        RETURN new;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
    `);
    
    // Drop trigger if it exists then create it
    await client.query(`
      DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
      CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
    `);
    
    // Create a default scoring preset so the app doesn't crash when creating tasks
    await client.query(`
      INSERT INTO public.scoring_presets (name, criteria, scale)
      VALUES ('Standard Speech', '{"Content": 40, "Delivery": 30, "Fluency": 30}', 100)
      ON CONFLICT DO NOTHING;
    `);

    console.log('Auth Trigger and Default Preset applied successfully.');

  } catch (err) {
    console.error('Error applying trigger:', err);
  } finally {
    await client.end();
  }
}

run();
