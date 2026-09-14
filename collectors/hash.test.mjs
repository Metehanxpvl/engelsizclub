import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  classifyKeep,
  hasPotentialFamilyBenefit,
  hasRelevanceKeyword,
  hasScholarshipTerm,
  isDisabilityOpportunity,
  isDuplicate,
  isHardReject,
  shouldKeepCandidate,
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

  it('dedups similar title + source', () => {
    const existing = {
      urls: new Set(),
      hashes: new Set(),
      externalIds: new Set(),
      titleKeys: new Set(['sosyal yardim basvurusu basladi|adana bb']),
    };
    assert.equal(
      isDuplicate(existing, {
        title: 'Sosyal Yardım Başvurusu Başladı',
        sourceName: 'Adana BB',
        sourceUrl: 'https://www.adana.bel.tr/haberler/2',
      }),
      true,
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
    assert.equal(
      isDisabilityOpportunity('Evde Bakım Yardımı ödemeleri hesaplara yatırıldı'),
      true,
    );
    assert.equal(isDisabilityOpportunity('EYHGM erişilebilirlik duyurusu'), true);
    assert.equal(isDisabilityOpportunity('ÇÖZGER raporu başvurusu'), true);
  });

  it('rejects İŞKUR / generic burs with no disability terms', () => {
    assert.equal(isDisabilityOpportunity('İŞKUR iş ilanı'), false);
    assert.equal(isDisabilityOpportunity('İŞKUR iş ilanı genel personel alımı'), false);
    assert.equal(hasRelevanceKeyword('Belediye asfalt ihalesi tamamlandı'), false);
    assert.equal(hasRelevanceKeyword('Genel istihdam ve kota duyurusu'), false);
    assert.equal(hasRelevanceKeyword('Rehabilitasyon merkezi fizik tedavi'), false);
    assert.equal(hasRelevanceKeyword('Evde bakım hizmeti yaşlılara'), false);
  });

  it('keeps burs only with a disability / özel gereksinim core term', () => {
    assert.equal(isDisabilityOpportunity('engellilere burs'), true);
    assert.equal(isDisabilityOpportunity('engellilere burs başvurusu'), true);
    assert.equal(isDisabilityOpportunity('engelli öğrencilerine burs'), true);
    assert.equal(isDisabilityOpportunity('özel gereksinimli burs'), true);
    assert.equal(isDisabilityOpportunity('özel gereksinimli öğrencilere burs'), true);
    assert.equal(isDisabilityOpportunity('down sendromlu çocuklara burs'), true);
    assert.equal(isDisabilityOpportunity('serebral palsili öğrencilere burs'), true);
    assert.equal(hasScholarshipTerm('engellilere burs başvurusu'), true);
    assert.equal(isDisabilityOpportunity('üniversite burs başvurusu'), false);
    assert.equal(isDisabilityOpportunity('KYK burs sonuçları açıklandı'), false);
    assert.equal(isDisabilityOpportunity('İŞKUR burs başvurusu'), false);
    assert.equal(isDisabilityOpportunity('belediye spor bursu'), false);
    assert.equal(hasScholarshipTerm('üniversite burs başvurusu'), true);
    assert.equal(hasScholarshipTerm("Bursa Büyükşehir Belediyespor’dan galibiyet"), false);
  });
});

describe('classifyKeep phase 2', () => {
  it('rejects asfalt / yol / atama without benefit', () => {
    assert.equal(classifyKeep('Asfalt çalışması başladı'), null);
    assert.equal(classifyKeep('Yol çalışması nedeniyle güzergah değişikliği'), null);
    assert.equal(classifyKeep('Personel atama duyurusu'), null);
    assert.equal(classifyKeep('Belediye başkanı açıklama yaptı'), null);
    assert.equal(isHardReject('Asfalt çalışması başladı'), true);
  });

  it('keeps sosyal yardım as potential without engelli', () => {
    assert.equal(classifyKeep('Sosyal yardım başvurusu başladı'), 'potential');
    assert.equal(hasPotentialFamilyBenefit('Nakdi yardım ödemeleri yatıyor'), true);
    assert.equal(classifyKeep('Dar gelirli ailelere maddi destek'), 'potential');
    assert.equal(classifyKeep('Ücretsiz ulaşım kartı başvuruları açıldı'), 'potential');
    assert.equal(shouldKeepCandidate('Sosyal yardım başvurusu başladı'), true);
  });

  it('keeps burs / ücretsiz kurs / başvuru without engelli, still dumps asfalt', () => {
    assert.equal(classifyKeep('üniversite burs başvurusu'), 'potential');
    assert.equal(classifyKeep('KYK burs sonuçları açıklandı'), 'potential');
    assert.equal(classifyKeep('Ücretsiz kurs kayıtları başladı'), 'potential');
    assert.equal(classifyKeep('Başvurular başladı'), 'potential');
    assert.equal(isDisabilityOpportunity('üniversite burs başvurusu'), false);
    assert.equal(classifyKeep('İhale ilanı başvurusu'), null);
    assert.equal(classifyKeep('Asfalt çalışması başladı'), null);
  });
});
