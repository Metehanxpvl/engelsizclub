import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  aileEyhgmListingUrls,
  extractAileEyhgmListings,
  isAileEyhgmSourceUrl,
} from './lib/aile_eyhgm.mjs';
import { isDisabilityOpportunity } from './lib/hash.mjs';

const FIXTURE = `
<div class="card-deck">
  <a href="/eyhgm/haberler/evde-bakim-yardimi-hesaplara-yatirildi/" title="Evde Bakım Yardımı hesaplara yatırıldı">
    <img src="/media/1.jpg" alt="" />
    <h6 class="card-title">Evde Bakım Yardımı hesaplara yatırıldı</h6>
    <div class="card-link">Haberin Detayı</div>
  </a>
  <a href="/eyhgm/haberler/bakanimiz-goktas-agri-da-terorsuz-turkiye-sureciyle-ilgili-konustu/" title="Bakanımız Göktaş, Ağrı'da Terörsüz Türkiye süreciyle ilgili konuştu">
    <h6 class="card-title">Bakanımız Göktaş, Ağrı'da Terörsüz Türkiye süreciyle ilgili konuştu</h6>
  </a>
  <a href="/eyhgm/haberler/konya-da-engelli-aktif-yasam-merkezi-acilisinda-konustu/" title="Konya'da engelli aktif yaşam merkezi açılışında konuştu">
    <h6 class="card-title">Konya'da engelli aktif yaşam merkezi açılışında konuştu</h6>
  </a>
  <a href="/eyhgm/duyurular/2026-ekpss-kura-ile-engelli-kamu-personeli-yerlestirmeleri-icin-tercih-islemleri-basladi/" title="2026-EKPSS/Kura ile Engelli Kamu Personeli Yerleştirmeleri için Tercih İşlemleri Başladı">
    <h6 class="card-title">2026-EKPSS/Kura ile Engelli Kamu Personeli Yerleştirmeleri için Tercih İşlemleri Başladı</h6>
  </a>
  <a href="/eyhgm/haberler">Hepsini Görüntüle</a>
  <a href="/eyhgm/haberler/engelsiz-yasam-parki-acildi/">Haberin Detayı</a>
</div>
`;

describe('isAileEyhgmSourceUrl', () => {
  it('accepts EYHGM paths and bakanlık /duyurular, not homepage', () => {
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/eyhgm'), true);
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/eyhgm/haberler'), true);
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/duyurular'), true);
    assert.equal(isAileEyhgmSourceUrl('https://aile.gov.tr/duyurular'), true);
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/'), false);
    assert.equal(isAileEyhgmSourceUrl('https://orgm.meb.gov.tr/'), false);
    assert.equal(
      isAileEyhgmSourceUrl('https://ailecocuk.aile.gov.tr/dergimiz?lang=tr'),
      false,
    );
  });
});

describe('aileEyhgmListingUrls', () => {
  it('expands the GM homepage to haberler + duyurular', () => {
    assert.deepEqual(aileEyhgmListingUrls('https://www.aile.gov.tr/eyhgm'), [
      'https://www.aile.gov.tr/eyhgm/haberler',
      'https://www.aile.gov.tr/eyhgm/duyurular',
    ]);
    assert.deepEqual(aileEyhgmListingUrls('https://www.aile.gov.tr/eyhgm/haberler'), [
      'https://www.aile.gov.tr/eyhgm/haberler',
    ]);
    assert.deepEqual(aileEyhgmListingUrls('https://aile.gov.tr/duyurular'), [
      'https://www.aile.gov.tr/duyurular',
    ]);
  });
});

describe('extractAileEyhgmListings', () => {
  it('keeps disability / evde bakım yardımı / EKPSS cards, drops generic bakan news', () => {
    const items = extractAileEyhgmListings(FIXTURE, 'https://www.aile.gov.tr/eyhgm/haberler');
    const urls = items.map((i) => i.sourceUrl);
    assert.ok(
      urls.includes(
        'https://www.aile.gov.tr/eyhgm/haberler/evde-bakim-yardimi-hesaplara-yatirildi/',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.aile.gov.tr/eyhgm/haberler/konya-da-engelli-aktif-yasam-merkezi-acilisinda-konustu/',
      ),
    );
    assert.ok(
      urls.includes(
        'https://www.aile.gov.tr/eyhgm/duyurular/2026-ekpss-kura-ile-engelli-kamu-personeli-yerlestirmeleri-icin-tercih-islemleri-basladi/',
      ),
    );
    assert.equal(
      urls.some((u) => u.includes('terorsuz-turkiye')),
      false,
    );
    assert.equal(
      urls.includes('https://www.aile.gov.tr/eyhgm/haberler'),
      false,
    );
    assert.equal(items.every((i) => isDisabilityOpportunity(i.title)), true);
  });

  it('parses bakanlık /duyurular cards and keeps EKPSS, drops personel alımı', () => {
    const html = `
<article id="anouncements-list">
  <div class="announcement-col">
    <a href="/duyurular/2026-1-ekpss-kura-ile-engelli-kamu-personeli-yerlestirme-sonucu/" title="2026-1 EKPSS/Kura ile Engelli Kamu Personeli Yerleştirme Sonucu">
      <div class="date">
        <span class="day">14</span>
        <span class="moon">Eylül</span>
        <span class="year">2026</span>
      </div>
      <span class="title">2026-1 EKPSS/Kura ile Engelli Kamu Personeli Yerleştirme Sonucu</span>
    </a>
  </div>
  <div class="announcement-col">
    <a href="/duyurular/aile-ve-sosyal-hizmetler-bakanligi-680-sozlesmeli-personel-alim-ilani/" title="680 Sözleşmeli Personel Alım İlanı">
      <span class="title">680 Sözleşmeli Personel Alım İlanı</span>
    </a>
  </div>
  <a href="/duyurular">Duyurular</a>
</article>`;
    const items = extractAileEyhgmListings(html, 'https://www.aile.gov.tr/duyurular');
    const urls = items.map((i) => i.sourceUrl);
    assert.ok(
      urls.includes(
        'https://www.aile.gov.tr/duyurular/2026-1-ekpss-kura-ile-engelli-kamu-personeli-yerlestirme-sonucu/',
      ),
    );
    assert.equal(
      urls.some((u) => u.includes('sozlesmeli-personel')),
      false,
    );
    assert.equal(urls.includes('https://www.aile.gov.tr/duyurular'), false);
    assert.equal(items[0].publishedAt.slice(0, 10), '2026-09-14');
  });
});
