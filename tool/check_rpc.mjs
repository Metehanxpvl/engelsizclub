/** RPC var mı kontrol et */
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

for (const fn of ['admin_change_ilan_kind', 'admin_upsert_app_category']) {
  const res = await fetch(`${url}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(
      fn === 'admin_change_ilan_kind'
        ? { p_id: 0, p_kind: 'uzman' }
        : { p_id: 'x', p_scope: 'x', p_label: 'x' },
    ),
  });
  const text = await res.text();
  console.log(fn, res.status, text.slice(0, 200));
}
