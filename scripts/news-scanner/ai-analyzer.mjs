const MODELS = [
  'gemini-flash-latest',
  'gemini-3.8-flash',
  'gemini-flash-lite-latest',
];

const CATEGORIES = [
  'Engelli Hakları',
  'Sosyal Yardım',
  'Ekonomik Destek',
  'Evde Bakım',
  'Engelli Aylığı',
  'Eğitim',
  'Özel Eğitim',
  'Sağlık',
  'Rehabilitasyon',
  'İstihdam',
  'EKPSS',
  'Erişilebilirlik',
  'Ulaşım',
  'Araç / ÖTV',
  'Medikal Cihaz',
  'Ortez / Protez',
  'Belediyeler',
  'Kamu Hizmetleri',
  'Çocuk / Aile',
  'Sosyal Yaşam',
  'Farkındalık',
  'Diğer',
];

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

function importanceFromScore(score) {
  if (score >= 90) return 'very_high';
  if (score >= 70) return 'high';
  if (score >= 50) return 'informational';
  return 'drop';
}

function pickCategory(raw, list) {
  const known = new Set(CATEGORIES);
  const cats = (Array.isArray(list) ? list : [raw])
    .map((v) => String(v || '').trim())
    .filter((v) => known.has(v));
  const primary = known.has(String(raw || '').trim())
    ? String(raw).trim()
    : cats[0] || 'Diğer';
  return { category: primary, categories: cats.length ? cats : [primary] };
}

export function normalizeAiResult(parsed) {
  if (!parsed || typeof parsed !== 'object') return null;
  const score = Math.round(Number(parsed.relevance_score));
  if (!Number.isFinite(score)) return null;
  const clamped = Math.max(0, Math.min(100, score));
  const relevant = parsed.is_relevant === true && clamped >= 50;
  const { category, categories } = pickCategory(
    parsed.category,
    parsed.categories,
  );
  const summary = String(parsed.summary || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 900);
  const title = String(parsed.title || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 240);
  const reason = String(parsed.reason || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 500);
  const affected = Array.isArray(parsed.affected_users)
    ? parsed.affected_users.map((v) => String(v).trim()).filter(Boolean).slice(0, 6)
    : [];
  return {
    is_relevant: relevant,
    relevance_score: clamped,
    importance_level: importanceFromScore(clamped),
    category,
    categories,
    title,
    summary,
    reason,
    affected_users: affected,
  };
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
        temperature: 0.15,
        maxOutputTokens: 700,
        responseMimeType: 'application/json',
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

export async function analyzeNewsItem(apiKey, item) {
  const prompt = `Engelsiz Club, Türkiye'de engelli / özel gereksinimli bireyler ve aileleri için bir topluluk uygulamasıdır.

Bu haber onlar için gerçekten anlamlı mı? Başlıkta "engelli" geçmese bile ÖTV muafiyeti, evde bakım, özel eğitim, EKPSS, engelli aylığı, erişilebilirlik, istihdam kotası gibi dolaylı konular da ilgili olabilir.

ALMA (is_relevant=false, score 0-49):
- Magazin, reklam, sponsorlu ürün
- "engelsiz" kelimesi geçip engellilikle ilgisi yok
- Sadece spor sonucu (önemli engelli spor haberi hariç)
- Eski / tekrar haber
- Konuyla ilgisiz etkinlik duyurusu

SKOR:
90-100 very_high: yeni hak, aylık/bakım değişikliği, ÖTV/araç, EKPSS, büyük kamu desteği
70-89 high: belediye/eğitim/erişilebilirlik/sağlık/burs/ulaşım desteği
50-69 informational: farkındalık, sosyal proje, başarı hikayesi

Özet en fazla 3-4 cümle, Türkçe, kaynakta olmayan bilgi ekleme.

Kaynak: ${item.source_name}
Tarih: ${item.published_at || ''}
URL: ${item.article_url}
Başlık: ${item.title}
Metin: ${String(item.summary || '').slice(0, 900)}

Yalnız JSON:
{"is_relevant":true,"relevance_score":0,"importance_level":"very_high|high|informational","category":"Engelli Hakları","categories":["Engelli Hakları"],"title":"...","summary":"...","reason":"...","affected_users":["Engelli bireyler"]}`;

  let lastErr;
  for (const model of MODELS) {
    try {
      const text = await generateOnce(apiKey, model, prompt);
      const parsed = extractJson(text);
      const norm = normalizeAiResult(parsed);
      if (!norm) throw new Error('AI JSON yok');
      return norm;
    } catch (e) {
      lastErr = e;
      if (e.status && e.status !== 404 && e.status !== 503) break;
    }
  }
  throw lastErr || new Error('AI başarısız');
}
