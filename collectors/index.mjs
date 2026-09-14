import { classifyCandidate } from './lib/ai.mjs';
import {
  hasRelevanceKeyword,
  isDisabilityOpportunity,
  isDuplicate,
  stripHtml,
  usefulContentHash,
} from './lib/hash.mjs';
import {
  extractDisabilityListings,
  originAllowsFetch,
  resolveRssFromHomepage,
} from './lib/discover.mjs';
import {
  aileEyhgmListingUrls,
  extractAileEyhgmListings,
  isAileEyhgmSourceUrl,
} from './lib/aile_eyhgm.mjs';
import {
  fetchText,
  isXmlUrl,
  looksLikeHtml,
  looksLikeRssOrAtom,
  looksLikeSitemap,
  parseRssOrAtom,
  parseSitemapLocs,
} from './lib/rss.mjs';

const MAX_ITEMS_RSS = 25;
const MAX_ITEMS_SCRAPE = 12;
const MAX_SITEMAP_FEEDS = 8;
const SOURCE_DELAY_MS = 600;
const HTML_MAX_BYTES = 80_000;
const AILE_EYHGM_HTML_MAX_BYTES = 300_000;
const XML_MAX_BYTES = 250_000;
const MAX_ITEMS_AILE_EYHGM = 20;
const TBB_INDEX_RE =
  /tbb\.gov\.tr\/tr\/(buyuksehir-belediyeleri|il-belediyeleri|bagli-idareler)/i;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const AI_KEY = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '').trim();

function headers() {
  return {
    apikey: SERVICE_KEY,
    authorization: `Bearer ${SERVICE_KEY}`,
    'content-type': 'application/json',
    prefer: 'return=representation',
  };
}

async function sb(path, { method = 'GET', body, extraQuery = '' } = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}${extraQuery}`;
  const res = await fetch(url, {
    method,
    headers: headers(),
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Supabase ${method} ${path}: ${res.status} ${text}`);
  }
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function loadExistingKeys() {
  const rows = (await sb(
    'useful_content?select=source_url,content_hash,external_id',
  )) || [];
  const urls = new Set();
  const hashes = new Set();
  const externalIds = new Set();
  for (const row of rows) {
    const url = String(row.source_url || '').trim();
    const hash = String(row.content_hash || '').trim();
    const ext = String(row.external_id || '').trim();
    if (url) urls.add(url);
    if (hash) hashes.add(hash);
    if (ext) externalIds.add(ext);
  }
  return { urls, hashes, externalIds };
}

function remember(existing, { sourceUrl, contentHash, externalId }) {
  if (sourceUrl) existing.urls.add(sourceUrl);
  if (contentHash) existing.hashes.add(contentHash);
  if (externalId) existing.externalIds.add(externalId);
}

async function loadDueSources() {
  const rows = (await sb(
    'content_sources?is_active=eq.true&select=id,name,url,method,fetch_interval_hours,last_fetched_at',
  )) || [];
  const now = Date.now();
  return rows.filter((s) => {
    if (!s.last_fetched_at) return true;
    const hours = Number(s.fetch_interval_hours) || 24;
    const last = Date.parse(s.last_fetched_at);
    if (!Number.isFinite(last)) return true;
    return now - last >= hours * 3600 * 1000;
  });
}

async function rejectUnrelatedPending() {
  const rows =
    (await sb(
      'useful_content?status=eq.pending_review&select=id,title,summary',
    )) || [];
  let n = 0;
  for (const row of rows) {
    const blob = `${row.title || ''} ${row.summary || ''}`;
    if (isDisabilityOpportunity(blob)) continue;
    await sb(`useful_content?id=eq.${row.id}`, {
      method: 'PATCH',
      body: {
        status: 'rejected',
        ai_notes: 'alakasız_haber',
      },
    });
    n += 1;
    console.log(`pending reddedildi (alakasız): ${row.title}`);
  }
  if (n) console.log(`alakasız pending reddi: ${n}`);
}

async function markExpired() {
  const now = new Date().toISOString();
  await sb(
    `useful_content?status=eq.published&expires_at=lt.${encodeURIComponent(now)}`,
    {
      method: 'PATCH',
      body: { status: 'expired' },
    },
  );
}

async function collectFromRss(source, xml) {
  return parseRssOrAtom(xml).map((item) => ({
    ...item,
    sourceName: source.name,
    sourceId: source.id,
  }));
}

