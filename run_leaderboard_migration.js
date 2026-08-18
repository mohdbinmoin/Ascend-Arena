const fs = require('fs');
const { Client } = require('pg');

const DB_URL = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

async function runMigration() {
  const pgClient = new Client({ connectionString: DB_URL });
  await pgClient.connect();

  const query = fs.readFileSync('update_leaderboard_rpc.sql', 'utf8');

  console.log("Running Leaderboard RPC Migration...");
  try {
    await pgClient.query(query);
    console.log("Migration executed successfully!");
  } catch (err) {
    console.error("SQL Error:", err);
  } finally {
    await pgClient.end();
  }
}

runMigration();
