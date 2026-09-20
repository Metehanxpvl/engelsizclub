import { stripHtml } from './hash.mjs';

const HOST_RE = /(^|\.)ailecocuk\.aile\.gov\.tr$/i;
const PDF_HREF_RE = /href=["']([^"']+\.pdf(?:\?[^"']*)?)["']/gi;
const DEFAULT_LISTING = 'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr';

export function isAileCocukDergiSourceUrl(url) {
  try {
    const u = new URL(url);
    if (!HOST_RE.test(u.hostname)) return false;
    const path = u.pathname.replace(/\/+$/, '') || '/';
    return /^\/dergimiz$/i.test(path);
  } catch {
    return false;
  }
}

export function aileCocukDergiListingUrls(sourceUrl) {
  try {
    const u = new URL(sourceUrl);
    u.hash = '';
    if (!u.searchParams.get('lang')) u.searchParams.set('lang', 'tr');
    return [u.href];
  } catch {
    return [DEFAULT_LISTING];
  }
}

function issueFrom(text) {
  const s = String(text || '');
  const m =
    s.match(/say[iı]\s*[-_]?(\d+)/i) || s.match(/(\d+)\s*[-_]?say[iı]/i);
  return m ? Number(m[1]) : 0;
}

function absSameOrigin(href, baseUrl, origin) {
  let abs;
  try {
    abs = new URL(String(href || '').replace(/&amp;/g, '&'), baseUrl);
  } catch {
    return null;
  }
  if (abs.origin !== origin) return null;
  return abs;
}

/**
 * ASHB Aile Çocuk Dergisi listing: PDF issues, not belediye HTML news.
 * Generic crawl skips .pdf; this parser keeps numbered sayılar.
 */
export function extractAileCocukDergiListings(html, baseUrl, { limit = 8 } = {}) {
  let origin;
  try {
    origin = new URL(baseUrl).origin;
  } catch {
    return [];
  }
  const byIssue = new Map();
  const re = new RegExp(PDF_HREF_RE.source, 'gi');
  const raw = String(html || '');
  let m;
  while ((m = re.exec(raw))) {
    const abs = absSameOrigin(m[1], baseUrl, origin);
    if (!abs || !/\.pdf$/i.test(abs.pathname)) continue;
    const nearby = raw.slice(m.index, m.index + 900);
    const sayi =
      issueFrom(stripHtml(nearby)) ||
      issueFrom(decodeURIComponent(abs.pathname));
    if (!sayi || byIssue.has(sayi)) continue;
    const imgRaw =
      (nearby.match(
        /<img[^>]*class=["'][^"']*card-img-top[^"']*["'][^>]*src=["']([^"']+)["']/i,
      ) ||
        nearby.match(/src=["']([^"']+\.(?:jpe?g|png|webp))["']/i) ||
        [])[1] || '';
    let imageUrl = '';
    if (imgRaw) {
      const img = absSameOrigin(imgRaw, baseUrl, origin);
      if (img && !/\.pdf$/i.test(img.pathname)) imageUrl = img.href;
    }
    byIssue.set(sayi, {
      title: `Aile Çocuk Dergisi Sayı ${sayi}`,
      summary:
        'T.C. Aile ve Sosyal Hizmetler Bakanlığı Aile Çocuk Dergisi dijital sayısı.',
      sourceUrl: abs.href,
      externalId: abs.href,
      imageUrl,
      listingKind: 'magazine_issue',
      issue: sayi,
    });
  }
  return [...byIssue.values()]
    .sort((a, b) => b.issue - a.issue)
    .slice(0, limit)
    .map(({ issue, ...rest }) => rest);
}
