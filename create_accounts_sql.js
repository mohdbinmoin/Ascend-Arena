const { Client } = require('pg');

const DB_URL = 'postgresql://postgres:h1FrkITW3Y9sBCo5@db.fdzrkzgdbgxlvojuhhyw.supabase.co:5432/postgres';

async function createAccountsSQL() {
  const pgClient = new Client({ connectionString: DB_URL });
  await pgClient.connect();

  const query = `
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    
    DO $$
    DECLARE
      admin_id uuid := gen_random_uuid();
      sib2_id uuid := gen_random_uuid();
    BEGIN
      -- Insert Admin
      INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
      VALUES (admin_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ascend_admin@gmail.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"name":"Admin"}', NOW(), NOW(), '', '', '', '');
      
      INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
      VALUES (gen_random_uuid(), admin_id, format('{"sub":"%s","email":"ascend_admin@gmail.com"}', admin_id)::jsonb, 'email', admin_id::text, NOW(), NOW(), NOW());
      
      -- Sibling 1 was already created successfully in the previous run, we just need to fix its role/name if the trigger didn't
      UPDATE public.users SET role = 'user', display_name = 'Sibling 1' WHERE id = (SELECT id FROM auth.users WHERE email = 'sibling1@ascend.com');

      -- Insert Sibling 2
      INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
      VALUES (sib2_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ascend_sibling2@gmail.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"name":"Sibling 2"}', NOW(), NOW(), '', '', '', '');
      
      INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
      VALUES (gen_random_uuid(), sib2_id, format('{"sub":"%s","email":"ascend_sibling2@gmail.com"}', sib2_id)::jsonb, 'email', sib2_id::text, NOW(), NOW(), NOW());
      
      -- Wait a second for trigger to fire (in pg, triggers fire synchronously within the transaction, so public.users rows exist now)
      UPDATE public.users SET role = 'admin', display_name = 'Admin' WHERE id = admin_id;
      UPDATE public.users SET role = 'user', display_name = 'Sibling 2' WHERE id = sib2_id;
    END $$;
  `;

  console.log("Running SQL account creation...");
  try {
    await pgClient.query(query);
    console.log("Accounts created successfully via SQL bypass!");
  } catch (err) {
    console.error("SQL Error:", err);
  } finally {
    await pgClient.end();
  }
}

createAccountsSQL();
