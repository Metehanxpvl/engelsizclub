import { classifyCandidate } from './lib/ai.mjs';
import {
  classifyKeep,
  hasScholarshipTerm,
  isDuplicate,
  normalizeCategoryLabels,
  primaryCategory,
  shouldKeepCandidate,
  stripHtml,
  titleSourceFingerprint,
  usefulContentHash,
} from './lib/hash.mjs';
import { originAllowsFetch, resolveRssFromHomepage } from './lib/discover.mjs';
import { crawlMunicipality, withSourceGuard } from './lib/crawl.mjs';
import {
  aileEyhgmListingUrls,
  extractAileEyhgmListings,
  isAileEyhgmSourceUrl,
} from './lib/aile_eyhgm.mjs';
import {
  extractResmiGazeteListings,
  isResmiGazeteSourceUrl,
  resmiGazeteListingUrls,
} from './lib/resmi_gazete.mjs';
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
const MAX_ITEMS_SCRAPE = 30;
const MAX_SITEMAP_FEEDS = 8;
const SOURCE_DELAY_MS = 600;
const AILE_EYHGM_HTML_MAX_BYTES = 300_000;
const RESMI_GAZETE_HTML_MAX_BYTES = 300_000;
const XML_MAX_BYTES = 250_000;
const MAX_ITEMS_AILE_EYHGM = 20;
const MAX_ITEMS_RESMI_GAZETE = 20;
const EXISTING_PAGE = 1000;
const TBB_INDEX_RE =
  /tbb\.gov\.tr\/tr\/(buyuksehir-belediyeleri|il-belediyeleri|bagli-idareler)/i;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const AI_KEY = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '').trim();

function emptyStats(name) {
  return {
    name,
    found: 0,
    neu: 0,
    keyword: 0,
    aiReject: 0,
    aiFailFallback: 0,
    inserted: 0,
    error: '',
  };
}

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
  const urls = new Set();
  const hashes = new Set();
  const externalIds = new Set();
  const titleKeys = new Set();
  let offset = 0;
  for (;;) {
    const rows =
      (await sb(
        `useful_content?select=source_url,content_hash,external_id,title,source_name&limit=${EXISTING_PAGE}&offset=${offset}`,
      )) || [];
    if (!Array.isArray(rows) || !rows.length) break;
    for (const row of rows) {
      const url = String(row.source_url || '').trim();
      const hash = String(row.content_hash || '').trim();
      const ext = String(row.external_id || '').trim();
      if (url) urls.add(url);
      if (hash) hashes.add(hash);
      if (ext) externalIds.add(ext);
      const fp = titleSourceFingerprint(row.title, row.source_name);
      if (fp) titleKeys.add(fp);
    }
    if (rows.length < EXISTING_PAGE) break;
    offset += rows.length;
  }
  return { urls, hashes, externalIds, titleKeys };
}

function remember(existing, { sourceUrl, contentHash, externalId, title, sourceName }) {
  if (sourceUrl) existing.urls.add(sourceUrl);
  if (contentHash) existing.hashes.add(contentHash);
  if (externalId) existing.externalIds.add(externalId);
  const fp = titleSourceFingerprint(title, sourceName);
  if (fp && existing.titleKeys) existing.titleKeys.add(fp);
}

