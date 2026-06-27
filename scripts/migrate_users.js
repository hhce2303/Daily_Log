/**
 * migrate_users.js
 *
 * Crea usuarios en Supabase Auth desde users_data.json y los vincula a daily_users.
 *
 * Requiere variables de entorno:
 *   SUPABASE_URL        — ej: https://gbtmbuzlnxdjcexppomf.supabase.co
 *   SUPABASE_SERVICE_KEY — service_role key (NO la anon key)
 *
 * Uso:
 *   SUPABASE_URL=... SUPABASE_SERVICE_KEY=... node scripts/migrate_users.js
 *
 * El script es idempotente: si el usuario ya existe en Auth (email duplicado),
 * lo omite y solo actualiza daily_users si es necesario.
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('ERROR: Faltan variables de entorno SUPABASE_URL y/o SUPABASE_SERVICE_KEY');
  process.exit(1);
}

const DEFAULT_PASSWORD = 'Daily2024!';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const data = JSON.parse(readFileSync(join(__dirname, '../users_data.json'), 'utf8'));

const ROLE_ID_MAP = {
  1: 1, // Admin
  2: 2, // Operador
  3: 3, // Supervisor
  4: 4, // Lead Supervisor
  5: 5, // IT
};

async function main() {
  const users = data.users;
  console.log(`Procesando ${users.length} usuarios...`);

  let created = 0, updated = 0, skipped = 0, errors = 0;

  for (const user of users) {
    try {
      // 1. Intentar crear en Supabase Auth
      const { data: authData, error: authError } =
        await supabase.auth.admin.createUser({
          email: user.email,
          password: DEFAULT_PASSWORD,
          email_confirm: true,
          user_metadata: {
            username: user.username,
            display_name: user.name,
          },
        });

      let authUid;

      if (authError) {
        if (authError.message?.includes('already been registered') || authError.code === 'email_exists') {
          // Usuario ya existe en Auth — obtener su UUID
          const { data: listData } = await supabase.auth.admin.listUsers({ perPage: 1000 });
          const existing = listData?.users?.find((u) => u.email === user.email);
          if (!existing) {
            console.warn(`  [SKIP] ${user.email}: ya existe en Auth pero no pude obtener UUID`);
            skipped++;
            continue;
          }
          authUid = existing.id;
          // Reset password so all users can log in with the default password
          await supabase.auth.admin.updateUserById(authUid, { password: DEFAULT_PASSWORD });
          console.log(`  [EXISTS] ${user.email} -> ${authUid} (password reset)`);
        } else {
          console.error(`  [ERROR] ${user.email}: ${authError.message}`);
          errors++;
          continue;
        }
      } else {
        authUid = authData.user.id;
        created++;
        console.log(`  [NEW] ${user.email} -> ${authUid}`);
      }

      // 2. Actualizar/insertar daily_users con supabase_auth_id y rol correcto
      // El trigger handle_new_user ya habrá creado la fila si el usuario es nuevo.
      // Usamos upsert para sincronizar.
      const { error: dbError } = await supabase
        .from('daily_users')
        .upsert(
          {
            ID_user: user.id,
            ID_user_rol: ROLE_ID_MAP[user.role_id] ?? 2,
            user_password: 'supabase-auth',
            active: user.active,
            supabase_auth_id: authUid,
          },
          {
            onConflict: 'ID_user',
            ignoreDuplicates: false,
          }
        );

      if (dbError) {
        // Si falla por supabase_auth_id duplicado, actualizar por columna
        const { error: updateErr } = await supabase
          .from('daily_users')
          .update({
            ID_user_rol: ROLE_ID_MAP[user.role_id] ?? 2,
            active: user.active,
            supabase_auth_id: authUid,
          })
          .eq('ID_user', user.id);

        if (updateErr) {
          console.error(`  [DB ERROR] daily_users ID=${user.id}: ${updateErr.message}`);
          errors++;
          continue;
        }
      }

      // 3. Sincronizar daily_users_names
      const { error: nameError } = await supabase
        .from('daily_users_names')
        .upsert(
          { ID_user: user.id, user_name: user.name },
          { onConflict: 'ID_user', ignoreDuplicates: false }
        );

      if (nameError) {
        console.warn(`  [WARN] daily_users_names ID=${user.id}: ${nameError.message}`);
      }

      updated++;
    } catch (err) {
      console.error(`  [EXCEPTION] ${user.email}:`, err.message);
      errors++;
    }
  }

  console.log('\n=== RESUMEN ===');
  console.log(`Nuevos en Auth:    ${created}`);
  console.log(`Ya existían:       ${skipped}`);
  console.log(`DB actualizados:   ${updated}`);
  console.log(`Errores:           ${errors}`);
  console.log('\nContrasena por defecto: Daily2024!');
  console.log('Los usuarios deben cambiarla en su primer login.');
}

main().catch((err) => {
  console.error('Error fatal:', err);
  process.exit(1);
});
