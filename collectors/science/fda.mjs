import { createHash } from 'node:crypto';
import { loadConditions, sleep } from './config.mjs';
import { foldTr } from './hash.mjs';
import { parseFlexibleDate } from './dates.mjs';
import { TITLE_TR_FALLBACK } from './ai.mjs';

export const FDA_DRUGSFDA_API = 'https://api.fda.gov/drug/drugsfda.json';
export const FDA_LABEL_API = 'https://api.fda.gov/drug/label.json';
export const FDA_SOURCE_NAME = 'FDA';

const EMAIL = 'sakir.caykara@gmail.com';
const PAGE_LIMIT = 25;

const KEEP_MARKETING =
  /prescription|over-the-counter|\botc\b|tentative/i;
const DROP_MARKETING = /discontinued/i;

const NEGATION_NEAR =
  /not (been )?(found )?effective|not indicated|not recommended|contraindicat|have not been found|is not (indicated|recommended|effective)/i;

export function fdaApplDigits(applicationNumber) {
  const raw = String(applicationNumber || '').toUpperCase().replace(/\s+/g, '');
  const m = raw.match(/^(?:NDA|ANDA|BLA)?(\d{1,6})$/);
  if (!m) return '';
  return m[1].padStart(6, '0');
}

/** Official Drugs@FDA overview page (not a blog). */
export function fdaSourceUrl(applicationNumber) {
  const digits = fdaApplDigits(applicationNumber);
  if (!digits) return 'https://www.accessdata.fda.gov/scripts/cder/daf/';
  return `https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?event=overview.process&ApplNo=${digits}`;
}

export function fdaContentHash(applicationNumber, genericName) {
  const appl = String(applicationNumber || '').replace(/\s+/g, '').toUpperCase();
  const gen = foldTr(genericName);
  return createHash('sha256').update(`fda|${appl}|${gen}`, 'utf8').digest('hex');
}

export function listConditionDefs(config = loadConditions()) {
  return Array.isArray(config.conditions) ? config.conditions : [];
}

export function mapTextToConditions(text, config = loadConditions()) {
  const hay = foldTr(text);
  if (!hay) return [];
  const out = [];
  const seen = new Set();
  for (const def of listConditionDefs(config)) {
    const aliases = [
      def.id,
      def.label_tr,
      def.label_en,
      ...(Array.isArray(def.aliases) ? def.aliases : []),
    ];
    for (const alias of aliases) {
      const a = foldTr(alias);
      if (!a || a.length < 3) continue;
      if (!hay.includes(a)) continue;
      if (isNegatedAlias(hay, a)) continue;
      const label = String(def.label_tr || def.label_en || def.id).trim();
      if (!label || seen.has(foldTr(label))) continue;
      seen.add(foldTr(label));
      out.push(label);
      break;
    }
  }
  return out;
}

function isNegatedAlias(hay, alias) {
  const idx = hay.indexOf(alias);
  if (idx < 0) return false;
  const window = hay.slice(Math.max(0, idx - 90), idx + alias.length + 50);
  return NEGATION_NEAR.test(window);
}

export function classifyFdaStatus({ marketingStatuses = [], submissions = [] } = {}) {
  const markets = (marketingStatuses || []).map((s) => String(s || ''));
  const subs = Array.isArray(submissions) ? submissions : [];
  const codes = subs.map((s) => String(s?.submission_status || '').toUpperCase());
  const types = subs.map((s) => String(s?.submission_type || '').toUpperCase());
  const classCodes = subs.map((s) =>
    `${s?.submission_class_code || ''} ${s?.submission_class_code_description || ''}`.toUpperCase(),
  );
  const liveMarket = markets.some(
    (m) => KEEP_MARKETING.test(m) && !DROP_MARKETING.test(m) && !/tentative/i.test(m),
  );

  if (liveMarket || codes.includes('AP')) {
    return 'approved';
  }
  if (markets.some((m) => /tentative/i.test(m)) || codes.includes('TA')) {
    return 'tentatively_approved';
  }
  const reviewHint = [...codes, ...types, ...classCodes].join(' ');
  if (
    /\b(PENDING|UNDER[- ]?REVIEW|FILED|IN[- ]?REVIEW)\b/.test(reviewHint) ||
    (/\b(NDA|BLA)\b/.test(reviewHint) && !codes.includes('AP') && !codes.includes('TA'))
  ) {
    return 'in_review';
  }
  if (types.includes('ORIG') && !codes.includes('AP') && !codes.includes('TA')) {
    return 'in_review';
  }
  return '';
}

