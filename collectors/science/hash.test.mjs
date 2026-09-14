import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  isDuplicate,
  normalizeDoi,
  remember,
  researchContentHash,
} from './hash.mjs';

describe('researchContentHash', () => {
  it('is stable for the same payload', () => {
    const a = researchContentHash({
      title: ' Cerebral Palsy Trial ',
      pmid: '38700001',
      nctId: '',
      doi: 'https://doi.org/10.1000/XYZ',
      sourceUrl: 'https://pubmed.ncbi.nlm.nih.gov/38700001/',
    });
    const b = researchContentHash({
      title: 'cerebral palsy trial',
      pmid: '38700001',
      nctId: '',
      doi: '10.1000/xyz',
      sourceUrl: 'https://pubmed.ncbi.nlm.nih.gov/38700001/',
    });
    assert.equal(a, b);
    assert.equal(a.length, 64);
  });

  it('changes when pmid changes', () => {
    const a = researchContentHash({ title: 't', pmid: '1' });
    const b = researchContentHash({ title: 't', pmid: '2' });
    assert.notEqual(a, b);
  });
});

describe('normalizeDoi', () => {
  it('strips doi.org prefix', () => {
    assert.equal(normalizeDoi('https://doi.org/10.1000/Abc'), '10.1000/abc');
    assert.equal(normalizeDoi('doi:10.1000/Abc'), '10.1000/abc');
  });
});

describe('isDuplicate', () => {
  it('dedups by pmid, nct, doi, url, hash', () => {
    const existing = {
      pmids: new Set(),
      ncts: new Set(),
      dois: new Set(),
      urls: new Set(),
      hashes: new Set(),
    };
    remember(existing, {
      pmid: '111',
      nctId: 'NCT00000001',
      doi: '10.1/x',
      sourceUrl: 'https://example.test/a',
      contentHash: 'abc',
    });
    assert.equal(isDuplicate(existing, { pmid: '111' }), true);
    assert.equal(isDuplicate(existing, { nctId: 'NCT00000001' }), true);
    assert.equal(isDuplicate(existing, { doi: 'https://doi.org/10.1/x' }), true);
    assert.equal(isDuplicate(existing, { sourceUrl: 'https://example.test/a' }), true);
    assert.equal(isDuplicate(existing, { contentHash: 'abc' }), true);
    assert.equal(
      isDuplicate(existing, {
        pmid: '222',
        nctId: 'NCT9',
        doi: '10.9/z',
        sourceUrl: 'https://example.test/b',
        contentHash: 'zzz',
      }),
      false,
    );
  });
});
