import { contentHash, foldTr, normalizeUrl, titleFingerprint, titleHash } from './normalize.mjs';

function tokens(title) {
  return titleFingerprint(title)
    .split(' ')
    .filter((w) => w.length > 2);
}

function charGrams(title, n = 3) {
  const t = titleFingerprint(title).replace(/ /g, '');
  const out = new Set();
  if (t.length < n) {
    if (t) out.add(t);
    return out;
  }
  for (let i = 0; i <= t.length - n; i += 1) out.add(t.slice(i, i + n));
  return out;
}

function dice(a, b) {
  if (!a.size || !b.size) return 0;
  let inter = 0;
  for (const g of a) if (b.has(g)) inter += 1;
  return (2 * inter) / (a.size + b.size);
}

export function titleSimilarity(a, b) {
  const ta = tokens(a);
  const tb = tokens(b);
  if (!ta.length || !tb.length) return 0;
  const sa = new Set(ta);
  const sb = new Set(tb);
  let inter = 0;
  for (const t of sa) if (sb.has(t)) inter += 1;
  const union = new Set([...sa, ...sb]).size;
  const jaccard = union ? inter / union : 0;
  return Math.max(jaccard, dice(charGrams(a), charGrams(b)));
}

export function emptyIndex() {
  return {
    urls: new Map(),
    hashes: new Map(),
    titles: new Map(),
    records: [],
  };
}

function mergeSources(a, b) {
  const set = new Set([...(a || []), ...(b || [])].filter(Boolean));
  return [...set];
}

export function addOrMerge(index, item, { fuzzy = 0.85 } = {}) {
  const url = normalizeUrl(item.canonical_url || item.url);
  const hash = item.content_hash || contentHash({
    title: item.title,
    url,
    snippet: item.raw_snippet,
  });
  const fp = titleHash(item.title);
  const hit =
    (url && index.urls.get(url)) ||
    (hash && index.hashes.get(hash)) ||
    (fp && index.titles.get(fp));
  if (hit) {
    hit.sources = mergeSources(hit.sources, item.sources || [item.source]);
    if (!hit.raw_snippet && item.raw_snippet) hit.raw_snippet = item.raw_snippet;
    return { merged: true, record: hit };
  }
  for (const rec of index.records) {
    if (titleSimilarity(item.title, rec.title) > fuzzy) {
      rec.sources = mergeSources(rec.sources, item.sources || [item.source]);
      if (url) index.urls.set(url, rec);
      return { merged: true, record: rec };
    }
  }
  const record = {
    ...item,
    canonical_url: url,
    content_hash: hash,
    title_fingerprint: titleFingerprint(item.title),
    title_hash: fp,
    sources: mergeSources(item.sources, [item.source]),
  };
  if (url) index.urls.set(url, record);
  if (hash) index.hashes.set(hash, record);
  if (fp) index.titles.set(fp, record);
  index.records.push(record);
  return { merged: false, record };
}

export function isSeen(seen, item) {
  const url = normalizeUrl(item.canonical_url || item.url);
  const hash = item.content_hash || item.title_hash || titleHash(item.title);
  if (url && seen.urls?.has(url)) return true;
  if (hash && seen.hashes?.has(hash)) return true;
  const fp = foldTr(item.title);
  if (fp && seen.titles?.has(fp)) return true;
  return false;
}
