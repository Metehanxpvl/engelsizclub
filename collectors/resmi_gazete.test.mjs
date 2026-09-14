import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  extractResmiGazeteListings,
  isResmiGazeteSourceUrl,
  resmiGazeteListingUrls,
} from './lib/resmi_gazete.mjs';
import { isDisabilityOpportunity } from './lib/hash.mjs';

const FIXTURE = `
<div id="html-content" class="html-content">
  <div class="card-title html-title"> YÜRÜTME VE İDARE BÖLÜMÜ </div>
  <div class="html-subtitle"> YÖNETMELİKLER </div>
  <div class="fihrist-item mb-1"><a href="https://www.resmigazete.gov.tr/eskiler/2026/09/20260914-1.htm" data-modal="True">–– Türk Gıda Kodeksi Aroma Vericiler Yönetmeliği</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260914-2.htm" data-modal="True">–– Gelir Vergisi Kanununda Değişiklik Yapılmasına Dair Kanun</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260914-3.htm">–– İmar Kanunu Genel Tebliği</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260914-4.htm">–– Atama Kararnamesi</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260913-8.htm">–– Engelliler Hakkında Kanunda Değişiklik Yapılmasına Dair Kanun</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260913-9.htm">–– ÖTV Muafiyeti ile Engelli Araç Alımına Dair Tebliğ</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260912-1.htm">–– EKPSS ile Engelli Kamu Personeli Yerleştirme Yönetmeliği</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260912-2.htm">–– ÇÖZGER ve özel eğitim desteklerine dair tebliğ</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260912-3.htm">–– Evde Bakım Yardımı ödemelerine dair tebliğ</a></div>
  <div class="fihrist-item mb-1"><a href="/ilanlar/eskiilanlar/2026/09/20260914-2.htm">a - Yargı İlânı</a></div>
  <div class="fihrist-item mb-1"><a href="/ilanlar/eskiilanlar/2026/09/20260914-3.htm">b - Artırma, Eksiltme ve İhale İlânları</a></div>
  <div class="fihrist-item mb-1"><a href="/ilanlar/eskiilanlar/2026/09/20260914-4.htm">c - Çeşitli İlânlar</a></div>
  <div class="fihrist-item mb-1"><a href="/ilanlar/eskiilanlar/2026/09/20260914-5.htm">– T.C. Merkez Bankasınca Belirlenen Devlet İç Borçlanma Senetlerinin Günlük Değerleri</a></div>
  <div class="fihrist-item mb-1"><a href="/eskiler/2026/09/20260914.pdf">14 Eylül 2026 tam sayı PDF</a></div>
</div>
`;

describe('isResmiGazeteSourceUrl', () => {
  it('accepts homepage, date issue, fihrist; rejects archive and other hosts', () => {
    assert.equal(isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/'), true);
    assert.equal(isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr'), true);
    assert.equal(isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/13.09.2026'), true);
    assert.equal(
      isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/fihrist?tarih=2026-09-14'),
      true,
    );
    assert.equal(isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/rss'), true);
    assert.equal(
      isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/eskiler/2026/09/20260914-1.htm'),
      false,
    );
    assert.equal(
      isResmiGazeteSourceUrl('https://www.resmigazete.gov.tr/ilanlar/eskiilanlar/2026/09/20260914-2.htm'),
      false,
    );
    assert.equal(isResmiGazeteSourceUrl('https://www.aile.gov.tr/eyhgm'), false);
    assert.equal(isResmiGazeteSourceUrl('https://www.bolu.bel.tr/'), false);
  });
});

describe('resmiGazeteListingUrls', () => {
  it('expands homepage to today plus previous calendar days', () => {
    assert.deepEqual(
      resmiGazeteListingUrls('https://www.resmigazete.gov.tr/', {
        days: 3,
        now: new Date('2026-09-14T10:30:00+03:00'),
      }),
      [
        'https://www.resmigazete.gov.tr/',
        'https://www.resmigazete.gov.tr/13.09.2026',
        'https://www.resmigazete.gov.tr/12.09.2026',
      ],
    );
  });

  it('keeps a dated issue URL as-is', () => {
    assert.deepEqual(
      resmiGazeteListingUrls('https://www.resmigazete.gov.tr/13.09.2026'),
      ['https://www.resmigazete.gov.tr/13.09.2026'],
    );
  });
});

describe('extractResmiGazeteListings', () => {
  it('keeps disability / ÖTV-engelli / EKPSS titles, drops generic kanun and ilan indexes', () => {
    const items = extractResmiGazeteListings(
      FIXTURE,
      'https://www.resmigazete.gov.tr/',
    );
    const urls = items.map((i) => i.sourceUrl);
    assert.ok(
      urls.includes(
        'https://www.resmigazete.gov.tr/eskiler/2026/09/20260913-8.htm',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.resmigazete.gov.tr/eskiler/2026/09/20260913-9.htm',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.resmigazete.gov.tr/eskiler/2026/09/20260912-1.htm',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.resmigazete.gov.tr/eskiler/2026/09/20260912-2.htm',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.resmigazete.gov.tr/eskiler/2026/09/20260912-3.htm',
      ),
    );
    assert.equal(
      urls.some((u) => u.includes('20260914-1.htm')),
      false,
    );
    assert.equal(
      urls.some((u) => u.includes('20260914-2.htm')),
      false,
    );
    assert.equal(
      urls.some((u) => u.includes('ilanlar')),
      false,
    );
    assert.equal(
      urls.some((u) => u.endsWith('.pdf')),
      false,
    );
    assert.equal(items.every((i) => isDisabilityOpportunity(i.title)), true);
    assert.equal(isDisabilityOpportunity('Gelir Vergisi Kanununda Değişiklik'), false);
    assert.equal(isDisabilityOpportunity('İmar Kanunu Genel Tebliği'), false);
    assert.equal(isDisabilityOpportunity('Atama Kararnamesi'), false);
  });
});
