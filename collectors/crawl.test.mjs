import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  crawlMunicipality,
  extractListingLinks,
  mergeCommonListingUrls,
  paginationUrls,
  withSourceGuard,
} from './lib/crawl.mjs';

const HOMEPAGE = `
<!doctype html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="/rss.xml" />
</head>
<body>
<nav>
  <a href="/haberler">Haberler</a>
  <a href="/duyurular">Duyurular</a>
  <a href="/ilanlar">İlanlar</a>
  <a href="/sosyal-yardim">Sosyal Yardım</a>
  <a href="/engelsiz-yasam">Engelsiz Yaşam</a>
  <a href="/kurumsal">Kurumsal</a>
  <a href="https://other.example/haberler">Dış haber</a>
</nav>
<footer>
  <a href="/etkinlik">Etkinlik</a>
  <a href="/basvuru">Başvuru</a>
</footer>
</body>
</html>
`;

const LISTING = `
<html>
<head><link rel="next" href="/haberler?page=2" /></head>
<body>
  <a href="/haberler/engelli-rampasi">Engelli rampası yenilendi</a>
  <a href="/haberler/sosyal-yardim-basvurusu">Sosyal yardım başvurusu başladı</a>
  <a href="/haberler/asfalt-calismasi">Asfalt çalışması başladı</a>
  <a href="/haberler?page=2">2</a>
  <a href="/haberler?page=3">3</a>
  <a href="/haberler?page=4">4</a>
  <a href="/haberler?page=99">99</a>
</body>
</html>
`;

describe('extractListingLinks', () => {
  it('finds /haberler and sibling listing slugs from a homepage fixture', () => {
    const links = extractListingLinks(HOMEPAGE, 'https://www.example.bel.tr/');
    assert.ok(links.includes('https://www.example.bel.tr/haberler'));
    assert.ok(links.includes('https://www.example.bel.tr/duyurular'));
    assert.ok(links.includes('https://www.example.bel.tr/ilanlar'));
    assert.ok(links.includes('https://www.example.bel.tr/sosyal-yardim'));
    assert.ok(links.includes('https://www.example.bel.tr/engelsiz-yasam'));
    assert.equal(
      links.includes('https://www.example.bel.tr/kurumsal'),
      false,
    );
    assert.equal(
      links.includes('https://other.example/haberler'),
      false,
    );
  });

  it('probes /haberler like AVM events_url when nav omits it', () => {
    const merged = mergeCommonListingUrls('https://www.example.bel.tr', []);
    assert.ok(merged.some((u) => u.endsWith('/haberler')));
    assert.ok(merged.some((u) => u.endsWith('/duyurular')));
  });

  it('prepends valilik extraPaths before common slugs', () => {
    const merged = mergeCommonListingUrls('https://www.adana.gov.tr', [], {
      extraPaths: ['/engelli-hizmetleri', 'skip-me'],
    });
    assert.ok(merged.includes('https://www.adana.gov.tr/engelli-hizmetleri'));
    assert.equal(
      merged.includes('https://www.adana.gov.trskip-me'),
      false,
    );
  });

  it('puts catalog extraUrls first and drops other hosts', () => {
    const merged = mergeCommonListingUrls('https://www.adana.gov.tr', [], {
      extraUrls: [
        'https://www.adana.gov.tr/duyurular',
        'https://evil.example/duyurular',
      ],
    });
    assert.equal(merged[0], 'https://www.adana.gov.tr/duyurular');
    assert.equal(
      merged.includes('https://evil.example/duyurular'),
      false,
    );
  });
});

describe('paginationUrls', () => {
  it('caps extra pages at 3 and ignores archive page=99', () => {
    const urls = paginationUrls(
      LISTING,
      'https://www.example.bel.tr/haberler',
      { maxExtra: 3 },
    );
    assert.ok(urls.length <= 3);
    assert.ok(urls.some((u) => u.includes('page=2')));
    assert.equal(
      urls.some((u) => /page=99\b/.test(u)),
      false,
    );
  });
});

