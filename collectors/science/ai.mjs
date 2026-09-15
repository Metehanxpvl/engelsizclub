import { MISSING, sleep } from './config.mjs';
import { preferSourceStudyPhase } from './filter.mjs';

const MODELS = [
  'gemini-flash-latest',
  'gemini-3.8-flash',
  'gemini-flash-lite-latest',
];

export const ANIMAL_HUMAN_DISCLAIMER =
  'Hayvan çalışmaları insan tedavisi değildir. Animals are not humans: animal or in-vitro results must NOT be described as a human treatment, cure, or clinical readiness. NEVER claim a cure. Tedavi vaadi yok; “iyileştirir / tedavi eder / çare” yazma.';

/** Shown as `title` when Gemini is missing or both score+translate fail. */
export const TITLE_TR_FALLBACK =
  'Kaynak başlığı aşağıdadır; özet çevrilemedi.';

/** Serial gap between Gemini calls. 429 uses RATE_LIMIT_BACKOFF_MS, not this. */
export const GEMINI_MIN_GAP_MS = 2000;

/** 429 / RESOURCE_EXHAUSTED waits — do not skip the rest of the queue. */
export const RATE_LIMIT_BACKOFF_MS = [15_000, 30_000, 60_000, 90_000];

/** Stop translating when this budget elapses; workflow timeout is longer. */
export const WORKFLOW_BUDGET_MS = 50 * 60 * 1000;

const geminiPace = {
  lastAt: 0,
  minGapMs: GEMINI_MIN_GAP_MS,
  sleepFn: sleep,
  lastStatus: null,
};

export function resetGeminiPace({ minGapMs, sleepFn } = {}) {
  geminiPace.lastAt = 0;
  geminiPace.lastStatus = null;
  if (minGapMs != null) geminiPace.minGapMs = minGapMs;
  if (sleepFn) geminiPace.sleepFn = sleepFn;
}

export function lastGeminiHttpStatus() {
  return geminiPace.lastStatus;
}

export function isRetryableGeminiStatus(status) {
  return status === 429 || status === 503 || status === 500;
}

export function isRateLimitError(err) {
  if (!err) return false;
  if (isRetryableGeminiStatus(err.status)) return true;
  return /RESOURCE_EXHAUSTED|Too Many Requests|rate.?limit|quota/i.test(
    String(err.message || ''),
  );
}

export function backoffDelayMs(attempt = 0) {
  const i = Math.min(
    Math.max(0, Number(attempt) || 0),
    RATE_LIMIT_BACKOFF_MS.length - 1,
  );
  return RATE_LIMIT_BACKOFF_MS[i];
}

export function geminiRetryDelayMs(status, attempt = 0) {
  if (status === 429 || isRetryableGeminiStatus(status)) {
    return backoffDelayMs(attempt);
  }
  return backoffDelayMs(attempt);
}

export function withinBudget(
  startedAt,
  now = Date.now(),
  budgetMs = WORKFLOW_BUDGET_MS,
) {
  return now - startedAt < budgetMs;
}

export function titleTranslateOutcome(title) {
  return looksEnglishTitle(title) ? 'english_left' : 'translated';
}

/** All English/stub pending_review+published rows; no cap of 3 or 40. */
export function selectBackfillRows(rows, cap = Number.POSITIVE_INFINITY) {
  const out = [];
  const n = Number.isFinite(cap) ? Math.max(0, Number(cap) || 0) : Infinity;
  for (const row of rows || []) {
    if (!needsTurkishBackfill(row)) continue;
    out.push(row);
    if (out.length >= n) break;
  }
  return out;
}

function retryDelayFromGeminiError(err, attempt = 0) {
  const scheduled = backoffDelayMs(attempt);
  const hinted = Number(err?.retryAfterMs);
  if (Number.isFinite(hinted) && hinted > 0) {
    return Math.min(
      Math.max(scheduled, Math.ceil(hinted)),
      backoffDelayMs(RATE_LIMIT_BACKOFF_MS.length - 1),
    );
  }
  return scheduled;
}