async function loadDueSources() {
  const rows =
    (await sb(
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
      'useful_content?status=eq.pending_review&select=id,title,summary,ai_notes',
    )) || [];
  let n = 0;
  for (const row of rows) {
    const blob = `${row.title || ''} ${row.summary || ''} ${row.ai_notes || ''}`;
    if (shouldKeepCandidate(blob)) continue;
    if (/potential_family_benefit/.test(String(row.ai_notes || ''))) continue;
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

function keywordRefined(title, summary, keep) {
  const blob = `${title} ${summary}`;
  const labels =
    keep === 'potential'
      ? hasScholarshipTerm(blob)
        ? ['burs']
        : ['sosyal_yardim', 'destek']
      : ['diger'];
  return {
    title,
    summary,
    category: primaryCategory(labels),
    city: '',
    deadlineAt: null,
    aiNotes:
      keep === 'potential' ? 'potential_family_benefit' : 'anahtar_kelime',
  };
}

async function refineItem(item, stats) {
  const title = stripHtml(item.title);
  const summary = stripHtml(item.summary).slice(0, 1200);
  if (!title || !item.sourceUrl) return null;

  const blob = `${title} ${summary}`;
  const keep = classifyKeep(blob);
  if (!keep) {
    console.log(`süzgeç elendi: ${title}`);
    return null;
  }
  stats.keyword += 1;

  if (AI_KEY) {
    try {
      const ai = await classifyCandidate(AI_KEY, {
        title,
        summary,
        sourceUrl: item.sourceUrl,
      });
      const aiDirect = ai.relevant === true || ai.relevant === 'true';
      const aiPotential =
        ai.potential_family_benefit === true ||
        ai.potential_family_benefit === 'true';
      const labels = normalizeCategoryLabels(
        Array.isArray(ai.categories) && ai.categories.length
          ? ai.categories
          : ai.category,
      );
      if (!aiDirect && !aiPotential) {
        stats.aiReject += 1;
        if (keep === 'direct' || keep === 'potential') {
          console.log(`AI hayır, kelime yedek pending: ${title}`);
          return keywordRefined(title, summary, keep);
        }
        return null;
      }
      const notes = [
        stripHtml(ai.notes || ''),
        keep === 'potential' || aiPotential ? 'potential_family_benefit' : '',
        `labels:${labels.join(',')}`,
      ]
        .filter(Boolean)
        .join('; ')
        .slice(0, 500);
      return {
        title: stripHtml(ai.title || title).slice(0, 240) || title,
        summary: stripHtml(ai.summary || summary).slice(0, 1200),
        category: primaryCategory(labels),
        city: stripHtml(ai.city || ''),
        deadlineAt: parseDeadline(ai.deadline),
        aiNotes: notes,
      };
    } catch (e) {
      stats.aiFailFallback += 1;
      console.warn(`AI hata, anahtar kelime yedek: ${title} — ${e.message}`);
      return keywordRefined(title, summary, keep);
    }
  }

  return keywordRefined(title, summary, keep);
}

async function insertPending(existing, source, raw, stats) {
  const refined = await refineItem(raw, stats);
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
      title: refined.title,
      sourceName: source.name,
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
      remember(existing, {
        sourceUrl,
        contentHash,
        externalId,
        title: refined.title,
        sourceName: source.name,
      });
      return false;
    }
    if (row.image_url && (msg.includes('image_url') || msg.includes('PGRST204'))) {
      delete row.image_url;
      await sb('useful_content', { method: 'POST', body: row });
    } else {
      throw e;
    }
  }

  remember(existing, {
    sourceUrl,
    contentHash,
    externalId,
    title: refined.title,
    sourceName: source.name,
  });
  console.log(`pending_review: ${refined.title}`);
  return true;
}

async function touchSource(source) {
  await sb(`content_sources?id=eq.${source.id}`, {
    method: 'PATCH',
    body: { last_fetched_at: new Date().toISOString() },
  });
}

