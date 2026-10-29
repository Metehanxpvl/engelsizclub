import { deadlineFlags } from './dates.mjs';
import { newsCategoryLabel, routeRecord, usefulRowCategory } from './route.mjs';
import { isTrustedHost } from './config.mjs';
import { hostOf } from './normalize.mjs';

export function supabaseConfig() {
  const url = String(process.env.SUPABASE_URL || '')
    .replace(/\/+$/, '')
    .replace('qycrkqwqrysypvqipqn', 'qycrkqwqrysypvqaipqn')
    .replace('ypvqipqn.supabase.co', 'ypvqaipqn.supabase.co');
  const key = String(process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  return { url, key };
}

function headers(key) {
  return {
    apikey: key,
    authorization: `Bearer ${key}`,
    'content-type': 'application/json',
    prefer: 'return=minimal',
  };
}

export async function sb(url, key, path, { method = 'GET', body } = {}) {
  const res = await fetch(`${url}/rest/v1/${path}`, {
    method,
    headers: headers(key),
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Supabase ${method} ${path}: ${res.status} ${text.slice(0, 400)}`);
  }
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

const OPTIONAL = [
  'ai_generated',
  'risk_flag',
  'confidence',
  'enrich_failed',
  'sources',
  'disability_type',
  'target_audience',
  'amount',
  'eligibility',
  'apply_url',
  'evidence_level',
  'ai_notes',
  'date_status',
  'content_kind',
  'image_url',
  'published_at',
];

async function insertWithOptional(url, key, table, row) {
  const payload = { ...row };
  try {
    await sb(url, key, table, { method: 'POST', body: payload });
    return true;
  } catch (e) {
    const msg = String(e.message || e);
    if (/duplicate|unique|23505|409/i.test(msg)) return false;
    if (/PGRST204/i.test(msg) || OPTIONAL.some((c) => msg.includes(c))) {
      for (const col of OPTIONAL) delete payload[col];
      try {
        await sb(url, key, table, { method: 'POST', body: payload });
        return true;
      } catch (e2) {
        const msg2 = String(e2.message || e2);
        if (/duplicate|unique|23505|409/i.test(msg2)) return false;
        throw e2;
      }
    }
    throw e;
  }
}

export function shouldAutoApprove(item, sources, pipelineOn) {
  if (!pipelineOn) return false;
  if (item.risk_flag) return false;
  if (Number(item.confidence) < 0.85) return false;
  const host = hostOf(item.apply_url || item.url);
  return isTrustedHost(host, sources, 'resmi');
}

export function newsRow(item, sources) {
  const score = Math.round((Number(item.confidence) || 0) * 100);
  const official = isTrustedHost(hostOf(item.url), sources, 'resmi');
  return {
    source_name: item.source || hostOf(item.url) || 'Kaynak',
    source_url: item.url,
    article_url: item.url,
    canonical_url: item.canonical_url,
    title: item.title,
    summary: item.summary_tr || item.raw_snippet || '',
    published_at: item.date,
    image_url: '',
    category: newsCategoryLabel(item),
    categories: [newsCategoryLabel(item)],
    relevance_score: Math.min(100, Math.max(0, score)),
    importance_level: official && score >= 85 ? 'high' : 'informational',
    ai_reason: item.enrich_failed
      ? 'enrich_failed'
      : `AI özeti · güven ${score}%${item.risk_flag ? ' · risk' : ''}`,
    affected_users: item.condition || [],
    content_hash: item.content_hash,
    title_fingerprint: item.title_fingerprint || '',
    duplicate_group_id: null,
    status: 'pending',
    ai_generated: true,
    risk_flag: !!item.risk_flag,
    confidence: Number(item.confidence) || 0,
    enrich_failed: !!item.enrich_failed,
    sources: item.sources || [],
  };
}

export function usefulRow(item, routed) {
  const flags = deadlineFlags(item.deadline);
  const status = flags.expired ? 'expired' : 'pending_review';
  return {
    title: item.title,
    summary: item.summary_tr || item.raw_snippet || '',
    body: '',
    category: usefulRowCategory(item, routed),
    city: item.city || 'Ulusal',
    source_name: item.source || hostOf(item.url) || 'Kaynak',
    source_url: item.apply_url || item.url,
    external_id: item.canonical_url || item.url,
    content_hash: item.content_hash,
    status,
    deadline_at: item.deadline ? `${item.deadline}T00:00:00Z` : null,
    expires_at: item.deadline ? `${item.deadline}T23:59:59Z` : null,
    ai_notes: item.enrich_failed ? 'enrich_failed' : 'AI özeti',
    published_at: item.date,
    date_status: item.date ? 'recent' : 'unknown',
    content_kind: flags.expired ? '' : 'active_opportunity',
    ai_generated: true,
    risk_flag: !!item.risk_flag,
    confidence: Number(item.confidence) || 0,
    enrich_failed: !!item.enrich_failed,
  };
}

function evidenceToPotential(level) {
  if (level === 'onayli-tedavi' || level === 'faz3') return 'HIGH_VALUE';
  return 'POTENTIAL_VALUE';
}

export function scienceRow(item) {
  return {
    title: item.title.slice(0, 400),
    original_title: item.title.slice(0, 400),
    summary: (item.summary_tr || item.raw_snippet || '').slice(0, 4000),
    why_important: 'Engelli bireyler ve aileler için araştırma özeti.',
    limitations:
      'Bilgilendirme amaçlıdır, karar için doktorunuza danışın. Kanıt düzeyi sınırlı olabilir.',
    conditions: item.condition || [],
    categories: ['bilim'],
    study_type: item.nct_id ? 'clinical_trial' : 'research',
    evidence_level: item.evidence_level || 'arastirma-asamasi',
    study_phase: item.evidence_level || null,
    human_or_animal: item.evidence_level === 'hayvan-deneyi' ? 'animal' : 'human',
    pediatric_relevance: '',
    relevance_score: Math.round((Number(item.confidence) || 0.5) * 100),
    scientific_importance_score: 50,
    treatment_potential_score: item.evidence_level === 'faz3' ? 70 : 40,
    clinical_readiness_score: item.evidence_level === 'onayli-tedavi' ? 80 : 30,
    treatment_potential: evidenceToPotential(item.evidence_level),
    recruitment_status: item.recruitment_status || null,
    publication_date: item.date ? String(item.date).slice(0, 10) : null,
    country: 'Turkey',
    journal: item.journal || '',
    doi: item.doi || null,
    pmid: item.pmid || null,
    nct_id: item.nct_id || null,
    source_name: item.source || 'Bilim',
    source_url: item.url,
    external_id: item.canonical_url || item.url,
    content_hash: item.content_hash,
    status: 'pending_review',
    ai_notes: item.enrich_failed ? 'enrich_failed' : 'AI özeti',
    ai_generated: true,
    risk_flag: !!item.risk_flag,
    confidence: Number(item.confidence) || 0,
    enrich_failed: !!item.enrich_failed,
  };
}

export function buildPayload(item, sources, autoOn) {
  const routed = routeRecord(item);
  if (routed.table === 'news_candidates') {
    return { table: routed.table, row: newsRow(item, sources), skip: false };
  }
  if (routed.table === 'useful_content') {
    const row = usefulRow(item, routed);
    if (shouldAutoApprove(item, sources, autoOn) && row.status === 'pending_review') {
      row.status = 'pending_review';
      row.ai_notes = `${row.ai_notes || ''}; auto_approve_eligible`.trim();
    }
    return { table: routed.table, row, skip: row.status === 'expired' };
  }
  return { table: routed.table, row: scienceRow(item), skip: false };
}

export async function publishItem(url, key, item, sources, autoOn) {
  const built = buildPayload(item, sources, autoOn);
  if (built.skip) return { ok: false, skipped: 'expired' };
  const ok = await insertWithOptional(url, key, built.table, built.row);
  return { ok, table: built.table, skipped: ok ? '' : 'duplicate' };
}

export async function loadExistingKeys(url, key) {
  const urls = new Set();
  const hashes = new Set();
  const titles = new Set();
  const tables = [
    ['news_candidates', 'canonical_url,content_hash,title'],
    ['useful_content', 'source_url,content_hash,title'],
    ['scientific_researches', 'source_url,content_hash,title'],
  ];
  for (const [table, cols] of tables) {
    let offset = 0;
    for (;;) {
      try {
        const rows =
          (await sb(
            url,
            key,
            `${table}?select=${cols}&order=created_at.desc&limit=500&offset=${offset}`,
          )) || [];
        if (!Array.isArray(rows) || !rows.length) break;
        for (const row of rows) {
          const u = String(row.canonical_url || row.source_url || '').trim();
          const h = String(row.content_hash || '').trim();
          const t = String(row.title || '').trim().toLowerCase();
          if (u) urls.add(u);
          if (h) hashes.add(h);
          if (t) titles.add(t);
        }
        if (rows.length < 500) break;
        offset += rows.length;
        if (offset > 4000) break;
      } catch {
        break;
      }
    }
  }
  return { urls, hashes, titles };
}
