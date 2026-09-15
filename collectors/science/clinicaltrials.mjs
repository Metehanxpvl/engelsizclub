import { loadConditions, sleep } from './config.mjs';

const API = 'https://clinicaltrials.gov/api/v2/studies';
const EMAIL = 'sakir.caykara@gmail.com';

function nested(obj, path) {
  let cur = obj;
  for (const key of path.split('.')) {
    if (cur == null) return undefined;
    cur = cur[key];
  }
  return cur;
}

function asList(v) {
  if (v == null) return [];
  if (Array.isArray(v)) return v.map((x) => String(x).trim()).filter(Boolean);
  return String(v).trim() ? [String(v).trim()] : [];
}

function unique(list) {
  const seen = new Set();
  const out = [];
  for (const x of list) {
    const k = x.toLowerCase();
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(x);
  }
  return out;
}

export function parseStudy(study) {
  const proto = study?.protocolSection || study || {};
  const ident = proto.identificationModule || {};
  const status = proto.statusModule || {};
  const desc = proto.descriptionModule || {};
  const cond = proto.conditionsModule || {};
  const design = proto.designModule || {};
  const elig = proto.eligibilityModule || {};
  const loc = proto.contactsLocationsModule || {};

  const nctId = String(ident.nctId || nested(study, 'protocolSection.identificationModule.nctId') || '').trim();
  const title = String(
    ident.briefTitle || ident.officialTitle || '',
  ).trim();
  const official = String(ident.officialTitle || title).trim();
  const summary = String(desc.briefSummary || desc.detailedDescription || '').trim();
  const conditions = asList(cond.conditions);
  const phases = asList(design.phases || design.phaseList);
  const studyType = String(design.studyType || '').trim();
  const overall = String(status.overallStatus || '').trim();
  const countries = unique(
    (loc.locations || []).map((l) => String(l.country || '').trim()).filter(Boolean),
  );
  const stdAges = asList(elig.stdAges);
  const start = status.startDateStruct?.date || status.startDate || '';
  const resultsFirst =
    status.resultsFirstPostDateStruct?.date ||
    status.resultsFirstPostDate ||
    status.resultsFirstSubmitDateStruct?.date ||
    '';
  const hasResults = Boolean(
    study.hasResults === true ||
      resultsFirst ||
      (study.resultsSection && typeof study.resultsSection === 'object'),
  );

  return {
    nctId,
    title,
    officialTitle: official,
    summary,
    conditions,
    phases,
    studyType,
    overallStatus: overall,
    countries,
    stdAges,
    startDate: String(start).slice(0, 10) || null,
    hasResults,
    resultsFirstPostDate: String(resultsFirst).slice(0, 10) || null,
  };
}

export function toTrialItem(parsed, source) {
  const nctId = String(parsed.nctId || '').trim();
  const title = String(parsed.title || '').trim();
  const pediatric =
    (parsed.stdAges || []).some((a) => /child|infant|pediatric/i.test(a)) ||
    /\b(child|infant|pediatric|neonat)/i.test(`${title} ${parsed.summary}`);
  return {
    title,
    originalTitle: parsed.officialTitle || title,
    summary: String(parsed.summary || '').trim(),
    sourceUrl: nctId ? `https://clinicaltrials.gov/study/${nctId}` : '',
    pmid: '',
    nctId,
    doi: '',
    journal: '',
    publicationDate: parsed.startDate || null,
    country: (parsed.countries || []).join(', '),
    studyType: parsed.studyType || '',
    studyPhase: (parsed.phases || []).join(', '),
    phases: parsed.phases || [],
    recruitmentStatus: parsed.overallStatus || '',
    hasResults: Boolean(parsed.hasResults),
    resultsFirstPostDate: parsed.resultsFirstPostDate || null,
    humanOrAnimal: 'human',
    conditions: parsed.conditions || [],
    pediatricHint: pediatric,
    sourceName: source?.name || 'ClinicalTrials.gov',
    sourceId: source?.id || null,
    externalId: nctId ? `nct:${nctId}` : '',
  };
}

export async function fetchClinicalTrialsPage(term, { pageSize = 25, retries = 3 } = {}) {
  const url = new URL(API);
  url.searchParams.set('query.cond', term);
  url.searchParams.set('filter.phase', 'PHASE2,PHASE3,PHASE4');
  url.searchParams.set('pageSize', String(pageSize));
  url.searchParams.set('sort', 'LastUpdatePostDate:desc');
  url.searchParams.set('format', 'json');
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const res = await fetch(url, {
        headers: {
          accept: 'application/json',
          'user-agent': `EngelsizClub-ScienceCollector/1.0 (${EMAIL})`,
        },
        signal: AbortSignal.timeout(60000),
      });
      const text = await res.text();
      if (!res.ok) {
        throw new Error(`ClinicalTrials HTTP ${res.status}: ${text.slice(0, 240)}`);
      }
      let json;
      try {
        json = JSON.parse(text);
      } catch {
        throw new Error(`ClinicalTrials JSON yok: ${text.slice(0, 180)}`);
      }
      const studies = Array.isArray(json?.studies) ? json.studies : [];
      console.log(`ClinicalTrials studies=${studies.length} term=${String(term).slice(0, 80)}`);
      return studies.map(parseStudy).filter((s) => s.nctId && s.title);
    } catch (e) {
      lastErr = e;
      if (attempt < retries) {
        await sleep(400 * attempt);
        continue;
      }
    }
  }
  throw lastErr || new Error('ClinicalTrials başarısız');
}

function trialsQueryList(source, config) {
  const queries = [
    ...(Array.isArray(config.clinicaltrials_queries)
      ? config.clinicaltrials_queries
      : []),
  ];
  const extra = String(source?.query || '').trim();
  if (extra && !queries.some((q) => String(q.term || '').trim() === extra)) {
    queries.unshift({ id: 'source_query', term: extra });
  }
  return queries;
}

export async function fetchClinicalTrials(source, opts = {}) {
  const config = opts.config || loadConditions();
  const pageSize = Number(opts.pageSize || config.clinicaltrials_page_size || 25);
  const queries = trialsQueryList(source, config);
  const wait = opts.sleep || sleep;
  const seen = new Set();
  const items = [];
  const errors = [];

  if (!queries.length) {
    throw new Error('ClinicalTrials: conditions.json clinicaltrials_queries boş');
  }

  for (const q of queries) {
    const term = String(q.term || '').trim();
    if (!term) continue;
    try {
      const parsed = await fetchClinicalTrialsPage(term, { pageSize });
      for (const p of parsed) {
        if (seen.has(p.nctId)) continue;
        seen.add(p.nctId);
        items.push(toTrialItem(p, source));
      }
      await wait(300);
    } catch (e) {
      errors.push(`${q.id}: ${e.message}`);
      console.warn(`ClinicalTrials sorgu atlandı ${q.id}: ${e.message}`);
    }
  }

  if (!items.length && errors.length) {
    throw new Error(
      `ClinicalTrials tüm sorgular hata: ${errors.slice(0, 3).join(' | ')}`,
    );
  }
  if (!items.length) {
    console.warn('ClinicalTrials: 0 çalışma. query.cond / API v2 kontrol edin.');
  }
  return items;
}
