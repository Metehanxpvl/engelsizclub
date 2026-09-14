import { isDisabilityOpportunity, stripHtml } from './hash.mjs';
import { fetchText, looksLikeRssOrAtom } from './rss.mjs';

const RSS_LINK_RE =
  /<link\b[^>]+(?:type=["']application\/(?:rss|atom)\+xml["'][^>]*href=["']([^"']+)["']|href=["']([^"']+)["'][^>]*type=["']application\/(?:rss|atom)\+xml["'])/gi;

const HREF_FEED_RE = /href=["']([^"']*(?:rss|atom|feed)[^"']*)["']/gi;

const ANCHOR_RE = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;

const ARTICLE_PATH_RE =
  /\/(haber|haberler|duyuru|duyurular|news|announcement|ilan|ilanlar|firsat|destek)\b/i;

export function discoverRssLinks(html, baseUrl) {
  const out = [];
  const seen = new Set();
  const push = (href) => {
    if (!href || href.startsWith('javascript:') || href.startsWith('mailto:')) {
      return;
    }
    let abs;
    try {
      abs = new URL(href, baseUrl).href;
    } catch {
      return;
    }
    if (seen.has(abs)) return;
    seen.add(abs);
    out.push(abs);
  };

  let m;
  const linkRe = new RegExp(RSS_LINK_RE.source, 'gi');
  while ((m = linkRe.exec(html))) {
    push(m[1] || m[2]);
  }
  const hrefRe = new RegExp(HREF_FEED_RE.source, 'gi');
  while ((m = hrefRe.exec(html)) && out.length < 12) {
    const href = m[1];
    if (/\.(css|js|png|jpe?g|gif|svg|woff2?)$/i.test(href)) continue;
    push(href);
  }
  return out.slice(0, 8);
}

export function extractDisabilityListings(html, baseUrl, { limit = 12 } = {}) {
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
  while ((m = re.exec(html)) && items.length < limit) {
    const href = (m[1] || '').trim();
    const title = stripHtml(m[2] || '').slice(0, 240);
    if (!href || !title || title.length < 8) continue;
    let abs;
    try {
      abs = new URL(href, baseUrl);
    } catch {
      continue;
    }
    if (abs.origin !== origin) continue;
    if (!ARTICLE_PATH_RE.test(abs.pathname) && !ARTICLE_PATH_RE.test(abs.href)) {
      continue;
    }
    if (/\/(rss|feed|atom|login|facebook|twitter|instagram)\b/i.test(abs.pathname)) {
      continue;
    }
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

export function robotsBlocksAll(robotsTxt) {
  const text = String(robotsTxt || '');
  if (!text.trim()) return false;
  const lines = text.split(/\r?\n/).map((l) => l.replace(/#.*$/, '').trim());
  let inStar = false;
  let starDisallowRoot = false;
  for (const line of lines) {
    const ua = line.match(/^user-agent:\s*(.+)$/i);
    if (ua) {
      const name = ua[1].trim();
      inStar = name === '*';
      continue;
    }
    if (!inStar) continue;
    if (/^disallow:\s*\/\s*$/i.test(line)) starDisallowRoot = true;
    if (/^allow:\s*\/\s*$/i.test(line)) starDisallowRoot = false;
  }
  return starDisallowRoot;
}

const robotsCache = new Map();

export async function originAllowsFetch(url) {
  let origin;
  try {
    origin = new URL(url).origin;
  } catch {
    return true;
  }
  if (robotsCache.has(origin)) return robotsCache.get(origin);
  try {
    const txt = await fetchText(`${origin}/robots.txt`, {
      timeoutMs: 8000,
      maxBytes: 20_000,
      accept: 'text/plain, */*',
    });
    const ok = !robotsBlocksAll(txt);
    robotsCache.set(origin, ok);
    return ok;
  } catch {
    robotsCache.set(origin, true);
    return true;
  }
}

export async function resolveRssFromHomepage(homepageUrl, html) {
  const candidates = discoverRssLinks(html, homepageUrl);
  for (const url of candidates.slice(0, 3)) {
    try {
      const body = await fetchText(url, { timeoutMs: 12000, maxBytes: 120_000 });
      if (looksLikeRssOrAtom(body)) return { url, xml: body };
    } catch {
      /* ignore */
    }
  }
  return null;
}
