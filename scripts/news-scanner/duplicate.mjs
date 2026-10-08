import { createHash } from 'node:crypto';
import { foldTr } from './filter.mjs';

const DROP_QUERY = /^(utm_|fbclid|gclid|ocid|ns_|ref)/i;

export function normalizeUrl(raw) {
  const s = String(raw || '').trim();
  if (!s) return '';
  try {
    const u = new URL(s);
    u.hash = '';
    u.hostname = u.hostname.replace(/^www\./i, '').toLowerCase();
    u.protocol = u.protocol.toLowerCase();
    const kept = [];
    for (const [k, v] of u.searchParams.entries()) {
      if (DROP_QUERY.test(k)) continue;
      kept.push([k, v]);
    }
    kept.sort((a, b) => a[0].localeCompare(b[0]));
    u.search = '';
    for (const [k, v] of kept) u.searchParams.append(k, v);
    let path = u.pathname.replace(/\/+$/, '');
    if (!path) path = '/';
    u.pathname = path;
    return u.toString();
  } catch {
    return s.replace(/\/+$/, '').toLowerCase();
  }
}

export function titleFingerprint(title) {
  return foldTr(title)
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .slice(0, 96);
}

export function contentHash({ title, canonicalUrl, summary }) {
  const normalized = [
    foldTr(title),
    String(canonicalUrl || '').trim().toLowerCase(),
    foldTr(String(summary || '').slice(0, 280)),
  ].join('|');
  return createHash('sha256').update(normalized, 'utf8').digest('hex');
}

const STOP = new Set([
  'icin',
  'ile',
  'yeni',
  'bugun',
  'yarin',
  'sonra',
  'daha',
  'gibi',
  'olan',
  'uzere',
  'basladi',
  'baslandi',
]);

const SYN = [
  ['aylik', 'ayligi', 'ayliklari', 'maas', 'maasi', 'maaslari'],
  ['hesaplara', 'hesaplarda', 'yatirildi', 'yatirilmaya'],
  ['engelli', 'engelliler', 'engellilerin'],
];

function canonToken(w) {
  for (const group of SYN) {
    if (group.includes(w)) return group[0];
  }
  return w;
}

function tokens(title) {
  return titleFingerprint(title)
    .split(' ')
    .filter((w) => w.length > 2 && !STOP.has(w))
    .map(canonToken);
}

function charGrams(title, n = 4) {
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
  const gram = dice(charGrams(a), charGrams(b));
  return Math.max(jaccard, gram);
}

export function isNearDuplicate(existing, { canonicalUrl, contentHash: hash, title }) {
  const url = String(canonicalUrl || '').trim();
  const h = String(hash || '').trim();
  if (url && existing.urls.has(url)) return { hit: true, groupId: existing.urlGroups.get(url) || null };
  if (h && existing.hashes.has(h)) return { hit: true, groupId: existing.hashGroups.get(h) || null };
  const fp = titleFingerprint(title);
  if (fp && existing.fingerprints.has(fp)) {
    return { hit: true, groupId: existing.fpGroups.get(fp) || null };
  }
  for (const row of existing.titles) {
    if (titleSimilarity(title, row.title) >= 0.42) {
      return { hit: true, groupId: row.groupId || row.id || null };
    }
  }
  return { hit: false, groupId: null };
}

export function emptyExisting() {
  return {
    urls: new Set(),
    hashes: new Set(),
    fingerprints: new Set(),
    urlGroups: new Map(),
    hashGroups: new Map(),
    fpGroups: new Map(),
    titles: [],
  };
}

export function remember(existing, row) {
  const url = String(row.canonicalUrl || '').trim();
  const hash = String(row.contentHash || '').trim();
  const fp = titleFingerprint(row.title);
  const group = row.duplicateGroupId || row.id || null;
  if (url) {
    existing.urls.add(url);
    if (group) existing.urlGroups.set(url, group);
  }
  if (hash) {
    existing.hashes.add(hash);
    if (group) existing.hashGroups.set(hash, group);
  }
  if (fp) {
    existing.fingerprints.add(fp);
    if (group) existing.fpGroups.set(fp, group);
  }
  existing.titles.push({
    title: row.title,
    id: row.id,
    groupId: group,
  });
}
