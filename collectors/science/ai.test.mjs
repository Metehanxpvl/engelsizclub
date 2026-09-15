import assert from 'node:assert/strict';
import { afterEach, describe, it, mock } from 'node:test';
import {
  ANIMAL_HUMAN_DISCLAIMER,
  TITLE_TR_FALLBACK,
  backfillSourceItem,
  backfillUpdatePayload,
  buildScorePrompt,
  buildTranslatePrompt,
  extractJson,
  forceTurkishPrimary,
  generateJson,
  geminiRetryDelayMs,
  heuristicPendingScore,
  isRateLimitError,
  isRetryableGeminiStatus,
  looksEnglishTitle,
  looksTurkishText,
  needsTurkishBackfill,
  normalizeAiResult,
  RATE_LIMIT_BACKOFF_MS,
  resetGeminiPace,
  runSerialTranslateQueue,
  scoreResearch,
  selectBackfillRows,
  titleTranslateOutcome,
  translateResearchCopy,
  withinBudget,
  WORKFLOW_BUDGET_MS,
} from './ai.mjs';
import { sleep } from './config.mjs';
import { TRANSLATE_BUDGET_MS } from './index.mjs';
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
    assert.match(prompt, /IRRELEVANT/);
    assert.match(prompt, /faz 2/);
    assert.match(prompt, /recruiting-only|işe alım/);
    assert.equal(prompt.includes(ANIMAL_HUMAN_DISCLAIMER), true);
  });

  it('requires Turkish title/summary fields and original_title', () => {
    const item = {
      title: 'Gait trial in cerebral palsy',
      originalTitle: 'Gait trial in cerebral palsy',
      summary: 'Children with CP received training.',
    };
    const prompt = buildScorePrompt(item);
    assert.match(prompt, /title: MUTLAKA sade Türkçe/);
    assert.match(prompt, /original_title: kaynak başlığını AYNEN bırak/);
    assert.match(prompt, /summary, why_important, limitations: MUTLAKA Türkçe/);
    assert.match(prompt, /"title":"Türkçe sade başlık"/);
    assert.match(prompt, /"original_title":"English source title unchanged"/);
    assert.match(prompt, /İngilizce\/kaynak başlığını title alanına kopyalama/);
    assert.match(prompt, /İngilizce akademik başlık YASAK/);

    const translate = buildTranslatePrompt(item);
    assert.match(translate, /title: MUTLAKA sade Türkçe/);
    assert.match(translate, /original_title: kaynak başlığını AYNEN bırak/);
    assert.match(translate, /summary, why_important, limitations: MUTLAKA Türkçe/);
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

describe('English title detection and backfill source', () => {
  it('detects English titles and keeps Turkish', () => {
    assert.equal(looksEnglishTitle('Gait trial in cerebral palsy'), true);
    assert.equal(looksEnglishTitle('Stem cells in a rat model of PVL'), true);
    assert.equal(looksEnglishTitle('Randomized children trial for autism'), true);
    assert.equal(looksEnglishTitle('Serebral palside yürüyüş denemesi'), false);
    assert.equal(looksEnglishTitle(TITLE_TR_FALLBACK), false);
    assert.equal(looksTurkishText('Serebral palside yürüyüş denemesi'), true);
    assert.equal(looksTurkishText('Gait trial in cerebral palsy'), false);
  });

  it('needs backfill for English pending/published titles only', () => {
    assert.equal(
      needsTurkishBackfill({
        status: 'pending_review',
        title: 'Gait trial in cerebral palsy',
        original_title: 'Gait trial in cerebral palsy',
      }),
      true,
    );
    assert.equal(
      needsTurkishBackfill({
        status: 'published',
        title: TITLE_TR_FALLBACK,
        original_title: 'Early PVL cohort',
      }),
      true,
    );
    assert.equal(
      needsTurkishBackfill({
        status: 'pending_review',
        title: 'Serebral palside yürüyüş denemesi',
        original_title: 'Gait trial in cerebral palsy',
      }),
      false,
    );
    assert.equal(
      needsTurkishBackfill({
        status: 'rejected',
        title: 'Gait trial in cerebral palsy',
        original_title: 'Gait trial in cerebral palsy',
      }),
      false,
    );
  });

  it('backfill payload uses original_title for source', () => {
    const item = backfillSourceItem({
      title: TITLE_TR_FALLBACK,
      original_title: 'Gait trial in cerebral palsy',
      summary: 'Children with CP received training.',
      why_important: 'Early signal.',
      limitations: 'Small n.',
    });
    assert.equal(item.title, 'Gait trial in cerebral palsy');
    assert.equal(item.originalTitle, 'Gait trial in cerebral palsy');
    assert.notEqual(item.title, TITLE_TR_FALLBACK);

    const copy = forceTurkishPrimary(
      {
        title: 'Gait trial in cerebral palsy',
        original_title: 'ignored',
        summary: 'Children with CP received training.',
        why_important: 'Early clinical signal in children.',
        limitations: 'Small randomized sample.',
      },
      item,
    );
    assert.equal(copy.title, TITLE_TR_FALLBACK);
    assert.equal(copy.original_title, 'Gait trial in cerebral palsy');
    assert.notEqual(copy.title, copy.original_title);

    const payload = backfillUpdatePayload(
      {
        title: 'Gait trial in cerebral palsy',
        original_title: 'Gait trial in cerebral palsy',
      },
      {
        title: 'Serebral palside yürüyüş denemesi',
        original_title: 'should not replace source',
        summary: 'Çocuklarda küçük örneklemli çalışma.',
        why_important: 'Hedef kitleyle ilgili.',
        limitations: 'Kesin sonuç değildir.',
      },
    );
    assert.equal(payload.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(payload.original_title, 'Gait trial in cerebral palsy');
    assert.match(payload.summary, /Çocuklarda/);
    assert.equal(payload.original_title, item.originalTitle);
  });
});

function geminiHttp(status, text = '') {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => {
      if (status !== 200) {
        return {
          error: {
            message: `HTTP ${status}`,
            details: status === 429 ? [{ retryDelay: '1s' }] : [],
          },
        };
      }
      return {
        candidates: [{ content: { parts: [{ text }] } }],
      };
    },
  };
}

const TR_JSON =
  '{"title":"Serebral palside yürüyüş denemesi","original_title":"Gait trial in cerebral palsy","summary":"Çocuklarda küçük örneklem.","why_important":"Hedef kitle.","limitations":"Küçük n","conditions":["serebral palsi"],"categories":["rehabilitasyon"]}';
const EN_SCORE_JSON =
  '{"treatment_potential":"POTENTIAL_VALUE","title":"Gait trial in cerebral palsy","original_title":"Gait trial in cerebral palsy","summary":"Children received training.","why_important":"Early signal.","limitations":"Small n","conditions":["cerebral palsy"],"categories":["rehab"],"ai_notes":"ok"}';
const TR_SCORE_JSON =
  '{"treatment_potential":"HIGH_VALUE","title":"Serebral palside yürüyüş denemesi","original_title":"Gait trial in cerebral palsy","summary":"Çocuklarda küçük örneklem.","why_important":"Hedef kitle.","limitations":"Küçük n","conditions":["serebral palsi"],"categories":["rehabilitasyon"],"ai_notes":"ok"}';

const paper = {
  title: 'Gait trial in cerebral palsy',
  originalTitle: 'Gait trial in cerebral palsy',
  summary: 'Children with CP received training.',
};

describe('Gemini 429 retries and backfill cap', () => {
  afterEach(() => {
    mock.restoreAll();
    resetGeminiPace({ minGapMs: 2000, sleepFn: sleep });
  });

  it('treats 429 as retryable, not a fatal break', () => {
    assert.equal(isRetryableGeminiStatus(429), true);
    assert.equal(isRetryableGeminiStatus(503), true);
    assert.equal(isRetryableGeminiStatus(404), false);
    assert.equal(isRetryableGeminiStatus(400), false);
    const quota = new Error('RESOURCE_EXHAUSTED');
    quota.status = 429;
    assert.equal(isRateLimitError(quota), true);
    assert.equal(isRateLimitError(new Error('RESOURCE_EXHAUSTED')), true);
    assert.deepEqual(RATE_LIMIT_BACKOFF_MS, [15_000, 30_000, 60_000, 90_000]);
    assert.equal(geminiRetryDelayMs(429, 0), 15_000);
    assert.equal(geminiRetryDelayMs(429, 1), 30_000);
    assert.equal(geminiRetryDelayMs(429, 2), 60_000);
    assert.equal(geminiRetryDelayMs(429, 3), 90_000);
    assert.equal(TRANSLATE_BUDGET_MS, WORKFLOW_BUDGET_MS);
    assert.equal(withinBudget(Date.now() - 49 * 60 * 1000), true);
    assert.equal(withinBudget(Date.now() - 51 * 60 * 1000), false);
  });

  it('retries after 429 instead of stopping at the first call', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    const queue = [
      geminiHttp(429),
      geminiHttp(200, TR_JSON),
    ];
    mock.method(globalThis, 'fetch', async () => {
      const next = queue.shift();
      if (!next) return geminiHttp(500, '');
      return next;
    });
    const parsed = await generateJson('k', 'p', {
      sleepFn: async () => {},
      maxAttemptsPerModel: 3,
    });
    assert.equal(parsed.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(queue.length, 0);
  });

  it('translates later items after a 429 (serial, not first-only)', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    const queue = [
      geminiHttp(200, TR_JSON),
      geminiHttp(429),
      geminiHttp(200, TR_JSON),
      geminiHttp(429),
      geminiHttp(200, TR_JSON),
    ];
    mock.method(globalThis, 'fetch', async () => {
      const next = queue.shift();
      if (!next) return geminiHttp(500, '');
      return next;
    });
    const opts = { sleepFn: async () => {}, maxAttemptsPerModel: 3 };
    const a = await generateJson('k', 'p', opts);
    const b = await generateJson('k', 'p', opts);
    const c = await generateJson('k', 'p', opts);
    assert.equal(a.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(b.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(c.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(queue.length, 0);
  });

  it('translate-only retry after English score keeps Turkish title', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    const queue = [
      geminiHttp(200, EN_SCORE_JSON),
      geminiHttp(429),
      geminiHttp(200, TR_JSON),
    ];
    mock.method(globalThis, 'fetch', async () => {
      const next = queue.shift();
      if (!next) return geminiHttp(500, '');
      return next;
    });
    const ai = await scoreResearch('k', paper, { sleepFn: async () => {} });
    assert.equal(ai.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(ai.original_title, 'Gait trial in cerebral palsy');
    assert.notEqual(ai.title, ai.original_title);
    assert.equal(looksEnglishTitle(ai.title), false);
    assert.equal(titleTranslateOutcome(ai.title), 'translated');
  });

  it('selectBackfillRows paginates all English rows, no cap of 3 or 40', () => {
    const rows = Array.from({ length: 45 }, (_, i) => ({
      id: `id-${i}`,
      status: i % 2 === 0 ? 'pending_review' : 'published',
      title: 'Gait trial in cerebral palsy',
      original_title: 'Gait trial in cerebral palsy',
    }));
    rows[0].title = 'Serebral palside yürüyüş denemesi';
    const picked = selectBackfillRows(rows);
    assert.equal(picked.length, 44);
    assert.equal(picked[0].id, 'id-1');
    assert.ok(picked.length > 40);
    assert.equal(titleTranslateOutcome('Gait trial in cerebral palsy'), 'english_left');
    assert.equal(titleTranslateOutcome('Serebral palside yürüyüş denemesi'), 'translated');
  });

  it('429 after three successes does not abort the rest of the queue', async () => {
    const sleeps = [];
    const seen = [];
    const items = [
      { id: 'a' },
      { id: 'b' },
      { id: 'c' },
      { id: 'd' },
      { id: 'e' },
    ];
    let dTries = 0;
    const result = await runSerialTranslateQueue(
      items,
      async (row) => {
        seen.push(row.id);
        if (row.id === 'd' && dTries === 0) {
          dTries += 1;
          const err = new Error('RESOURCE_EXHAUSTED');
          err.status = 429;
          throw err;
        }
        return { title: `Serebral palside yürüyüş ${row.id}` };
      },
      {
        sleepFn: async (ms) => {
          sleeps.push(ms);
        },
        startedAt: Date.now(),
        budgetMs: 60_000,
      },
    );
    assert.equal(result.translated, 5);
    assert.equal(result.leftover.length, 0);
    assert.ok(seen.includes('d') && seen.includes('e'));
    assert.ok(seen.length > 3);
    assert.deepEqual(sleeps, [15_000]);
    assert.equal(result.lastHttpStatus, 429);
  });

  it('keeps walking the queue after repeated 429 instead of breaking', async () => {
    const seen = [];
    const items = [{ id: '1' }, { id: '2' }, { id: '3' }, { id: '4' }, { id: '5' }];
    let ticks = 0;
    const result = await runSerialTranslateQueue(
      items,
      async (row) => {
        seen.push(row.id);
        if (row.id === '1' || row.id === '2' || row.id === '3') {
          return { title: 'Serebral palside yürüyüş denemesi' };
        }
        const err = new Error('RESOURCE_EXHAUSTED');
        err.status = 429;
        throw err;
      },
      {
        sleepFn: async () => {},
        nowFn: () => {
          ticks += 1;
          return ticks > 12 ? 90_000 : 0;
        },
        startedAt: 0,
        budgetMs: 80_000,
      },
    );
    assert.equal(result.translated, 3);
    assert.ok(seen.includes('4'));
    assert.ok(seen.includes('5'));
    assert.ok(seen.length > 3);
    assert.ok(result.leftover.length >= 1);
  });

  it('generateJson 429 uses 15s backoff on the same model, not the next', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    const urls = [];
    const waits = [];
    const queue = [geminiHttp(429), geminiHttp(200, TR_JSON)];
    mock.method(globalThis, 'fetch', async (url) => {
      urls.push(String(url));
      const next = queue.shift();
      if (!next) return geminiHttp(500, '');
      return next;
    });
    const parsed = await generateJson('k', 'p', {
      sleepFn: async (ms) => {
        waits.push(ms);
      },
      maxRateLimitRetries: 4,
    });
    assert.equal(parsed.title, 'Serebral palside yürüyüş denemesi');
    assert.deepEqual(waits, [15_000]);
    assert.equal(urls.length, 2);
    assert.ok(urls.every((u) => u.includes('gemini-flash-latest')));
    assert.equal(
      urls.some((u) => u.includes('gemini-3.8-flash') || u.includes('lite')),
      false,
    );
  });

  it('score JSON that is already Turkish does not require a second call', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    let n = 0;
    mock.method(globalThis, 'fetch', async () => {
      n += 1;
      return geminiHttp(200, TR_SCORE_JSON);
    });
    const ai = await scoreResearch('k', paper, { sleepFn: async () => {} });
    assert.equal(ai.treatment_potential, 'HIGH_VALUE');
    assert.equal(ai.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(n, 1);
  });

  it('translateResearchCopy retries 429 with delay then returns Turkish', async () => {
    resetGeminiPace({ minGapMs: 0, sleepFn: async () => {} });
    const queue = [geminiHttp(429), geminiHttp(200, TR_JSON)];
    mock.method(globalThis, 'fetch', async () => {
      const next = queue.shift();
      if (!next) return geminiHttp(500, '');
      return next;
    });
    const copy = await translateResearchCopy('k', paper, {
      maxRetries: 3,
      sleepFn: async () => {},
    });
    assert.equal(copy.title, 'Serebral palside yürüyüş denemesi');
    assert.equal(copy.original_title, 'Gait trial in cerebral palsy');
  });
});

