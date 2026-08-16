const { Client } = require('pg');

const connectionString = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

const client = new Client({
  connectionString,
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase Postgres');
    
    // Create the submissions bucket
    await client.query(`
      INSERT INTO storage.buckets (id, name, public) 
      VALUES ('submissions', 'submissions', true)
      ON CONFLICT (id) DO NOTHING;
    `);
    
    // Set RLS for the bucket (allow public reads, allow authenticated inserts)
    await client.query(`
      CREATE POLICY "Allow public reads on submissions" ON storage.objects FOR SELECT USING (bucket_id = 'submissions');
      CREATE POLICY "Allow authenticated inserts on submissions" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'submissions');
    `);
    
    console.log('Storage bucket setup successfully.');

  } catch (err) {
    console.error('Error applying storage bucket:', err);
  } finally {
    await client.end();
  }
}

run();
