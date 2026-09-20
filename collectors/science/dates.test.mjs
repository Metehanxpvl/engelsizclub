import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  LOOKBACK_YEARS,
  RELDATE_DAYS,
  filterRecentItems,
  isWithinLookback,
  lookbackStartYmd,
  pubmedMaxdate,
  pubmedMindate,
  scienceDateWindow,
  shouldDropOlder,
  utcYmd,
} from './dates.mjs';

const NOW = new Date('2026-09-15T12:00:00.000Z');

describe('1-year science date window', () => {
  it('uses 1 year / 365 reldate and calendar start', () => {
    assert.equal(LOOKBACK_YEARS, 1);
    assert.equal(RELDATE_DAYS, 365);
    const win = scienceDateWindow(NOW);
    assert.equal(win.start, '2025-09-15');
    assert.equal(win.end, '2026-09-15');
    assert.equal(win.reldateDays, 365);
    assert.equal(win.pubmedMindate, '2025/09/15');
    assert.equal(win.pubmedMaxdate, '2026/09/15');
    assert.equal(lookbackStartYmd(NOW), '2025-09-15');
    assert.equal(pubmedMindate(NOW), '2025/09/15');
    assert.equal(pubmedMaxdate(NOW), '2026/09/15');
    assert.equal(utcYmd(NOW), '2026-09-15');
  });

  it('keeps dates on/after the cutoff and drops older', () => {
    assert.equal(isWithinLookback('2025-09-15', NOW), true);
    assert.equal(isWithinLookback('2026-06-12', NOW), true);
    assert.equal(isWithinLookback('2025-09-14', NOW), false);
    assert.equal(isWithinLookback('2024-09-15', NOW), false);
    assert.equal(isWithinLookback('2019-01-01', NOW), false);
    assert.equal(isWithinLookback('2025', NOW), true);
    assert.equal(isWithinLookback('2025-01-01', NOW), true);
    assert.equal(isWithinLookback('2024', NOW), false);
    assert.equal(isWithinLookback('20250915', NOW), true);
    assert.equal(isWithinLookback('', NOW), null);
  });

  it('drops older items on insert using publication/start date', () => {
    assert.equal(
      shouldDropOlder({ publicationDate: '2018-03-01' }, NOW),
      true,
    );
    assert.equal(
      shouldDropOlder({ publicationDate: '2026-01-01' }, NOW),
      false,
    );
    assert.equal(
      shouldDropOlder({ startDate: '2020-12-31' }, NOW),
      true,
    );
    assert.equal(
      shouldDropOlder({ lastUpdatePostDate: '2022-01-01' }, NOW),
      true,
    );
    assert.equal(shouldDropOlder({ title: 'no date' }, NOW), false);
    const kept = filterRecentItems(
      [
        { title: 'old', publicationDate: '2024-01-01' },
        { title: 'new', publicationDate: '2026-01-01' },
      ],
      NOW,
    );
    assert.equal(kept.length, 1);
    assert.equal(kept[0].title, 'new');
  });
});
