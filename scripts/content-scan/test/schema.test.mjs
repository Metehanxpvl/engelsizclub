import assert from 'node:assert/strict';
import { test } from 'node:test';

import { loadScanConfig, newsQueries, scienceQueries } from '../lib/config.mjs';

test('sources.json keeps required keys and 30+ catalog rows', () => {
  const { sources } = loadScanConfig();
  assert.ok(sources.google_news.template.includes('{q}'));
  assert.ok(Array.isArray(sources.google_news.queries));
  assert.ok(sources.google_news.queries.includes('engelli'));
  assert.ok(sources.official_via_news.queries.some((q) => q.includes('aile.gov.tr')));
  assert.ok(sources.science.openalex.includes('openalex.org'));
  assert.ok(sources.science.pubmed.includes('pubmed'));
  assert.ok(sources.science.clinicaltrials.includes('clinicaltrials.gov'));
  assert.ok(sources.trust.resmi.includes('gov.tr'));
  assert.ok(sources.gdelt.url.includes('gdeltproject.org'));
  assert.ok(sources.dergipark.oai.includes('dergipark.org.tr'));
  assert.ok((sources.catalog || []).length >= 30);
});

test('conditions drive extra news and science queries', () => {
  const { sources, conditions } = loadScanConfig();
  const news = newsQueries(sources, conditions);
  const sci = scienceQueries(sources, conditions);
  assert.ok(news.some((q) => q.id === 'cond:otizm'));
  assert.ok(sci.some((q) => q.id === 'cp' && /cerebral palsy/i.test(q.q)));
  assert.equal(conditions.length, 13);
});
