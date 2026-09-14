import { foldTr, isDisabilityOpportunity, stripHtml } from './hash.mjs';

const HOST_RE = /(^|\.)resmigazete\.gov\.tr$/i;
const DATE_PATH_RE = /^\/(\d{2})\.(\d{2})\.(\d{4})\/?$/;
const FIHRIST_PATH_RE = /^\/fihrist\/?$/i;
const SPA_FEED_PATH_RE = /^\/(rss|rss\.xml|feed)\/?$/i;
const ESKILER_ITEM_RE =
  /^\/eskiler\/\d{4}\/\d{2}\/\d{8}(?:-\d+)?\.html?$/i;
const FIHRIST_ITEM_RE =
  /<div class="fihrist-item[^"]*">\s*<a\b([^>]*?)href=["']([^"']+)["']([^>]*)>([\s\S]*?)<\/a>/gi;
const SKIP_TITLE_RE =
  /^(a\s*-|b\s*-|c\s*-|yargi ilan|artirma|eksiltme|ihale ilan|cesitli ilan|merkez bankasinca belirlenen)/i;

export const RESMI_GAZETE_ORIGIN = 'https://www.resmigazete.gov.tr';
export const RESMI_GAZETE_RECENT_DAYS = 3;

export function isResmiGazeteSourceUrl(url) {
  try {
    const u = new URL(url);
    if (!HOST_RE.test(u.hostname)) return false;
    const path = u.pathname.replace(/\/+$/, '') || '/';
    if (path === '/') return true;
    if (DATE_PATH_RE.test(path)) return true;
    if (FIHRIST_PATH_RE.test(path) || path === '/fihrist') return true;
    if (SPA_FEED_PATH_RE.test(path)) return true;
    return false;
  } catch {
    return false;
  }
}

function istanbulYmd(now) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

function shiftYmd(ymd, days) {
  const [y, m, d] = ymd.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + days));
  return dt.toISOString().slice(0, 10);
}

function issuePathFromYmd(ymd) {
  const [y, m, d] = ymd.split('-');
  return `/${d}.${m}.${y}`;
}

/**
 * Homepage expands to today + previous calendar days (/DD.MM.YYYY).
 * A date or fihrist URL stays as-is. Never walks /eskiler archive.
 */
export function resmiGazeteListingUrls(
  sourceUrl,
  { days = RESMI_GAZETE_RECENT_DAYS, now = new Date() } = {},
) {
  let u;
  try {
    u = new URL(sourceUrl);
  } catch {
    return [];
  }
  const path = u.pathname.replace(/\/+$/, '') || '/';
  if (DATE_PATH_RE.test(path) || FIHRIST_PATH_RE.test(path) || path === '/fihrist') {
    return [u.href];
  }
  const n = Math.max(1, Number(days) || RESMI_GAZETE_RECENT_DAYS);
  const today = istanbulYmd(now);
  const out = [`${RESMI_GAZETE_ORIGIN}/`];
  for (let i = 1; i < n; i += 1) {
    out.push(`${RESMI_GAZETE_ORIGIN}${issuePathFromYmd(shiftYmd(today, -i))}`);
  }
  return out;
}

function attr(blob, name) {
  const re = new RegExp(`\\b${name}=["']([^"']*)["']`, 'i');
  const m = String(blob || '').match(re);
  return m ? m[1] : '';
}

function cleanTitle(raw) {
  return stripHtml(raw)
    .replace(/^[–—\-•\s]+/, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 240);
}

/**
 * Narrow parser for today's / last-N-days fihrist only.
 * Keeps /eskiler/YYYY/MM/YYYYMMDD-N.htm items whose title matches
 * the disability core. Drops ilan section indexes and generic kanun.
 */
export function extractResmiGazeteListings(html, baseUrl, { limit = 20 } = {}) {
  let origin;
  try {
    origin = new URL(baseUrl).origin;
  } catch {
    return [];
  }
  const items = [];
  const seen = new Set();
  const re = new RegExp(FIHRIST_ITEM_RE.source, 'gi');
  let m;
  while ((m = re.exec(String(html || ''))) && items.length < limit) {
    const href = (m[2] || '').trim();
    if (!href || href.startsWith('javascript:') || href.startsWith('#')) continue;
    let abs;
    try {
      abs = new URL(href, baseUrl);
    } catch {
      continue;
    }
    if (abs.origin !== origin) continue;
    if (!ESKILER_ITEM_RE.test(abs.pathname)) continue;
    const title = cleanTitle(attr(`${m[1]} ${m[3]}`, 'title') || m[4] || '');
    if (!title || title.length < 12) continue;
    if (SKIP_TITLE_RE.test(foldTr(title))) continue;
    if (!isDisabilityOpportunity(title)) continue;
    if (seen.has(abs.href)) continue;
    seen.add(abs.href);
    items.push({
      title,
      summary: '',
      sourceUrl: abs.href,
      externalId: abs.href,
      imageUrl: '',
    });
  }
  return items;
}
