import { foldTr, isOpenOpportunitySignal, stripHtml } from './hash.mjs';

/** Inclusive lookback: today minus 15 calendar days (2026-09-15 → 2026-08-31). */
export const RECENT_DAYS = 15;

const TR_MONTHS = {
  ocak: '01',
  subat: '02',
  mart: '03',
  nisan: '04',
  mayis: '05',
  haziran: '06',
  temmuz: '07',
  agustos: '08',
  eylul: '09',
  ekim: '10',
  kasim: '11',
  aralik: '12',
};

const CRAWL_DATE_KEYS = new Set([
  'lastcheckedat',
  'last_checked_at',
  'lastfetchedat',
  'last_fetched_at',
  'crawledat',
  'crawled_at',
  'checkedat',
  'fetchedat',
]);

export function utcYmd(now = new Date()) {
  const d = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(d.getTime())) return '';
  return d.toISOString().slice(0, 10);
}

export function addUtcDays(ymd, days) {
  const s = String(ymd || '');
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return '';
  const dt = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]) + Number(days)));
  return dt.toISOString().slice(0, 10);
}

export function recentCutoffYmd(now = new Date(), days = RECENT_DAYS) {
  const today = utcYmd(now);
  return today ? addUtcDays(today, -Math.abs(Number(days) || RECENT_DAYS)) : '';
}

export function ymdOf(raw) {
  const iso = toIsoDate(raw);
  return iso ? iso.slice(0, 10) : null;
}

export function isYmdWithinRecent(ymd, now = new Date(), days = RECENT_DAYS) {
  const day = String(ymd || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return false;
  const today = utcYmd(now);
  const cutoff = recentCutoffYmd(now, days);
  if (!today || !cutoff) return false;
  return day >= cutoff && day <= today;
}

export function isIsoWithinRecent(raw, now = new Date(), days = RECENT_DAYS) {
  return isYmdWithinRecent(ymdOf(raw), now, days);
}

export function compareYmd(a, b) {
  const x = String(a || '').slice(0, 10);
  const y = String(b || '').slice(0, 10);
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

export function toIsoDate(raw) {
  if (raw == null || raw === '') return null;
  if (raw instanceof Date) {
    return Number.isNaN(raw.getTime()) ? null : raw.toISOString();
  }
  const s = String(raw).trim();
  if (!s) return null;
  if (/^\d{4}-\d{2}-\d{2}T/.test(s)) {
    const t = Date.parse(s);
    return Number.isFinite(t) ? new Date(t).toISOString() : `${s.slice(0, 10)}T00:00:00.000Z`;
  }
  const isoDay = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:\b|$)/);
  if (isoDay) return `${isoDay[1]}-${isoDay[2]}-${isoDay[3]}T00:00:00.000Z`;
  const compact = s.match(/^(\d{4})(\d{2})(\d{2})(?:\b|$)/);
  if (compact) return `${compact[1]}-${compact[2]}-${compact[3]}T00:00:00.000Z`;
  const dmy = s.match(/^(\d{1,2})[./](\d{1,2})[./](\d{4})/);
  if (dmy) {
    return `${dmy[3]}-${dmy[2].padStart(2, '0')}-${dmy[1].padStart(2, '0')}T00:00:00.000Z`;
  }
  const tr = parseTurkishLongDate(s);
  if (tr) return tr;
  const t = Date.parse(s);
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
}

function parseTurkishLongDate(s) {
  const m = String(s || '').match(
    /(\d{1,2})\s+(ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)\s+(\d{4})/i,
  );
  if (!m) return null;
  const month = TR_MONTHS[foldTr(m[2])] || '';
  if (!month) return null;
  return `${m[3]}-${month}-${m[1].padStart(2, '0')}T00:00:00.000Z`;
}

function firstIso(...vals) {
  for (const v of vals) {
    const iso = toIsoDate(v);
    if (iso) return iso;
  }
  return null;
}

