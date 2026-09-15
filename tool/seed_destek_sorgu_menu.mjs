/** Insert Destek Sorgu URL into daha_fazlasi_menu. Do not print secrets. */
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

const url = (env.SUPABASE_URL || '').replace(/\/$/, '');
const key = env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation',
};

const payload = {
  title: 'Destek Sorgu',
  subtitle: 'SUT taban fiyatı, SGK katkısı ve yenileme takvimi',
  link_type: 'url',
  link: '/destek-sorgu',
  icon: 'calculate',
  sort_order: 22,
  is_active: true,
  is_builtin: false,
};

const res = await fetch(
  `${url}/rest/v1/daha_fazlasi_menu?or=(title.ilike.Destek%20Sorgu,link.ilike.*destek-sorgu*)&select=id,title,link,link_type,is_active,sort_order`,
  { headers },
);
const text = await res.text();
if (!res.ok) {
  console.error('GET failed', res.status, text.slice(0, 300));
  process.exit(1);
}
const rows = JSON.parse(text);

if (rows.length) {
  const id = rows[0].id;
  const patch = await fetch(`${url}/rest/v1/daha_fazlasi_menu?id=eq.${id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ ...payload, updated_at: new Date().toISOString() }),
  });
  const patchText = await patch.text();
  if (!patch.ok) {
    console.error('PATCH failed', patch.status, patchText.slice(0, 300));
    process.exit(1);
  }
  const updated = patchText ? JSON.parse(patchText) : [{ id }];
  console.log('updated', JSON.stringify({ id: updated[0]?.id, title: payload.title, link: payload.link }));
} else {
  const ins = await fetch(`${url}/rest/v1/daha_fazlasi_menu`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });
  const insText = await ins.text();
  if (!ins.ok) {
    console.error('POST failed', ins.status, insText.slice(0, 300));
    process.exit(1);
  }
  const created = JSON.parse(insText);
  console.log('inserted', JSON.stringify({ id: created[0]?.id, title: payload.title, link: payload.link }));
}
