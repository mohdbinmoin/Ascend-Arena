const { Client } = require('pg');
const fs = require('fs');

const connectionString = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

const client = new Client({
  connectionString,
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase Postgres');
    
    const sql = fs.readFileSync('schema.sql', 'utf8');
    
    // Split on double newlines to run statements (or just run it all if Postgres supports multiple statements in one query)
    // Actually `client.query(sql)` supports multiple statements.
    await client.query(sql);
    console.log('Schema applied successfully.');

  } catch (err) {
    console.error('Error applying schema:', err);
  } finally {
    await client.end();
  }
}

run();
