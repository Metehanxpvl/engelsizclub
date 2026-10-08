import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { analyzeNewsItem } from './ai-analyzer.mjs';
import {
  emptyExisting,
  contentHash,
  isNearDuplicate,
  normalizeUrl,
  remember,
  titleFingerprint,
} from './duplicate.mjs';
import {
  loadExistingCandidates,
  loadLastOkRun,
  insertCandidate,
  insertScanRun,
  supabaseConfig,
} from './database.mjs';
import { fetchText, looksLikeRssOrAtom } from './fetcher.mjs';
import { passesKeywordFilter } from './filter.mjs';
import { isWithinWindow, lookbackSinceMs, parseRssOrAtom } from './parser.mjs';
import { enabledSources } from './sources.mjs';

const MAX_PER_SOURCE = 40;
const MAX_AI = 20;
const SOURCE_DELAY_MS = 400;

function log(msg) {
  console.log(`[NEWS-SCAN] ${msg}`);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function existingFromRows(rows) {
  const existing = emptyExisting();
  for (const row of rows) {
    remember(existing, {
      id: row.id,
      canonicalUrl: row.canonical_url,
      contentHash: row.content_hash,
      title: row.title,
      duplicateGroupId: row.duplicate_group_id || row.id,
    });
  }
  return existing;
}

async function scanSource(source, sinceMs) {
  const xml = await fetchText(source.rss_url);
  if (!looksLikeRssOrAtom(xml)) {
    throw new Error('RSS/Atom değil');
  }
  const parsed = parseRssOrAtom(xml).slice(0, MAX_PER_SOURCE);
  const dated = parsed.filter((e) => isWithinWindow(e.publishedAt, sinceMs));
  return { parsed: parsed.length, dated };
}

export async function runNewsScan({ nowMs = Date.now() } = {}) {
  log('Starting');
  const { url, key } = supabaseConfig();
  const aiKey = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '').trim();
  if (!url || !key) {
    throw new Error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.');
  }
  if (!aiKey) {
    throw new Error('GEMINI_API_KEY (veya AI_API_KEY) gerekli.');
  }

  const lastOk = await loadLastOkRun(url, key);
  const sinceMs = lookbackSinceMs(lastOk, nowMs);
  log(`Window since ${new Date(sinceMs).toISOString()} (last ok: ${lastOk || 'none'})`);

  const existing = existingFromRows(await loadExistingCandidates(url, key));
  const sources = enabledSources();
  const stats = {
    sources_scanned: 0,
    sources_failed: 0,
    articles_discovered: 0,
    after_date: 0,
    after_keyword: 0,
    after_duplicate: 0,
    ai_relevant: 0,
    inserted: 0,
    duplicates_skipped: 0,
    ai_skipped_json: 0,
    failed_sources: [],
  };

  const keywordHits = [];
  for (const source of sources) {
    stats.sources_scanned += 1;
    log(`Source: ${source.source_name}`);
    try {
      const { parsed, dated } = await scanSource(source, sinceMs);
      stats.articles_discovered += parsed;
      stats.after_date += dated.length;
      log(`Found: ${parsed}  in-window: ${dated.length}`);
      let kept = 0;
      for (const item of dated) {
        if (!passesKeywordFilter(item)) continue;
        kept += 1;
        keywordHits.push({
          source_name: source.source_name,
          source_url: source.source_url,
          ...item,
        });
      }
      log(`After filter: ${kept}`);
    } catch (e) {
      stats.sources_failed += 1;
      stats.failed_sources.push(source.source_name);
      log(`FAIL ${source.source_name}: ${e.message || e}`);
    }
    await sleep(SOURCE_DELAY_MS);
  }
  stats.after_keyword = keywordHits.length;

  const unique = [];
  for (const item of keywordHits) {
    const canonicalUrl = normalizeUrl(item.articleUrl);
    const hash = contentHash({
      title: item.title,
      canonicalUrl,
      summary: item.summary,
    });
    const dup = isNearDuplicate(existing, {
      canonicalUrl,
      contentHash: hash,
      title: item.title,
    });
    if (dup.hit) {
      stats.duplicates_skipped += 1;
      continue;
    }
    const row = {
      ...item,
      canonicalUrl,
      contentHash: hash,
      titleFingerprint: titleFingerprint(item.title),
    };
    remember(existing, {
      canonicalUrl,
      contentHash: hash,
      title: item.title,
      duplicateGroupId: null,
    });
    unique.push(row);
  }
  stats.after_duplicate = unique.length;

  const toAi = unique.slice(0, MAX_AI);
  if (unique.length > MAX_AI) {
    log(`AI cap ${MAX_AI}/${unique.length}`);
  }

  for (const item of toAi) {
    let ai;
    try {
      ai = await analyzeNewsItem(aiKey, {
        source_name: item.source_name,
        published_at: item.publishedAt,
        article_url: item.articleUrl,
        title: item.title,
        summary: item.summary,
      });
    } catch (e) {
      stats.ai_skipped_json += 1;
      log(`AI skip: ${e.message || e}`);
      continue;
    }
    if (!ai.is_relevant || ai.importance_level === 'drop' || ai.relevance_score < 50) {
      continue;
    }
    stats.ai_relevant += 1;
    const payload = {
      source_name: item.source_name,
      source_url: item.source_url,
      article_url: item.articleUrl,
      canonical_url: item.canonicalUrl,
      title: ai.title || item.title,
      summary: ai.summary || item.summary,
      published_at: item.publishedAt,
      image_url: item.imageUrl || '',
      category: ai.category,
      categories: ai.categories,
      relevance_score: ai.relevance_score,
      importance_level: ai.importance_level,
      ai_reason: ai.reason,
      affected_users: ai.affected_users,
      content_hash: item.contentHash,
      title_fingerprint: item.titleFingerprint,
      duplicate_group_id: null,
      status: 'pending',
    };
    try {
      const inserted = await insertCandidate(url, key, payload);
      const id = Array.isArray(inserted) ? inserted[0]?.id : inserted?.id;
      if (id) {
        remember(existing, {
          id,
          canonicalUrl: item.canonicalUrl,
          contentHash: item.contentHash,
          title: payload.title,
          duplicateGroupId: id,
        });
      }
      stats.inserted += 1;
      log(`Inserted: ${payload.title.slice(0, 80)}`);
    } catch (e) {
      const msg = String(e.message || e);
      if (/duplicate|unique|23505/i.test(msg)) {
        stats.duplicates_skipped += 1;
        log('Duplicate skipped (db unique)');
      } else {
        log(`Insert fail: ${msg.slice(0, 200)}`);
      }
    }
  }

  await insertScanRun(url, key, {
    started_at: new Date(nowMs).toISOString(),
    finished_at: new Date().toISOString(),
    ok: true,
    stats,
  });

  log(`Sources scanned: ${stats.sources_scanned}`);
  log(`Sources failed: ${stats.sources_failed}${stats.failed_sources.length ? ` (${stats.failed_sources.join(', ')})` : ''}`);
  log(`Articles discovered: ${stats.articles_discovered}`);
  log(`After keyword filter: ${stats.after_keyword}`);
  log(`After duplicate filter: ${stats.after_duplicate}`);
  log(`AI relevant: ${stats.ai_relevant}`);
  log(`Inserted as pending: ${stats.inserted}`);
  log(`Duplicates skipped: ${stats.duplicates_skipped}`);
  return stats;
}

const thisFile = fileURLToPath(import.meta.url);
const invoked = process.argv[1] ? path.resolve(process.argv[1]) : '';
const isMain =
  invoked !== '' && path.normalize(invoked) === path.normalize(thisFile);
if (isMain || process.env.NEWS_SCAN_RUN === '1') {
  runNewsScan().catch((e) => {
    console.error(`[NEWS-SCAN] Fatal: ${e.message || e}`);
    process.exitCode = 1;
  });
}
