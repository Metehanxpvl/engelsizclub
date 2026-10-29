import assert from 'node:assert/strict';
import { test } from 'node:test';

import { heuristicCategory, routeRecord } from '../lib/route.mjs';
import { buildPayload } from '../lib/publish.mjs';
import { loadScanConfig } from '../lib/config.mjs';
import { normalizeEnrichment } from '../lib/enrich.mjs';

test('haber / fırsat / destek / bilim doğru tabloya gider', () => {
  assert.equal(routeRecord({ category: 'haber' }).table, 'news_candidates');
  assert.equal(routeRecord({ category: 'firsat', subcategory: 'burs' }).table, 'useful_content');
  assert.equal(routeRecord({ category: 'firsat', subcategory: 'burs' }).usefulCategory, 'burs');
  assert.equal(routeRecord({ category: 'destek', subcategory: 'mevzuat' }).usefulCategory, 'hak');
  assert.equal(routeRecord({ category: 'bilim' }).table, 'scientific_researches');
});

test('heuristic burs and maaş routing', () => {
  assert.equal(heuristicCategory({ title: 'Engelli burs başvurusu açıldı' }), 'firsat');
  assert.equal(heuristicCategory({ title: 'Engelli maaşı yattı' }), 'destek');
  assert.equal(heuristicCategory({ title: 'Engelli spor haberi', group: 'science' }), 'bilim');
});

test('payload matches existing pending schemas', () => {
  const { sources } = loadScanConfig();
  const news = buildPayload(
    {
      title: 'Engelli kartı düzenlemesi',
      url: 'https://www.resmigazete.gov.tr/x',
      canonical_url: 'https://resmigazete.gov.tr/x',
      source: 'Resmi Gazete',
      summary_tr: 'Özet',
      category: 'haber',
      content_hash: 'abc',
      title_fingerprint: 'engelli karti',
      confidence: 0.9,
      risk_flag: false,
    },
    sources,
    false,
  );
  assert.equal(news.table, 'news_candidates');
  assert.equal(news.row.status, 'pending');
  assert.ok(news.row.canonical_url);
  assert.ok(news.row.content_hash);

  const firsat = buildPayload(
    {
      title: 'KOSGEB engelli hibe',
      url: 'https://www.kosgeb.gov.tr/h',
      canonical_url: 'https://kosgeb.gov.tr/h',
      source: 'KOSGEB',
      summary_tr: 'Özet',
      category: 'firsat',
      subcategory: 'hibe',
      deadline: '2026-12-01',
      content_hash: 'def',
      city: 'Ulusal',
      confidence: 0.7,
    },
    sources,
    false,
  );
  assert.equal(firsat.table, 'useful_content');
  assert.equal(firsat.row.status, 'pending_review');
  assert.equal(firsat.row.category, 'firsat');

  const bilim = buildPayload(
    {
      title: 'Cerebral palsy trial',
      url: 'https://pubmed.ncbi.nlm.nih.gov/1/',
      canonical_url: 'https://pubmed.ncbi.nlm.nih.gov/1/',
      source: 'PubMed',
      summary_tr: 'Çalışmada şu görüldü.',
      category: 'bilim',
      evidence_level: 'faz2',
      content_hash: 'ghi',
      pmid: '1',
    },
    sources,
    false,
  );
  assert.equal(bilim.table, 'scientific_researches');
  assert.equal(bilim.row.status, 'pending_review');
  assert.equal(bilim.row.evidence_level, 'faz2');
  assert.ok(['HIGH_VALUE', 'POTENTIAL_VALUE'].includes(bilim.row.treatment_potential));
});

test('auto_approve stays off by default even for resmi kaynak', () => {
  const { sources } = loadScanConfig();
  const built = buildPayload(
    {
      title: 'SGK duyuru',
      url: 'https://www.sgk.gov.tr/x',
      canonical_url: 'https://sgk.gov.tr/x',
      source: 'SGK',
      summary_tr: 'Özet',
      category: 'destek',
      content_hash: 'zzz',
      confidence: 0.95,
      risk_flag: false,
    },
    sources,
    false,
  );
  assert.equal(built.row.status, 'pending_review');
});

test('enrichment normalizer fills science evidence', () => {
  const out = normalizeEnrichment({ category: 'bilim', confidence: 0.6 }, { kind: 'science' });
  assert.equal(out.evidence_level, 'arastirma-asamasi');
  assert.equal(out.ai_generated, true);
});
