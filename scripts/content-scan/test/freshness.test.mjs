import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { isFreshForScan, isFreshForTable } from '../lib/freshness.mjs';
import { missingOptionalColumn } from '../lib/publish.mjs';

const NOW = Date.parse('2026-11-19T06:00:00.000Z');
const daysAgo = (n) => new Date(NOW - n * 86400000).toISOString();

describe('güncellik filtresi', () => {
  it('tarihsiz kayıt alınmaz', () => {
    assert.equal(isFreshForScan({ date: null }, NOW), false);
  });
  it('7 günden eski alınmaz, 6 günlük alınır', () => {
    assert.equal(isFreshForScan({ date: daysAgo(8) }, NOW), false);
    assert.equal(isFreshForScan({ date: daysAgo(6) }, NOW), true);
  });
  it('haber tablosu için 3 gün sınırı', () => {
    assert.equal(isFreshForTable('news_candidates', { date: daysAgo(4) }, NOW), false);
    assert.equal(isFreshForTable('news_candidates', { date: daysAgo(2) }, NOW), true);
    assert.equal(isFreshForTable('useful_content', { date: daysAgo(5) }, NOW), true);
  });
});

describe('eksik kolon ayıklama', () => {
  it('PGRST204 mesajından opsiyonel kolonu bulur', () => {
    const msg = `Supabase POST news_candidates: 400 {"code":"PGRST204","message":"Could not find the 'ai_generated' column of 'news_candidates' in the schema cache"}`;
    assert.equal(missingOptionalColumn(msg), 'ai_generated');
  });
  it('opsiyonel olmayan kolonu döndürmez', () => {
    assert.equal(missingOptionalColumn("Could not find the 'title' column"), null);
  });
});
