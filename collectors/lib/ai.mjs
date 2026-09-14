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
  const prompt = `Türkiye’de özel gereksinimli / engelli birey-aile VEYA dar gelirli aileye yönelik resmi fırsat, destek, burs, hak, cihaz, eğitim, sosyal yardım veya başvurusu açık duyuru mu?

relevant=true (direct): hedef kitle açıkça şu alandaysa
engelli, engelsiz, özel gereksinim(li), özel eğitim, ÖYÇ, kaynaştırma, BEP, otizm/OSB/asperger, down sendromu, serebral palsi, SMA, CVI, DEHB, işitme/görme/bedensel/zihinsel yetersizlik, erişilebilirlik, MEB ORGM, RAM, ÇÖZGER, bakım aylığı, ÖTV muafiyeti, EKPSS, işaret dili, tekerlekli sandalye, tıbbi/medikal cihaz, engelli aracı.
Burs: burs + çekirdek terim varsa relevant=true. Burs tek başına relevant=false.

potential_family_benefit=true (engelli demese de): sosyal yardım, nakdi yardım, maddi destek, dar gelirli aile, ücretsiz kurs, ücretsiz ulaşım, gıda/yakacak/kira yardımı, başvuru açıldı/başladı — aile faydası.

relevant=false VE potential_family_benefit=false:
- Asfalt, yol çalışması, kazı, imar, ihale
- Personel atama, memur alımı (engelli kotası yoksa)
- Siyasi açıklama, başkan açıklaması (yardım/hak yoksa)
- Genel açılış/tören, konser, spor galibiyeti, hava durumu

Kategori etiketleri (1-3, zorunlu değil; yoksa diger):
firsat, destek, hak, burs, egitim, istihdam, sosyal_yardim, nakdi_yardim, ulasim, cihaz, saglik, barinma, etkinlik, basvuru, bakim, erisilebilirlik, ozel_egitim, kultur, otv, diger

Teşhis koyma. Ham HTML yok. Yayınlama.

Başlık: ${item.title}
Özet: ${item.summary}
Kaynak: ${item.sourceUrl}

Yalnız JSON:
{"relevant":true|false,"potential_family_benefit":true|false,"title":"...","summary":"...","category":"destek","categories":["destek"],"city":"","deadline":"YYYY-MM-DD veya boş","notes":"kısa gerekçe"}`;

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
