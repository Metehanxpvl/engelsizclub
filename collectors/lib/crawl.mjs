import { classifyKeep, foldTr, stripHtml } from './hash.mjs';
import { extractPageDates, toIsoDate } from './content_dates.mjs';
import { discoverRssLinks, robotsBlocksAll } from './discover.mjs';
import {
  fetchText as defaultFetchText,
  looksLikeRssOrAtom,
  looksLikeSitemap,
  parseRssOrAtom,
  parseSitemapEntries,
} from './rss.mjs';

export const MAX_LISTING_PAGES = 10;
export const MAX_PAGINATION_EXTRA = 3;
export const MAX_ARTICLES_PER_SOURCE = 40;
export const MAX_SITEMAP_URLS = 250;
export const MAX_NESTED_SITEMAPS = 6;
export const HTML_MAX_BYTES = 120_000;
export const XML_MAX_BYTES = 250_000;
export const CRAWL_CONCURRENCY = 3;
export const CRAWL_TIMEOUT_MS = 12_000;

const ANCHOR_RE = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;

/**
 * AVM’nin events_url listesi gibi: şehir özel path yok, aynı listing slug’ları
 * nav’da olmasa da dene; 404 o şehri düşürmez.
 */
export const COMMON_LISTING_PATHS = [
  '/haberler',
  '/duyurular',
  '/ilanlar',
  '/haber',
  '/duyuru',
  '/sosyal-yardim',
  '/sosyal-hizmetler',
  '/engelsiz',
  '/burs',
  '/basvuru',
];

/** Same-host listing slugs — Turkish variants, not per-city paths. */
export const LISTING_PATH_RE =
  /\/(haberler|haberleri|haber|duyurular|duyurulari|duyuru|ilanlar|ilanlari|ilan|sosyal-hizmetler|sosyal-hizmet|sosyal_hizmet|sosyalhizmet|sosyal-yardimlar|sosyal-yardim|sosyal_yardim|sosyalyardim|engelsiz-yasam|engelsiz|engelli|etkinlikler|etkinlik|burslar|burs|basvurular|basvuru|kultur|egitim|announcement|news|firsatlar|firsat|destekler)\b/i;

const SKIP_PATH_RE =
  /\/(rss|feed|atom|login|facebook|twitter|instagram|youtube|cdn-cgi|wp-admin|wp-login)\b/i;

const BINARY_RE = /\.(pdf|jpe?g|png|gif|webp|svg|zip|mp4|mp3|css|js)(\?|$)/i;

const LISTING_HINT =
  /haber|duyuru|ilan|sosyal|engelli|engelsiz|burs|egitim|etkinlik|basvuru|kultur|yardim|destek|news|announcement/i;

function hrefOf(attrs) {
  const m = String(attrs || '').match(/\bhref=["']([^"']+)["']/i);
  return m ? m[1].trim() : '';
}

