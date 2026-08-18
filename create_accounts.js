const { createClient } = require('@supabase/supabase-js');
const { Client } = require('pg');

const SUPABASE_URL = 'https://fdzrkzgdbgxlvojuhhyw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkenJremdkYmd4bHZvanVoaHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MTY2ODYsImV4cCI6MjEwMjA5MjY4Nn0.QUeSxKOg9XDoGgLoA0PcNPPVppB5fOjuEcJIHQR5_hk';
const DB_URL = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function setupAccounts() {
  const pgClient = new Client({ connectionString: DB_URL });
  await pgClient.connect();

  const accounts = [
    { email: 'ascend_admin@gmail.com', password: 'password123', name: 'Admin', role: 'admin' },
    { email: 'ascend_sibling1@gmail.com', password: 'password123', name: 'Sibling 1', role: 'user' },
    { email: 'ascend_sibling2@gmail.com', password: 'password123', name: 'Sibling 2', role: 'user' },
  ];

  for (const acc of accounts) {
    console.log(`Creating ${acc.email}...`);
    const { data, error } = await supabase.auth.signUp({
      email: acc.email,
      password: acc.password,
    });
    
    if (error) {
      if (error.message.includes('already registered')) {
        console.log(`User ${acc.email} already exists. Skipping signup.`);
      } else {
        console.error(`Error signing up ${acc.email}:`, error);
        continue;
      }
    }
    
    // We need to bypass email confirmation manually by updating auth.users
    console.log(`Confirming email for ${acc.email}...`);
    await pgClient.query(`
      UPDATE auth.users 
      SET email_confirmed_at = NOW() 
      WHERE email = $1
    `, [acc.email]);
    
    // Also update public.users to set role and display_name
    console.log(`Updating role and name for ${acc.email} in public.users...`);
    await pgClient.query(`
      UPDATE public.users 
      SET role = $1, display_name = $2 
      WHERE id = (SELECT id FROM auth.users WHERE email = $3)
    `, [acc.role, acc.name, acc.email]);
  }

  await pgClient.end();
  console.log('All accounts created and confirmed successfully!');
}

setupAccounts().catch(console.error);