export function dateFromSourceUrl(url) {
  const u = String(url || '');
  const eskiler = u.match(/\/eskiler\/\d{4}\/\d{2}\/(\d{8})(?:-\d+)?\.(?:html?|pdf)/i);
  if (eskiler) return toIsoDate(eskiler[1]);
  const dotted = u.match(/\/(\d{2})\.(\d{2})\.(\d{4})(?:\/|$)/);
  if (dotted) return toIsoDate(`${dotted[1]}.${dotted[2]}.${dotted[3]}`);
  const isoPath = u.match(/\/(\d{4})\/(\d{2})\/(\d{2})(?:\/|$)/);
  if (isoPath) return toIsoDate(`${isoPath[1]}-${isoPath[2]}-${isoPath[3]}`);
  return null;
}

function attrContent(html, names) {
  for (const name of names) {
    const re = new RegExp(
      `<meta[^>]+(?:property|name|itemprop)=["']${name}["'][^>]+content=["']([^"']+)["'][^>]*>`,
      'i',
    );
    const reFlip = new RegExp(
      `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name|itemprop)=["']${name}["'][^>]*>`,
      'i',
    );
    const m = html.match(re) || html.match(reFlip);
    if (m?.[1]) {
      const iso = toIsoDate(m[1]);
      if (iso) return iso;
    }
  }
  return null;
}

function jsonLdDates(html) {
  const out = { publishedAt: null, updatedAt: null, deadlineAt: null };
  const re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) {
    const body = m[1] || '';
    const published = body.match(/"datePublished"\s*:\s*"([^"]+)"/i);
    const modified = body.match(/"dateModified"\s*:\s*"([^"]+)"/i);
    const through = body.match(/"validThrough"\s*:\s*"([^"]+)"/i);
    if (!out.publishedAt && published) out.publishedAt = toIsoDate(published[1]);
    if (!out.updatedAt && modified) out.updatedAt = toIsoDate(modified[1]);
    if (!out.deadlineAt && through) out.deadlineAt = toIsoDate(through[1]);
  }
  return out;
}

function timeDatetimes(html) {
  const out = [];
  const re = /<time\b[^>]*datetime=["']([^"']+)["'][^>]*>/gi;
  let m;
  while ((m = re.exec(html))) {
    const iso = toIsoDate(m[1]);
    if (iso) out.push(iso);
  }
  return out;
}

