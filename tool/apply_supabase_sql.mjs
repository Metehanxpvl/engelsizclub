/**
 * Apply supabase/*.sql files to a Postgres database in order.
 * Usage:
 *   $env:SUPABASE_DB_PASSWORD='...'
 *   node tool/apply_supabase_sql.mjs
 *
 * Optional:
 *   SUPABASE_DB_HOST=db.ifwcrmehzipguncrnsxp.supabase.co
 *   SUPABASE_DB_PORT=5432
 *   SUPABASE_DB_USER=postgres
 *   SUPABASE_DB_NAME=postgres
 *   SUPABASE_DB_SSL=require
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from './pg-runner/node_modules/pg/lib/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const supabaseDir = path.join(root, 'supabase');
const orderFile = path.join(supabaseDir, '_migrate_order.txt');

const password = process.env.SUPABASE_DB_PASSWORD ?? '';
if (!password) {
  console.error('SUPABASE_DB_PASSWORD eksik.');
  process.exit(1);
}

const host =
  process.env.SUPABASE_DB_HOST ?? 'db.ifwcrmehzipguncrnsxp.supabase.co';
const port = Number(process.env.SUPABASE_DB_PORT ?? '5432');
const user = process.env.SUPABASE_DB_USER ?? 'postgres';
const database = process.env.SUPABASE_DB_NAME ?? 'postgres';

const files = fs
  .readFileSync(orderFile, 'utf8')
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'));

const client = new pg.Client({
  host,
  port,
  user,
  password,
  database,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 30000,
});

async function runFile(fileName) {
  const full = path.join(supabaseDir, fileName);
  if (!fs.existsSync(full)) {
    throw new Error(`Dosya yok: ${fileName}`);
  }
  let sql = fs.readFileSync(full, 'utf8');
  // Strip psql meta-commands if any
  sql = sql
    .split(/\r?\n/)
    .filter((line) => !line.trim().startsWith('\\'))
    .join('\n');
  if (!sql.trim()) {
    console.log(`  (boş, atlandı)`);
    return;
  }
  await client.query(sql);
}

async function main() {
  console.log(`Bağlanıyor: ${user}@${host}:${port}/${database}`);
  await client.connect();
  console.log(`Bağlandı. ${files.length} dosya uygulanacak.\n`);

  const failed = [];
  for (const file of files) {
    process.stdout.write(`→ ${file} ... `);
    try {
      await runFile(file);
      console.log('OK');
    } catch (err) {
      console.log('FAIL');
      console.error(`  ${err.message}`);
      failed.push({ file, message: err.message });
      // Continue: many scripts are additive; stop only on hard failures if preferred.
      // For empty project we abort to avoid cascading nonsense.
      break;
    }
  }

  await client.end();

  if (failed.length) {
    console.error('\nDurdu. İlk hata:');
    for (const f of failed) {
      console.error(`- ${f.file}: ${f.message}`);
    }
    process.exit(1);
  }
  console.log('\nTüm şema dosyaları başarıyla uygulandı.');
}

main().catch(async (e) => {
  console.error(e);
  try {
    await client.end();
  } catch (_) {}
  process.exit(1);
});
