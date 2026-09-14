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
  it('accepts only aile.gov.tr /eyhgm paths', () => {
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/eyhgm'), true);
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/eyhgm/haberler'), true);
    assert.equal(isAileEyhgmSourceUrl('https://www.aile.gov.tr/'), false);
    assert.equal(isAileEyhgmSourceUrl('https://orgm.meb.gov.tr/'), false);
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
});
