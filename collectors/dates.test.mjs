import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  evaluateFreshness,
  pickContentDate,
  recentCutoffYmd,
  utcYmd,
} from './lib/content_dates.mjs';

const NOW = new Date('2026-09-15T12:00:00.000Z');

describe('useful-content recency window', () => {
  it('cutoff for 2026-09-15 is 2026-08-31', () => {
    assert.equal(utcYmd(NOW), '2026-09-15');
    assert.equal(recentCutoffYmd(NOW, 15), '2026-08-31');
  });

  it('10-day news KEEP', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli rampası yenilendi',
        publishedAt: '2026-09-05T08:00:00.000Z',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.contentKind, 'recent');
    assert.equal(d.dateStatus, 'recent');
    assert.equal(d.publishedAt.slice(0, 10), '2026-09-05');
  });

  it('40-day news no deadline REJECT', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli rampası yenilendi',
        publishedAt: '2026-08-06T08:00:00.000Z',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'reject');
    assert.equal(d.reason, 'older_than_15_days');
    assert.equal(d.contentKind, null);
  });

  it('40-day news deadline future KEEP', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli bursu başvuruları',
        publishedAt: '2026-08-06T08:00:00.000Z',
        deadlineAt: '2026-10-01',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.contentKind, 'active_opportunity');
    assert.equal(d.isActiveOpportunity, true);
    assert.equal(d.dateStatus, 'older');
  });

  it('event future KEEP', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli spor şenliği etkinlik tarihi 20 Ekim 2026',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.contentKind, 'active_opportunity');
    assert.ok(d.eventAt);
    assert.equal(d.eventAt.slice(0, 10), '2026-10-20');
  });

  it('event past REJECT', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli spor şenliği etkinlik tarihi 1 Ağustos 2026',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'reject');
    assert.equal(d.reason, 'past_event');
  });

  it('crawl date is not used as published_at', () => {
    const d = evaluateFreshness(
      {
        title: 'Engelli rampası yenilendi',
        last_checked_at: '2026-09-15T12:00:00.000Z',
        lastFetchedAt: '2026-09-15T12:00:00.000Z',
        crawledAt: '2026-09-15T12:00:00.000Z',
      },
      { now: NOW },
    );
    assert.equal(d.publishedAt, null);
    assert.equal(d.dateStatus, 'unknown');
    assert.equal(d.isRecent, false);
    assert.equal(d.action, 'skip');

    const picked = pickContentDate({
      last_checked_at: '2026-09-15T12:00:00.000Z',
      lastFetchedAt: '2026-09-15T12:00:00.000Z',
      sitemapLastmod: '2026-09-14',
      dateSource: 'sitemap_lastmod',
      publishedAt: '2026-09-14T00:00:00.000Z',
    });
    assert.equal(picked.contentAt, null);
    assert.equal(picked.publishedAt, null);
  });

  it('reliable updated_at within 15 days is RECENT', () => {
    const d = evaluateFreshness(
      {
        title: 'Sosyal yardım duyurusu',
        publishedAt: '2026-01-10T00:00:00.000Z',
        updatedAt: '2026-09-10T00:00:00.000Z',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.contentKind, 'recent');
    assert.equal(d.reason, 'updated_recent');
  });

  it('unknown date without open opportunity is skipped, not treated recent', () => {
    const d = evaluateFreshness(
      { title: 'Engelli rampası yenilendi' },
      { now: NOW },
    );
    assert.equal(d.dateStatus, 'unknown');
    assert.equal(d.action, 'skip');
    assert.equal(d.isRecent, false);
  });

  it('unknown date with clearly open burs is ACTIVE_OPPORTUNITY', () => {
    const d = evaluateFreshness(
      { title: 'Engelli bursu başvuruları devam ediyor' },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.contentKind, 'active_opportunity');
    assert.equal(d.dateStatus, 'unknown');
  });

  it('ASHB Aile Çocuk magazine issues on the listing are treated recent', () => {
    const d = evaluateFreshness(
      {
        title: 'Aile Çocuk Dergisi Sayı 14',
        listingKind: 'magazine_issue',
      },
      { now: NOW },
    );
    assert.equal(d.action, 'keep');
    assert.equal(d.reason, 'magazine_listing');
    assert.equal(d.dateStatus, 'recent');
  });
});