function retryAfterMsFromBody(json) {
  const details = json?.error?.details;
  if (!Array.isArray(details)) return 0;
  for (const d of details) {
    const raw = d?.retryDelay;
    if (!raw) continue;
    const m = String(raw).match(/([\d.]+)\s*s/i);
    if (m) return Math.ceil(Number(m[1]) * 1000);
  }
  return 0;
}

async function waitGeminiGap() {
  const wait = geminiPace.lastAt + geminiPace.minGapMs - Date.now();
  if (wait > 0) await geminiPace.sleepFn(wait);
}

const TR_CHARS = /[çğıöşüÇĞİÖŞÜ]/;
const TR_WORDS =
  /\b(ve|bir|ile|bu|olan|için|icin|çalışma|calisma|deneme|özet|ozet|çocuk|cocuk|serebral|palsi|tedavi|rehabilitasyon|hayvan|insan|faz|klinik|erken|küçük|kucuk|örneklem|orneklem|sonuç|sonuc|değil|degil|yok|var|başlık|baslik|kaynak|aşağıdadır|asagidadir|çevrilemedi|cevrilemedi|üzerine|uzerine|yürüyüş|yuruyus)\b/i;
const EN_WORDS =
  /\b(the|and|for|with|from|of|in|a|an|on|to|by|or|as|at|into|versus|vs|study|studies|trial|trials|review|effect|effects|children|child|infant|infants|autism|treatment|therapy|clinical|patient|patients|disorder|syndrome|randomized|randomised|intervention|developmental|outcome|outcomes|analysis|among|between|cerebral|palsy|stem|cell|cells|model|rat|rats|mice|mouse|human|neonatal|preterm|gait|training|efficacy|safety|phase|remyelination|leukomalacia)\b/i;

export function looksTurkishText(s) {
  const t = String(s || '').trim();
  if (!t) return false;
  if (TR_CHARS.test(t)) return true;
  return TR_WORDS.test(t);
}

function asciiLetterRatio(s) {
  const letters = [...String(s || '')].filter((c) => /\p{L}/u.test(c));
  if (!letters.length) return 1;
  const ascii = letters.filter((c) => c.charCodeAt(0) < 128);
  return ascii.length / letters.length;
}

/** ASCII-heavy, common English words, no Turkish chars — not a primary `title`. */
export function looksEnglishTitle(s) {
  const t = String(s || '').trim();
  if (!t) return false;
  if (looksTurkishText(t)) return false;
  if (!EN_WORDS.test(t)) return false;
  const letterCount = [...t].filter((c) => /\p{L}/u.test(c)).length;
  if (letterCount < 8) return false;
  return asciiLetterRatio(t) >= 0.9;
}

export function needsTurkishBackfill(row) {
  const status = String(row?.status || '');
  if (status !== 'pending_review' && status !== 'published') return false;
  const title = String(row?.title || '').trim();
  if (!title) return true;
  if (title === TITLE_TR_FALLBACK) return true;
  return looksEnglishTitle(title);
}

/** Translate from English `original_title`, never from a TR stub already in `title`. */
export function backfillSourceItem(row) {
  const original = String(row?.original_title || row?.title || '').trim();
  return {
    title: original,
    originalTitle: original,
    summary: String(row?.summary || ''),
    conditions: row?.conditions,
    categories: row?.categories,
  };
}

export function forceTurkishPrimary(copy, item) {
  const src = String(
    item?.originalTitle || item?.title || copy?.original_title || '',
  ).trim();
  const next = { ...copy };
  if (!String(next.title || '').trim() || looksEnglishTitle(next.title)) {
    next.title = TITLE_TR_FALLBACK;
  }
  if (src) next.original_title = src.slice(0, 400);
  if (looksEnglishTitle(next.summary)) next.summary = TITLE_TR_FALLBACK;
  if (looksEnglishTitle(next.why_important)) next.why_important = MISSING;
  if (looksEnglishTitle(next.limitations)) next.limitations = MISSING;
  return next;
}

export function backfillUpdatePayload(row, copy) {
  const original = String(
    row?.original_title || copy?.original_title || row?.title || '',
  )
    .trim()
    .slice(0, 400);
  return {
    title: String(copy?.title || '').slice(0, 400),
    original_title: original,
    summary: String(copy?.summary || '').slice(0, 4000),
    why_important: String(copy?.why_important || '').slice(0, 2000),
    limitations: String(copy?.limitations || '').slice(0, 2000),
  };
}