export function keepFdaStatus(status) {
  return (
    status === 'approved' ||
    status === 'tentatively_approved' ||
    status === 'in_review'
  );
}

export function fdaStatusTr(status) {
  if (status === 'approved') return 'onaylandı';
  if (status === 'tentatively_approved') return 'geçici onay';
  if (status === 'in_review') return 'incelemede (NDA/BLA)';
  return 'durumu belirsiz';
}

function uniqueStrings(list) {
  const seen = new Set();
  const out = [];
  for (const x of list || []) {
    const s = String(x || '').trim();
    if (!s) continue;
    const k = foldTr(s);
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(s);
  }
  return out;
}

function asList(v) {
  if (v == null) return [];
  if (Array.isArray(v)) return v.map((x) => String(x || '').trim()).filter(Boolean);
  const s = String(v).trim();
  return s ? [s] : [];
}

export function turkishFdaTitle(conditions, status) {
  const labels = uniqueStrings(conditions);
  const cond = labels.length ? labels.join(', ') : 'hedef hastalık';
  const st = fdaStatusTr(status);
  return `${cond} için FDA ilacı (${st})`;
}

export function turkishFdaSummary({
  brandName,
  genericName,
  applicationNumber,
  conditions,
  status,
  indicationSnippet,
}) {
  const labels = uniqueStrings(conditions);
  const cond = labels.length ? labels.join(', ') : 'ilgili hastalık';
  const names = [brandName, genericName].filter(Boolean).join(' / ');
  const appl = String(applicationNumber || '').trim();
  const snippet = String(indicationSnippet || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 400);
  return [
    `FDA Drugs@FDA kaydına göre bu ilaç ${cond} ile ilişkilendirildi.`,
    `Durum: ${fdaStatusTr(status)}.`,
    names ? `Ürün: ${names}.` : '',
    appl ? `Başvuru no: ${appl}.` : '',
    snippet ? `Endikasyon özeti (kaynak dilinde): ${snippet}` : '',
    'Tedavi vaadi yoktur; bu bir onay kaydıdır, yayınlanmış klinik sonuç değildir.',
  ]
    .filter(Boolean)
    .join(' ');
}

export function toFdaItem(record, source = { name: FDA_SOURCE_NAME }) {
  const applicationNumber = String(record.applicationNumber || '').trim();
  const genericName = String(record.genericName || '').trim();
  const brandName = String(record.brandName || '').trim();
  const status = record.status || classifyFdaStatus(record);
  const conditions = Array.isArray(record.conditions) ? record.conditions : [];
  const title = turkishFdaTitle(conditions, status);
  const originalTitle = [brandName, genericName, applicationNumber]
    .filter(Boolean)
    .join(' | ');
  const sourceUrl = fdaSourceUrl(applicationNumber);
  const approvalDate = record.approvalDate || null;
  return {
    title,
    originalTitle,
    summary: turkishFdaSummary({
      brandName,
      genericName,
      applicationNumber,
      conditions,
      status,
      indicationSnippet: record.indicationSnippet,
    }),
    sourceUrl,
    pmid: '',
    nctId: '',
    doi: '',
    journal: 'Drugs@FDA',
    publicationDate: approvalDate,
    country: 'United States',
    studyType: 'drug_approval',
    studyPhase: '',
    recruitmentStatus: status,
    hasResults: true,
    humanOrAnimal: 'human',
    conditions,
    sourceName: source?.name || FDA_SOURCE_NAME,
    sourceId: source?.id || null,
    externalId: applicationNumber ? `fda:${applicationNumber}` : '',
    applicationNumber,
    genericName,
    brandName,
    fdaStatus: status,
    fdaHash: null,
  };
}

