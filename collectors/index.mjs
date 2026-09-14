import { classifyCandidate } from './lib/ai.mjs';
import {
  hasRelevanceKeyword,
  isDuplicate,
  stripHtml,
  usefulContentHash,
} from './lib/hash.mjs';
import {
  fetchText,
  isXmlUrl,
  parseRssOrAtom,
  parseSitemapLocs,
} from './lib/rss.mjs';

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
  const locs = parseSitemapLocs(xml).filter(isXmlUrl).slice(0, 8);
  const items = [];
  for (const loc of locs) {
    try {
      const nested = await fetchText(loc);
      items.push(...(await collectFromRss(source, nested)));
    } catch (e) {
      console.warn(`sitemap alt XML atlandı ${loc}: ${e.message}`);
    }
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
      return {
        title: stripHtml(ai.title || title).slice(0, 240) || title,
        summary: stripHtml(ai.summary || summary).slice(0, 1200),
        category: String(ai.category || 'diger').trim() || 'diger',
        city: stripHtml(ai.city || ''),
        deadlineAt: parseDeadline(ai.deadline),
        aiNotes: stripHtml(ai.notes || ''),
      };
    } catch (e) {
      console.warn(`AI hata, insert yok: ${title} — ${e.message}`);
      return null;
    }
  }

  const blob = `${title} ${summary}`;
  if (!hasRelevanceKeyword(blob)) {
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

  try {
    await sb('useful_content', { method: 'POST', body: row });
  } catch (e) {
    if (String(e.message).includes('23505') || String(e.message).includes('409')) {
      console.log(`benzersiz kısıt, atlandı: ${sourceUrl}`);
      remember(existing, { sourceUrl, contentHash, externalId });
      return false;
    }
    throw e;
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
  const existing = await loadExistingKeys();
  const sources = await loadDueSources();
  console.log(`aktif kaynak: ${sources.length}`);

  let inserted = 0;
  for (const source of sources) {
    const method = String(source.method || 'rss').toLowerCase();
    if (method === 'scrape' || method === 'api') {
      console.warn(`v1 ${method} atlandı: ${source.name}`);
      await touchSource(source);
      continue;
    }
    try {
      const xml = await fetchText(source.url);
      const items =
        method === 'sitemap'
          ? await collectFromSitemap(source, xml)
          : await collectFromRss(source, xml);
      for (const item of items.slice(0, 40)) {
        if (await insertPending(existing, source, item)) inserted += 1;
      }
      await touchSource(source);
    } catch (e) {
      console.warn(`kaynak hata ${source.name}: ${e.message}`);
    }
  }

  console.log(`eklenen pending_review: ${inserted}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
