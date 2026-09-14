import { MISSING } from './config.mjs';

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

export function buildScorePrompt(item) {
  return `Sen EngelsizClub bilimsel tarama asistanısın. Ailelere yönelik, özel gereksinim / pediatrik nöroloji (serebral palsi, PVL, HIE, otizm, Down, epilepsi, nöroplastisite, remiyelinizasyon, oligodendrosit, gen tedavisi, kök hücre) bağlamında çalışmayı değerlendir.

${ANIMAL_HUMAN_DISCLAIMER}

Kurallar:
- title: ZORUNLU sade Türkçe (aile dostu). İngilizce/kaynak başlığını title alanına kopyalama. Tedavi/çare iddiası yok.
- original_title: kaynak başlığını AYNEN bırak (genelde İngilizce).
- summary, why_important, limitations: ZORUNLU Türkçe. Uydurma yok.
- categories ve conditions: Türkçe etiket veya kısa iki dilli etiket (ör. "serebral palsi").
- Eksik bilgi uydurma. Bilinmeyen metin alanları için null değil "${MISSING}" kullan. Sayısal skor yoksa null.
- treatment_potential yalnız: HIGH_VALUE | POTENTIAL_VALUE | IRRELEVANT
  HIGH_VALUE: insan, hedef kitleyle ilgili, tedavi/rehabilitasyon/mekanizma açısından anlamlı klinik bağ.
  POTENTIAL_VALUE: ilgili ama erken, hayvan, küçük örneklem, belirsiz.
  IRRELEVANT: konumuzla alakasız (ör. yalnızca erişkin onkoloji). Serebral palsi, PVL, HIE, otizm, Down, pediatrik epilepsi, nöroplastisite/remiyelinizasyon/kök hücre-gen tedavisi (bu popülasyonlarda) asla IRRELEVANT değil — en az POTENTIAL_VALUE.
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
- title: ZORUNLU sade Türkçe (aile dostu). İngilizce başlığı title’a kopyalama. Tedavi/çare iddiası yok.
- original_title: kaynak başlığını AYNEN bırak (İngilizce/orijinal dil).
- summary, why_important, limitations: ZORUNLU Türkçe. Uydurma yok; yoksa "${MISSING}".
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
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(apiKey)}`;
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
  if (!res.ok) {
    const msg = json?.error?.message || `Gemini HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    throw err;
  }
  const text = json?.candidates?.[0]?.content?.parts
    ?.map((p) => p.text)
    .filter(Boolean)
    .join('\n')
    .trim();
  return text || '';
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
    study_phase: textOrMissing(parsed.study_phase || item.studyPhase),
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

async function generateJson(apiKey, prompt, { maxOutputTokens = 1536 } = {}) {
  let lastErr;
  for (const model of MODELS) {
    try {
      const text = await generateOnce(apiKey, model, prompt, { maxOutputTokens });
      const parsed = extractJson(text);
      if (!parsed) throw new Error('AI JSON yok');
      return parsed;
    } catch (e) {
      lastErr = e;
      if (e.status && e.status !== 404 && e.status !== 503) break;
    }
  }
  throw lastErr || new Error('AI başarısız');
}

/** Cheaper second pass: Turkish title/summary only; no scores. */
export async function translateResearchCopy(apiKey, item) {
  const parsed = await generateJson(apiKey, buildTranslatePrompt(item), {
    maxOutputTokens: 1024,
  });
  return applyTranslatedCopy(item, parsed);
}

export async function scoreResearch(apiKey, item) {
  try {
    const parsed = await generateJson(apiKey, buildScorePrompt(item));
    const normalized = normalizeAiResult(parsed, item);
    if (!normalized) throw new Error('AI JSON yok veya treatment_potential geçersiz');
    return normalized;
  } catch (scoreErr) {
    try {
      const copy = await translateResearchCopy(apiKey, item);
      return {
        ...heuristicPendingScore(item),
        ...copy,
        ai_notes:
          'Tam skor başarısız; yalnız Türkçe çeviri. Tedavi vaadi yok; yayın yok.',
      };
    } catch {
      throw scoreErr;
    }
  }
}