export function buildScorePrompt(item) {
  return `Sen EngelsizClub bilimsel tarama asistanısın. Ailelere yönelik, özel gereksinim / pediatrik nöroloji (serebral palsi, PVL, HIE, otizm, Down, epilepsi, nöroplastisite, remiyelinizasyon, oligodendrosit, gen tedavisi, kök hücre) bağlamında çalışmayı değerlendir.

${ANIMAL_HUMAN_DISCLAIMER}

Kurallar:
- title: MUTLAKA sade Türkçe (aile dostu). İngilizce/kaynak başlığını title alanına kopyalama. title, original_title ile aynı olamaz. "study/trial/effect/children/cerebral palsy/randomized" gibi İngilizce akademik başlık YASAK — Türkçe karşılığını yaz. Tedavi/çare iddiası yok.
- original_title: kaynak başlığını AYNEN bırak (genelde İngilizce).
- summary, why_important, limitations: MUTLAKA Türkçe. Uydurma yok.
- categories ve conditions: Türkçe etiket veya kısa iki dilli etiket (ör. "serebral palsi").
- Eksik bilgi uydurma. Bilinmeyen metin alanları için null değil "${MISSING}" kullan. Sayısal skor yoksa null.
- treatment_potential yalnız: HIGH_VALUE | POTENTIAL_VALUE | IRRELEVANT
  HIGH_VALUE: faz 2+ insan çalışması, sonuç/outcome yayınlanmış (hasResults / resultsFirstPostDate / COMPLETED). Faz 1 veya yalnızca işe alım (recruiting, results yok) HIGH_VALUE değildir.
  POTENTIAL_VALUE: ilgili RCT/sonuçlu makale (faz yazılmamış olabilir); faz 2+ ama sonuçlar sınırlı.
  IRRELEVANT: sonuç yok ve en az faz 2 değil (faz 1, early phase 1, NA, yalnızca işe alım/recruiting ilanı, protokol-only, özet yok). Konumuzla alakasız (erişkin onkoloji) da IRRELEVANT. Faz 1 / recruiting-only / results yok → IRRELEVANT, konu eşleşse bile.
- Skorlar 0-100 tamsayı.
- PDF/tam metin yok; yalnız verilen başlık+özet.

Başlık: ${item.title || ''}
Orijinal: ${item.originalTitle || item.title || ''}
Özet: ${String(item.summary || '').slice(0, 3500)}
Kaynak: ${item.sourceUrl || ''}
PMID: ${item.pmid || ''}
NCT: ${item.nctId || ''}
DOI: ${item.doi || ''}
Dergi: ${item.journal || ''}
Faz: ${item.studyPhase || ''}
Durum: ${item.recruitmentStatus || ''}
human_or_animal ipucu: ${item.humanOrAnimal || ''}
Koşullar: ${(item.conditions || []).join(', ')}

Yalnız JSON:
{"treatment_potential":"HIGH_VALUE|POTENTIAL_VALUE|IRRELEVANT","title":"Türkçe sade başlık","original_title":"English source title unchanged","summary":"Türkçe özet","why_important":"Türkçe","limitations":"Türkçe","conditions":["serebral palsi"],"categories":["rehabilitasyon"],"study_type":"...","evidence_level":"...","study_phase":"...","human_or_animal":"human|animal|both|unspecified","pediatric_relevance":"...","relevance_score":0,"scientific_importance_score":0,"treatment_potential_score":0,"clinical_readiness_score":0,"ai_notes":"kısa gerekçe"}`;
}

