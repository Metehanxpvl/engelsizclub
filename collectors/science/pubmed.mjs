import { loadConditions, sleep } from './config.mjs';
import { highestPhase } from './filter.mjs';
import { normalizeDoi } from './hash.mjs';

const EUTILS = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils';
const TOOL = 'engelsizclub';
const EMAIL = 'sakir.caykara@gmail.com';

function delayMs(apiKey) {
  return apiKey ? 120 : 400;
}

function qs(params) {
  const u = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null || v === '') continue;
    u.set(k, String(v));
  }
  return u.toString();
}

async function eutilsGet(path, params, { timeoutMs = 25000, retries = 3 } = {}) {
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const url = `${EUTILS}/${path}?${qs(params)}`;
      const res = await fetch(url, {
        headers: {
          accept: 'application/json, text/plain, application/xml, */*',
          'user-agent': `EngelsizClub-ScienceCollector/1.0 (${EMAIL})`,
        },
        signal: AbortSignal.timeout(timeoutMs),
      });
      const text = await res.text();
      if (!res.ok) {
        throw new Error(`PubMed ${path} HTTP ${res.status}: ${text.slice(0, 240)}`);
      }
      return text;
    } catch (e) {
      lastErr = e;
      if (attempt < retries) {
        await sleep(delayMs(params.api_key) * attempt);
        continue;
      }
    }
  }
  throw lastErr || new Error(`PubMed ${path} başarısız`);
}

export function parseMedlineRecords(raw) {
  const text = String(raw || '').replace(/\r\n/g, '\n');
  if (!text.trim()) return [];
  const chunks = text.split(/\n(?=PMID- )/);
  const out = [];
  for (const chunk of chunks) {
    const rec = parseMedlineOne(chunk);
    if (rec?.pmid && rec.title) out.push(rec);
  }
  return out;
}

function parseMedlineOne(chunk) {
  const fields = {};
  let tag = '';
  for (const line of String(chunk).split('\n')) {
    const m = line.match(/^([A-Z0-9]{2,4}) *- (.*)$/);
    if (m) {
      tag = m[1];
      const val = m[2];
      if (fields[tag] === undefined) fields[tag] = val;
      else if (Array.isArray(fields[tag])) fields[tag].push(val);
      else fields[tag] = [fields[tag], val];
    } else if (tag && /^ {6}/.test(line)) {
      const cont = line.slice(6);
      if (Array.isArray(fields[tag])) {
        fields[tag][fields[tag].length - 1] += ` ${cont}`;
      } else {
        fields[tag] += ` ${cont}`;
      }
    }
  }
  const pmid = String(fields.PMID || '').trim();
  const title = String(fields.TI || '').replace(/\s+/g, ' ').trim();
  const abstract = String(fields.AB || '').replace(/\s+/g, ' ').trim();
  const journal = String(fields.JT || fields.TA || '').trim();
  const country = String(fields.PL || '').trim();
  const dp = String(fields.DP || '').trim();
  const pts = []
    .concat(fields.PT || [])
    .map((s) => String(s).trim())
    .filter(Boolean);
  const doi = pickDoi(fields);
  return {
    pmid,
    title,
    abstract,
    journal,
    country,
    publicationDate: parsePubDate(dp),
    doi,
    publicationTypes: pts,
  };
}

function pickDoi(fields) {
  const lids = [].concat(fields.LID || [], fields.AID || []);
  for (const raw of lids) {
    const s = String(raw);
    const m = s.match(/(\S+)\s*\[doi\]/i);
    if (m) return normalizeDoi(m[1]);
    if (/^10\.\d{4,}\//.test(s.trim())) return normalizeDoi(s);
  }
  return '';
}

export function parsePubDate(dp) {
  const s = String(dp || '').trim();
  if (!s) return null;
  const ymd = s.match(/^(\d{4})\s+([A-Za-z]{3})(?:\s+(\d{1,2}))?/);
  if (ymd) {
    const months = {
      jan: '01',
      feb: '02',
      mar: '03',
      apr: '04',
      may: '05',
      jun: '06',
      jul: '07',
      aug: '08',
      sep: '09',
      oct: '10',
      nov: '11',
      dec: '12',
    };
    const mo = months[ymd[2].toLowerCase()];
    const day = String(ymd[3] || '01').padStart(2, '0');
    if (mo) return `${ymd[1]}-${mo}-${day}`;
  }
  const y = s.match(/^(\d{4})/);
  return y ? `${y[1]}-01-01` : null;
}

function guessHumanOrAnimal(rec) {
  const blob = `${rec.title} ${rec.abstract} ${(rec.publicationTypes || []).join(' ')}`;
  if (/\b(mice|mouse|rat|rats|murine|zebrafish|non-human|animal model|in vivo)\b/i.test(blob)) {
    return 'animal';
  }
  if (/\b(clinical trial|randomized|cohort|patients|infant|child|pediatric)\b/i.test(blob)) {
    return 'human';
  }
  return '';
}

export async function esearchIds(term, { apiKey, retmax, reldateDays } = {}) {
  const text = await eutilsGet('esearch.fcgi', {
    db: 'pubmed',
    term,
    retmax: retmax ?? 25,
    retmode: 'json',
    sort: 'pub date',
    reldate: reldateDays ?? 90,
    datetype: 'pdat',
    tool: TOOL,
    email: EMAIL,
    api_key: apiKey,
  });
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`PubMed esearch JSON yok: ${text.slice(0, 180)}`);
  }
  const err = json?.esearchresult?.ERROR;
  if (err) throw new Error(`PubMed esearch ERROR: ${err}`);
  const count = json?.esearchresult?.count;
  const ids = json?.esearchresult?.idlist;
  const list = Array.isArray(ids) ? ids.map(String) : [];
  console.log(
    `PubMed esearch count=${count ?? '?'} ids=${list.length} term=${String(term).slice(0, 90)}`,
  );
  return list;
}