async function collectFromSitemap(source, xml) {
  const locs = parseSitemapLocs(xml).filter(isXmlUrl).slice(0, MAX_SITEMAP_FEEDS);
  const items = [];
  for (const loc of locs) {
    try {
      const nested = await fetchText(loc, { maxBytes: XML_MAX_BYTES });
      if (!looksLikeRssOrAtom(nested)) continue;
      items.push(...(await collectFromRss(source, nested)));
    } catch (e) {
      console.warn(`sitemap alt XML atlandı ${loc}: ${e.message}`);
    }
    await sleep(200);
  }
  return items;
}

function parseDeadline(raw) {
  const s = String(raw ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}/.test(s)) return null;
  const d = new Date(`${s.slice(0, 10)}T00:00:00.000Z`);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

async function refineItem(item) {
  const title = stripHtml(item.title);
  const summary = stripHtml(item.summary).slice(0, 1200);
  if (!title || !item.sourceUrl) return null;

  if (!isDisabilityOpportunity(`${title} ${summary}`)) {
    console.log(`özel gereksinim çekirdeği yok, atlandı: ${title}`);
    return null;
  }

  if (AI_KEY) {
    try {
      const ai = await classifyCandidate(AI_KEY, {
        title,
        summary,
        sourceUrl: item.sourceUrl,
      });
      if (!ai.relevant) {
        console.log(`AI alakasız, atlandı: ${title}`);
        return null;
      }
      const merged = `${ai.title || title} ${ai.summary || summary}`;
      if (!isDisabilityOpportunity(merged) && !isDisabilityOpportunity(`${title} ${summary}`)) {
        console.log(`AI evet dedi ama özel gereksinim çekirdeği yok, atlandı: ${title}`);
        return null;
      }
      return {
        title: stripHtml(ai.title || title).slice(0, 240) || title,
        summary: stripHtml(ai.summary || summary).slice(0, 1200),
        category: String(ai.category || 'diger').trim() || 'diger',
        city: stripHtml(ai.city || ''),
        deadlineAt: parseDeadline(ai.deadline),
        aiNotes: stripHtml(ai.notes || ''),
      };
    } catch (e) {
      console.warn(`AI hata, kayıt yazılmadı: ${title} — ${e.message}`);
      return null;
    }
  }

  if (!hasRelevanceKeyword(`${title} ${summary}`)) {
    console.log(`Anahtar kelime yok, atlandı: ${title}`);
    return null;
  }
  return {
    title,
    summary,
    category: 'diger',
    city: '',
    deadlineAt: null,
    aiNotes: 'anahtar_kelime',
  };
}

async function insertPending(existing, source, raw) {
  const refined = await refineItem(raw);
  if (!refined) return false;

  const sourceUrl = String(raw.sourceUrl || '').trim();
  const externalId = String(raw.externalId || sourceUrl).trim() || null;
  const contentHash = usefulContentHash({
    title: refined.title,
    summary: refined.summary,
    sourceUrl,
  });

  if (
    isDuplicate(existing, {
      sourceUrl,
      contentHash,
      externalId,
    })
  ) {
    return false;
  }

  const row = {
    source_id: source.id,
    title: refined.title,
    summary: refined.summary,
    body: '',
    category: refined.category,
    city: refined.city,
    source_name: source.name,
    source_url: sourceUrl,
    external_id: externalId,
    content_hash: contentHash,
    status: 'pending_review',
    deadline_at: refined.deadlineAt,
    ai_notes: refined.aiNotes,
  };
  const imageUrl = String(raw.imageUrl || '').trim();
  if (imageUrl.startsWith('http')) row.image_url = imageUrl;

  try {
    await sb('useful_content', { method: 'POST', body: row });
  } catch (e) {
    const msg = String(e.message);
    if (msg.includes('23505') || msg.includes('409')) {
      console.log(`benzersiz kısıt, atlandı: ${sourceUrl}`);
      remember(existing, { sourceUrl, contentHash, externalId });
      return false;
    }
    if (row.image_url && (msg.includes('image_url') || msg.includes('PGRST204'))) {
      delete row.image_url;
      await sb('useful_content', { method: 'POST', body: row });
    } else {
      throw e;
    }
  }

  remember(existing, { sourceUrl, contentHash, externalId });
  console.log(`pending_review: ${refined.title}`);
  return true;
}

