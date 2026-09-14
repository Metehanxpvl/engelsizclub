import { XMLParser } from 'fast-xml-parser';
import { stripHtml } from './hash.mjs';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  textNodeName: '#text',
  trimValues: true,
  processEntities: {
    enabled: true,
    maxTotalExpansions: 50000,
    maxEntityCount: 20000,
  },
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

function firstHttpUrl(value) {
  if (typeof value === 'string' && value.startsWith('http')) return value.trim();
  if (value && typeof value === 'object') {
    const href = value.url || value.href || value['#text'];
    if (typeof href === 'string' && href.startsWith('http')) return href.trim();
  }
  return '';
}

function enclosureImageUrl(item) {
  const blobs = [
    item.enclosure,
    item['media:content'],
    item['media:thumbnail'],
    item['itunes:image'],
  ];
  for (const raw of blobs) {
    for (const node of asArray(raw)) {
      const url = firstHttpUrl(node);
      if (!url) continue;
      const type = String(node?.type || node?.medium || '').toLowerCase();
      if (
        /image|jpeg|jpg|png|webp|gif/i.test(type) ||
        /\.(jpe?g|png|webp|gif)(\?|$)/i.test(url)
      ) {
        return url;
      }
    }
  }
  return '';
}

export const COLLECTOR_UA =
  'EngelsizClubContentCollector/1.0 (+https://engelsizclub.com)';

export async function fetchText(
  url,
  {
    timeoutMs = 15000,
    maxBytes = 0,
    accept = 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
  } = {},
) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      headers: {
        'user-agent': COLLECTOR_UA,
        accept,
      },
      redirect: 'follow',
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} ${url}`);
    }
    if (maxBytes > 0 && res.body) {
      const reader = res.body.getReader();
      const chunks = [];
      let n = 0;
      while (n < maxBytes) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
        n += value.byteLength;
      }
      try {
        await reader.cancel();
      } catch {
        /* ignore */
      }
      return Buffer.concat(chunks.map((c) => Buffer.from(c))).toString('utf8');
    }
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

export function looksLikeHtml(text) {
  const head = String(text || '').slice(0, 2500).toLowerCase();
  return head.includes('<!doctype html') || /<html[\s>]/.test(head);
}

export function looksLikeRssOrAtom(text) {
  if (looksLikeHtml(text)) return false;
  const head = String(text || '').slice(0, 2500).toLowerCase();
  return (
    head.includes('<rss') ||
    head.includes('<feed') ||
    head.includes('<rdf:rdf')
  );
}

export function looksLikeSitemap(text) {
  if (looksLikeHtml(text)) return false;
  const head = String(text || '').slice(0, 2500).toLowerCase();
  return head.includes('<urlset') || head.includes('<sitemapindex');
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
      const imageUrl = enclosureImageUrl(item);
      return { title, summary, sourceUrl, externalId, imageUrl };
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
