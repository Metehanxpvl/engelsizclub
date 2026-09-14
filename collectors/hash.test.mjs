import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { hasRelevanceKeyword, isDuplicate, stripHtml, usefulContentHash } from './lib/hash.mjs';

describe('stripHtml', () => {
  it('removes tags and scripts', () => {
    assert.equal(
      stripHtml('<p>Burs <b>duyurusu</b><script>alert(1)</script></p>'),
      'Burs duyurusu',
    );
  });
});

describe('hash/dedup', () => {
  it('is stable for the same payload', () => {
    const a = usefulContentHash({
      title: ' Engelli Bursu ',
      summary: 'Başvuru açık',
      sourceUrl: 'https://example.gov.tr/a',
    });
    const b = usefulContentHash({
      title: 'engelli bursu',
      summary: 'başvuru açık',
      sourceUrl: 'https://example.gov.tr/a',
    });
    assert.equal(a, b);
    assert.equal(a.length, 64);
  });

  it('dedups by url, hash, or external id', () => {
    const existing = {
      urls: new Set(['https://a.example/1']),
      hashes: new Set(['abc']),
      externalIds: new Set(['ext-1']),
    };
    assert.equal(
      isDuplicate(existing, { sourceUrl: 'https://a.example/1' }),
      true,
    );
    assert.equal(isDuplicate(existing, { contentHash: 'abc' }), true);
    assert.equal(isDuplicate(existing, { externalId: 'ext-1' }), true);
    assert.equal(
      isDuplicate(existing, { sourceUrl: 'https://b.example/2', contentHash: 'zz' }),
      false,
    );
  });

  it('matches relevance keywords', () => {
    assert.equal(hasRelevanceKeyword('Özel eğitim bursu'), true);
    assert.equal(hasRelevanceKeyword('Hava durumu'), false);
  });
});
