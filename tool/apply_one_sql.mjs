/**
 * Tek bir supabase/*.sql dosyasını Postgres'e uygular.
 *
 *   $env:SUPABASE_DB_PASSWORD='...'
 *   $env:SUPABASE_DB_HOST='db.qycrkqwqrysypvqaipqn.supabase.co'
 *   node tool/apply_one_sql.mjs ilanlar_admin_change_kind.sql
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from './pg-runner/node_modules/pg/lib/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const fileName = process.argv[2];
if (!fileName) {
  console.error('Kullanım: node tool/apply_one_sql.mjs <dosya.sql>');
  process.exit(1);
}

const password = process.env.SUPABASE_DB_PASSWORD ?? '';
if (!password) {
  console.error('SUPABASE_DB_PASSWORD eksik.');
  process.exit(1);
}

const host =
  process.env.SUPABASE_DB_HOST ?? 'db.qycrkqwqrysypvqaipqn.supabase.co';
const port = Number(process.env.SUPABASE_DB_PORT ?? '5432');
const user = process.env.SUPABASE_DB_USER ?? 'postgres';
const database = process.env.SUPABASE_DB_NAME ?? 'postgres';

const full = path.join(root, 'supabase', fileName);
if (!fs.existsSync(full)) {
  console.error(`Dosya yok: ${full}`);
  process.exit(1);
}

let sql = fs.readFileSync(full, 'utf8');
sql = sql
  .split(/\r?\n/)
  .filter((line) => !line.trim().startsWith('\\'))
  .join('\n');

const client = new pg.Client({
  host,
  port,
  user,
  password,
  database,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 30000,
});

async function main() {
  console.log(`Bağlanıyor: ${user}@${host}:${port}/${database}`);
  await client.connect();
  console.log(`Uygulanıyor: ${fileName}`);
  await client.query(sql);
  await client.end();
  console.log('OK');
}

main().catch(async (e) => {
  console.error(e.message || e);
  try {
    await client.end();
  } catch (_) {}
  process.exit(1);
});
