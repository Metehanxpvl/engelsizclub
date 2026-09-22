import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  aileCocukDergiListingUrls,
  extractAileCocukDergiListings,
  isAileCocukDergiSourceUrl,
} from './lib/aile_cocuk_dergi.mjs';

const FIXTURE = `
<section id="Journals">
  <a href="/media/jnpj4u2k/aile_cocuk_sayi14_smll.pdf" target="_blank">
    <img class="card-img-top" src="/media/kd1bzot5/aile-cocuk-14-sayi-kapak.jpg" alt="" />
    <h5 class="custom-title">Sayı 14</h5>
  </a>
  <a href="/media/9888/aile_cocuk_sayi13-sml.pdf" target="_blank">
    <h5 class="custom-title">Sayı 13</h5>
  </a>
  <a href="/media/9886/11-kapak-aile-cocuk.png" target="_blank">
    <h5 class="custom-title">Sayı 11</h5>
  </a>
  <a href="https://twitter.com/ailecocukdergi">Twitter</a>
</section>
`;

describe('isAileCocukDergiSourceUrl', () => {
  it('accepts the dergimiz listing, not ASHB homepage', () => {
    assert.equal(
      isAileCocukDergiSourceUrl('https://ailecocuk.aile.gov.tr/dergimiz?lang=tr'),
      true,
    );
    assert.equal(
      isAileCocukDergiSourceUrl('https://ailecocuk.aile.gov.tr/dergimiz'),
      true,
    );
    assert.equal(isAileCocukDergiSourceUrl('https://www.aile.gov.tr/duyurular'), false);
    assert.equal(isAileCocukDergiSourceUrl('https://www.aile.gov.tr/eyhgm'), false);
  });
});

describe('aileCocukDergiListingUrls', () => {
  it('keeps lang=tr on the listing URL', () => {
    assert.deepEqual(
      aileCocukDergiListingUrls('https://ailecocuk.aile.gov.tr/dergimiz?lang=tr'),
      ['https://ailecocuk.aile.gov.tr/dergimiz?lang=tr'],
    );
  });
});

describe('extractAileCocukDergiListings', () => {
  it('keeps numbered PDF issues, drops cover PNG and social links', () => {
    const items = extractAileCocukDergiListings(
      FIXTURE,
      'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr',
    );
    const urls = items.map((i) => i.sourceUrl);
    assert.ok(
      urls.includes(
        'https://ailecocuk.aile.gov.tr/media/jnpj4u2k/aile_cocuk_sayi14_smll.pdf',
      ),
    );
    assert.ok(
      urls.includes(
        'https://ailecocuk.aile.gov.tr/media/9888/aile_cocuk_sayi13-sml.pdf',
      ),
    );
    assert.equal(
      urls.some((u) => u.endsWith('.png')),
      false,
    );
    assert.equal(
      urls.some((u) => u.includes('twitter')),
      false,
    );
    assert.equal(items[0].title, 'Aile Çocuk Dergisi Sayı 14');
    assert.equal(items[0].listingKind, 'magazine_issue');
  });
});
