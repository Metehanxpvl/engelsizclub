/** İlan taşıma simülasyonu (service role) */
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
const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

const list = await fetch(`${url}/rest/v1/ilanlar?select=id,kind,title,photos&order=created_at.desc&limit=5`, { headers });
const ilanlar = await list.json();
console.log('Sample ilanlar:', JSON.stringify(ilanlar, null, 2));

if (!ilanlar.length) process.exit(0);
const test = ilanlar[0];
const newKind = test.kind === 'uzman' ? 'bakici' : 'uzman';
const photos = test.photos;
const photoLen = Array.isArray(photos) ? photos.length : 0;

let payload = { kind: newKind };
if (newKind !== 'ikinciel' && photoLen > 2) {
  payload.photos = photos.slice(0, 2);
}
if (newKind === 'ikinciel') {
  payload.category = 'Diğer';
  payload.condition = 'İyi';
  payload.brand = '—';
  payload.emoji = '📦';
}

const res = await fetch(`${url}/rest/v1/ilanlar?id=eq.${test.id}`, {
  method: 'PATCH',
  headers,
  body: JSON.stringify(payload),
});
const body = await res.text();
console.log(`PATCH kind ${test.kind}->${newKind} id=${test.id}:`, res.status, body.slice(0, 300));

// revert
await fetch(`${url}/rest/v1/ilanlar?id=eq.${test.id}`, {
  method: 'PATCH',
  headers,
  body: JSON.stringify({ kind: test.kind, photos: test.photos }),
});
console.log('Reverted');