function printSummary(allStats, inserted) {
  console.log('--- kaynak özeti ---');
  for (const s of allStats) {
    const err = s.error ? ` err=${s.error}` : '';
    console.log(
      `${s.name}: found=${s.found} new=${s.neu} keyword=${s.keyword} ai_reject=${s.aiReject} inserted=${s.inserted}${err}`,
    );
  }
  const tot = allStats.reduce(
    (a, s) => ({
      found: a.found + s.found,
      neu: a.neu + s.neu,
      keyword: a.keyword + s.keyword,
      aiReject: a.aiReject + s.aiReject,
      aiFailFallback: a.aiFailFallback + s.aiFailFallback,
      inserted: a.inserted + s.inserted,
      errors: a.errors + (s.error ? 1 : 0),
    }),
    {
      found: 0,
      neu: 0,
      keyword: 0,
      aiReject: 0,
      aiFailFallback: 0,
      inserted: 0,
      errors: 0,
    },
  );
  console.log(
    `TOPLAM found=${tot.found} new=${tot.neu} keyword=${tot.keyword} ai_reject=${tot.aiReject} ai_fail_yedek=${tot.aiFailFallback} inserted=${tot.inserted} kaynak_hata=${tot.errors}`,
  );
  console.log(`eklenen pending_review: ${inserted}`);
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
  const allStats = [];
  for (const source of sources) {
    const method = String(source.method || 'rss').toLowerCase();
    const stats = emptyStats(source.name);
    if (TBB_INDEX_RE.test(source.url || '')) {
      console.warn(`TBB indeks atlandı (belediye listesi): ${source.name}`);
      await touchSource(source);
      stats.error = 'tbb_index';
      allStats.push(stats);
      continue;
    }
    if (method === 'api') {
      console.warn(`v1 api atlandı: ${source.name}`);
      await touchSource(source);
      stats.error = 'api_skip';
      allStats.push(stats);
      continue;
    }
    const result = await withSourceGuard(source.name, async () => {
      if (method !== 'scrape' && !(await originAllowsFetch(source.url))) {
        console.warn(`robots Disallow:/ atlandı: ${source.name}`);
        await touchSource(source);
        return { items: [], found: 0, error: 'robots' };
      }
      const items = await collectSourceItems(source, method, existing);
      stats.found = items.length;
      const known = existing.urls;
      stats.neu = items.filter((it) => !known.has(String(it.sourceUrl || ''))).length;
      const cap = isAileEyhgmSourceUrl(source.url)
        ? MAX_ITEMS_AILE_EYHGM
        : isResmiGazeteSourceUrl(source.url)
          ? MAX_ITEMS_RESMI_GAZETE
          : method === 'scrape'
            ? MAX_ITEMS_SCRAPE
            : MAX_ITEMS_RSS;
      let n = 0;
      for (const item of items) {
        if (n >= cap) break;
        if (await insertPending(existing, source, item, stats)) {
          n += 1;
          inserted += 1;
        }
      }
      stats.inserted = n;
      await touchSource(source);
      return { items, found: items.length, error: null };
    });
    if (result?.error) {
      stats.error = result.error;
      console.warn(`kaynak hata ${source.name}: ${result.error}`);
    }
    allStats.push(stats);
    await sleep(SOURCE_DELAY_MS);
  }

  printSummary(allStats, inserted);
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

async function collectResmiGazete(source) {
  const pages = resmiGazeteListingUrls(source.url);
  const items = [];
  const seen = new Set();
  for (const pageUrl of pages) {
    const html = await fetchText(pageUrl, {
      maxBytes: RESMI_GAZETE_HTML_MAX_BYTES,
      timeoutMs: 20000,
      accept: 'text/html, application/xhtml+xml, */*;q=0.5',
    });
    const listings = extractResmiGazeteListings(html, pageUrl, {
      limit: MAX_ITEMS_RESMI_GAZETE,
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
  console.log(`resmi gazete fihrist: ${source.name} ${items.length}`);
  return items.slice(0, MAX_ITEMS_RESMI_GAZETE);
}

async function collectSourceItems(source, method, existing) {
  if (method === 'scrape' && isAileEyhgmSourceUrl(source.url)) {
    return collectAileEyhgm(source);
  }
  if (method === 'scrape' && isResmiGazeteSourceUrl(source.url)) {
    return collectResmiGazete(source);
  }
  if (method === 'scrape') {
    const crawled = await crawlMunicipality(source, {
      fetchText,
      existingUrls: existing?.urls || new Set(),
      lastFetchedAt: source.last_fetched_at || null,
    });
    if (crawled.error) {
      console.warn(`scrape ${source.name}: ${crawled.error}`);
    }
    console.log(
      `scrape tarama: ${source.name} listing=${crawled.listingCount ?? 0} aday=${crawled.found}`,
    );
    if (crawled.error && !(crawled.items && crawled.items.length)) {
      throw new Error(crawled.error);
    }
    return crawled.items || [];
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
    const crawled = await crawlMunicipality(source, {
      fetchText,
      existingUrls: existing?.urls || new Set(),
      lastFetchedAt: source.last_fetched_at || null,
    });
    console.log(`html→tarama: ${source.name} aday=${crawled.found}`);
    return crawled.items || [];
  }
  console.warn(`beklenmeyen gövde, atlandı: ${source.name}`);
  return [];
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