async function touchSource(source) {
  await sb(`content_sources?id=eq.${source.id}`, {
    method: 'PATCH',
    body: { last_fetched_at: new Date().toISOString() },
  });
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    throw new Error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.');
  }

  if (!AI_KEY) {
    console.warn('GEMINI_API_KEY / AI_API_KEY yok; yalnız anahtar kelime süzgeci.');
  }

  await markExpired();
  await rejectUnrelatedPending();
  const existing = await loadExistingKeys();
  const sources = await loadDueSources();
  console.log(`aktif kaynak: ${sources.length}`);

  let inserted = 0;
  for (const source of sources) {
    const method = String(source.method || 'rss').toLowerCase();
    if (TBB_INDEX_RE.test(source.url || '')) {
      console.warn(`TBB indeks atlandı (belediye listesi): ${source.name}`);
      await touchSource(source);
      continue;
    }
    if (method === 'api') {
      console.warn(`v1 api atlandı: ${source.name}`);
      await touchSource(source);
      continue;
    }
    if (method === 'scrape' && /bursa\.bel\.tr/i.test(source.url || '')) {
      console.warn(`Bursa genel HTML tarama atlandı: ${source.name}`);
      await touchSource(source);
      continue;
    }
    try {
      if (!(await originAllowsFetch(source.url))) {
        console.warn(`robots Disallow:/ atlandı: ${source.name}`);
        await touchSource(source);
        continue;
      }
      const items = await collectSourceItems(source, method);
      const cap = isAileEyhgmSourceUrl(source.url)
        ? MAX_ITEMS_AILE_EYHGM
        : method === 'scrape'
          ? MAX_ITEMS_SCRAPE
          : MAX_ITEMS_RSS;
      for (const item of items.slice(0, cap)) {
        if (await insertPending(existing, source, item)) inserted += 1;
      }
      await touchSource(source);
    } catch (e) {
      console.warn(`kaynak hata ${source.name}: ${e.message}`);
    }
    await sleep(SOURCE_DELAY_MS);
  }

  console.log(`eklenen pending_review: ${inserted}`);
}

async function collectAileEyhgm(source) {
  const pages = aileEyhgmListingUrls(source.url);
  const items = [];
  const seen = new Set();
  for (const pageUrl of pages) {
    const html = await fetchText(pageUrl, {
      maxBytes: AILE_EYHGM_HTML_MAX_BYTES,
      timeoutMs: 20000,
      accept: 'text/html, application/xhtml+xml, */*;q=0.5',
    });
    const listings = extractAileEyhgmListings(html, pageUrl, {
      limit: MAX_ITEMS_AILE_EYHGM,
    });
    for (const item of listings) {
      if (seen.has(item.sourceUrl)) continue;
      seen.add(item.sourceUrl);
      items.push({
        ...item,
        sourceName: source.name,
        sourceId: source.id,
      });
    }
    await sleep(200);
  }
  console.log(`eyhgm HTML liste: ${source.name} ${items.length}`);
  return items.slice(0, MAX_ITEMS_AILE_EYHGM);
}

async function collectSourceItems(source, method) {
  if (method === 'scrape' && isAileEyhgmSourceUrl(source.url)) {
    return collectAileEyhgm(source);
  }
  if (method === 'scrape') {
    const html = await fetchText(source.url, {
      maxBytes: HTML_MAX_BYTES,
      accept: 'text/html, application/xhtml+xml, */*;q=0.5',
    });
    if (!looksLikeHtml(html) && looksLikeRssOrAtom(html)) {
      return collectFromRss(source, html);
    }
    const discovered = await resolveRssFromHomepage(source.url, html);
    if (discovered) {
      console.log(`scrape→rss keşif: ${source.name} → ${discovered.url}`);
      return collectFromRss(source, discovered.xml);
    }
    const listings = extractDisabilityListings(html, source.url, {
      limit: MAX_ITEMS_SCRAPE,
    });
    console.log(`scrape aday (özel gereksinim başlık): ${source.name} ${listings.length}`);
    return listings.map((item) => ({
      ...item,
      sourceName: source.name,
      sourceId: source.id,
    }));
  }

  const body = await fetchText(source.url, { maxBytes: XML_MAX_BYTES });
  if (method === 'sitemap' || looksLikeSitemap(body)) {
    if (looksLikeSitemap(body)) return collectFromSitemap(source, body);
  }
  if (looksLikeRssOrAtom(body)) {
    return collectFromRss(source, body);
  }
  if (looksLikeHtml(body)) {
    const discovered = await resolveRssFromHomepage(source.url, body);
    if (discovered) {
      console.log(`html→rss keşif: ${source.name} → ${discovered.url}`);
      return collectFromRss(source, discovered.xml);
    }
    console.warn(`XML/RSS yok, HTML dökümü atlandı: ${source.name}`);
    return [];
  }
  console.warn(`beklenmeyen gövde, atlandı: ${source.name}`);
  return [];
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