describe('withSourceGuard', () => {
  it('one source HTTP 500 does not abort the rest', async () => {
    const fetchText = async (url) => {
      if (url.includes('fail.bel.tr')) {
        throw new Error('HTTP 500 https://fail.bel.tr/');
      }
      if (url.endsWith('robots.txt')) {
        return 'User-agent: *\nAllow: /\n';
      }
      if (url.includes('sitemap')) {
        throw new Error('HTTP 404');
      }
      if (url.includes('/rss.xml')) {
        throw new Error('HTTP 404');
      }
      if (url.includes('/haberler')) {
        return LISTING;
      }
      return HOMEPAGE;
    };

    const failed = await withSourceGuard('fail', () =>
      crawlMunicipality(
        { id: '1', name: 'Fail BB', url: 'https://fail.bel.tr/' },
        { fetchText },
      ),
    );
    const ok = await withSourceGuard('ok', () =>
      crawlMunicipality(
        { id: '2', name: 'Ok BB', url: 'https://www.example.bel.tr/' },
        { fetchText },
      ),
    );

    assert.ok(failed.error);
    assert.match(String(failed.error), /500/);
    assert.equal((failed.items || []).length, 0);
    assert.equal(ok.error, null);
    assert.ok(
      (ok.items || []).some((it) => /haberler/.test(it.sourceUrl || '')),
      'ok source should still crawl /haberler articles',
    );
  });

  it('still finds /haberler articles when homepage nav has no listing links', async () => {
    const bareHome = '<html><body><a href="/kurumsal">Kurumsal</a></body></html>';
    const fetchText = async (url) => {
      if (url.endsWith('robots.txt')) return 'User-agent: *\nAllow: /\n';
      if (url.includes('sitemap') || url.includes('/rss')) {
        throw new Error('HTTP 404');
      }
      if (/\/haberler(\?|$)/.test(url) || url.includes('/haberler/')) {
        return LISTING;
      }
      if (url.includes('example.bel.tr') && !/\/haberler/.test(url)) {
        if (/\/(duyurular|ilanlar|haber|duyuru|sosyal|engelsiz|burs|basvuru)/.test(url)) {
          throw new Error('HTTP 404');
        }
        return bareHome;
      }
      return bareHome;
    };
    const ok = await crawlMunicipality(
      { id: '3', name: 'Bare BB', url: 'https://www.example.bel.tr/' },
      { fetchText },
    );
    assert.equal(ok.error, null);
    assert.ok(
      (ok.items || []).some((it) => /haberler\//.test(it.sourceUrl || '')),
    );
  });
});

describe('content dates vs crawl dates', () => {
  it('does not treat sitemap lastmod or lastFetchedAt as publishedAt', async () => {
    const sitemap = `<?xml version="1.0"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://www.example.bel.tr/haberler/eski-engelli-rampasi</loc>
    <lastmod>2026-09-14</lastmod>
  </url>
</urlset>`;
    const article = `<html><head><title>Eski engelli rampası</title>
<meta property="article:published_time" content="2025-01-02" />
</head><body><h1>Eski engelli rampası haberi</h1></body></html>`;
    const fetchText = async (url) => {
      if (url.endsWith('robots.txt')) return 'User-agent: *\nAllow: /\nSitemap: https://www.example.bel.tr/sitemap.xml\n';
      if (url.includes('sitemap')) return sitemap;
      if (url.includes('/rss')) throw new Error('HTTP 404');
      if (url.includes('/haberler/eski-engelli')) return article;
      if (/\/haberler(\?|$)/.test(url)) {
        return '<html><body><a href="/haberler/eski-engelli-rampasi">Eski engelli rampası haberi</a></body></html>';
      }
      if (/\/(duyurular|ilanlar|sosyal|engelsiz|burs|basvuru)/.test(url)) {
        throw new Error('HTTP 404');
      }
      return HOMEPAGE;
    };
    const crawled = await crawlMunicipality(
      { id: '9', name: 'Date BB', url: 'https://www.example.bel.tr/' },
      {
        fetchText,
        lastFetchedAt: '2026-09-15T12:00:00.000Z',
      },
    );
    const item = (crawled.items || []).find((it) =>
      /eski-engelli/.test(it.sourceUrl || ''),
    );
    assert.ok(item, 'article candidate');
    assert.equal(String(item.publishedAt || '').slice(0, 10), '2025-01-02');
    assert.notEqual(String(item.publishedAt || '').slice(0, 10), '2026-09-14');
    assert.notEqual(String(item.publishedAt || '').slice(0, 10), '2026-09-15');
  });
});