export async function efetchMedline(ids, { apiKey } = {}) {
  if (!ids.length) return [];
  const text = await eutilsGet('efetch.fcgi', {
    db: 'pubmed',
    id: ids.join(','),
    rettype: 'medline',
    retmode: 'text',
    tool: TOOL,
    email: EMAIL,
    api_key: apiKey,
  });
  return parseMedlineRecords(text);
}

export function toPubmedItem(rec, source) {
  const pmid = String(rec.pmid || '').trim();
  const title = String(rec.title || '').trim();
  const summary = String(rec.abstract || '').trim();
  const publicationTypes = rec.publicationTypes || [];
  const phaseHint = highestPhase({
    title,
    summary,
    studyPhase: publicationTypes.join(' '),
  });
  return {
    title,
    originalTitle: title,
    summary,
    sourceUrl: pmid ? `https://pubmed.ncbi.nlm.nih.gov/${pmid}/` : '',
    pmid,
    nctId: '',
    doi: rec.doi || '',
    journal: rec.journal || '',
    publicationDate: rec.publicationDate || null,
    country: rec.country || '',
    studyType: publicationTypes[0] || '',
    studyPhase: phaseHint != null ? `PHASE${phaseHint}` : '',
    publicationTypes,
    recruitmentStatus: '',
    hasResults: /\b(Randomized Controlled Trial|Clinical Trial|results|outcomes?|efficacy)\b/i.test(
      `${publicationTypes.join(' ')} ${summary}`,
    ),
    humanOrAnimal: guessHumanOrAnimal(rec),
    conditions: [],
    sourceName: source?.name || 'PubMed',
    sourceId: source?.id || null,
    externalId: pmid ? `pmid:${pmid}` : '',
  };
}

const PUBMED_RESULTS_FILTER =
  '(Clinical Trial[Publication Type] OR Randomized Controlled Trial[Publication Type] OR "Clinical Trial, Phase II"[Publication Type] OR "Clinical Trial, Phase III"[Publication Type] OR "Clinical Trial, Phase IV"[Publication Type] OR "phase 2"[Title/Abstract] OR "phase 3"[Title/Abstract] OR "phase 4"[Title/Abstract] OR "phase II"[Title/Abstract] OR "phase III"[Title/Abstract] OR randomized[Title/Abstract] OR randomised[Title/Abstract]) AND hasabstract[text] NOT protocol[Title]';

function withResultsFilter(term) {
  const t = String(term || '').trim();
  if (!t) return t;
  if (/hasabstract\[text\]/i.test(t)) return t;
  return `(${t}) AND ${PUBMED_RESULTS_FILTER}`;
}

function pubmedQueryList(source, config) {
  const queries = [
    ...(Array.isArray(config.pubmed_queries) ? config.pubmed_queries : []),
  ];
  const extra = String(source?.query || '').trim();
  if (extra && !queries.some((q) => String(q.term || '').trim() === extra)) {
    queries.unshift({ id: 'source_query', term: extra });
  }
  return queries.map((q) => ({ ...q, term: withResultsFilter(q.term) }));
}

export async function fetchPubmed(source, opts = {}) {
  const config = opts.config || loadConditions();
  const apiKey = (opts.apiKey || process.env.NCBI_API_KEY || '').trim();
  const retmax = Number(opts.retmax || config.retmax || 25);
  const reldateDays = Number(opts.reldateDays || config.reldate_days || 90);
  const queries = pubmedQueryList(source, config);
  const wait = opts.sleep || sleep;
  const seen = new Set();
  const items = [];
  const errors = [];

  if (!queries.length) {
    throw new Error('PubMed: conditions.json pubmed_queries boş');
  }

  for (const q of queries) {
    const term = String(q.term || '').trim();
    if (!term) continue;
    try {
      const ids = await esearchIds(term, { apiKey, retmax, reldateDays });
      await wait(delayMs(apiKey));
      const fresh = ids.filter((id) => {
        if (seen.has(id)) return false;
        seen.add(id);
        return true;
      });
      if (!fresh.length) continue;
      const recs = await efetchMedline(fresh, { apiKey });
      console.log(`PubMed efetch ${q.id}: recs=${recs.length}`);
      for (const rec of recs) {
        items.push(toPubmedItem(rec, source));
      }
      await wait(delayMs(apiKey));
    } catch (e) {
      errors.push(`${q.id}: ${e.message}`);
      console.warn(`PubMed sorgu atlandı ${q.id}: ${e.message}`);
    }
  }

  if (!items.length && errors.length) {
    throw new Error(`PubMed tüm sorgular hata: ${errors.slice(0, 3).join(' | ')}`);
  }
  if (!items.length) {
    console.warn('PubMed: esearch 0 id (reldate/sorgu). conditions.json pubmed_queries kontrol edin.');
  }
  return items;
}
