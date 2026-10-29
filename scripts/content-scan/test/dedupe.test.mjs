import assert from 'node:assert/strict';
import { test } from 'node:test';

import { addOrMerge, emptyIndex, titleSimilarity } from '../lib/dedupe.mjs';
import { normalizeUrl } from '../lib/normalize.mjs';

test('URL tracking params drop for canonical form', () => {
  assert.equal(
    normalizeUrl('https://WWW.Example.com/haber/?utm_source=x&id=1'),
    'https://example.com/haber?id=1',
  );
});

test('fuzzy title ratio merges near-duplicate stories', () => {
  assert.ok(
    titleSimilarity(
      'Engelli aylığı hesaplara yatırıldı',
      'Engelli ayligi hesaplara yatirildi',
    ) > 0.85,
  );
});

test('same haber from two sites becomes one record with sources[]', () => {
  const index = emptyIndex();
  addOrMerge(index, {
    title: 'EKPSS tercih kılavuzu yayımlandı',
    url: 'https://a.com/ekpss',
    canonical_url: 'https://a.com/ekpss',
    source: 'A Haber',
    sources: ['A Haber'],
    raw_snippet: 'kılavuz',
  });
  const r = addOrMerge(index, {
    title: 'EKPSS tercih kilavuzu yayimlandi',
    url: 'https://b.com/ekpss',
    canonical_url: 'https://b.com/ekpss',
    source: 'B Gazete',
    sources: ['B Gazete'],
    raw_snippet: 'kılavuz',
  });
  assert.equal(r.merged, true);
  assert.equal(index.records.length, 1);
  assert.ok(index.records[0].sources.includes('A Haber'));
  assert.ok(index.records[0].sources.includes('B Gazete'));
});
