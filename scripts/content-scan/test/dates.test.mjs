import assert from 'node:assert/strict';
import { test } from 'node:test';

import { daysLeft, deadlineFlags, parseDeadline } from '../lib/dates.mjs';

test('deadline parser keeps YYYY-MM-DD and rejects junk', () => {
  assert.equal(parseDeadline('2026-11-01'), '2026-11-01');
  assert.equal(parseDeadline('yarın'), null);
  assert.equal(parseDeadline(null), null);
});

test('past deadline is expired; 7 days or fewer is urgent', () => {
  const now = new Date('2026-10-24T12:00:00Z');
  assert.equal(daysLeft('2026-10-20', now), -4);
  assert.equal(deadlineFlags('2026-10-20', now).expired, true);
  assert.equal(deadlineFlags('2026-10-28', now).urgent, true);
  assert.equal(deadlineFlags('2026-10-28', now).expired, false);
  assert.equal(deadlineFlags('2026-12-01', now).urgent, false);
});
