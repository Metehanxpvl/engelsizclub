import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import {
  paperForImageQueue,
  papersJsonPath,
  writeGithubPapersJson,
  writePapersJson,
} from './papers_queue.mjs';

describe('papers image queue', () => {
  it('keeps title, date and ids for Imagen', () => {
    const q = paperForImageQueue(
      {
        title: 'Yürüyüş denemesi',
        original_title: 'Gait trial',
        summary: 'Özet',
        publication_date: '2026-03-01',
        pmid: '123',
        nct_id: null,
        treatment_potential: 'HIGH_VALUE',
      },
      { id: 'uuid-1' },
    );
    assert.equal(q.id, 'uuid-1');
    assert.equal(q.title, 'Yürüyüş denemesi');
    assert.equal(q.publication_date, '2026-03-01');
    assert.equal(q.pmid, '123');
  });

  it('writes papers.json under output/', () => {
    const root = mkdtempSync(join(tmpdir(), 'science-papers-'));
    const dest = writePapersJson(
      [{ title: 'A', publication_date: '2026-01-02', pmid: '9' }],
      root,
    );
    assert.equal(dest, papersJsonPath(root));
    const parsed = JSON.parse(readFileSync(dest, 'utf8'));
    assert.equal(parsed.length, 1);
    assert.equal(parsed[0].pmid, '9');
  });

  it('writes GitHub catalog at repo output/papers.json', () => {
    const dest = writeGithubPapersJson(
      [{ title: 'B', status: 'pending_review', pmid: '8' }],
      join(mkdtempSync(join(tmpdir(), 'science-gh-')), 'papers.json'),
    );
    const parsed = JSON.parse(readFileSync(dest, 'utf8'));
    assert.equal(parsed[0].status, 'pending_review');
    assert.equal(parsed[0].pmid, '8');
  });
});
