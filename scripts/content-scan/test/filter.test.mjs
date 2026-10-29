import assert from 'node:assert/strict';
import { test } from 'node:test';

import { loadScanConfig } from '../lib/config.mjs';
import { passesKeywordFilter } from '../lib/filter.mjs';

test('core keywords keep disability news; sports scores drop', () => {
  const { conditions } = loadScanConfig();
  assert.equal(
    passesKeywordFilter(
      { title: 'Engelli maaşı yattı', raw_snippet: 'SGK' },
      conditions,
    ),
    true,
  );
  assert.equal(
    passesKeywordFilter(
      { title: 'Serebral palsi rehabilitasyon çalışması', raw_snippet: '' },
      conditions,
    ),
    true,
  );
  assert.equal(
    passesKeywordFilter(
      { title: 'Süper Lig maç sonucu', raw_snippet: 'Gol dakikaları' },
      conditions,
    ),
    false,
  );
});

test('adding a condition is JSON-only: SMA alias is enough', () => {
  const { conditions } = loadScanConfig();
  assert.ok(conditions.some((c) => c.id === 'sma'));
  assert.equal(
    passesKeywordFilter(
      { title: 'Spinal musküler atrofi araştırma haberi', raw_snippet: '' },
      conditions,
    ),
    true,
  );
});