export function buildTranslatePrompt(item) {
  return `Sen EngelsizClub çeviri asistanısın. Aşağıdaki bilimsel başlık ve özeti ailelere yönelik sade Türkçeye çevir. Skorlama yapma.

${ANIMAL_HUMAN_DISCLAIMER}

Kurallar:
- title: MUTLAKA sade Türkçe (aile dostu). İngilizce başlığı title’a kopyalama. title, original_title ile aynı olamaz. İngilizce akademik başlık YASAK. Tedavi/çare iddiası yok.
- original_title: kaynak başlığını AYNEN bırak (İngilizce/orijinal dil).
- summary, why_important, limitations: MUTLAKA Türkçe. Uydurma yok; yoksa "${MISSING}".
- categories ve conditions: Türkçe etiket veya kısa iki dilli etiket.
- Yalnız JSON.

Başlık: ${item.title || ''}
Orijinal: ${item.originalTitle || item.title || ''}
Özet: ${String(item.summary || '').slice(0, 3500)}

Yalnız JSON:
{"title":"Türkçe sade başlık","original_title":"English source title unchanged","summary":"Türkçe özet","why_important":"Türkçe","limitations":"Türkçe","conditions":["serebral palsi"],"categories":["rehabilitasyon"]}`;
}

export function extractJson(text) {
  const raw = String(text ?? '').trim();
  if (!raw) return null;
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fenced ? fenced[1] : raw).trim();
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(body.slice(start, end + 1));
  } catch {
    return null;
  }
}

async function generateOnce(apiKey, model, prompt, { maxOutputTokens = 1536 } = {}) {
  await waitGeminiGap();
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(apiKey)}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.15,
          maxOutputTokens,
        },
      }),
      signal: AbortSignal.timeout(45000),
    });
    const json = await res.json().catch(() => ({}));
    geminiPace.lastStatus = res.status;
    if (!res.ok) {
      const msg = json?.error?.message || `Gemini HTTP ${res.status}`;
      const err = new Error(msg);
      err.status = res.status;
      err.retryAfterMs = retryAfterMsFromBody(json);
      throw err;
    }
    const text = json?.candidates?.[0]?.content?.parts
      ?.map((p) => p.text)
      .filter(Boolean)
      .join('\n')
      .trim();
    return text || '';
  } finally {
    geminiPace.lastAt = Date.now();
  }
}

function clampScore(n) {
  if (n == null || n === '') return null;
  const v = Number(n);
  if (!Number.isFinite(v)) return null;
  return Math.max(0, Math.min(100, Math.round(v)));
}

function textOrMissing(v) {
  const s = String(v ?? '').trim();
  if (!s || s.toLowerCase() === 'null') return MISSING;
  return s;
}

function turkishOrFallback(v) {
  const s = String(v ?? '').trim();
  if (!s || s.toLowerCase() === 'null') return TITLE_TR_FALLBACK;
  return s;
}

function sourceOriginalTitle(item, parsed) {
  const fromSource = String(item?.originalTitle || item?.title || '').trim();
  if (fromSource) return fromSource.slice(0, 400);
  return textOrMissing(parsed?.original_title).slice(0, 400);
}

function asStringList(raw) {
  if (Array.isArray(raw)) {
    return raw.map((x) => String(x || '').trim()).filter(Boolean);
  }
  const s = String(raw || '').trim();
  if (!s) return [];
  return s
    .split(/[,;/|]+/)
    .map((x) => x.trim())
    .filter(Boolean);
}

export function applyTranslatedCopy(item, parsed) {
  return {
    title: turkishOrFallback(parsed?.title).slice(0, 400),
    original_title: sourceOriginalTitle(item, parsed),
    summary: turkishOrFallback(parsed?.summary).slice(0, 4000),
    why_important: textOrMissing(parsed?.why_important).slice(0, 2000),
    limitations: textOrMissing(parsed?.limitations).slice(0, 2000),
    conditions: asStringList(parsed?.conditions || item.conditions),
    categories: asStringList(parsed?.categories),
  };
}

export function normalizeAiResult(parsed, item) {
  if (!parsed || typeof parsed !== 'object') return null;
  const pot = String(parsed.treatment_potential || '')
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!['HIGH_VALUE', 'POTENTIAL_VALUE', 'IRRELEVANT'].includes(pot)) {
    return null;
  }
  const copy = applyTranslatedCopy(item, parsed);
  return {
    treatment_potential: pot,
    ...copy,
    study_type: textOrMissing(parsed.study_type || item.studyType),
    evidence_level: textOrMissing(parsed.evidence_level),
    study_phase: textOrMissing(
      preferSourceStudyPhase(parsed.study_phase, item.studyPhase),
    ),
    human_or_animal: textOrMissing(
      parsed.human_or_animal || item.humanOrAnimal,
    ),
    pediatric_relevance: textOrMissing(parsed.pediatric_relevance),
    relevance_score: clampScore(parsed.relevance_score),
    scientific_importance_score: clampScore(parsed.scientific_importance_score),
    treatment_potential_score: clampScore(parsed.treatment_potential_score),
    clinical_readiness_score: clampScore(parsed.clinical_readiness_score),
    ai_notes: String(parsed.ai_notes || '').trim().slice(0, 800),
  };
}

