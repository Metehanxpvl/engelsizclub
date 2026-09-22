import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  VALILIK_BATCH_SIZE,
  parseValilikCatalog,
  pickValilikBatch,
  toValilikScrapeSource,
  valilikBatchIndex,
} from './lib/valilikler.mjs';

const SAMPLE = {
  source: 'engelsiz-club-valilikler',
  count: 2,
  items: [
    {
      plate: '01',
      city: 'Adana',
      slug: 'adana',
      url: 'https://www.adana.gov.tr',
      duyurular_url: 'https://www.adana.gov.tr/duyurular',
      engelli_url: 'https://www.adana.gov.tr/engelli',
    },
    {
      plate: '34',
      city: 'İstanbul',
      url: 'https://www.istanbul.gov.tr/',
    },
  ],
};

describe('parseValilikCatalog', () => {
  it('keeps official .gov.tr rows and fills listing paths', () => {
    const items = parseValilikCatalog(JSON.stringify(SAMPLE));
    assert.equal(items.length, 2);
    assert.equal(items[0].url, 'https://www.adana.gov.tr');
    assert.equal(items[1].url, 'https://www.istanbul.gov.tr');
    assert.equal(items[1].duyurular_url, 'https://www.istanbul.gov.tr/duyurular');
  });

  it('drops non-gov hosts and duplicate plates', () => {
    const items = parseValilikCatalog({
      items: [
        { plate: '01', city: 'Adana', url: 'https://evil.example' },
        { plate: '01', city: 'Adana', url: 'https://www.adana.gov.tr' },
        { plate: '01', city: 'Adana tekrar', url: 'https://www.adana.gov.tr' },
      ],
    });
    assert.equal(items.length, 1);
    assert.equal(items[0].city, 'Adana');
  });
});

describe('valilik daily batch', () => {
  it('rotates 12-city windows', () => {
    const items = Array.from({ length: 81 }, (_, i) => ({
      plate: String(i + 1).padStart(2, '0'),
      city: `Il${i + 1}`,
      url: `https://www.il${i + 1}.gov.tr`,
    }));
    const dayA = new Date('2026-09-20T00:00:00Z');
    const dayB = new Date('2026-09-21T00:00:00Z');
    const a = pickValilikBatch(items, dayA);
    const b = pickValilikBatch(items, dayB);
    assert.equal(a.length, VALILIK_BATCH_SIZE);
    assert.notEqual(a[0].plate, b[0].plate);
    assert.equal(valilikBatchIndex(dayA, 81), valilikBatchIndex(dayA, 81));
  });

  it('maps a catalog row to a scrape source without UUID', () => {
    const src = toValilikScrapeSource(SAMPLE.items[0]);
    assert.equal(src.id, 'valilik-01');
    assert.equal(src.method, 'scrape');
    assert.equal(src.city, 'Adana');
    assert.equal(src.name, 'Adana Valiliği');
    assert.ok(src.extraListingPaths.includes('/engelli'));
    assert.ok(src.extraListingPaths.includes('/burs'));
    assert.ok(src.extraListingPaths.includes('/egitim'));
    assert.ok(src.extraListingUrls.includes('https://www.adana.gov.tr/duyurular'));
    assert.ok(src.extraListingUrls.includes('https://www.adana.gov.tr/engelli'));
  });
});
