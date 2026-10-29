import { createHash } from 'node:crypto';

const DROP_QUERY = /^(utm_|fbclid|gclid|ocid|ns_|ref|ved|usg)/i;

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

export function stripHtml(raw) {
  return String(raw ?? '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

export function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./i, '').toLowerCase();
  } catch {
    return '';
  }
}

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
    .slice(0, 120);
}

export function titleHash(title) {
  return createHash('sha256').update(titleFingerprint(title), 'utf8').digest('hex');
}

export function contentHash({ title, url, snippet }) {
  const normalized = [
    foldTr(title),
    normalizeUrl(url),
    foldTr(String(snippet || '').slice(0, 280)),
  ].join('|');
  return createHash('sha256').update(normalized, 'utf8').digest('hex');
}

export function parseDate(raw) {
  const s = String(raw || '').trim();
  if (!s) return null;
  const d = Date.parse(s);
  if (Number.isFinite(d)) return new Date(d).toISOString();
  const m = s.match(/^(\d{4})(\d{2})(\d{2})T?(\d{2})?(\d{2})?(\d{2})?/);
  if (m) {
    const iso = `${m[1]}-${m[2]}-${m[3]}T${m[4] || '00'}:${m[5] || '00'}:${m[6] || '00'}Z`;
    const t = Date.parse(iso);
    if (Number.isFinite(t)) return new Date(t).toISOString();
  }
  return null;
}

export function isoDateOnly(raw) {
  const iso = parseDate(raw);
  return iso ? iso.slice(0, 10) : null;
}

export function recordFromRaw({
  title,
  url,
  source,
  date,
  snippet,
  extra = {},
}) {
  const cleanTitle = stripHtml(title).slice(0, 400);
  const cleanUrl = String(url || '').trim();
  return {
    title: cleanTitle,
    url: cleanUrl,
    canonical_url: normalizeUrl(cleanUrl),
    source: String(source || hostOf(cleanUrl) || '').slice(0, 120),
    date: parseDate(date),
    raw_snippet: stripHtml(snippet).slice(0, 1200),
    sources: extra.sources || (source ? [String(source)] : []),
    ...extra,
  };
}
