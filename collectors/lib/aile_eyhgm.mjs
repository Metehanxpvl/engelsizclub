import { toIsoDate } from './content_dates.mjs';
import { foldTr, isDisabilityOpportunity, stripHtml } from './hash.mjs';

const EYHGM_HOST_RE = /(^|\.)aile\.gov\.tr$/i;
const ITEM_PATH_RE =
  /^\/(?:eyhgm\/(haberler|duyurular)|duyurular)\/([^/?#]+)\/?$/i;
const SKIP_TITLE_RE =
  /^(haberin detayi|hepsini goruntule|devamini oku|daha fazla|haberler|duyurular)$/i;
const TITLE_SPAN_RE = /<span[^>]*class=["'][^"']*\btitle\b[^"']*["'][^>]*>([\s\S]*?)<\/span>/i;
const SUMMARY_SPAN_RE =
  /<span[^>]*class=["'][^"']*\bsummary\b[^"']*["'][^>]*>([\s\S]*?)<\/span>/i;
const CARD_DATE_RE =
  /class=["']day["'][^>]*>([^<]+)<[\s\S]*?class=["']moon["'][^>]*>([\s\S]*?)<\/span>[\s\S]*?class=["']year["'][^>]*>([^<]+)/i;
const ANCHOR_RE =
  /<a\b([^>]*?)href=["']([^"']+)["']([^>]*)>([\s\S]*?)<\/a>/gi;
const CARD_TITLE_RE = /<h[1-6][^>]*class=["'][^"']*card-title[^"']*["'][^>]*>([\s\S]*?)<\/h[1-6]>/i;
const IMG_SRC_RE = /<img\b[^>]*src=["']([^"']+)["']/i;

export function isAileEyhgmSourceUrl(url) {
  try {
    const u = new URL(url);
    if (!EYHGM_HOST_RE.test(u.hostname)) return false;
    const path = u.pathname.replace(/\/+$/, '') || '/';
    return /^\/eyhgm(\/|$)/i.test(path) || /^\/duyurular(\/|$)/i.test(path);
  } catch {
    return false;
  }
}

/** Homepage expands to the two listing pages; a listing URL stays as-is. */
export function aileEyhgmListingUrls(sourceUrl) {
  let u;
  try {
    u = new URL(sourceUrl);
  } catch {
    return [];
  }
  const path = u.pathname.replace(/\/+$/, '') || '/';
  if (/^\/eyhgm$/i.test(path)) {
    return [
      'https://www.aile.gov.tr/eyhgm/haberler',
      'https://www.aile.gov.tr/eyhgm/duyurular',
    ];
  }
  if (/^\/duyurular$/i.test(path)) {
    return ['https://www.aile.gov.tr/duyurular'];
  }
  return [u.href];
}

function attr(blob, name) {
  const re = new RegExp(`\\b${name}=["']([^"']*)["']`, 'i');
  const m = String(blob || '').match(re);
  return m ? m[1] : '';
}

function slugText(pathname) {
  return String(pathname || '')
    .replace(/^\/eyhgm\/(haberler|duyurular)\//i, '')
    .replace(/^\/duyurular\//i, '')
    .replace(/[-_/]+/g, ' ');
}

function pickPublishedAt(inner) {
  const m = String(inner || '').match(CARD_DATE_RE);
  if (!m) return null;
  return toIsoDate(`${stripHtml(m[1])} ${stripHtml(m[2])} ${stripHtml(m[3])}`);
}

function pickTitle(attrTitle, inner) {
  const fromAttr = stripHtml(attrTitle);
  const fromSpan = stripHtml((inner.match(TITLE_SPAN_RE) || [])[1] || '');
  const fromCard = stripHtml((inner.match(CARD_TITLE_RE) || [])[1] || '');
  const fromInner = stripHtml(inner);
  for (const t of [fromAttr, fromSpan, fromCard, fromInner]) {
    const title = t.replace(/\s+/g, ' ').trim().slice(0, 240);
    if (title.length < 12) continue;
    if (SKIP_TITLE_RE.test(foldTr(title))) continue;
    return title;
  }
  return '';
}

function pickImage(inner, baseUrl) {
  const src = (inner.match(IMG_SRC_RE) || [])[1] || '';
  if (!src) return '';
  try {
    const abs = new URL(src, baseUrl).href;
    return abs.startsWith('http') ? abs : '';
  } catch {
    return '';
  }
}

/**
 * Narrow parser for ASHB EYHGM haber/duyuru cards and bakanlık /duyurular.
 * Not a generic .gov.tr / .bel.tr homepage scrape.
 */
export function extractAileEyhgmListings(html, baseUrl, { limit = 20 } = {}) {
  let origin;
  try {
    origin = new URL(baseUrl).origin;
  } catch {
    return [];
  }
  const items = [];
  const seen = new Set();
  const re = new RegExp(ANCHOR_RE.source, 'gi');
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
    if (!ITEM_PATH_RE.test(abs.pathname)) continue;
    const title = pickTitle(attr(`${m[1]} ${m[3]}`, 'title'), m[4] || '');
    if (!title) continue;
    const slug = slugText(abs.pathname);
    if (!isDisabilityOpportunity(`${title} ${slug}`)) continue;
    if (seen.has(abs.href)) continue;
    seen.add(abs.href);
    const summary = stripHtml((m[4] || '').match(SUMMARY_SPAN_RE)?.[1] || '');
    items.push({
      title,
      summary: summary && summary !== title ? summary.slice(0, 1200) : '',
      sourceUrl: abs.href,
      externalId: abs.href,
      imageUrl: pickImage(m[4] || '', baseUrl),
      publishedAt: pickPublishedAt(m[4] || ''),
    });
  }
  return items;
}