/** No Gemini: Turkish stub title/summary, keep source original_title. pending_review only. */
export function heuristicPendingScore(item) {
  const original =
    String(item.originalTitle || item.title || '')
      .trim()
      .slice(0, 400) || TITLE_TR_FALLBACK;
  return {
    treatment_potential: 'POTENTIAL_VALUE',
    title: TITLE_TR_FALLBACK,
    original_title: original,
    summary: TITLE_TR_FALLBACK,
    why_important: MISSING,
    limitations: MISSING,
    conditions: Array.isArray(item.conditions) ? item.conditions : [],
    categories: [],
    study_type: item.studyType || MISSING,
    evidence_level: MISSING,
    study_phase: item.studyPhase || MISSING,
    human_or_animal: item.humanOrAnimal || MISSING,
    pediatric_relevance: MISSING,
    relevance_score: null,
    scientific_importance_score: null,
    treatment_potential_score: null,
    clinical_readiness_score: null,
    ai_notes:
      'AI yok veya hata; özet çevrilemedi. Ön filtre anahtar kelime → POTENTIAL_VALUE. Tedavi vaadi yok; yayın yok.',
  };
}

/**
 * Serial Gemini only. On 429/RESOURCE_EXHAUSTED retry the SAME model with
 * 15s/30s/60s/90s — do not hop models (they share quota) and do not `break`
 * the caller's paper queue.
 */
export async function generateJson(
  apiKey,
  prompt,
  {
    maxOutputTokens = 1536,
    sleepFn,
    maxAttemptsPerModel = 4,
    maxRateLimitRetries = RATE_LIMIT_BACKOFF_MS.length,
  } = {},
) {
  const wait = sleepFn || geminiPace.sleepFn;
  const rlMax = maxRateLimitRetries ?? maxAttemptsPerModel;
  let lastErr;
  for (const model of MODELS) {
    let rateAttempt = 0;
    let otherAttempt = 0;
    while (otherAttempt < maxAttemptsPerModel) {
      try {
        const text = await generateOnce(apiKey, model, prompt, { maxOutputTokens });
        const parsed = extractJson(text);
        if (!parsed) throw new Error('AI JSON yok');
        return parsed;
      } catch (e) {
        lastErr = e;
        if (e.status != null) geminiPace.lastStatus = e.status;
        if (e.status === 404) break;
        if (isRateLimitError(e)) {
          if (rateAttempt >= rlMax) {
            throw e;
          }
          await wait(retryDelayFromGeminiError(e, rateAttempt));
          rateAttempt += 1;
          continue;
        }
        if (e.status === 500 || e.status === 503) {
          if (rateAttempt >= rlMax) break;
          await wait(retryDelayFromGeminiError(e, rateAttempt));
          rateAttempt += 1;
          continue;
        }
        if (e.status) throw e;
        otherAttempt += 1;
      }
    }
  }
  throw lastErr || new Error('AI başarısız');
}

/**
 * Translate items one-by-one. A 429 after N successes must NOT abort the rest;
 * backoff and keep going until the queue or time budget is done.
 */
