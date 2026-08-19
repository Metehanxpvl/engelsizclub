/**
 * Service role ile katalog upsert testi (RLS bypass).
 *   node tool/test_catalog_upsert.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

function loadEnv() {
  const envPath = path.join(root, '.env');
  if (!fs.existsSync(envPath)) return {};
  const out = {};
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    out[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return out;
}

const env = { ...loadEnv(), ...process.env };
const url = (env.SUPABASE_URL ?? '').replace(/\/$/, '');
const key = env.SUPABASE_SERVICE_ROLE_KEY ?? '';
if (!url || !key) {
  console.error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli (.env)');
  process.exit(1);
}

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

async function rest(method, table, { query = '', body } = {}) {
  const res = await fetch(`${url}/rest/v1/${table}${query}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { ok: res.ok, status: res.status, data };
}

const testId = `test-${Date.now()}`;
const upsert = await rest('POST', 'app_categories', {
  query: '?on_conflict=id',
  body: {
    id: testId,
    scope: 'uzmanlik',
    label: 'Test Katalog',
    icon: '🧪',
    sort_order: 9999,
    active: true,
    meta: {},
    updated_at: new Date().toISOString(),
  },
});

if (!upsert.ok) {
  console.error('app_categories upsert FAILED:', upsert.status, upsert.data);
  process.exit(1);
}
console.log('app_categories upsert OK');

const verRead = await rest('GET', 'app_catalog_versions', {
  query: '?select=version&name=eq.categories',
});
const cur = Array.isArray(verRead.data) ? verRead.data[0]?.version ?? 0 : 0;
const nextVer = Number(cur) + 1;

const verWrite = await rest('POST', 'app_catalog_versions', {
  query: '?on_conflict=name',
  body: {
    name: 'categories',
    version: nextVer,
    updated_at: new Date().toISOString(),
  },
});

if (!verWrite.ok) {
  console.error('app_catalog_versions upsert FAILED:', verWrite.status, verWrite.data);
  process.exit(1);
}
console.log('app_catalog_versions bump OK ->', nextVer);

await rest('DELETE', 'app_categories', { query: `?id=eq.${testId}` });
console.log('Test satırı silindi. Service role ile katalog yazımı çalışıyor.');
