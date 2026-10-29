const ANTHROPIC_MODEL =
  process.env.ANTHROPIC_MODEL || 'claude-3-5-haiku-latest';
const GEMINI_MODELS = [
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
];

const CATEGORIES = new Set(['haber', 'firsat', 'destek', 'bilim']);
const SUBS = new Set([
  'burs',
  'hibe',
  'istihdam',
  'egitim',
  'saglik',
  'mevzuat',
  'etkinlik',
  'tedavi',
  'cihaz',
]);
const EVIDENCE = new Set([
  'arastirma-asamasi',
  'hayvan-deneyi',
  'faz1',
  'faz2',
  'faz3',
  'onayli-tedavi',
  'rehabilitasyon-yontemi',
]);

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

export function buildPrompt(item, conditionIds) {
  return `Türkiye'de engelli birey ve aileleri için içerik sınıflandır.

KURALLAR:
- "Tedavi eder, iyileştirir, kesin çözüm" deme. "Araştırılıyor, çalışmada şu görüldü" dili kullan.
- Mucize tedavi, kanıtsız ürün, bağış/dolandırıcılık → risk_flag=true.
- Bilim kayıtlarında evidence_level zorunlu.
- Tarih/tutar emin değilsen null bırak, uydurma.
- Orijinal metni kopyalama; 1-2 cümle sade Türkçe özet yaz.
- Bilim ve sağlık için not: "Bilgilendirme amaçlıdır, karar için doktorunuza danışın."

Başlık: ${item.title}
Kaynak: ${item.source}
URL: ${item.url}
Tarih: ${item.date || ''}
Özet: ${item.raw_snippet || ''}
Durum id'leri: ${conditionIds.join(', ')}

Yalnız JSON:
{"category":"haber|firsat|destek|bilim","subcategory":"burs|hibe|istihdam|egitim|saglik|mevzuat|etkinlik|tedavi|cihaz","condition":[],"disability_type":"","city":"Ulusal","target_audience":"","summary_tr":"","deadline":null,"amount":null,"eligibility":"","apply_url":"","evidence_level":null,"confidence":0.0,"risk_flag":false}`;
}

export function normalizeEnrichment(raw, item) {
  const obj = raw && typeof raw === 'object' ? raw : {};
  let category = String(obj.category || '').toLowerCase();
  if (!CATEGORIES.has(category)) category = item.kind === 'science' ? 'bilim' : 'haber';
  let subcategory = String(obj.subcategory || '').toLowerCase();
  if (!SUBS.has(subcategory)) subcategory = '';
  let evidence = String(obj.evidence_level || '').toLowerCase();
  if (category === 'bilim' && !EVIDENCE.has(evidence)) evidence = 'arastirma-asamasi';
  if (category !== 'bilim') evidence = EVIDENCE.has(evidence) ? evidence : null;
  const confidence = Math.min(1, Math.max(0, Number(obj.confidence) || 0));
  const risk = obj.risk_flag === true || obj.risk_flag === 'true';
  const conditions = Array.isArray(obj.condition)
    ? obj.condition.map((x) => String(x).trim()).filter(Boolean)
    : [];
  const deadline = String(obj.deadline || '').match(/^\d{4}-\d{2}-\d{2}$/)
    ? String(obj.deadline).slice(0, 10)
    : null;
  return {
    category,
    subcategory,
    condition: conditions,
    disability_type: String(obj.disability_type || '').slice(0, 80),
    city: String(obj.city || 'Ulusal').trim() || 'Ulusal',
    target_audience: String(obj.target_audience || '').slice(0, 120),
    summary_tr: String(obj.summary_tr || '').slice(0, 800),
    deadline,
    amount: obj.amount == null || obj.amount === '' ? null : String(obj.amount).slice(0, 80),
    eligibility: String(obj.eligibility || '').slice(0, 400),
    apply_url: String(obj.apply_url || item.url || '').slice(0, 500),
    evidence_level: evidence,
    confidence,
    risk_flag: risk,
    ai_generated: true,
  };
}

async function anthropicOnce(apiKey, prompt) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: 700,
      temperature: 0,
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(json?.error?.message || `Anthropic HTTP ${res.status}`);
  }
  const text = (json?.content || [])
    .map((p) => p.text)
    .filter(Boolean)
    .join('\n');
  const parsed = extractJson(text);
  if (!parsed) throw new Error('Anthropic JSON yok');
  return parsed;
}

async function geminiOnce(apiKey, prompt) {
  let lastErr;
  for (const model of GEMINI_MODELS) {
    try {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
        `?key=${encodeURIComponent(apiKey)}`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 700 },
        }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(json?.error?.message || `Gemini HTTP ${res.status}`);
      const text = json?.candidates?.[0]?.content?.parts
        ?.map((p) => p.text)
        .filter(Boolean)
        .join('\n');
      const parsed = extractJson(text);
      if (!parsed) throw new Error('Gemini JSON yok');
      return parsed;
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr || new Error('Gemini başarısız');
}

export async function enrichItem(item, { conditionIds, healthNote }) {
  const prompt = buildPrompt(item, conditionIds);
  const anthropic = (process.env.ANTHROPIC_API_KEY || '').trim();
  const gemini = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '').trim();
  let parsed;
  if (anthropic) parsed = await anthropicOnce(anthropic, prompt);
  else if (gemini) parsed = await geminiOnce(gemini, prompt);
  else throw new Error('ANTHROPIC_API_KEY veya GEMINI_API_KEY yok');
  const out = normalizeEnrichment(parsed, item);
  if (!out.summary_tr) out.summary_tr = String(item.raw_snippet || '').slice(0, 280);
  if (
    (out.category === 'bilim' || out.subcategory === 'saglik' || out.subcategory === 'tedavi') &&
    healthNote &&
    !out.summary_tr.includes('doktorunuza')
  ) {
    out.summary_tr = `${out.summary_tr} ${healthNote}`.trim();
  }
  return out;
}
