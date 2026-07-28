#!/usr/bin/env node
/**
 * content/*.json → Supabase upsert (service role).
 * Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Kullanım:
 *   node tools/sync_catalog.mjs
 * GitHub Actions: content/** değişince otomatik çalışır.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const contentDir = path.join(root, 'content');

const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!url || !key) {
  console.error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.');
  process.exit(1);
}

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
  Prefer: 'resolution=merge-duplicates,return=minimal',
};

async function upsert(table, rows, onConflict = 'id') {
  if (!rows?.length) return;
  const res = await fetch(
    `${url}/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify(rows),
    },
  );
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`${table} upsert failed: ${res.status} ${t}`);
  }
  console.log(`✓ ${table}: ${rows.length} satır`);
}

async function upsertSettings(obj) {
  const rows = Object.entries(obj)
    .filter(([k]) => k !== 'store_note')
    .map(([k, v]) => ({
      key: k,
      value: typeof v === 'object' && v !== null && !Array.isArray(v) ? v : v,
      description: k === 'show_demo_ilanlar'
        ? 'false = yalnızca kullanıcı ilanları (store)'
        : '',
      updated_at: new Date().toISOString(),
    }));
  // settings PK = key
  const res = await fetch(
    `${url}/rest/v1/app_settings?on_conflict=key`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify(rows),
    },
  );
  if (!res.ok) {
    throw new Error(`app_settings: ${res.status} ${await res.text()}`);
  }
  console.log(`✓ app_settings: ${rows.length} anahtar`);
}

function readJson(name) {
  const p = path.join(contentDir, name);
  if (!fs.existsSync(p)) return null;
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

async function main() {
  const settings = readJson('settings.json');
  if (settings) await upsertSettings(settings);

  const forumCats = readJson('categories_forum.json');
  if (forumCats) {
    await upsert(
      'app_categories',
      forumCats.map((r) => ({
        ...r,
        active: r.active !== false,
        icon: r.icon ?? '',
        meta: r.meta ?? {},
        updated_at: new Date().toISOString(),
      })),
    );
  }

  const diseases = readJson('diseases.json');
  if (diseases) {
    await upsert(
      'app_diseases',
      diseases.map((d, i) => ({
        id: d.id,
        name: d.name,
        icon: d.icon ?? '',
        color: d.color ?? 4281568586,
        bg: d.bg ?? 4293980400,
        photo: d.photo ?? '',
        description: d.description ?? d.desc ?? '',
        symptoms: d.symptoms ?? [],
        diagnosis: d.diagnosis ?? '',
        support: d.support ?? [],
        faq: d.faq ?? [],
        sort_order: d.sort_order ?? i,
        active: d.active !== false,
        updated_at: new Date().toISOString(),
      })),
    );
  }

  const cards = readJson('cards.json');
  if (cards) {
    await upsert(
      'app_content',
      cards.map((c, i) => ({
        id: c.id,
        scope: 'cards',
        title: c.title ?? c.label ?? '',
        body: c.body ?? c.desc ?? '',
        media_url: c.media_url ?? c.photo ?? '',
        sort_order: c.sort_order ?? i,
        active: c.active !== false,
        meta: c.meta ?? {},
        updated_at: new Date().toISOString(),
      })),
    );
  }

  const rights = readJson('rights.json');
  if (rights) {
    await upsert(
      'app_rights',
      rights.map((r, i) => ({
        ...r,
        sort_order: r.sort_order ?? i,
        active: r.active !== false,
        updated_at: new Date().toISOString(),
      })),
    );
  }

  console.log('Sync tamam.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