export function extractDatesFromText(text) {
  const raw = String(text || '');
  const folded = foldTr(raw);
  const found = [];
  const push = (iso, kind) => {
    if (!iso) return;
    found.push({ iso, ymd: iso.slice(0, 10), kind });
  };

  const labeled = (labelRe, kind) => {
    const re = new RegExp(`${labelRe.source}.{0,40}?(\\d{1,2}[./]\\d{1,2}[./]\\d{4})`, 'i');
    const m = folded.match(re) || raw.match(re);
    if (m) push(toIsoDate(m[1]), kind);
    const reTr = new RegExp(
      `${labelRe.source}.{0,48}?(\\d{1,2}\\s+(?:ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)\\s+\\d{4})`,
      'i',
    );
    const t = raw.match(reTr);
    if (t) push(toIsoDate(t[1]), kind);
  };

  labeled(/son\s+basvuru(?:\s+tarihi)?|basvuru\s+bitis|son\s+tarih|validthrough|son\s+gun/, 'deadline');
  labeled(/etkinlik\s+tarihi|etkinlik\s+gunu|duzenlenecegi\s+tarih/, 'event');
  labeled(/yayin(?:lanma)?(?:\s+tarihi)?|guncelleme(?:\s+tarihi)?|tarih/, 'visible');

  const dmyRe = /(\d{1,2}[./]\d{1,2}[./]\d{4})/g;
  let m;
  while ((m = dmyRe.exec(raw))) {
    const iso = toIsoDate(m[1]);
    if (!iso) continue;
    const ctx = foldTr(raw.slice(Math.max(0, m.index - 28), m.index + m[1].length + 12));
    if (/son\s+basvuru|basvuru\s+bitis|son\s+tarih|kadar/.test(ctx)) push(iso, 'deadline');
    else if (/etkinlik|duzenlenecek|yapilacak/.test(ctx)) push(iso, 'event');
    else push(iso, 'visible');
  }

  const trRe =
    /(\d{1,2}\s+(?:Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\s+\d{4})/gi;
  while ((m = trRe.exec(raw))) {
    push(toIsoDate(m[1]), 'visible');
  }

  return found;
}

export function extractPageDates(html) {
  const raw = String(html || '');
  const ld = jsonLdDates(raw);
  const publishedAt = firstIso(
    attrContent(raw, [
      'article:published_time',
      'og:published_time',
      'datePublished',
      'pubdate',
      'publishdate',
      'dc.date.issued',
      'dc.date',
      'date',
    ]),
    ld.publishedAt,
    timeDatetimes(raw)[0],
  );
  const updatedAt = firstIso(
    attrContent(raw, [
      'article:modified_time',
      'og:updated_time',
      'dateModified',
      'revised',
    ]),
    ld.updatedAt,
  );
  const text = stripHtml(raw).slice(0, 8000);
  const fromText = extractDatesFromText(text);
  const deadlineAt = firstIso(
    ld.deadlineAt,
    fromText.find((d) => d.kind === 'deadline')?.iso,
  );
  const eventAt = firstIso(fromText.find((d) => d.kind === 'event')?.iso);
  const visibleDate = firstIso(
    fromText.find((d) => d.kind === 'visible')?.iso,
    fromText[0]?.iso,
  );
  return {
    publishedAt,
    updatedAt,
    deadlineAt,
    eventAt,
    visibleDate,
  };
}

function ignoreCrawlish(key, value) {
  const k = foldTr(String(key || '')).replace(/[^a-z0-9_]+/g, '');
  if (CRAWL_DATE_KEYS.has(k)) return true;
  if (k === 'lastmod' || k === 'sitemaplastmod') return true;
  return !value;
}

/**
 * Date priority: published_at, updated_at, datePublished, dateModified,
 * visible page date, RSS pubDate. Sitemap lastmod is never used alone.
 * Crawl last_checked_at / last_fetched_at are not content dates.
 */
export function pickContentDate(item = {}) {
  const sitemapOnly =
    item.dateSource === 'sitemap_lastmod' ||
    (item.sitemapLastmod && !item.publishedAt && !item.updatedAt && !item.datePublished);

  const publishedAt = sitemapOnly
    ? null
    : firstIso(
        ignoreCrawlish('publishedAt', item.publishedAt) ? null : item.publishedAt,
        item.published_at,
        item.datePublished,
        item.pubDate,
      );
  const updatedAt = sitemapOnly
    ? null
    : firstIso(
        item.updatedAt,
        item.updated_at,
        item.dateModified,
        item.updated,
      );
  const visibleDate = firstIso(item.visibleDate, item.visible_date);
  const fromUrl = dateFromSourceUrl(item.sourceUrl || item.source_url);
  const chosen = firstIso(publishedAt, updatedAt, visibleDate, fromUrl);
  return {
    publishedAt: publishedAt || (chosen && chosen === fromUrl ? fromUrl : publishedAt),
    updatedAt,
    visibleDate: visibleDate || fromUrl,
    contentAt: firstIso(updatedAt, publishedAt, visibleDate, fromUrl),
    fromUrl,
  };
}

export function looksLikeEventText(text) {
  const hay = foldTr(text);
  return /etkinlik|senlik|festival|toplant[iı]|seminer|konferans|workshop/.test(hay);
}

/**
 * @returns {{
 *   action: 'keep'|'reject'|'skip',
 *   reason: string,
 *   dateStatus: 'recent'|'unknown'|'older',
 *   contentKind: 'recent'|'active_opportunity'|null,
 *   publishedAt: string|null,
 *   updatedAt: string|null,
 *   deadlineAt: string|null,
 *   eventAt: string|null,
 *   isRecent: boolean,
 *   isActiveOpportunity: boolean,
 * }}
 */
export function evaluateFreshness(item = {}, { now = new Date(), html = '' } = {}) {
  if (item.listingKind === 'magazine_issue') {
    const today = utcYmd(now);
    return {
      action: 'keep',
      reason: 'magazine_listing',
      dateStatus: 'recent',
      contentKind: 'recent',
      publishedAt: today ? `${today}T00:00:00.000Z` : null,
      updatedAt: null,
      deadlineAt: null,
      eventAt: null,
      isRecent: true,
      isActiveOpportunity: false,
    };
  }
  const page = html ? extractPageDates(html) : {};
  const picked = pickContentDate({ ...item, ...page });
  const blob = `${item.title || ''} ${item.summary || ''} ${
    html ? stripHtml(html).slice(0, 4000) : ''
  }`;
  const textDates = extractDatesFromText(blob);
  const deadlineAt = firstIso(
    item.deadlineAt,
    item.deadline_at,
    item.deadline,
    page.deadlineAt,
    textDates.find((d) => d.kind === 'deadline')?.iso,
  );
  const eventAt = firstIso(
    item.eventAt,
    item.event_date,
    item.eventDate,
    page.eventAt,
    textDates.find((d) => d.kind === 'event')?.iso,
    looksLikeEventText(blob) ? textDates.find((d) => d.kind === 'visible')?.iso : null,
  );

  const today = utcYmd(now);
  const contentAt = picked.contentAt;
  const contentYmd = ymdOf(contentAt);
  const updatedRecent = Boolean(picked.updatedAt && isIsoWithinRecent(picked.updatedAt, now));
  const originalPublishedRecent = Boolean(
    picked.publishedAt && isIsoWithinRecent(picked.publishedAt, now),
  );
  const fallbackRecent = Boolean(contentYmd && isYmdWithinRecent(contentYmd, now));
  const isRecent = updatedRecent || originalPublishedRecent || fallbackRecent;

  const deadlineYmd = ymdOf(deadlineAt);
  const eventYmd = ymdOf(eventAt);
  const deadlineOpen = deadlineYmd ? deadlineYmd >= today : false;
  const deadlineExpired = deadlineYmd ? deadlineYmd < today : false;
  const eventFuture = eventYmd ? eventYmd >= today : false;
  const eventPast = eventYmd ? eventYmd < today : false;
  const openSignal = isOpenOpportunitySignal(blob);

  let dateStatus = 'unknown';
  if (contentYmd) dateStatus = isRecent ? 'recent' : 'older';
  else if (updatedRecent) dateStatus = 'recent';

  const publishedAt = picked.publishedAt || (isRecent ? contentAt : picked.contentAt);
  const base = {
    publishedAt: publishedAt || null,
    updatedAt: picked.updatedAt || null,
    deadlineAt: deadlineAt || null,
    eventAt: eventAt || null,
    isRecent,
    dateStatus,
  };

  if (deadlineExpired && !eventFuture) {
    return {
      ...base,
      action: 'reject',
      reason: 'expired_deadline',
      contentKind: null,
      isActiveOpportunity: false,
    };
  }
  if (eventPast && !deadlineOpen && !isRecent) {
    return {
      ...base,
      action: 'reject',
      reason: 'past_event',
      contentKind: null,
      isActiveOpportunity: false,
    };
  }

  if (isRecent) {
    return {
      ...base,
      dateStatus: 'recent',
      action: 'keep',
      reason: updatedRecent && !originalPublishedRecent ? 'updated_recent' : 'recent',
      contentKind: 'recent',
      isActiveOpportunity: false,
    };
  }

  const active =
    deadlineOpen || eventFuture || (openSignal && !deadlineExpired && !eventPast);

  if (active) {
    return {
      ...base,
      action: 'keep',
      reason: deadlineOpen ? 'deadline_open' : eventFuture ? 'event_future' : 'open_signal',
      contentKind: 'active_opportunity',
      isActiveOpportunity: true,
    };
  }

  if (dateStatus === 'older') {
    return {
      ...base,
      action: 'reject',
      reason: 'older_than_15_days',
      contentKind: null,
      isActiveOpportunity: false,
    };
  }

  return {
    ...base,
    dateStatus: 'unknown',
    action: 'skip',
    reason: 'unknown_date',
    contentKind: null,
    isActiveOpportunity: false,
  };
}

export function emptyDateStats() {
  return {
    candidates: 0,
    recent: 0,
    older: 0,
    activeAmongOlder: 0,
    expiredRejected: 0,
    unknownSkipped: 0,
    sentToAi: 0,
    saved: 0,
  };
}

export function printDateStats(stats) {
  const s = stats || emptyDateStats();
  console.log('--- tarih süzgeci ---');
  console.log(`Total candidates: ${s.candidates}`);
  console.log(`Recent (<15 days): ${s.recent}`);
  console.log(`Older than 15 days: ${s.older}`);
  console.log(`Active opportunities among older: ${s.activeAmongOlder}`);
  console.log(`Expired old rejected: ${s.expiredRejected}`);
  console.log(`Sent to AI: ${s.sentToAi}`);
  console.log(`Saved: ${s.saved}`);
}
