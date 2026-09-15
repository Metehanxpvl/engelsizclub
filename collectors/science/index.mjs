import { pathToFileURL } from 'node:url';
import {
  TITLE_TR_FALLBACK,
  WORKFLOW_BUDGET_MS,
  backfillSourceItem,
  backfillUpdatePayload,
  forceTurkishPrimary,
  heuristicPendingScore,
  lastGeminiHttpStatus,
  looksEnglishTitle,
  needsTurkishBackfill,
  runSerialTranslateQueue,
  scoreResearch,
  selectBackfillRows,
  titleTranslateOutcome,
  translateResearchCopy,
  withinBudget,
} from './ai.mjs';
import { fetchClinicalTrials } from './clinicaltrials.mjs';
import {
  EMPTY_SOURCES_SQL_HINT,
  TABLES_SQL_HINT,
  fallbackSources,
  loadConditions,
  sleep,
} from './config.mjs';
import {
  prefilterKeep,
  promoteKeepTopicPotential,
  shouldInsertResearch,
} from './filter.mjs';
import {
  isDuplicate,
  remember,
  researchContentHash,
} from './hash.mjs';
import { fetchPubmed } from './pubmed.mjs';
import { buildInsertRow } from './row.mjs';

const EXISTING_PAGE = 1000;
const AI_DELAY_MS = 2000;
const BACKFILL_PAGE = 200;
const TRANSLATE_BUDGET_MS = WORKFLOW_BUDGET_MS;

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const AI_KEY = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '').trim();
const NCBI_KEY = (process.env.NCBI_API_KEY || '').trim();

