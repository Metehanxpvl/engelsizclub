import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  EMPTY_SOURCES_SQL_HINT,
  TABLES_SQL_HINT,
  fallbackSources,
} from './config.mjs';

describe('fallbackSources', () => {
  it('covers PubMed E-utilities and ClinicalTrials v2', () => {
    const src = fallbackSources();
    assert.equal(src.length, 2);
    assert.match(src[0].url, /eutils\.ncbi\.nlm\.nih\.gov\/entrez\/eutils/);
    assert.equal(src[1].url, 'https://clinicaltrials.gov/api/v2/studies');
    assert.equal(src.every((s) => s.fallback === true && !s.id), true);
  });

  it('SQL hints name the file to run', () => {
    assert.match(EMPTY_SOURCES_SQL_HINT, /scientific_researches\.sql/);
    assert.match(EMPTY_SOURCES_SQL_HINT, /is_active/);
    assert.match(TABLES_SQL_HINT, /scientific_researches\.sql/);
  });
});
