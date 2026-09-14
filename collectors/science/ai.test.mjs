import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ANIMAL_HUMAN_DISCLAIMER,
  buildScorePrompt,
  normalizeAiResult,
} from './ai.mjs';
import { shouldInsertResearch } from './filter.mjs';
import { buildInsertRow } from './row.mjs';

describe('AI prompt disclaimer', () => {
  it('includes animal vs human and no-cure language', () => {
    const prompt = buildScorePrompt({
      title: 'Stem cells in a rat model of PVL',
      summary: 'Rats received MSC.',
      sourceUrl: 'https://pubmed.ncbi.nlm.nih.gov/1/',
    });
    assert.match(prompt, /hayvan/i);
    assert.match(prompt, /insan/i);
    assert.match(ANIMAL_HUMAN_DISCLAIMER, /Animals are not humans/i);
    assert.match(prompt, /Animals are not humans/i);
    assert.match(prompt, /tedavi vaadi|NEVER claim a cure/i);
    assert.equal(prompt.includes(ANIMAL_HUMAN_DISCLAIMER), true);
  });
});

describe('IRRELEVANT is not inserted', () => {
  it('skips row build path when IRRELEVANT', () => {
    const ai = normalizeAiResult(
      {
        treatment_potential: 'IRRELEVANT',
        title: 'Onkoloji',
        summary: 'Alakasız',
        why_important: 'x',
        limitations: 'y',
      },
      { title: 'Onkoloji', summary: 'Alakasız' },
    );
    assert.equal(ai.treatment_potential, 'IRRELEVANT');
    assert.equal(shouldInsertResearch(ai.treatment_potential), false);
  });

  it('buildInsertRow is only for kept potentials', () => {
    const ai = {
      treatment_potential: 'HIGH_VALUE',
      title: 'CP denemesi',
      original_title: 'CP trial',
      summary: 'Özet',
      why_important: 'önemli',
      limitations: 'küçük n',
      conditions: ['serebral palsi'],
      categories: ['rehabilitasyon'],
      relevance_score: 80,
      scientific_importance_score: 70,
      treatment_potential_score: 60,
      clinical_readiness_score: 40,
      ai_notes: 'ok',
    };
    const row = buildInsertRow(
      {
        title: 'CP trial',
        originalTitle: 'CP trial',
        pmid: '1',
        nctId: '',
        doi: '',
        sourceUrl: 'https://pubmed.ncbi.nlm.nih.gov/1/',
        publicationDate: '2024-01-02',
      },
      ai,
      { id: null, name: 'PubMed' },
      'hash1',
    );
    assert.equal(row.status, 'pending_review');
    assert.equal(row.treatment_potential, 'HIGH_VALUE');
    assert.notEqual(row.status, 'published');
  });
});
