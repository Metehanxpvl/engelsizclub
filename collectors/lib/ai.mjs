const MODELS = [
  'gemini-flash-latest',
  'gemini-3.8-flash',
  'gemini-flash-lite-latest',
];

function extractJson(text) {
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

async function generateOnce(apiKey, model, prompt) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 512,
      },
    }),
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

export async function classifyCandidate(apiKey, item) {
  const prompt = `Türkiye’de ÖZEL GEREKSİNİMLİ / ENGELLİ birey veya ailesi için resmi fırsat, destek, burs, hak, cihaz, eğitim veya istihdam duyurusu mu?

relevant=true YALNIZCA hedef kitle açıkça engelli, özel gereksinimli, otizm, down, SMA, erişilebilirlik, özel eğitim, evde eğitim, bakım aylığı, ÖTV muafiyeti vb. ise.

relevant=false:
- Genel belediye / spor / konser / hava / imar haberi
- Herkese açık burs, iş ilanı, TÜBİTAK çağrısı (engelli vurgusu yoksa)
- "Bursa" şehri, genel istihdam, genel kota

Teşhis koyma. Ham HTML yok.

Başlık: ${item.title}
Özet: ${item.summary}
Kaynak: ${item.sourceUrl}

Yalnız JSON:
{"relevant":true|false,"title":"...","summary":"...","category":"firsat|destek|hak|burs|egitim|istihdam|diger","city":"","deadline":"YYYY-MM-DD veya boş","notes":"kısa gerekçe"}`;

  let lastErr;
  for (const model of MODELS) {
    try {
      const text = await generateOnce(apiKey, model, prompt);
      const parsed = extractJson(text);
      if (!parsed || typeof parsed !== 'object') {
        throw new Error('AI JSON yok');
      }
      return parsed;
    } catch (e) {
      lastErr = e;
      if (e.status && e.status !== 404 && e.status !== 503) break;
    }
  }
  throw lastErr || new Error('AI başarısız');
}
