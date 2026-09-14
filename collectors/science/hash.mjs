import { createHash } from 'node:crypto';

export function foldTr(text) {
  return String(text ?? '')
    .toLowerCase()
    .replace(/\u0130/g, 'i')
    .replace(/\u0307/g, '')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    .replace(/[''`´’]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function normalizeDoi(raw) {
  let s = String(raw ?? '').trim();
  if (!s) return '';
  s = s.replace(/^https?:\/\/(dx\.)?doi\.org\//i, '');
  s = s.replace(/^doi:\s*/i, '');
  return s.toLowerCase().trim();
}

export function researchContentHash({
  title,
  pmid,
  nctId,
  doi,
  sourceUrl,
}) {
  const normalized = [
    String(pmid ?? '').trim().toLowerCase(),
    String(nctId ?? '').trim().toLowerCase(),
    normalizeDoi(doi),
    String(sourceUrl ?? '').trim().toLowerCase(),
    String(title ?? '').trim().toLowerCase(),
  ].join('|');
  return createHash('sha256').update(normalized, 'utf8').digest('hex');
}

export function isDuplicate(
  existing,
  { pmid, nctId, doi, sourceUrl, contentHash },
) {
  const p = String(pmid ?? '').trim();
  const n = String(nctId ?? '').trim();
  const d = normalizeDoi(doi);
  const u = String(sourceUrl ?? '').trim();
  const h = String(contentHash ?? '').trim();
  if (p && existing.pmids?.has(p)) return true;
  if (n && existing.ncts?.has(n)) return true;
  if (d && existing.dois?.has(d)) return true;
  if (u && existing.urls?.has(u)) return true;
  if (h && existing.hashes?.has(h)) return true;
  return false;
}

export function remember(existing, item) {
  const p = String(item.pmid ?? '').trim();
  const n = String(item.nctId ?? item.nct_id ?? '').trim();
  const d = normalizeDoi(item.doi);
  const u = String(item.sourceUrl ?? item.source_url ?? '').trim();
  const h = String(item.contentHash ?? item.content_hash ?? '').trim();
  if (p) existing.pmids.add(p);
  if (n) existing.ncts.add(n);
  if (d) existing.dois.add(d);
  if (u) existing.urls.add(u);
  if (h) existing.hashes.add(h);
}
