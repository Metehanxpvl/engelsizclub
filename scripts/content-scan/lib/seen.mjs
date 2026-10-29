import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { foldTr, normalizeUrl } from './normalize.mjs';

const DIR = dirname(fileURLToPath(import.meta.url));
export const SEEN_PATH = join(DIR, '..', '.cache', 'seen.json');

export function emptySeen() {
  return { urls: new Set(), hashes: new Set(), titles: new Set(), rows: [] };
}

export function loadSeenFile(keep = 300) {
  const seen = emptySeen();
  try {
    const raw = JSON.parse(readFileSync(SEEN_PATH, 'utf8'));
    const rows = Array.isArray(raw?.rows) ? raw.rows.slice(-keep) : [];
    for (const row of rows) rememberSeen(seen, row);
    seen.rows = rows;
  } catch {
    /* first run */
  }
  return seen;
}

export function rememberSeen(seen, row) {
  const url = normalizeUrl(row.url || row.canonical_url);
  const hash = String(row.hash || row.content_hash || '').trim();
  const title = foldTr(row.title);
  if (url) seen.urls.add(url);
  if (hash) seen.hashes.add(hash);
  if (title) seen.titles.add(title);
  seen.rows.push({
    url,
    hash,
    title: String(row.title || '').slice(0, 180),
    at: row.at || new Date().toISOString(),
  });
}

export function writeSeenFile(seen, keep = 300) {
  const rows = (seen.rows || []).slice(-keep);
  mkdirSync(dirname(SEEN_PATH), { recursive: true });
  writeFileSync(
    SEEN_PATH,
    `${JSON.stringify({ updated_at: new Date().toISOString(), rows }, null, 2)}\n`,
  );
  return rows.length;
}
