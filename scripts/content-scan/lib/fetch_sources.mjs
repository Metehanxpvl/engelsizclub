import { XMLParser } from 'fast-xml-parser';

import { fillTemplate, newsQueries, scienceQueries } from './config.mjs';
import { fetchJson, fetchText, sleep } from './http.mjs';
import { hostOf, parseDate, recordFromRaw, stripHtml } from './normalize.mjs';

const xml = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  textNodeName: '#text',
  trimValues: true,
  processEntities: { enabled: true, maxTotalExpansions: 20000, maxEntityCount: 8000 },
});

function asArray(v) {
  if (v == null) return [];
  return Array.isArray(v) ? v : [v];
}

function textOf(v) {
  if (v == null) return '';
  if (typeof v === 'string' || typeof v === 'number') return stripHtml(String(v));
  if (typeof v === 'object') {
    if (typeof v['#text'] === 'string') return stripHtml(v['#text']);
    if (typeof v.href === 'string') return v.href;
  }
  return '';
}

function linkOf(item) {
  for (const c of [item.link, item.guid, item.id, item['atom:link']]) {
    if (typeof c === 'string' && c.startsWith('http')) return c.trim();
    if (c && typeof c === 'object') {
      const href = c.href || c.url || c['#text'];
      if (typeof href === 'string' && href.startsWith('http')) return href.trim();
    }
  }
  return '';
}

export function parseRssOrAtom(raw) {
  const doc = xml.parse(String(raw || ''));
  const channel = doc?.rss?.channel || doc?.feed || {};
  const items = asArray(channel.item || channel.entry);
  const out = [];
  for (const it of items) {
    const title = textOf(it.title);
    const url = linkOf(it);
    if (!title || !url) continue;
    const source =
      textOf(it.source) ||
      textOf(it['dc:creator']) ||
      hostOf(url);
    out.push(
      recordFromRaw({
        title,
        url,
        source,
        date: textOf(it.pubDate) || textOf(it.published) || textOf(it.updated) || it.pubDate,
        snippet: textOf(it.description) || textOf(it.summary) || textOf(it.content),
      }),
    );
  }
  return out;
}

function emptySourceStat(id) {
  return { id, fetched: 0, kept: 0, error: '' };
}

async function safeFetch(stat, fn) {
  try {
    const items = await fn();
    stat.fetched = items.length;
    return items;
  } catch (e) {
    stat.error = String(e.message || e).slice(0, 180);
    return [];
  }
}

function googleUrl(template, q) {
  return String(template || '').replace('{q}', encodeURIComponent(q));
}

export async function fetchGoogleNews(template, q, opts) {
  const xmlText = await fetchText(googleUrl(template, q), opts);
  return parseRssOrAtom(xmlText);
}

export async function fetchGdelt(cfg, { science = false, ...opts } = {}) {
  const u = new URL(cfg.url);
  u.searchParams.set('query', science ? cfg.science_query : cfg.news_query);
  u.searchParams.set('mode', cfg.mode || 'ArtList');
  u.searchParams.set('format', cfg.format || 'json');
  u.searchParams.set('maxrecords', String(cfg.maxrecords || 50));
  u.searchParams.set('timespan', science ? cfg.timespan_science : cfg.timespan_news);
  const json = await fetchJson(u.toString(), opts);
  const arts = json?.articles || json?.article || [];
  return asArray(arts)
    .map((a) =>
      recordFromRaw({
        title: a.title,
        url: a.url,
        source: a.domain || a.sourceCountry || 'GDELT',
        date: a.seendate,
        snippet: a.seendate || '',
      }),
    )
    .filter((r) => r.title && r.url);
}

function reconstructAbstract(inv) {
  if (!inv || typeof inv !== 'object') return '';
  const pairs = [];
  for (const [word, idx] of Object.entries(inv)) {
    for (const i of idx || []) pairs.push([i, word]);
  }
  pairs.sort((a, b) => a[0] - b[0]);
  return pairs.map((p) => p[1]).join(' ');
}

export async function fetchOpenAlex(template, q, fromDate, opts) {
  const url = fillTemplate(template, { q, date: fromDate });
  const json = await fetchJson(url, opts);
  return asArray(json?.results)
    .map((w) =>
      recordFromRaw({
        title: w.display_name,
        url: w.doi
          ? `https://doi.org/${String(w.doi).replace(/^https?:\/\/doi.org\//i, '')}`
          : w.id,
        source: 'OpenAlex',
        date: w.publication_date,
        snippet: reconstructAbstract(w.abstract_inverted_index),
        extra: {
          group: 'science',
          kind: 'science',
          doi: w.doi || '',
          journal: w.primary_location?.source?.display_name || '',
        },
      }),
    )
    .filter((r) => r.title && r.url);
}

export async function fetchPubmed(template, q, opts) {
  const searchUrl = fillTemplate(template, { q });
  const search = await fetchJson(searchUrl, opts);
  const ids = search?.esearchresult?.idlist || [];
  if (!ids.length) return [];
  const sumUrl =
    `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=json&id=${ids.slice(0, 40).join(',')}`;
  const sum = await fetchJson(sumUrl, opts);
  const recs = sum?.result || {};
  return ids
    .map((id) => recs[id])
    .filter(Boolean)
    .map((r) =>
      recordFromRaw({
        title: r.title,
        url: `https://pubmed.ncbi.nlm.nih.gov/${r.uid}/`,
        source: 'PubMed',
        date: r.pubdate,
        snippet: r.source || '',
        extra: {
          group: 'science',
          kind: 'science',
          pmid: String(r.uid || ''),
          journal: r.fulljournalname || r.source || '',
        },
      }),
    )
    .filter((row) => row.title);
}

