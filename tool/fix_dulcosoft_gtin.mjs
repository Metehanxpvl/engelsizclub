/** One-off: 8683060650037 was cached as Roxem. Do not print secrets. */
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

async function get(pathAndQuery) {
  const res = await fetch(`${url}/rest/v1/${pathAndQuery}`, { headers });
  const text = await res.text();
  if (!res.ok) throw new Error(`GET ${res.status} ${text.slice(0, 400)}`);
  return JSON.parse(text);
}

async function patch(table, query, body) {
  const res = await fetch(`${url}/rest/v1/${table}?${query}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`PATCH ${res.status} ${text.slice(0, 400)}`);
  return text ? JSON.parse(text) : [];
}

const barcodeQ =
  'or=(barcode.eq.8683060650037,barcode.eq.08683060650037,barcode.eq.868306065003)';
const byCode = await get(
  `medicines?${barcodeQ}&select=id,barcode,medicine_name,active_ingredient,source,usage_text,indications`,
);
const byName = await get(
  'medicines?medicine_name=ilike.*roxem*&select=id,barcode,medicine_name,source',
);
const products = await get(
  `products?or=(barcode.eq.8683060650037,barcode.eq.08683060650037)&select=id,barcode,product_name`,
);

console.log('medicines_by_barcode', JSON.stringify(byCode, null, 2));
console.log('medicines_named_roxem', JSON.stringify(byName, null, 2));
console.log('products_by_barcode', JSON.stringify(products, null, 2));

const fix = {
  medicine_name: 'DULCOSOFT Oral Solüsyon 5 g/10 ml 250 ml',
  active_ingredient: 'Makrogol 4000',
  indications:
    'Kabızlığın semptomatik tedavisinde ve sert dışkının yumuşatılmasında kullanılır.',
  usage_text:
    'Yetişkinler ve 8 yaş üzeri: günde 20–40 ml, tercihen sabah tek doz. 8 yaş altı: doktor önerisiyle. Kullanma talimatına bakınız.',
  side_effects: [],
  drug_interactions: [],
  safety_warnings:
    'Tıbbi cihaz / laksatif. Antibiyotik değildir. Doz ve uyarılar için kutu / kullanma talimatı esas alınır.',
  source: 'manual',
};

const ids = new Set();
for (const row of byCode) ids.add(row.id);
for (const row of byName) {
  const code = (row.barcode || '').replace(/\D/g, '');
  if (code.includes('868306065003') || !code) ids.add(row.id);
}

if (ids.size === 0 && byCode.length === 0) {
  const inserted = await fetch(`${url}/rest/v1/medicines`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      barcode: '8683060650037',
      ...fix,
    }),
  });
  const text = await inserted.text();
  if (!inserted.ok) throw new Error(`INSERT ${inserted.status} ${text.slice(0, 400)}`);
  console.log('inserted', text.slice(0, 500));
} else {
  for (const id of ids) {
    const updated = await patch('medicines', `id=eq.${id}`, {
      barcode: '8683060650037',
      ...fix,
    });
    console.log(
      'updated',
      JSON.stringify(
        updated.map((r) => ({
          id: r.id,
          barcode: r.barcode,
          medicine_name: r.medicine_name,
          source: r.source,
        })),
      ),
    );
  }
}

const after = await get(
  `medicines?barcode=eq.8683060650037&select=id,barcode,medicine_name,active_ingredient,source`,
);
console.log('after', JSON.stringify(after, null, 2));
