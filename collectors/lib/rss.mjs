import { XMLParser } from 'fast-xml-parser';
import { stripHtml } from './hash.mjs';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  textNodeName: '#text',
  trimValues: true,
});

function asArray(value) {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

function textOf(value) {
  if (value == null) return '';
  if (typeof value === 'string') return stripHtml(value);
  if (typeof value === 'number') return String(value);
  if (typeof value === 'object') {
    if (typeof value['#text'] === 'string') return stripHtml(value['#text']);
    if (typeof value.href === 'string') return value.href;
    if (typeof value.url === 'string') return value.url;
  }
  return '';
}

function linkOf(item) {
  const candidates = [
    item.link,
    item.guid,
    item.id,
    item['atom:link'],
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.startsWith('http')) return c.trim();
    if (c && typeof c === 'object') {
      const href = c.href || c.url || c['#text'];
      if (typeof href === 'string' && href.startsWith('http')) return href.trim();
      const alt = asArray(c).find(
        (n) => typeof n?.href === 'string' && n.href.startsWith('http'),
      );
      if (alt) return alt.href.trim();
    }
  }
  return '';
}

export async function fetchText(url, { timeoutMs = 15000 } = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      headers: {
        'user-agent':
          'EngelsizClubContentCollector/1.0 (+https://engelsizclub.com)',
        accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
      redirect: 'follow',
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} ${url}`);
    }
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

export function parseRssOrAtom(xml) {
  const doc = parser.parse(xml);
  const channelItems = asArray(doc?.rss?.channel?.item);
  const rdfItems = asArray(doc?.rdf?.item);
  const atomEntries = asArray(doc?.feed?.entry);
  const items = [...channelItems, ...rdfItems, ...atomEntries];
  return items
    .map((item) => {
      const title = textOf(item.title);
      const summary = textOf(
        item.description || item.summary || item.content || item['content:encoded'],
      );
      const sourceUrl = linkOf(item);
      const externalId = textOf(item.guid || item.id) || sourceUrl;
      return { title, summary, sourceUrl, externalId };
    })
    .filter((e) => e.title && e.sourceUrl);
}

export function parseSitemapLocs(xml) {
  const doc = parser.parse(xml);
  const urlset = asArray(doc?.urlset?.url);
  const sitemapIndex = asArray(doc?.sitemapindex?.sitemap);
  const locs = [
    ...urlset.map((u) => textOf(u.loc)),
    ...sitemapIndex.map((s) => textOf(s.loc)),
  ].filter((u) => u.startsWith('http'));
  return [...new Set(locs)];
}

export function isXmlUrl(url) {
  const u = String(url ?? '').toLowerCase();
  return (
    u.includes('.xml') ||
    u.includes('rss') ||
    u.includes('atom') ||
    u.includes('feed') ||
    u.includes('sitemap')
  );
}