export function fdaPendingScore(item) {
  const approved = item?.fdaStatus === 'approved';
  const title = String(item?.title || '').trim() || TITLE_TR_FALLBACK;
  return {
    treatment_potential: approved ? 'HIGH_VALUE' : 'POTENTIAL_VALUE',
    title,
    original_title: String(item?.originalTitle || '').slice(0, 400),
    summary: String(item?.summary || TITLE_TR_FALLBACK).slice(0, 4000),
    why_important: `${(item?.conditions || []).join(', ') || 'hedef hastalık'} için FDA kaydı. Tedavi vaadi yok.`,
    limitations:
      'openFDA / Drugs@FDA özeti; tam etiket ve hekim kararı gerekir. Tedavi vaadi yoktur.',
    conditions: Array.isArray(item?.conditions) ? item.conditions : [],
    categories: ['ilaç onayı'],
    study_type: 'drug_approval',
    evidence_level: 'FDA kaydı',
    study_phase: 'Çalışmada belirtilmemiş',
    human_or_animal: 'human',
    pediatric_relevance: 'koşula bağlı',
    relevance_score: approved ? 80 : 60,
    scientific_importance_score: approved ? 75 : 55,
    treatment_potential_score: approved ? 70 : 50,
    clinical_readiness_score: approved ? 85 : 40,
    ai_notes:
      'FDA Drugs@FDA / openFDA. Collector pending_review yazar; yayın yok; FCM yok; tedavi vaadi yok.',
  };
}

function latestApprovalDate(submissions) {
  let best = null;
  for (const s of submissions || []) {
    if (String(s?.submission_status || '').toUpperCase() !== 'AP') continue;
    const parsed = parseFlexibleDate(s.submission_status_date);
    if (!parsed) continue;
    if (!best || parsed.ymd > best) best = parsed.ymd;
  }
  return best;
}

export function normalizeDrugsfdaRecord(raw, extra = {}) {
  const applicationNumber = String(raw?.application_number || extra.applicationNumber || '').trim();
  const openfda = raw?.openfda || {};
  const products = Array.isArray(raw?.products) ? raw.products : [];
  const submissions = Array.isArray(raw?.submissions) ? raw.submissions : [];
  const brandName =
    asList(openfda.brand_name)[0] ||
    products.map((p) => p.brand_name).find(Boolean) ||
    '';
  const genericName =
    asList(openfda.generic_name)[0] ||
    products
      .flatMap((p) => asList(p.active_ingredients).map((a) => a.name || a))
      .find(Boolean) ||
    '';
  const marketingStatuses = products.map((p) => p.marketing_status).filter(Boolean);
  const status = classifyFdaStatus({ marketingStatuses, submissions });
  const indicationSnippet = String(extra.indicationSnippet || '').trim();
  const blob = [
    indicationSnippet,
    extra.queryTerm,
    extra.conditionLabel,
    brandName,
    genericName,
    asList(openfda.pharm_class_epc).join(' '),
  ].join(' ');
  const conditions = uniqueStrings([
    ...(extra.conditions || []),
    ...mapTextToConditions(blob, extra.config),
  ]);
  return {
    applicationNumber,
    brandName,
    genericName,
    marketingStatuses,
    submissions,
    status,
    approvalDate: latestApprovalDate(submissions),
    indicationSnippet: indicationSnippet.slice(0, 500),
    conditions,
  };
}

async function fdaGet(url, { retries = 3 } = {}) {
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const res = await fetch(url, {
        headers: {
          accept: 'application/json',
          'user-agent': `EngelsizClub-ScienceCollector/1.0 (${EMAIL})`,
        },
        signal: AbortSignal.timeout(45000),
      });
      const text = await res.text();
      if (res.status === 404) return { results: [] };
      if (!res.ok) {
        throw new Error(`FDA HTTP ${res.status}: ${text.slice(0, 240)}`);
      }
      return JSON.parse(text);
    } catch (e) {
      lastErr = e;
      if (attempt < retries) {
        await sleep(400 * attempt);
        continue;
      }
    }
  }
  throw lastErr || new Error('FDA istek başarısız');
}

function encodeSearch(term) {
  return encodeURIComponent(term);
}

async function searchLabels(term, { limit = PAGE_LIMIT } = {}) {
  const q = `indications_and_usage:"${term}"`;
  const url = `${FDA_LABEL_API}?search=${encodeSearch(q)}&limit=${limit}`;
  const json = await fdaGet(url);
  return Array.isArray(json?.results) ? json.results : [];
}

async function searchDrugsfda(field, term, { limit = PAGE_LIMIT } = {}) {
  const q = `${field}:"${term}"`;
  const url = `${FDA_DRUGSFDA_API}?search=${encodeSearch(q)}&limit=${limit}`;
  const json = await fdaGet(url);
  return Array.isArray(json?.results) ? json.results : [];
}

