/** 2. el ilan detay — filtre analizi */
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
  `${url}/rest/v1/ilanlar?select=id,title,category,condition,city,district,country_code&kind=eq.ikinciel&order=id.desc`,
  { headers },
);
const rows = await res.json();
console.log('DB ikinciel sayısı:', rows.length);
console.log('\nid | condition | category | city');
for (const r of rows) {
  console.log(`${r.id} | ${r.condition} | ${r.category} | ${r.city}/${r.district ?? ''}`);
}

const byCond = {};
const byCat = {};
for (const r of rows) {
  byCond[r.condition ?? '(boş)'] = (byCond[r.condition ?? '(boş)'] ?? 0) + 1;
  byCat[r.category ?? '(boş)'] = (byCat[r.category ?? '(boş)'] ?? 0) + 1;
}
console.log('\nDurum dağılımı:', byCond);
console.log('Kategori dağılımı:', byCat);
