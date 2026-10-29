import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { autoApproveEnabled, loadScanConfig } from './lib/config.mjs';
import { addOrMerge, emptyIndex, isSeen } from './lib/dedupe.mjs';
import { enrichItem, normalizeEnrichment } from './lib/enrich.mjs';
import { passesKeywordFilter } from './lib/filter.mjs';
import { collectAll } from './lib/fetch_sources.mjs';
import { contentHash } from './lib/normalize.mjs';
import {
  loadExistingKeys,
  publishItem,
  supabaseConfig,
} from './lib/publish.mjs';
import { heuristicCategory } from './lib/route.mjs';
import { loadSeenFile, rememberSeen, writeSeenFile } from './lib/seen.mjs';

function argValue(flag, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`${flag}=`));
  if (hit) return hit.slice(flag.length + 1);
  const i = process.argv.indexOf(flag);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}

function log(msg) {
  console.log(`[CONTENT-SCAN] ${msg}`);
}

export async function runContentScan({ mode = 'news' } = {}) {
  const { sources, conditions, pipeline } = loadScanConfig();
  const { url, key } = supabaseConfig();
  if (!url || !key) {
    throw new Error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.');
  }

  const conditionIds = (conditions || []).map((c) => c.id);
  const maxLlm = Number(pipeline.max_llm_per_run || 60);
  const fuzzy = Number(pipeline.fuzzy_ratio || 0.85);
  const keep = Number(pipeline.seen_keep || 300);
  const autoOn = autoApproveEnabled(pipeline);

  log(`mode=${mode} auto_approve=${autoOn} max_llm=${maxLlm}`);

  const seen = loadSeenFile(keep);
  const existing = await loadExistingKeys(url, key);
  for (const u of existing.urls) seen.urls.add(u);
  for (const h of existing.hashes) seen.hashes.add(h);
  for (const t of existing.titles) seen.titles.add(t);

  const { items, stats } = await collectAll({
    mode,
    sources,
    conditions,
    pipeline,
    onStat: (s) => {
      if (s.error) log(`kaynak hata ${s.id}: ${s.error}`);
    },
  });

  let droppedFilter = 0;
  const filtered = [];
  for (const item of items) {
    if (!passesKeywordFilter(item, conditions)) {
      droppedFilter += 1;
      continue;
    }
    filtered.push(item);
  }

  const index = emptyIndex();
  let merged = 0;
  for (const item of filtered) {
    const r = addOrMerge(index, item, { fuzzy });
    if (r.merged) merged += 1;
  }

  const fresh = [];
  for (const rec of index.records) {
    rec.content_hash =
      rec.content_hash ||
      contentHash({ title: rec.title, url: rec.canonical_url, snippet: rec.raw_snippet });
    if (isSeen(seen, rec) || existing.urls.has(rec.canonical_url) || existing.hashes.has(rec.content_hash)) {
      continue;
    }
    fresh.push(rec);
  }

  const toLlm = fresh.slice(0, maxLlm);
  log(`çekilen=${items.length} filtre_atılan=${droppedFilter} birleşen=${merged} yeni=${fresh.length} llm=${toLlm.length}`);

  let inserted = 0;
  let enrichFail = 0;
  let published = { news_candidates: 0, useful_content: 0, scientific_researches: 0 };

  for (const item of toLlm) {
    let enrichFailed = false;
    let extra = {};
    try {
      extra = await enrichItem(item, {
        conditionIds,
        healthNote: pipeline.health_note,
      });
    } catch (e) {
      enrichFailed = true;
      enrichFail += 1;
      extra = normalizeEnrichment(
        { category: heuristicCategory(item), summary_tr: item.raw_snippet, confidence: 0.4 },
        item,
      );
      extra.enrich_failed = true;
      log(`LLM hata, pending+enrich_failed: ${String(e.message || e).slice(0, 120)}`);
    }
    const row = { ...item, ...extra, enrich_failed: enrichFailed || !!extra.enrich_failed };
    try {
      const res = await publishItem(url, key, row, sources, autoOn);
      if (res.ok) {
        inserted += 1;
        published[res.table] = (published[res.table] || 0) + 1;
        rememberSeen(seen, { url: row.canonical_url, hash: row.content_hash, title: row.title });
      }
    } catch (e) {
      log(`yazma hata: ${String(e.message || e).slice(0, 180)}`);
    }
  }

  writeSeenFile(seen, keep);

  const zero = stats.filter((s) => !s.error && s.fetched === 0).map((s) => s.id);
  const failed = stats.filter((s) => s.error);
  log('--- kaynak özeti ---');
  for (const s of stats) {
    log(`${s.id}: fetched=${s.fetched}${s.error ? ` err=${s.error}` : ''}`);
  }
  log(
    `eklenen pending: ${inserted} haber=${published.news_candidates || 0} firsat/destek=${published.useful_content || 0} bilim=${published.scientific_researches || 0} llm_hata=${enrichFail}`,
  );
  if (zero.length) log(`sağlık: 0 sonuç: ${zero.join(', ')}`);
  if (failed.length) log(`sağlık: hatalı kaynak: ${failed.map((s) => s.id).join(', ')}`);
  if (!inserted) log('değişiklik yok; commit yok.');
  return { inserted, stats, published, enrichFail, droppedFilter, fresh: fresh.length };
}

const thisFile = fileURLToPath(import.meta.url);
const invoked = process.argv[1] ? path.resolve(process.argv[1]) : '';
const isMain =
  invoked !== '' && path.normalize(invoked) === path.normalize(thisFile);
if (isMain || process.env.CONTENT_SCAN_RUN === '1') {
  const mode = argValue('--mode', 'news');
  runContentScan({ mode }).catch((e) => {
    console.error(`[CONTENT-SCAN] Fatal: ${e.message || e}`);
    process.exitCode = 1;
  });
}