export async function runSerialTranslateQueue(
  items,
  translateOne,
  {
    sleepFn = sleep,
    nowFn = Date.now,
    startedAt = Date.now(),
    budgetMs = WORKFLOW_BUDGET_MS,
  } = {},
) {
  let translated = 0;
  let lastHttpStatus = lastGeminiHttpStatus();
  let backoffAttempt = 0;
  const leftover = [];
  const queue = [...(items || [])].filter(Boolean);
  const rateTries = new WeakMap();

  while (queue.length && withinBudget(startedAt, nowFn(), budgetMs)) {
    const item = queue.shift();
    try {
      const copy = await translateOne(item);
      lastHttpStatus = lastGeminiHttpStatus() ?? lastHttpStatus;
      if (looksEnglishTitle(copy?.title)) {
        leftover.push(item);
        continue;
      }
      translated += 1;
      backoffAttempt = 0;
    } catch (e) {
      lastHttpStatus = e.status ?? lastGeminiHttpStatus() ?? lastHttpStatus;
      if (isRateLimitError(e) && withinBudget(startedAt, nowFn(), budgetMs)) {
        const waitMs = backoffDelayMs(backoffAttempt);
        console.warn(
          `Gemini HTTP ${e.status || lastHttpStatus || 'RESOURCE_EXHAUSTED'}; backoff ${waitMs}ms — queue continues (${queue.length + 1} left)`,
        );
        await sleepFn(waitMs);
        backoffAttempt = Math.min(
          backoffAttempt + 1,
          RATE_LIMIT_BACKOFF_MS.length - 1,
        );
        const n = (rateTries.get(item) || 0) + 1;
        rateTries.set(item, n);
        if (n < RATE_LIMIT_BACKOFF_MS.length) queue.unshift(item);
        else {
          rateTries.set(item, 0);
          queue.push(item);
        }
        continue;
      }
      leftover.push(item);
    }
  }
  leftover.push(...queue);
  return {
    translated,
    leftover,
    lastHttpStatus,
    englishRemaining: leftover.length,
  };
}

function sourceItemForTranslate(item) {
  const original = String(item?.originalTitle || item?.title || '').trim();
  return {
    ...item,
    title: original || item?.title,
    originalTitle: original || item?.originalTitle || item?.title,
  };
}

function jsonOpts(extra = {}) {
  return { sleepFn: geminiPace.sleepFn, ...extra };
}

/** Cheaper second pass: Turkish title/summary only; no scores. Retry if still English. */
export async function translateResearchCopy(
  apiKey,
  item,
  { maxRetries = 3, sleepFn } = {},
) {
  const wait = sleepFn || geminiPace.sleepFn;
  const source = sourceItemForTranslate(item);
  let last = null;
  let lastErr;
  for (let i = 0; i < maxRetries; i++) {
    try {
      const parsed = await generateJson(apiKey, buildTranslatePrompt(source), {
        maxOutputTokens: 1024,
        sleepFn: wait,
      });
      last = applyTranslatedCopy(source, parsed);
      if (!looksEnglishTitle(last.title)) return last;
    } catch (e) {
      lastErr = e;
      if (e.status != null) geminiPace.lastStatus = e.status;
      if (isRateLimitError(e)) throw e;
    }
    if (i < maxRetries - 1) await wait(backoffDelayMs(i));
  }
  if (last) return forceTurkishPrimary(last, source);
  throw lastErr || new Error('AI çeviri yok');
}

export async function scoreResearch(apiKey, item, { sleepFn } = {}) {
  const opts = jsonOpts(sleepFn ? { sleepFn } : {});
  try {
    const parsed = await generateJson(apiKey, buildScorePrompt(item), opts);
    let normalized = normalizeAiResult(parsed, item);
    if (!normalized) throw new Error('AI JSON yok veya treatment_potential geçersiz');
    if (looksEnglishTitle(normalized.title) || normalized.title === TITLE_TR_FALLBACK) {
      try {
        const copy = await translateResearchCopy(apiKey, item, opts);
        normalized = { ...normalized, ...copy };
      } catch {
        // translate-only already retried with delay; stub via forceTurkishPrimary
      }
    }
    return forceTurkishPrimary(normalized, item);
  } catch (scoreErr) {
    try {
      if (isRetryableGeminiStatus(scoreErr.status)) {
        await (opts.sleepFn || geminiPace.sleepFn)(
          retryDelayFromGeminiError(scoreErr, 0),
        );
      }
      const copy = await translateResearchCopy(apiKey, item, opts);
      return forceTurkishPrimary(
        {
          ...heuristicPendingScore(item),
          ...copy,
          ai_notes:
            'Tam skor başarısız; yalnız Türkçe çeviri. Tedavi vaadi yok; yayın yok.',
        },
        item,
      );
    } catch {
      throw scoreErr;
    }
  }
}
