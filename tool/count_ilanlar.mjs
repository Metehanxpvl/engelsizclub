/** İlan sayıları — kind / status dağılımı */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = {};
for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/)) {
  const t = line.trim();
  if (!t || t.startsWith('#')) continue;
  const i = t.indexOf('=');
  if (i >= 0) env[t.slice(0, i).trim()] = t.slice(i + 1).trim();
}

const url = env.SUPABASE_URL.replace(/\/$/, '');
const key = env.SUPABASE_SERVICE_ROLE_KEY;
const headers = { apikey: key, Authorization: `Bearer ${key}` };

const res = await fetch(
  `${url}/rest/v1/ilanlar?select=id,kind,title,created_at&order=created_at.desc`,
  { headers },
);
const rows = await res.json();
if (!Array.isArray(rows)) {
  console.error('Error:', rows);
  process.exit(1);
}

const byKind = {};
for (const r of rows) {
  const k = r.kind ?? '?';
  byKind[k] = (byKind[k] ?? 0) + 1;
}

console.log('Toplam ilan:', rows.length);
console.log('Kind dağılımı:', byKind);
console.log('\nUzman/Bakıcı (son 20 — taşınmış olabilir):');
for (const r of rows.filter((x) => x.kind !== 'ikinciel').slice(0, 20)) {
  console.log(`  #${r.id} [${r.kind}] ${r.title}`);
}
