import assert from 'node:assert/strict';
import { test } from 'node:test';
import { normalizeAiResult, extractJson } from './ai-analyzer.mjs';
import {
  contentHash,
  isNearDuplicate,
  normalizeUrl,
  emptyExisting,
  remember,
  titleSimilarity,
} from './duplicate.mjs';
import { passesKeywordFilter } from './filter.mjs';
import { isWithinWindow, lookbackSinceMs, parseRssOrAtom } from './parser.mjs';
import { NEWS_SOURCES, enabledSources } from './sources.mjs';

test('sources list has the required newspapers', () => {
  const names = NEWS_SOURCES.map((s) => s.source_name);
  for (const n of [
    'Hürriyet',
    'Milliyet',
    'Sabah',
    'Sözcü',
    'Habertürk',
    'CNN Türk',
    'NTV',
    'TRT Haber',
    'Anadolu Ajansı',
    'T24',
  ]) {
    assert.ok(names.includes(n), n);
  }
  assert.ok(enabledSources().length >= 15);
  assert.ok(enabledSources().every((s) => s.rss_url.startsWith('http')));
});

test('keyword filter keeps ÖTV and evde bakım without engelli', () => {
  assert.equal(
    passesKeywordFilter({
      title: "ÖTV'siz araç alımında yeni düzenleme",
      summary: 'Muafiyet şartları değişti.',
    }),
    true,
  );
  assert.equal(
    passesKeywordFilter({
      title: 'Evde bakım yardımında yeni dönem',
      summary: 'Aylık tutarlar güncellendi.',
    }),
    true,
  );
  assert.equal(
    passesKeywordFilter({
      title: 'Engelli aylıkları hesaplara yatırıldı',
      summary: '',
    }),
    true,
  );
  assert.equal(
    passesKeywordFilter({
      title: 'Süper Lig maç sonucu Galatasaray kazandı',
      summary: 'Gol dakikaları.',
    }),
    false,
  );
});

test('lookback is 24h by default and caps at 48h', () => {
  const now = Date.parse('2026-10-08T12:00:00Z');
  const d24 = 24 * 3600 * 1000;
  const d48 = 48 * 3600 * 1000;
  assert.equal(lookbackSinceMs(null, now), now - d24);
  assert.equal(lookbackSinceMs('2026-10-08T10:00:00Z', now), now - d24);
  assert.equal(lookbackSinceMs('2026-10-07T00:00:00Z', now), Date.parse('2026-10-07T00:00:00Z'));
  assert.equal(lookbackSinceMs('2026-10-01T00:00:00Z', now), now - d48);
});

test('date window rejects old articles', () => {
  const now = Date.parse('2026-10-08T12:00:00Z');
  const since = now - 24 * 3600 * 1000;
  assert.equal(isWithinWindow('2026-10-08T08:00:00Z', since, now), true);
  assert.equal(isWithinWindow('2026-10-05T08:00:00Z', since, now), false);
  assert.equal(isWithinWindow('', since, now), false);
});

test('rss parser reads items', () => {
  const xml = `<?xml version="1.0"?><rss version="2.0"><channel>
    <item>
      <title>Engelli aylığı örneği</title>
      <link>https://example.com/haber-1</link>
      <pubDate>Wed, 08 Oct 2026 08:00:00 GMT</pubDate>
      <description>Özet cümle.</description>
    </item>
  </channel></rss>`;
  const items = parseRssOrAtom(xml);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, 'Engelli aylığı örneği');
  assert.ok(items[0].articleUrl.includes('haber-1'));
  assert.ok(items[0].publishedAt);
});

test('url normalize and duplicate grouping', () => {
  const a = normalizeUrl('https://www.Hurriyet.com.tr/haber/?utm_source=x#x');
  const b = normalizeUrl('https://hurriyet.com.tr/haber');
  assert.equal(a, b);
  const existing = emptyExisting();
  remember(existing, {
    id: '1',
    canonicalUrl: a,
    contentHash: 'abc',
    title: 'Engelli aylıkları hesaplara yatırılmaya başlandı',
    duplicateGroupId: '1',
  });
  const dup = isNearDuplicate(existing, {
    canonicalUrl: 'https://milliyet.com.tr/other',
    contentHash: 'zzz',
    title: 'Engelli maaşları bugün hesaplarda',
  });
  assert.equal(dup.hit, true);
  assert.ok(
    titleSimilarity(
      'Engelli aylıkları hesaplara yatırılmaya başlandı',
      'Engelli maaşları bugün hesaplarda',
    ) >= 0.42,
  );
  assert.notEqual(
    contentHash({ title: 'a', canonicalUrl: 'u1', summary: '' }),
    contentHash({ title: 'b', canonicalUrl: 'u2', summary: '' }),
  );
});

test('AI JSON below 50 is dropped', () => {
  const parsed = extractJson('```json\n{"is_relevant":true,"relevance_score":40,"category":"Diğer","summary":"x","title":"t","reason":"r"}\n```');
  const norm = normalizeAiResult(parsed);
  assert.equal(norm.is_relevant, false);
  assert.equal(norm.importance_level, 'drop');
});

test('AI JSON 94 is very_high', () => {
  const norm = normalizeAiResult({
    is_relevant: true,
    relevance_score: 94,
    category: 'Engelli Hakları',
    categories: ['Engelli Hakları', 'Ekonomik Destek'],
    title: 'Başlık',
    summary: 'Özet.',
    reason: 'Yeni hak.',
    affected_users: ['Engelli bireyler'],
  });
  assert.equal(norm.is_relevant, true);
  assert.equal(norm.importance_level, 'very_high');
  assert.equal(norm.category, 'Engelli Hakları');
});
