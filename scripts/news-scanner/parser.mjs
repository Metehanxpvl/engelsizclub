import { XMLParser } from 'fast-xml-parser';
import { stripHtml } from './filter.mjs';

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

function firstHttpUrl(value) {
  if (typeof value === 'string' && value.startsWith('http')) return value.trim();
  if (value && typeof value === 'object') {
    const href = value.url || value.href || value['#text'];
    if (typeof href === 'string' && href.startsWith('http')) return href.trim();
  }
  return '';
}

function linkOf(item) {
  const candidates = [item.link, item.guid, item.id, item['atom:link']];
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

function dateOf(item) {
  const raw = textOf(
    item.pubDate ||
      item.published ||
      item.updated ||
      item['dc:date'] ||
      item['atom:updated'],
  );
  if (!raw) return null;
  const t = Date.parse(raw);
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
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
        item.description ||
          item.summary ||
          item.content ||
          item['content:encoded'],
      ).slice(0, 1200);
      const articleUrl = linkOf(item);
      const imageUrl = enclosureImageUrl(item);
      const publishedAt = dateOf(item);
      return { title, summary, articleUrl, imageUrl, publishedAt };
    })
    .filter((e) => e.title && e.articleUrl);
}

export function isWithinWindow(publishedAt, sinceMs, nowMs = Date.now()) {
  if (!publishedAt) return false;
  const t = Date.parse(publishedAt);
  if (!Number.isFinite(t)) return false;
  return t >= sinceMs && t <= nowMs + 5 * 60 * 1000;
}

export function lookbackSinceMs(lastOkAt, nowMs = Date.now()) {
  const minMs = 24 * 3600 * 1000;
  const maxMs = 48 * 3600 * 1000;
  if (!lastOkAt) return nowMs - minMs;
  const last = Date.parse(lastOkAt);
  if (!Number.isFinite(last)) return nowMs - minMs;
  const gap = nowMs - last;
  if (gap <= minMs) return nowMs - minMs;
  if (gap >= maxMs) return nowMs - maxMs;
  return last;
}
