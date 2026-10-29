import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = join(DIR, '..', '..', '..');
const CONFIG = join(ROOT, 'config');

function readJson(name) {
  return JSON.parse(readFileSync(join(CONFIG, name), 'utf8'));
}

let cached;

export function loadScanConfig() {
  if (cached) return cached;
  const sources = readJson('sources.json');
  const conditions = readJson('conditions.json');
  const pipeline = readJson('pipeline.json');
  cached = { sources, conditions, pipeline };
  return cached;
}

export function envFlag(name, fallback = false) {
  const raw = String(process.env[name] || '').trim().toLowerCase();
  if (!raw) return fallback;
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export function autoApproveEnabled(pipeline) {
  if (envFlag('CONTENT_SCAN_AUTO_APPROVE', false)) return true;
  return pipeline?.auto_approve === true;
}

export function fillTemplate(template, vars) {
  return String(template || '').replace(/\{([a-z_]+)\}/gi, (_, key) => {
    const v = vars[key];
    return v == null ? '' : encodeURIComponent(String(v));
  });
}

export function conditionKeywords(conditions) {
  const out = [];
  for (const c of conditions || []) {
    for (const w of [...(c.tr || []), ...(c.en || [])]) {
      const s = String(w || '').trim();
      if (s) out.push(s);
    }
  }
  return out;
}

export function newsQueries(sources, conditions) {
  const list = [];
  for (const q of sources.google_news?.queries || []) {
    list.push({ id: `gnews:${q}`, group: 'google_news', q });
  }
  for (const q of sources.official_via_news?.queries || []) {
    list.push({ id: `official:${q}`, group: 'official_via_news', q });
  }
  for (const item of sources.catalog || []) {
    if (item.kind === 'google_query' && item.q) {
      list.push({ id: item.id, group: item.group || 'catalog', q: item.q });
    }
  }
  for (const c of conditions || []) {
    const q = String(c.tr?.[0] || c.ad || '').trim();
    if (q) list.push({ id: `cond:${c.id}`, group: 'condition', q });
  }
  const seen = new Set();
  return list.filter((row) => {
    const key = String(row.q || '').toLowerCase();
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function scienceQueries(sources, conditions) {
  const list = [];
  for (const c of conditions || []) {
    const en = String(c.en?.[0] || '').trim();
    const tr = String(c.tr?.[0] || '').trim();
    if (en) list.push({ id: c.id, q: en, lang: 'en' });
    else if (tr) list.push({ id: c.id, q: tr, lang: 'tr' });
  }
  if (!list.length) {
    list.push({ id: 'disability', q: 'disability rehabilitation', lang: 'en' });
  }
  return list;
}

export function isTrustedHost(host, sources, kind) {
  const h = String(host || '').toLowerCase().replace(/^www\./, '');
  const list = sources.trust?.[kind] || [];
  return list.some((d) => h === d || h.endsWith(`.${d}`));
}