export function extractRobotsSitemaps(robotsTxt) {
  const out = [];
  for (const line of String(robotsTxt || '').split(/\r?\n/)) {
    const m = line.replace(/#.*$/, '').match(/^sitemap:\s*(\S+)/i);
    if (m) out.push(m[1].trim());
  }
  return out;
}

export function isCrawlRelevantPath(pathname) {
  const p = String(pathname || '');
  if (LISTING_PATH_RE.test(p)) return true;
  return /engelli|engelsiz|sosyal|burs|egitim|ozel-egitim|ozel_egitim|yardim/i.test(
    p,
  );
}

export function isListingPath(pathname) {
  const parts = String(pathname || '')
    .replace(/\/+$/, '')
    .split('/')
    .filter(Boolean);
  if (!parts.length) return false;
  return LISTING_PATH_RE.test(`/${parts[parts.length - 1]}`);
}

export function isArticlePath(pathname) {
  const parts = String(pathname || '')
    .replace(/\/+$/, '')
    .split('/')
    .filter(Boolean);
  if (parts.length < 2) return false;
  for (let i = 0; i < parts.length - 1; i += 1) {
    if (LISTING_PATH_RE.test(`/${parts[i]}`) && parts[i + 1].length > 2) return true;
  }
  return LISTING_HINT.test(parts.join('/')) && parts.length >= 2;
}

function absoluteSameHost(href, baseUrl) {
  if (!href || href.startsWith('javascript:') || href.startsWith('mailto:')) {
    return null;
  }
  let abs;
  try {
    abs = new URL(href, baseUrl);
  } catch {
    return null;
  }
  let origin;
  try {
    origin = new URL(baseUrl).origin;
  } catch {
    return null;
  }
  if (abs.origin !== origin) return null;
  if (SKIP_PATH_RE.test(abs.pathname) || BINARY_RE.test(abs.pathname)) return null;
  return abs;
}

export function extractAnchors(html, baseUrl) {
  const items = [];
  const re = new RegExp(ANCHOR_RE.source, 'gi');
  let m;
  while ((m = re.exec(html))) {
    const href = hrefOf(m[1]);
    const title = stripHtml(m[2] || '').slice(0, 240);
    const abs = absoluteSameHost(href, baseUrl);
    if (!abs) continue;
    items.push({ href: abs.href, pathname: abs.pathname, title });
  }
  return items;
}

export function extractListingLinks(html, baseUrl, { limit = MAX_LISTING_PAGES } = {}) {
  const seen = new Set();
  const out = [];
  for (const a of extractAnchors(html, baseUrl)) {
    if (!isListingPath(a.pathname) || isArticlePath(a.pathname)) continue;
    if (seen.has(a.href)) continue;
    seen.add(a.href);
    out.push(a.href);
    if (out.length >= limit) break;
  }
  return out;
}

export function mergeCommonListingUrls(origin, discovered, { limit = MAX_LISTING_PAGES } = {}) {
  const out = [];
  const seen = new Set();
  const push = (href) => {
    const url = String(href || '').replace(/\/+$/, '') || href;
    if (!url || seen.has(url) || seen.has(`${url}/`)) return;
    seen.add(url);
    out.push(href.startsWith('http') ? href : `${origin}${href}`);
  };
  for (const u of discovered) push(u);
  for (const path of COMMON_LISTING_PATHS) {
    if (out.length >= limit) break;
    push(`${origin}${path}`);
  }
  return out.slice(0, limit);
}

export function extractArticleLinks(html, baseUrl, { limit = MAX_ARTICLES_PER_SOURCE } = {}) {
  const seen = new Set();
  const out = [];
  for (const a of extractAnchors(html, baseUrl)) {
    if (!isArticlePath(a.pathname)) continue;
    if (seen.has(a.href)) continue;
    seen.add(a.href);
    out.push({
      title: a.title,
      summary: '',
      sourceUrl: a.href,
      externalId: a.href,
      imageUrl: '',
      publishedAt: null,
      updatedAt: null,
      dateSource: 'listing',
    });
    if (out.length >= limit) break;
  }
  return out;
}

export function paginationUrls(html, pageUrl, { maxExtra = MAX_PAGINATION_EXTRA } = {}) {
  const out = [];
  const seen = new Set([pageUrl]);
  const push = (href) => {
    const abs = absoluteSameHost(String(href || '').replace(/&amp;/g, '&'), pageUrl);
    if (!abs || seen.has(abs.href)) return;
    seen.add(abs.href);
    out.push(abs.href);
  };

  const nextRel =
    html.match(
      /<(?:link|a)\b[^>]*rel=["']next["'][^>]*href=["']([^"']+)["'][^>]*>/i,
    ) ||
    html.match(
      /<(?:link|a)\b[^>]*href=["']([^"']+)["'][^>]*rel=["']next["'][^>]*>/i,
    );
  if (nextRel) push(nextRel[1]);

  let current = 1;
  try {
    const u = new URL(pageUrl);
    const q = u.searchParams.get('page') || u.searchParams.get('sayfa');
    if (q && /^\d+$/.test(q)) current = Number(q);
    const pathPage = u.pathname.match(/\/(?:page|sayfa)\/(\d+)\/?$/i);
    if (pathPage) current = Number(pathPage[1]);
  } catch {
    /* ignore */
  }

  const re = /href=["']([^"']*(?:\?|&|&amp;)(?:page|sayfa)=(\d+)[^"']*)["']/gi;
  let m;
  while ((m = re.exec(html))) {
    const n = Number(m[2]);
    if (n > current && n <= current + maxExtra) push(m[1]);
  }

  const pathRe = /href=["']([^"']*\/(?:page|sayfa)\/(\d+)\/?[^"']*)["']/gi;
  while ((m = pathRe.exec(html))) {
    const n = Number(m[2]);
    if (n > current && n <= current + maxExtra) push(m[1]);
  }

  return out.slice(0, maxExtra);
}

export function parseFlexibleDate(raw) {
  return toIsoDate(raw);
}

export function extractDetailMeta(html) {
  const pick = (...vals) => {
    for (const v of vals) {
      const t = stripHtml(v || '').slice(0, 240);
      if (t.length >= 4) return t;
    }
    return '';
  };
  const ogTitle =
    (html.match(
      /<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i,
    ) ||
      html.match(
        /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/i,
      ) ||
      [])[1];
  const titleTag = (html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1];
  const h1 = (html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || [])[1];
  const desc =
    (html.match(
      /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i,
    ) ||
      html.match(
        /<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i,
      ) ||
      [])[1];
  const dates = extractPageDates(html);
  return {
    title: pick(ogTitle, h1, titleTag),
    summary: stripHtml(desc || '').slice(0, 1200),
    publishedAt: dates.publishedAt || dates.visibleDate,
    updatedAt: dates.updatedAt,
    deadlineAt: dates.deadlineAt,
    eventAt: dates.eventAt,
  };
}

export function isStaleDated(publishedAt, lastFetchedAt) {
  if (!publishedAt || !lastFetchedAt) return false;
  const a = Date.parse(publishedAt);
  const b = Date.parse(lastFetchedAt);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return false;
  return a < b;
}

export function shouldFetchDetail(item) {
  const title = String(item?.title || '').trim();
  if (!title || title.length < 12) return true;
  const folded = foldTr(title);
  if (/^(haberler|duyurular|ilanlar|detay|devamini oku)$/.test(folded)) return true;
  if (!item?.publishedAt && !item?.updatedAt) return true;
  return false;
}

export function quickDropTitle(title) {
  const t = String(title || '').trim();
  if (!t) return false;
  return classifyKeep(t) == null && /asfalt|yol calis|personel atama|konser|galibiyet/i.test(
    foldTr(t),
  );
}

export async function mapLimit(items, limit, fn) {
  const ret = new Array(items.length);
  let i = 0;
  const n = Math.max(1, Math.min(limit, items.length) || 1);
  async function worker() {
    while (i < items.length) {
      const idx = i;
      i += 1;
      ret[idx] = await fn(items[idx], idx);
    }
  }
  await Promise.all(Array.from({ length: n }, () => worker()));
  return ret;
}

export async function withSourceGuard(name, fn) {
  try {
    return await fn();
  } catch (e) {
    return {
      name,
      items: [],
      found: 0,
      error: e?.message || String(e),
    };
  }
}

async function safeFetch(fetchText, url, opts) {
  try {
    return await fetchText(url, opts);
  } catch (e) {
    return { __error: e?.message || String(e) };
  }
}

function isErr(body) {
  return body && typeof body === 'object' && body.__error;
}

async function readRobots(origin, fetchText) {
  const txt = await safeFetch(fetchText, `${origin}/robots.txt`, {
    timeoutMs: 8000,
    maxBytes: 20_000,
    accept: 'text/plain, */*',
  });
  if (isErr(txt) || typeof txt !== 'string') {
    return { blocked: false, sitemaps: [] };
  }
  return {
    blocked: robotsBlocksAll(txt),
    sitemaps: extractRobotsSitemaps(txt),
  };
}

async function collectSitemapUrls(origin, robotsSitemaps, fetchText) {
  const seeds = [...robotsSitemaps, `${origin}/sitemap.xml`];
  const seen = new Set();
  const relevant = [];
  const nested = [];

  for (const sm of seeds) {
    if (seen.has(sm) || nested.length + 1 > MAX_NESTED_SITEMAPS + 2) continue;
    seen.add(sm);
    const xml = await safeFetch(fetchText, sm, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      maxBytes: XML_MAX_BYTES,
      accept: 'application/xml, text/xml, */*',
    });
    if (isErr(xml) || typeof xml !== 'string' || !looksLikeSitemap(xml)) continue;
    const entries = parseSitemapEntries(xml);
    for (const e of entries) {
      if (e.isIndex) {
        if (nested.length < MAX_NESTED_SITEMAPS) nested.push(e.loc);
        continue;
      }
      if (!isCrawlRelevantPath(new URL(e.loc).pathname)) continue;
      relevant.push(e);
      if (relevant.length >= MAX_SITEMAP_URLS) break;
    }
    if (relevant.length >= MAX_SITEMAP_URLS) break;
  }

  for (const sm of nested) {
    if (seen.has(sm)) continue;
    seen.add(sm);
    const xml = await safeFetch(fetchText, sm, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      maxBytes: XML_MAX_BYTES,
      accept: 'application/xml, text/xml, */*',
    });
    if (isErr(xml) || typeof xml !== 'string' || !looksLikeSitemap(xml)) continue;
    for (const e of parseSitemapEntries(xml)) {
      if (e.isIndex) continue;
      try {
        if (!isCrawlRelevantPath(new URL(e.loc).pathname)) continue;
      } catch {
        continue;
      }
      relevant.push(e);
      if (relevant.length >= MAX_SITEMAP_URLS) break;
    }
    if (relevant.length >= MAX_SITEMAP_URLS) break;
  }

  return relevant;
}

async function collectRssItems(homepageUrl, html, fetchText) {
  const items = [];
  const candidates = discoverRssLinks(html, homepageUrl);
  for (const url of candidates.slice(0, 3)) {
    const body = await safeFetch(fetchText, url, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      maxBytes: XML_MAX_BYTES,
    });
    if (isErr(body) || typeof body !== 'string') continue;
    if (!looksLikeRssOrAtom(body)) continue;
    items.push(...parseRssOrAtom(body));
    break;
  }
  return items;
}

/**
 * Site-crawl a municipality homepage: robots, sitemap, RSS, nav listings,
 * capped pagination, article details. One city's failure is returned, not thrown.
 */
export async function crawlMunicipality(
  source,
  {
    fetchText = defaultFetchText,
    existingUrls = new Set(),
    lastFetchedAt = null,
  } = {},
) {
  const sourceUrl = String(source.url || '').trim();
  const empty = { name: source.name, items: [], found: 0, error: null };
  let origin;
  try {
    origin = new URL(sourceUrl).origin;
  } catch {
    return { ...empty, error: 'geçersiz url' };
  }

  const robots = await readRobots(origin, fetchText);
  if (robots.blocked) {
    return { ...empty, error: 'robots Disallow:/' };
  }

  const home = await safeFetch(fetchText, sourceUrl, {
    timeoutMs: CRAWL_TIMEOUT_MS,
    maxBytes: HTML_MAX_BYTES,
    accept: 'text/html, application/xhtml+xml, */*;q=0.5',
  });
  if (isErr(home)) {
    return { ...empty, error: home.__error };
  }
  const homepageHtml = typeof home === 'string' ? home : '';

  const listingUrls = mergeCommonListingUrls(
    origin,
    extractListingLinks(homepageHtml, sourceUrl, {
      limit: MAX_LISTING_PAGES,
    }),
    { limit: MAX_LISTING_PAGES },
  );

  let sitemapEntries = [];
  try {
    sitemapEntries = await collectSitemapUrls(
      origin,
      robots.sitemaps,
      fetchText,
    );
    for (const e of sitemapEntries) {
      let path;
      try {
        path = new URL(e.loc).pathname;
      } catch {
        continue;
      }
      if (isListingPath(path) && !isArticlePath(path) && listingUrls.length < MAX_LISTING_PAGES) {
        if (!listingUrls.includes(e.loc)) listingUrls.push(e.loc);
      }
    }
  } catch (e) {
    console.warn(`sitemap atlandı ${source.name}: ${e.message}`);
  }

  const rssItems = await collectRssItems(sourceUrl, homepageHtml, fetchText);

  const listingHtmls = [];
  const seenPages = new Set();
  for (const listingUrl of listingUrls.slice(0, MAX_LISTING_PAGES)) {
    if (seenPages.has(listingUrl)) continue;
    seenPages.add(listingUrl);
    const html = await safeFetch(fetchText, listingUrl, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      maxBytes: HTML_MAX_BYTES,
      accept: 'text/html, application/xhtml+xml, */*;q=0.5',
    });
    if (isErr(html) || typeof html !== 'string') continue;
    listingHtmls.push({ url: listingUrl, html });
    for (const extra of paginationUrls(html, listingUrl, {
      maxExtra: MAX_PAGINATION_EXTRA,
    })) {
      if (seenPages.has(extra)) continue;
      seenPages.add(extra);
      const extraHtml = await safeFetch(fetchText, extra, {
        timeoutMs: CRAWL_TIMEOUT_MS,
        maxBytes: HTML_MAX_BYTES,
        accept: 'text/html, application/xhtml+xml, */*;q=0.5',
      });
      if (isErr(extraHtml) || typeof extraHtml !== 'string') continue;
      listingHtmls.push({ url: extra, html: extraHtml });
    }
  }

  const byUrl = new Map();
  const pushItem = (item) => {
    const url = String(item.sourceUrl || '').trim();
    if (!url || byUrl.has(url)) return;
    if (existingUrls.has(url)) return;
    if (quickDropTitle(item.title)) return;
    byUrl.set(url, item);
  };

  for (const it of rssItems) pushItem(it);
  for (const a of extractArticleLinks(homepageHtml, sourceUrl)) pushItem(a);
  for (const page of listingHtmls) {
    for (const a of extractArticleLinks(page.html, page.url)) pushItem(a);
  }
  for (const e of sitemapEntries) {
    let path;
    try {
      path = new URL(e.loc).pathname;
    } catch {
      continue;
    }
    if (!isArticlePath(path)) continue;
    pushItem({
      title: '',
      summary: '',
      sourceUrl: e.loc,
      externalId: e.loc,
      imageUrl: '',
      publishedAt: null,
      sitemapLastmod: parseFlexibleDate(e.lastmod),
      dateSource: 'sitemap_lastmod',
    });
  }

  let candidates = [...byUrl.values()].slice(0, MAX_ARTICLES_PER_SOURCE);

  const needDetail = candidates.filter(shouldFetchDetail);
  await mapLimit(needDetail, CRAWL_CONCURRENCY, async (item) => {
    const html = await safeFetch(fetchText, item.sourceUrl, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      maxBytes: HTML_MAX_BYTES,
      accept: 'text/html, application/xhtml+xml, */*;q=0.5',
    });
    if (isErr(html) || typeof html !== 'string') return;
    const meta = extractDetailMeta(html);
    if (meta.title && meta.title.length >= 8) item.title = meta.title;
    if (meta.summary) item.summary = meta.summary;
    if (meta.publishedAt) {
      item.publishedAt = meta.publishedAt;
      if (item.dateSource === 'sitemap_lastmod') item.dateSource = 'page';
    }
    if (meta.updatedAt) item.updatedAt = meta.updatedAt;
    if (meta.deadlineAt) item.deadlineAt = meta.deadlineAt;
    if (meta.eventAt) item.eventAt = meta.eventAt;
  });

  candidates = candidates.filter((item) => {
    if (!item.title || !item.sourceUrl) return false;
    return true;
  });

  return {
    name: source.name,
    items: candidates.map((item) => ({
      ...item,
      sourceName: source.name,
      sourceId: source.id,
    })),
    found: candidates.length,
    error: null,
    listingCount: listingUrls.length,
  };
}
