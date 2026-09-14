import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ANIMAL_HUMAN_DISCLAIMER,
  TITLE_TR_FALLBACK,
  buildScorePrompt,
  buildTranslatePrompt,
  extractJson,
  heuristicPendingScore,
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
    assert.match(prompt, /asla IRRELEVANT/);
    assert.equal(prompt.includes(ANIMAL_HUMAN_DISCLAIMER), true);
  });

  it('requires Turkish title/summary fields and original_title', () => {
    const item = {
      title: 'Gait trial in cerebral palsy',
      originalTitle: 'Gait trial in cerebral palsy',
      summary: 'Children with CP received training.',
    };
    const prompt = buildScorePrompt(item);
    assert.match(prompt, /title: ZORUNLU sade Türkçe/);
    assert.match(prompt, /original_title: kaynak başlığını AYNEN bırak/);
    assert.match(prompt, /summary, why_important, limitations: ZORUNLU Türkçe/);
    assert.match(prompt, /"title":"Türkçe sade başlık"/);
    assert.match(prompt, /"original_title":"English source title unchanged"/);
    assert.match(prompt, /İngilizce\/kaynak başlığını title alanına kopyalama/);

    const translate = buildTranslatePrompt(item);
    assert.match(translate, /title: ZORUNLU sade Türkçe/);
    assert.match(translate, /original_title: kaynak başlığını AYNEN bırak/);
    assert.match(translate, /summary, why_important, limitations: ZORUNLU Türkçe/);
    assert.match(translate, /Skorlama yapma/);
  });
});

describe('parser keeps original_title', () => {
  it('extractJson + normalize keep source original and Turkish title', () => {
    const raw = `\`\`\`json
{"treatment_potential":"POTENTIAL_VALUE","title":"Serebral palside yürüyüş denemesi","original_title":"Gait trial in cerebral palsy","summary":"Çocuklarda küçük örneklemli çalışma.","why_important":"Hedef kitleyle ilgili.","limitations":"Kesin sonuç değildir.","conditions":["serebral palsi"],"categories":["rehabilitasyon"],"ai_notes":"ok"}
\`\`\``;
    const parsed = extractJson(raw);
    assert.equal(parsed.original_title, 'Gait trial in cerebral palsy');
    assert.equal(parsed.title, 'Serebral palside yürüyüş denemesi');
    const ai = normalizeAiResult(parsed, {
      title: 'Gait trial in cerebral palsy',
      originalTitle: 'Gait trial in cerebral palsy',
      summary: 'Children with CP received training.',
    });
    assert.equal(ai.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(ai.original_title, 'Gait trial in cerebral palsy');
    assert.match(ai.summary, /Çocuklarda/);
    assert.notEqual(ai.title, ai.original_title);
  });

  it('keeps original_title from JSON when item has no originalTitle', () => {
    const parsed = extractJson(
      '{"treatment_potential":"HIGH_VALUE","title":"PVL üzerine erken çalışma","original_title":"Early PVL cohort","summary":"Türkçe özet","why_important":"önemli","limitations":"küçük n"}',
    );
    const ai = normalizeAiResult(parsed, { title: '', summary: 'English abstract' });
    assert.equal(ai.original_title, 'Early PVL cohort');
    assert.equal(ai.title, 'PVL üzerine erken çalışma');
    assert.equal(ai.summary, 'Türkçe özet');
  });

  it('does not copy English source into title when AI title is missing', () => {
    const ai = normalizeAiResult(
      {
        treatment_potential: 'POTENTIAL_VALUE',
        original_title: 'Stem cells in PVL',
        summary: '',
        why_important: '',
        limitations: '',
      },
      {
        title: 'Stem cells in PVL',
        originalTitle: 'Stem cells in PVL',
        summary: 'English abstract only.',
      },
    );
    assert.equal(ai.title, TITLE_TR_FALLBACK);
    assert.equal(ai.original_title, 'Stem cells in PVL');
    assert.equal(ai.summary, TITLE_TR_FALLBACK);
    assert.notEqual(ai.summary, 'English abstract only.');
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
    assert.equal(row.title, 'CP denemesi');
    assert.equal(row.original_title, 'CP trial');
    assert.notEqual(row.status, 'published');
  });
});

describe('heuristicPendingScore', () => {
  it('uses Turkish stub title, keeps English original_title', () => {
    const ai = heuristicPendingScore({
      title: 'Cerebral palsy gait RCT',
      originalTitle: 'CP gait',
      summary: 'Children with CP.',
      studyType: 'RCT',
    });
    assert.equal(ai.treatment_potential, 'POTENTIAL_VALUE');
    assert.equal(ai.title, TITLE_TR_FALLBACK);
    assert.equal(ai.original_title, 'CP gait');
    assert.equal(ai.summary, TITLE_TR_FALLBACK);
    assert.notEqual(ai.title, 'Cerebral palsy gait RCT');
    assert.equal(shouldInsertResearch(ai.treatment_potential), true);
    assert.match(ai.ai_notes, /POTENTIAL_VALUE/);
    const row = buildInsertRow(
      {
        title: 'Cerebral palsy gait RCT',
        originalTitle: 'CP gait',
        sourceUrl: 'https://pubmed.ncbi.nlm.nih.gov/1/',
      },
      ai,
      { name: 'PubMed' },
      'h',
    );
    assert.equal(row.title, TITLE_TR_FALLBACK);
    assert.equal(row.original_title, 'CP gait');
    assert.equal(row.status, 'pending_review');
  });
});