async function fetchDrugsfdaByAppl(applicationNumber) {
  const appl = String(applicationNumber || '').trim();
  if (!appl) return null;
  const url = `${FDA_DRUGSFDA_API}?search=${encodeSearch(`application_number:"${appl}"`)}&limit=1`;
  const json = await fdaGet(url);
  return Array.isArray(json?.results) ? json.results[0] || null : null;
}

function labelIndicationText(label) {
  return asList(label?.indications_and_usage).join(' ');
}

function labelApplicationNumbers(label) {
  return uniqueStrings(asList(label?.openfda?.application_number));
}

function fdaQueryList(source, config) {
  const fromConfig = Array.isArray(config.fda_queries) ? config.fda_queries : [];
  const extra = String(source?.query || '').trim();
  const queries = fromConfig.map((q) => ({ ...q }));
  if (extra && !queries.some((q) => String(q.term || '').trim() === extra)) {
    queries.unshift({ id: 'source_query', term: extra });
  }
  if (queries.length) return queries;
  return listConditionDefs(config)
    .flatMap((d) =>
      (d.fda_indication_terms || [d.label_en, d.label_tr]).map((term) => ({
        id: d.id,
        term,
      })),
    )
    .filter((q) => String(q.term || '').trim());
}

function productTerms(config) {
  const out = [];
  for (const def of listConditionDefs(config)) {
    for (const term of def.fda_product_terms || []) {
      if (!term) continue;
      out.push({ id: def.id, term: String(term).trim(), label_tr: def.label_tr });
    }
  }
  return out;
}

export async function fetchFda(source, opts = {}) {
  const config = opts.config || loadConditions();
  const wait = opts.sleep || sleep;
  const queries = fdaQueryList(source, config);
  const seen = new Set();
  const items = [];
  const errors = [];

  const remember = async (normalized) => {
    if (!keepFdaStatus(normalized.status)) return;
    if (!normalized.applicationNumber && !normalized.genericName) return;
    if (!normalized.conditions.length) return;
    const key = `${String(normalized.applicationNumber || '').toUpperCase()}|${foldTr(normalized.genericName)}`;
    if (seen.has(key)) return;
    seen.add(key);
    const item = toFdaItem(normalized, source);
    item.fdaHash = fdaContentHash(
      normalized.applicationNumber,
      normalized.genericName,
    );
    items.push(item);
  };

  for (const q of queries) {
    const term = String(q.term || '').trim();
    if (!term) continue;
    try {
      const labels = await searchLabels(term);
      console.log(`FDA label hits=${labels.length} term=${term.slice(0, 80)}`);
      for (const label of labels) {
        const indication = labelIndicationText(label);
        const mapped = mapTextToConditions(`${indication} ${term}`, config);
        if (!mapped.length) continue;
        const appls = labelApplicationNumbers(label);
        if (!appls.length) continue;
        for (const appl of appls) {
          const rec = await fetchDrugsfdaByAppl(appl);
          await wait(120);
          if (!rec) continue;
          await remember(
            normalizeDrugsfdaRecord(rec, {
              applicationNumber: appl,
              indicationSnippet: indication,
              queryTerm: term,
              conditions: mapped,
              config,
            }),
          );
        }
      }
      await wait(200);
    } catch (e) {
      errors.push(`label ${q.id}: ${e.message}`);
      console.warn(`FDA etiket atlandı ${q.id}: ${e.message}`);
    }
  }

  for (const p of productTerms(config)) {
    try {
      const recs = [
        ...(await searchDrugsfda('openfda.generic_name', p.term, { limit: 5 })),
        ...(await searchDrugsfda('openfda.brand_name', p.term, { limit: 5 })),
      ];
      for (const rec of recs) {
        await remember(
          normalizeDrugsfdaRecord(rec, {
            queryTerm: p.term,
            conditionLabel: p.label_tr,
            conditions: p.label_tr ? [p.label_tr] : [],
            config,
          }),
        );
      }
      await wait(200);
    } catch (e) {
      errors.push(`product ${p.term}: ${e.message}`);
      console.warn(`FDA ürün atlandı ${p.term}: ${e.message}`);
    }
  }

  if (!items.length && errors.length) {
    throw new Error(`FDA tüm sorgular hata: ${errors.slice(0, 3).join(' | ')}`);
  }
  if (!items.length) {
    console.warn('FDA: 0 ilaç. openFDA drugsfda/label ve conditions.json kontrol edin.');
  }
  return items;
}
