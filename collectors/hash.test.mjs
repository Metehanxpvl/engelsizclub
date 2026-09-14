import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  hasRelevanceKeyword,
  isDisabilityOpportunity,
  isDuplicate,
  stripHtml,
  usefulContentHash,
} from './lib/hash.mjs';

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
    assert.equal(hasRelevanceKeyword('Engelli bakım aylığı'), true);
    assert.equal(hasRelevanceKeyword('Hava durumu'), false);
    assert.equal(hasRelevanceKeyword("Bursa Büyükşehir Belediyespor’dan galibiyet"), false);
    assert.equal(hasRelevanceKeyword('TÜBİTAK 1001 çağrısı açıldı'), false);
    assert.equal(hasRelevanceKeyword('İŞKUR genel iş ilanları'), false);
    assert.equal(hasRelevanceKeyword('Belediye konseri'), false);
  });

  it('keeps özel gereksinimli without the word engelli', () => {
    assert.equal(
      isDisabilityOpportunity('Özel gereksinimli öğrencilere destek eğitimi'),
      true,
    );
    assert.equal(isDisabilityOpportunity('Kaynaştırma öğrencisi kayıt duyurusu'), true);
    assert.equal(isDisabilityOpportunity('Otizm spektrum bozukluğu farkındalık günü'), true);
    assert.equal(isDisabilityOpportunity('Down sendromlu çocuklar için etkinlik'), true);
    assert.equal(isDisabilityOpportunity('BEP uygulaması hakkında veli toplantısı'), true);
    assert.equal(
      isDisabilityOpportunity('serebral palsi rehabilitasyon'),
      true,
    );
    assert.equal(isDisabilityOpportunity('down sendromu farkındalık'), true);
    assert.equal(isDisabilityOpportunity('Serebral paldi fizik tedavi'), true);
    assert.equal(isDisabilityOpportunity('Trizomi 21 farkındalık yürüyüşü'), true);
    assert.equal(isDisabilityOpportunity('Cerebral palsy family support'), true);
  });

  it('rejects İŞKUR / generic burs with no disability terms', () => {
    assert.equal(isDisabilityOpportunity('İŞKUR iş ilanı'), false);
    assert.equal(isDisabilityOpportunity('İŞKUR iş ilanı genel personel alımı'), false);
    assert.equal(hasRelevanceKeyword('Belediye asfalt ihalesi tamamlandı'), false);
    assert.equal(hasRelevanceKeyword('Genel istihdam ve kota duyurusu'), false);
    assert.equal(hasRelevanceKeyword('Rehabilitasyon merkezi fizik tedavi'), false);
    assert.equal(hasRelevanceKeyword('Evde bakım hizmeti yaşlılara'), false);
  });
});
