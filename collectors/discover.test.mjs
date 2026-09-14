import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  discoverRssLinks,
  extractDisabilityListings,
  robotsBlocksAll,
} from './lib/discover.mjs';
import { looksLikeHtml, looksLikeRssOrAtom, parseRssOrAtom } from './lib/rss.mjs';
import { isDisabilityOpportunity } from './lib/hash.mjs';

describe('discoverRssLinks', () => {
  it('reads rel=alternate RSS href', () => {
    const html = `
      <link rel="alternate" type="application/rss+xml" title="Haberler" href="/feed/" />
      <a href="/rss.xml">RSS</a>
    `;
    const links = discoverRssLinks(html, 'https://www.bolu.bel.tr/');
    assert.ok(links.includes('https://www.bolu.bel.tr/feed/'));
    assert.ok(links.includes('https://www.bolu.bel.tr/rss.xml'));
  });
});

describe('extractDisabilityListings', () => {
  it('keeps disability news titles only', () => {
    const html = `
      <a href="/haberler/engelli-rampasi">Engelli rampası açıldı</a>
      <a href="/haberler/spor-galibiyet">Belediyespor’dan galibiyet</a>
      <a href="/duyurular/konser">Yaz konseri</a>
    `;
    const items = extractDisabilityListings(html, 'https://www.example.bel.tr/');
    assert.equal(items.length, 1);
    assert.equal(items[0].sourceUrl, 'https://www.example.bel.tr/haberler/engelli-rampasi');
  });

  it('keeps özel gereksinimli titles that never say engelli', () => {
    const html = `
      <a href="/haberler/ozel-gereksinimli-destek">Özel gereksinimli öğrencilere tablet</a>
      <a href="/haberler/iskur-ilan">İŞKUR iş ilanı</a>
      <a href="/duyurular/asfalt">Asfalt çalışması başladı</a>
    `;
    const items = extractDisabilityListings(html, 'https://www.example.bel.tr/');
    assert.equal(items.length, 1);
    assert.equal(
      items[0].sourceUrl,
      'https://www.example.bel.tr/haberler/ozel-gereksinimli-destek',
    );
    assert.equal(isDisabilityOpportunity(items[0].title), true);
    assert.equal(isDisabilityOpportunity('İŞKUR iş ilanı'), false);
  });
});

describe('robotsBlocksAll', () => {
  it('blocks only Disallow:/ for *', () => {
    assert.equal(robotsBlocksAll('User-agent: *\nDisallow: /\n'), true);
    assert.equal(robotsBlocksAll('User-agent: *\nDisallow: /admin\n'), false);
    assert.equal(robotsBlocksAll('User-agent: Googlebot\nDisallow: /\n'), false);
  });
});

describe('rss enclosure', () => {
  it('picks image enclosure without storing HTML', () => {
    const xml = `<?xml version="1.0"?><rss version="2.0"><channel>
      <item>
        <title>Özel eğitim duyurusu</title>
        <link>https://orgm.meb.gov.tr/haber/1</link>
        <description>Engelli öğrenciler için</description>
        <enclosure url="https://cdn.example/a.jpg" type="image/jpeg" />
      </item>
    </channel></rss>`;
    const items = parseRssOrAtom(xml);
    assert.equal(items.length, 1);
    assert.equal(items[0].imageUrl, 'https://cdn.example/a.jpg');
    assert.equal(looksLikeRssOrAtom(xml), true);
    assert.equal(looksLikeHtml(xml), false);
    assert.equal(isDisabilityOpportunity(items[0].title), true);
  });
});