export async function fetchClinicalTrials(template, q, opts) {
  const url = fillTemplate(template, { q });
  const json = await fetchJson(url, opts);
  return asArray(json?.studies)
    .map((s) => {
      const proto = s?.protocolSection || {};
      const id = proto.identificationModule || {};
      const st = proto.statusModule || {};
      const nct = id.nctId || '';
      return recordFromRaw({
        title: id.briefTitle || id.officialTitle,
        url: nct ? `https://clinicaltrials.gov/study/${nct}` : '',
        source: 'ClinicalTrials.gov',
        date: st.startDateStruct?.date || st.lastUpdatePostDateStruct?.date,
        snippet: proto.descriptionModule?.briefSummary || '',
        extra: {
          group: 'science',
          kind: 'science',
          nct_id: nct,
          recruitment_status: st.overallStatus || 'RECRUITING',
        },
      });
    })
    .filter((r) => r.title && r.url);
}

export function parseOaiRecords(raw) {
  const doc = xml.parse(String(raw || ''));
  const recs = asArray(doc?.['OAI-PMH']?.ListRecords?.record || doc?.ListRecords?.record);
  const out = [];
  for (const rec of recs) {
    const md = rec?.metadata?.dc || rec?.metadata?.['oai_dc:dc'] || rec?.metadata || {};
    const title = textOf(asArray(md.title || md['dc:title'])[0]);
    const ident = asArray(md.identifier || md['dc:identifier']).map(textOf);
    const url = ident.find((x) => x.startsWith('http')) || '';
    if (!title || !url) continue;
    out.push(
      recordFromRaw({
        title,
        url,
        source: 'DergiPark',
        date: textOf(asArray(md.date || md['dc:date'])[0]),
        snippet: textOf(asArray(md.description || md['dc:description'])[0]),
        extra: { group: 'science', kind: 'science' },
      }),
    );
  }
  return out;
}

export async function fetchDergipark(cfg, fromDate, opts) {
  const u = new URL(cfg.oai);
  u.searchParams.set('verb', 'ListRecords');
  u.searchParams.set('metadataPrefix', cfg.metadata_prefix || 'oai_dc');
  if (fromDate) u.searchParams.set('from', fromDate);
  const xmlText = await fetchText(u.toString(), opts);
  return parseOaiRecords(xmlText);
}

export async function collectAll({ mode, sources, conditions, pipeline, onStat }) {
  const timeoutMs = pipeline.request_timeout_ms || 12000;
  const delayMs = pipeline.source_delay_ms || 250;
  const ua = pipeline.user_agent;
  const opts = { timeoutMs, userAgent: ua };
  const stats = [];
  const items = [];

  const pushStat = (stat) => {
    stats.push(stat);
    if (onStat) onStat(stat);
  };

  const pause = async () => {
    if (delayMs) await sleep(delayMs);
  };

  if (mode === 'news' || mode === 'all') {
    const gTemplate = sources.google_news.template;
    const oTemplate = sources.official_via_news.template;
    for (const row of newsQueries(sources, conditions)) {
      const stat = emptySourceStat(row.id);
      const template = row.group === 'official_via_news' ? oTemplate : gTemplate;
      const got = await safeFetch(stat, () => fetchGoogleNews(template, row.q, opts));
      for (const it of got) {
        it.query_id = row.id;
        it.group = row.group === 'official_via_news' ? 'official' : 'news';
        items.push(it);
      }
      pushStat(stat);
      await pause();
    }
    if (sources.gdelt?.url) {
      const stat = emptySourceStat('gdelt');
      const got = await safeFetch(stat, () => fetchGdelt(sources.gdelt, { ...opts, science: false }));
      for (const it of got) {
        it.group = 'news';
        items.push(it);
      }
      pushStat(stat);
      await pause();
    }
  }

  if (mode === 'science' || mode === 'all') {
    const from = new Date(Date.now() - 60 * 86400000).toISOString().slice(0, 10);
    for (const row of scienceQueries(sources, conditions)) {
      if (sources.science?.openalex) {
        const stat = emptySourceStat(`openalex:${row.id}`);
        const got = await safeFetch(stat, () =>
          fetchOpenAlex(sources.science.openalex, row.q, from, opts),
        );
        items.push(...got);
        pushStat(stat);
        await pause();
      }
      if (sources.science?.pubmed) {
        const stat = emptySourceStat(`pubmed:${row.id}`);
        const got = await safeFetch(stat, () => fetchPubmed(sources.science.pubmed, row.q, opts));
        items.push(...got);
        pushStat(stat);
        await pause();
      }
      if (sources.science?.clinicaltrials) {
        const stat = emptySourceStat(`clinicaltrials:${row.id}`);
        const got = await safeFetch(stat, () =>
          fetchClinicalTrials(sources.science.clinicaltrials, row.q, opts),
        );
        items.push(...got);
        pushStat(stat);
        await pause();
      }
    }
    if (sources.dergipark?.oai) {
      const stat = emptySourceStat('dergipark');
      const got = await safeFetch(stat, () => fetchDergipark(sources.dergipark, from, opts));
      items.push(...got);
      pushStat(stat);
    }
    if (sources.gdelt?.url) {
      const stat = emptySourceStat('gdelt_science');
      const got = await safeFetch(stat, () => fetchGdelt(sources.gdelt, { ...opts, science: true }));
      for (const it of got) {
        it.group = 'science';
        it.kind = 'science';
        items.push(it);
      }
      pushStat(stat);
    }
  }

  return { items, stats };
}

export { parseDate };
