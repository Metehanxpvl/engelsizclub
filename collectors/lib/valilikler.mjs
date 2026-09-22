import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** ~12 il/gün: 81 il ~7 günde döner; 90 dk + Gemini kotasını şişirmez. */
export const VALILIK_BATCH_SIZE = 12;

/**
 * Valilik sitelerinde engelli eğitim / burs / yardım duyurularının
 * sık görüldüğü listing yolları. Ortak belediye listesinden önce denenir.
 */
export const VALILIK_LISTING_PATHS = [
  '/duyurular',
  '/haberler',
  '/ilanlar',
  '/engelli',
  '/engelli-hizmetleri',
  '/engelli-birimi',
  '/engelsiz',
  '/engelsiz-yasam',
  '/sosyal-yardim',
  '/sosyal-hizmetler',
  '/burs',
  '/egitim',
  '/egitim-yardimi',
];

export function defaultValilikCatalogPath() {
  return join(
    dirname(fileURLToPath(import.meta.url)),
    '..',
    '..',
    'web',
    'valilikler.json',
  );
}

export function parseValilikCatalog(raw) {
  let decoded;
  try {
    decoded = typeof raw === 'string' ? JSON.parse(raw) : raw;
  } catch {
    return [];
  }
  const list = Array.isArray(decoded)
    ? decoded
    : Array.isArray(decoded?.items)
      ? decoded.items
      : [];
  const out = [];
  const seen = new Set();
  for (const row of list) {
    if (!row || typeof row !== 'object') continue;
    const plate = String(row.plate || '').trim().padStart(2, '0');
    const city = String(row.city || '').trim();
    const url = String(row.url || '').trim().replace(/\/+$/, '');
    if (!/^\d{2}$/.test(plate) || !city || !/^https:\/\/[^/]+\.gov\.tr$/i.test(url)) {
      continue;
    }
    if (seen.has(plate)) continue;
    seen.add(plate);
    const origin = url;
    out.push({
      plate,
      city,
      slug: String(row.slug || '').trim(),
      url: origin,
      duyurular_url:
        String(row.duyurular_url || '').trim().replace(/\/+$/, '') ||
        `${origin}/duyurular`,
      engelli_url:
        String(row.engelli_url || '').trim().replace(/\/+$/, '') ||
        `${origin}/engelli`,
    });
  }
  return out;
}

export function utcDayNumber(now = new Date()) {
  return Math.floor(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 86400000);
}

export function valilikBatchIndex(
  now = new Date(),
  count,
  batchSize = VALILIK_BATCH_SIZE,
) {
  const n = Number(count) || 0;
  const size = Number(batchSize) || VALILIK_BATCH_SIZE;
  const batches = Math.max(1, Math.ceil(n / size));
  return utcDayNumber(now) % batches;
}

export function pickValilikBatch(
  items,
  now = new Date(),
  batchSize = VALILIK_BATCH_SIZE,
) {
  const list = Array.isArray(items) ? items : [];
  if (!list.length) return [];
  const size = Number(batchSize) || VALILIK_BATCH_SIZE;
  const idx = valilikBatchIndex(now, list.length, size);
  const start = idx * size;
  return list.slice(start, start + size);
}

function listingUrlsFor(item) {
  const urls = [item.duyurular_url, item.engelli_url]
    .map((u) => String(u || '').trim().replace(/\/+$/, ''))
    .filter((u) => /^https:\/\//i.test(u) && /\.gov\.tr/i.test(u));
  return [...new Set(urls)];
}

export function toValilikScrapeSource(item) {
  return {
    id: `valilik-${item.plate}`,
    name: `${item.city} Valiliği`,
    url: item.url,
    method: 'scrape',
    city: item.city,
    extraListingPaths: VALILIK_LISTING_PATHS,
    extraListingUrls: listingUrlsFor(item),
    last_fetched_at: null,
  };
}

export async function loadValilikScrapeSources({
  catalogPath,
  now = new Date(),
  batchSize = VALILIK_BATCH_SIZE,
} = {}) {
  const path = catalogPath || defaultValilikCatalogPath();
  let raw = '';
  try {
    raw = await readFile(path, 'utf8');
  } catch (e) {
    console.warn(`valilik kataloğu okunamadı: ${path} — ${e.message}`);
    return [];
  }
  const items = parseValilikCatalog(raw);
  if (!items.length) {
    console.warn(`valilik kataloğu boş: ${path}`);
    return [];
  }
  const batch = pickValilikBatch(items, now, batchSize);
  console.log(
    `valilik tarama grubu: ${batch.length}/${items.length} (gün ${utcDayNumber(now)}) — engelli eğitim/burs/yardım`,
  );
  return batch.map(toValilikScrapeSource);
}