function emptyStats() {
  return {
    sources: 0,
    found: 0,
    neu: 0,
    dupes: 0,
    prefilter: 0,
    ai: 0,
    high: 0,
    potential: 0,
    irrelevant: 0,
    saved: 0,
    errors: 0,
    aiFail: 0,
    translatedBackfill: 0,
    englishLeft: 0,
    lastHttpStatus: null,
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

function isMissingTableError(err) {
  const msg = String(err?.message || err || '');
  return (
    /scientific_(sources|researches)/i.test(msg) &&
    (/does not exist/i.test(msg) ||
      /schema cache/i.test(msg) ||
      /PGRST205/i.test(msg) ||
      /404/.test(msg) ||
      /42P01/.test(msg))
  );
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
    const err = new Error(`Supabase ${method} ${path}: ${res.status} ${text}`);
    if (isMissingTableError(err)) {
      console.error(TABLES_SQL_HINT);
    }
    throw err;
  }
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function loadExistingKeys() {
  const existing = {
    pmids: new Set(),
    ncts: new Set(),
    dois: new Set(),
    urls: new Set(),
    hashes: new Set(),
  };
  let offset = 0;
  for (;;) {
    const rows =
      (await sb(
        `scientific_researches?select=pmid,nct_id,doi,source_url,content_hash&limit=${EXISTING_PAGE}&offset=${offset}`,
      )) || [];
    if (!Array.isArray(rows) || !rows.length) break;
    for (const row of rows) {
      remember(existing, {
        pmid: row.pmid,
        nctId: row.nct_id,
        doi: row.doi,
        sourceUrl: row.source_url,
        contentHash: row.content_hash,
      });
    }
    if (rows.length < EXISTING_PAGE) break;
    offset += rows.length;
  }
  return existing;
}

async function loadActiveSources() {
  let rows;
  try {
    rows =
      (await sb(
        'scientific_sources?select=id,name,url,method,query,is_active,fetch_interval_hours,last_fetched_at',
      )) || [];
  } catch (e) {
    if (isMissingTableError(e)) {
      console.error(TABLES_SQL_HINT);
    }
    throw e;
  }
  const all = Array.isArray(rows) ? rows : [];
  const active = all.filter(
    (s) => s.is_active === true || s.is_active === 'true',
  );
  console.log(`scientific_sources rows=${all.length} active=${active.length}`);
  if (!active.length) {
    console.error(EMPTY_SOURCES_SQL_HINT);
    return fallbackSources();
  }
  return active;
}

async function touchSource(source) {
  if (!source?.id) return;
  await sb(`scientific_sources?id=eq.${source.id}`, {
    method: 'PATCH',
    body: { last_fetched_at: new Date().toISOString() },
  });
}

function sourceKind(source) {
  const blob = `${source.name || ''} ${source.url || ''}`.toLowerCase();
  if (blob.includes('clinicaltrials')) return 'clinicaltrials';
  if (blob.includes('pubmed') || blob.includes('ncbi') || blob.includes('eutils')) {
    return 'pubmed';
  }
  return String(source.method || 'api').toLowerCase();
}

async function collectItems(source, config) {
  const kind = sourceKind(source);
  if (kind === 'pubmed') {
    return fetchPubmed(source, { config, apiKey: NCBI_KEY });
  }
  if (kind === 'clinicaltrials') {
    return fetchClinicalTrials(source, { config });
  }
  if (kind === 'rss') {
    console.warn(`rss atlandı (Phase A API only): ${source.name}`);
    return [];
  }
  console.warn(`bilinmeyen kaynak atlandı: ${source.name}`);
  return [];
}

async function insertPending(row) {
  try {
    const created = await sb('scientific_researches', { method: 'POST', body: row });
    const rec = Array.isArray(created) ? created[0] : created;
    return rec || true;
  } catch (e) {
    const msg = String(e.message);
    if (msg.includes('23505') || msg.includes('409')) {
      console.log(`benzersiz kısıt, atlandı: ${row.source_url || row.pmid || row.nct_id}`);
      return false;
    }
    throw e;
  }
}

function printSummary(stats) {
  console.log('--- bilimsel araştırma özeti ---');
  console.log(
    `sources=${stats.sources} new=${stats.neu} dupes=${stats.dupes} prefilter=${stats.prefilter} AI=${stats.ai} high=${stats.high} potential=${stats.potential} irrelevant=${stats.irrelevant} saved=${stats.saved} errors=${stats.errors} ai_fail_skip=${stats.aiFail} translated_count=${stats.translatedBackfill} english_remaining=${stats.englishLeft} last_http_status=${stats.lastHttpStatus ?? 'none'}`,
  );
}

async function loadBackfillPage(status, offset) {
  try {
    return (
      (await sb(
        `scientific_researches?status=eq.${status}&select=id,title,original_title,summary,why_important,limitations,status&limit=${BACKFILL_PAGE}&offset=${offset}&order=created_at.desc`,
      )) || []
    );
  } catch {
    return (
      (await sb(
        `scientific_researches?status=eq.${status}&select=id,title,original_title,summary,why_important,limitations,status&limit=${BACKFILL_PAGE}&offset=${offset}`,
      )) || []
    );
  }
}

async function loadAllEnglishRows() {
  const english = [];
  for (const status of ['pending_review', 'published']) {
    let offset = 0;
    for (;;) {
      const rows = await loadBackfillPage(status, offset);
      if (!Array.isArray(rows) || !rows.length) break;
      english.push(...selectBackfillRows(rows));
      if (rows.length < BACKFILL_PAGE) break;
      offset += rows.length;
    }
  }
  return english;
}

function logTitleOutcome(kind, id, title) {
  const outcome = titleTranslateOutcome(title);
  const line = `${outcome}: ${kind} ${id} ${String(title || '').slice(0, 120)}`;
  if (outcome === 'english_left') console.warn(line);
  else console.log(line);
  return outcome;
}

function leftoverFromRow(row, item) {
  if (!row?.id) return null;
  return {
    id: row.id,
    title: row.title,
    original_title:
      row.original_title || item?.originalTitle || item?.title || row.title,
    summary: row.summary,
    why_important: row.why_important,
    limitations: row.limitations,
    status: row.status || 'pending_review',
    conditions: row.conditions,
    categories: row.categories,
  };
}

async function translateAndPatchRow(row) {
  const item = backfillSourceItem(row);
  const copy = forceTurkishPrimary(
    await translateResearchCopy(AI_KEY, item),
    item,
  );
  const outcome = logTitleOutcome('backfill', row.id, copy.title);
  if (outcome === 'english_left') {
    const err = new Error('still English after translate');
    err.status = lastGeminiHttpStatus();
    throw err;
  }
  await sb(`scientific_researches?id=eq.${row.id}`, {
    method: 'PATCH',
    body: backfillUpdatePayload(row, copy),
  });
  return copy;
}

async function backfillEnglishRows({
  startedAt = Date.now(),
  leftover = [],
} = {}) {
  if (!AI_KEY) {
    console.warn('AI anahtarı yok; İngilizce başlık backfill atlandı.');
    console.log('translated_count=0 english_remaining=0 last_http_status=none');
    return { translated: 0, englishLeft: 0, lastHttpStatus: null };
  }

  let translated = 0;
  let lastHttpStatus = lastGeminiHttpStatus();
  let pending = leftover.filter((row) => row?.id);

  while (withinBudget(startedAt, Date.now(), TRANSLATE_BUDGET_MS)) {
    const fromDb = await loadAllEnglishRows();
    const byId = new Map();
    for (const row of pending) {
      if (row?.id) byId.set(row.id, row);
    }
    for (const row of fromDb) {
      if (row?.id) byId.set(row.id, row);
    }
    const queue = [...byId.values()];
    pending = [];
    console.log(`backfill queue=${queue.length} (all English pending_review+published pages)`);
    if (!queue.length) break;

    const result = await runSerialTranslateQueue(queue, translateAndPatchRow, {
      startedAt,
      budgetMs: TRANSLATE_BUDGET_MS,
      sleepFn: sleep,
    });
    translated += result.translated;
    lastHttpStatus = result.lastHttpStatus ?? lastHttpStatus;
    pending = result.leftover;
    if (!pending.length) break;
    if (result.translated === 0) break;
  }

  const remaining = (await loadAllEnglishRows()).length;
  lastHttpStatus = lastGeminiHttpStatus() ?? lastHttpStatus;
  console.log(
    `translated_count=${translated} english_remaining=${remaining} last_http_status=${lastHttpStatus ?? 'none'}`,
  );
  return { translated, englishLeft: remaining, lastHttpStatus };
}

async function processItem(item, source, existing, stats, leftover, startedAt) {
  const contentHash = researchContentHash({
    title: item.title,
    pmid: item.pmid,
    nctId: item.nctId,
    doi: item.doi,
    sourceUrl: item.sourceUrl,
  });
  if (
    isDuplicate(existing, {
      pmid: item.pmid,
      nctId: item.nctId,
      doi: item.doi,
      sourceUrl: item.sourceUrl,
      contentHash,
    })
  ) {
    stats.dupes += 1;
    return;
  }
  stats.neu += 1;

  if (!prefilterKeep(item)) {
    stats.prefilter += 1;
    return;
  }

  let ai;
  let needsLeftover = false;
  if (!AI_KEY) {
    console.warn(`AI anahtarı yok, Türkçe yedek POTENTIAL_VALUE: ${item.title}`);
    ai = heuristicPendingScore(item);
    stats.aiFail += 1;
    needsLeftover = true;
  } else if (!withinBudget(startedAt, Date.now(), TRANSLATE_BUDGET_MS)) {
    ai = heuristicPendingScore(item);
    stats.aiFail += 1;
    needsLeftover = true;
  } else {
    try {
      ai = await scoreResearch(AI_KEY, item);
      stats.ai += 1;
    } catch (e) {
      stats.aiFail += 1;
      stats.lastHttpStatus = e.status ?? lastGeminiHttpStatus() ?? stats.lastHttpStatus;
      console.warn(`AI hata, Türkçe yedek POTENTIAL_VALUE: ${item.title} — ${e.message}`);
      ai = heuristicPendingScore(item);
      needsLeftover = true;
    }
    if (looksEnglishTitle(ai.title) || ai.title === TITLE_TR_FALLBACK) {
      try {
        const copy = await translateResearchCopy(AI_KEY, item);
        ai = { ...ai, ...copy };
      } catch (e) {
        stats.lastHttpStatus = e.status ?? lastGeminiHttpStatus() ?? stats.lastHttpStatus;
        console.warn(`translate-only hata: ${item.title} — ${e.message}`);
        needsLeftover = true;
      }
    }
  }
  ai = forceTurkishPrimary(ai, item);

  const promoted = promoteKeepTopicPotential(item, ai.treatment_potential);
  if (promoted !== ai.treatment_potential) {
    ai = {
      ...ai,
      treatment_potential: promoted,
      ai_notes: `${ai.ai_notes || ''} | keep-topic override ${promoted}`.trim(),
    };
  }

  if (ai.treatment_potential === 'HIGH_VALUE') stats.high += 1;
  else if (ai.treatment_potential === 'POTENTIAL_VALUE') stats.potential += 1;
  else stats.irrelevant += 1;

  if (!shouldInsertResearch(ai.treatment_potential)) {
    console.log(`IRRELEVANT insert yok: ${item.title}`);
    remember(existing, {
      pmid: item.pmid,
      nctId: item.nctId,
      doi: item.doi,
      sourceUrl: item.sourceUrl,
      contentHash,
    });
    return;
  }

  const row = buildInsertRow(item, ai, source, contentHash);
  if (looksEnglishTitle(row.title)) {
    row.title = TITLE_TR_FALLBACK;
    needsLeftover = true;
  }
  const outcome = logTitleOutcome('insert', item.pmid || item.nctId || item.sourceUrl, row.title);
  if (outcome === 'english_left' || row.title === TITLE_TR_FALLBACK) {
    needsLeftover = true;
  }
  const created = await insertPending(row);
  if (created) {
    stats.saved += 1;
    remember(existing, {
      pmid: item.pmid,
      nctId: item.nctId,
      doi: item.doi,
      sourceUrl: item.sourceUrl,
      contentHash,
    });
    console.log(`pending_review ${ai.treatment_potential}: ${row.title}`);
    if (needsLeftover || needsTurkishBackfill({ ...row, ...(created.id ? created : {}), status: 'pending_review' })) {
      const queued = leftoverFromRow(
        {
          ...row,
          ...(created && created !== true ? created : {}),
          status: 'pending_review',
        },
        item,
      );
      if (queued) leftover.push(queued);
    }
  }
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    throw new Error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.');
  }
  if (!AI_KEY) {
    console.warn('GEMINI_API_KEY / AI_API_KEY yok; Türkçe yedek başlık + POTENTIAL_VALUE pending_review yazılır.');
  }

  const config = loadConditions();
  const existing = await loadExistingKeys();
  const stats = emptyStats();
  const startedAt = Date.now();
  const leftover = [];
  const firstPass = await backfillEnglishRows({ startedAt, leftover });
  stats.translatedBackfill += firstPass.translated;
  stats.lastHttpStatus = firstPass.lastHttpStatus ?? stats.lastHttpStatus;
  const sources = await loadActiveSources();
  stats.sources = sources.length;
  console.log(`aktif kaynak: ${sources.length}`);

  for (const source of sources) {
    try {
      const items = await collectItems(source, config);
      stats.found += items.length;
      console.log(`${source.name}: found=${items.length}`);
      for (const item of items) {
        if (!item?.title || !item.sourceUrl) continue;
        await processItem(item, source, existing, stats, leftover, startedAt);
        if (AI_KEY) await sleep(AI_DELAY_MS);
      }
      await touchSource(source);
    } catch (e) {
      stats.errors += 1;
      console.warn(`kaynak hata ${source.name}: ${e.message}`);
      if (isMissingTableError(e)) throw e;
    }
  }

  const leftoverPass = await backfillEnglishRows({ startedAt, leftover });
  stats.translatedBackfill += leftoverPass.translated;
  stats.englishLeft = leftoverPass.englishLeft;
  stats.lastHttpStatus =
    leftoverPass.lastHttpStatus ?? lastGeminiHttpStatus() ?? stats.lastHttpStatus;
  console.log(
    `translated_count=${stats.translatedBackfill} english_remaining=${stats.englishLeft} last_http_status=${stats.lastHttpStatus ?? 'none'}`,
  );

  printSummary(stats);
  if (stats.found === 0) {
    console.error(
      'found=0. SQL seed (scientific_sources) çalıştı mı? PubMed/ClinicalTrials hatalarına bakın. ' +
        'supabase/scientific_researches.sql → SQL Editor → Run, sonra workflow\'u main\'de tekrar çalıştırın.',
    );
  }
  if (stats.saved === 0 && stats.found > 0) {
    console.error(
      `saved=0 (found=${stats.found} prefilter=${stats.prefilter} irrelevant=${stats.irrelevant} ai_fail=${stats.aiFail}).`,
    );
  }
}

function isEntry() {
  try {
    const entry = process.argv[1];
    if (!entry) return false;
    return import.meta.url === pathToFileURL(entry).href;
  } catch {
    return false;
  }
}

if (isEntry()) {
  main().catch((e) => {
    console.error(e);
    if (isMissingTableError(e)) console.error(TABLES_SQL_HINT);
    process.exit(1);
  });
}

export {
  BACKFILL_PAGE,
  TRANSLATE_BUDGET_MS,
  main,
  shouldInsertResearch,
  TABLES_SQL_HINT,
  buildInsertRow,
};
