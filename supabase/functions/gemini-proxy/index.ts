// Engelsiz Club — Gemini CORS proxy (ücretsiz Edge Function, Blaze gerekmez).
// Sır: Supabase Dashboard → Edge Functions → gemini-proxy → Secrets → GEMINI_API_KEY
// veya: npx supabase secrets set --env-file functions/.env --project-ref qycrkqwqrysypvqaipqn
//
// Deploy (JWT kapalı — misafir tarama):
//   npx supabase functions deploy gemini-proxy --no-verify-jwt --project-ref qycrkqwqrysypvqaipqn
//
// Flutter: supabase.functions.invoke('gemini-proxy')
// Gövde: { prompt, imageBase64?, mimeType?, model? }
//    veya Gemini native: { model, contents, generationConfig }
// Görsel üretim: { generateImage: true, prompt, imageBase64, mimeType? }
//    → gemini-3.1-flash-image (Nano Banana 2); metin modellerine düşme.
//
// ÜLKE KISITI (önemli): Google görsel üretimi AB/TR IP’lerine kapalı —
// eu-central-1’den 400 FAILED_PRECONDITION
// "Image generation is not available in your country." döner.
// Edge Function varsayılan olarak kullanıcıya en yakın bölgede koşar
// (TR → eu-central-1), bu yüzden görsel istekleri ABD bölgesine sabitlenmeli:
//   header  x-region: us-east-1
//   query   ?forceFunctionRegion=us-east-1
// Dart: functions.invoke(..., region: 'us-east-1') ikisini de ekler.
// Metin analizi kısıtlı değil; bölge sabitlemesi yalnız görsel için gerekir.
//
// Canlı Google (2026-09): gemini-flash-latest → gemini-3.8-flash → lite 200.
// gemini-3.6-flash asılıyor — zincire alma. Model başına 12s; 503’te sonraki.
// Görsel: gemini-3.1-flash-image → gemini-3-pro-image (GA adlar, -preview yok).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version, x-region",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "x-ec-image-model, x-ec-region",
};

/** Fonksiyonun gerçekte koştuğu Supabase bölgesi (hata mesajlarında işe yarar). */
const SB_REGION = (Deno.env.get("SB_REGION") ?? "").trim() || "unknown";

const DEFAULT_MODEL = "gemini-flash-latest";
/** flash-latest → 3.8 → lite. gemini-3.6-flash asılır; zincire alma. */
const FALLBACK_MODELS = [
  "gemini-flash-latest",
  "gemini-3.8-flash",
  "gemini-flash-lite-latest",
];
const SKIP_HANG_MODELS = new Set(["gemini-3.6-flash"]);

/** GA adlar (2026-06-25 sonrası). `-preview` sürümleri kapatıldı.
 *  `gemini-3.1-flash-lite-image` diye bir model yok — listeye alma. */
const DEFAULT_IMAGE_MODEL = "gemini-3.1-flash-image";
const IMAGE_FALLBACK_MODELS = [
  "gemini-3.1-flash-image",
  "gemini-3-pro-image",
];

const PER_MODEL_MS = 12_000;
const IMAGE_PER_MODEL_MS = 40_000;
/** Edge Function duvar saati sınırının altında kal. */
const IMAGE_TOTAL_MS = 105_000;
const EXHAUSTED_TR = "Analiz modeli şu an yanıt vermedi, tekrar deneyin.";
const COUNTRY_BLOCK_TR =
  "Google görsel üretimi bu bölgeden kapalı. Görsel isteğini ABD bölgesine " +
  "sabitle (x-region: us-east-1 veya ?forceFunctionRegion=us-east-1).";

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function stripDataUrl(raw: string): string {
  const s = raw.trim();
  const i = s.indexOf("base64,");
  if (s.startsWith("data:") && i >= 0) return s.slice(i + 7).trim();
  return s;
}

function isImageModel(model: string): boolean {
  const m = model.toLowerCase();
  return m.includes("-image") || m.startsWith("imagen");
}

function wantsImage(payload: Record<string, unknown>): boolean {
  if (payload.generateImage === true || payload.generate_image === true) {
    return true;
  }
  const gc = (payload.generationConfig ?? payload.generation_config) as
    | Record<string, unknown>
    | undefined;
  if (!gc || typeof gc !== "object") return false;
  const mods = gc.responseModalities ?? gc.response_modalities;
  if (!Array.isArray(mods)) return false;
  return mods.some((m) => String(m).toUpperCase().includes("IMAGE"));
}

function buildContents(payload: Record<string, unknown>): unknown {
  if (payload.contents) return payload.contents;
  const prompt = String(payload.prompt ?? "").trim();
  if (!prompt) return null;
  const parts: Array<Record<string, unknown>> = [{ text: prompt }];
  const imageRaw = String(
    payload.imageBase64 ?? payload.image_base64 ?? "",
  ).trim();
  if (imageRaw) {
    const mimeRaw = String(payload.mimeType ?? payload.mime_type ?? "image/jpeg")
      .trim()
      .toLowerCase();
    const mime = mimeRaw.startsWith("image/") ? mimeRaw : "image/jpeg";
    parts.push({
      inlineData: {
        mimeType: mime,
        data: stripDataUrl(imageRaw),
      },
    });
  }
  return [{ role: "user", parts }];
}

function isMissingFunction(text: string): boolean {
  return text.toLowerCase().includes("requested function was not found");
}

/** Google model 404 — gemini-proxy yok değil. */
function isGoogleModel404(status: number, text: string): boolean {
  if (isMissingFunction(text)) return false;
  const lower = text.toLowerCase();
  if (status === 404) {
    return (
      lower.includes("model") ||
      lower.includes("gemini-") ||
      lower.includes("not_found") ||
      lower.includes("not found") ||
      lower.includes("no longer available") ||
      lower.length === 0
    );
  }
  return (
    lower.includes("not_found") &&
    (lower.includes("model") || lower.includes("gemini-") || lower.includes("is not found"))
  );
}

function shouldTryNextModel(status: number, text: string): boolean {
  if (isGoogleModel404(status, text)) return true;
  // Google overload 503'ü iletme — sonraki modeli dene (12s skip hang).
  if (
    status === 408 ||
    status === 429 ||
    status === 502 ||
    status === 503 ||
    status === 504
  ) {
    return true;
  }
  const lower = text.toLowerCase();
  return (
    lower.includes("timeout") ||
    lower.includes("abort") ||
    lower.includes("asılı") ||
    lower.includes("timed out")
  );
}

/** Google’un ülke kısıtı. Model değiştirmek çözmez — bölge değişmeli. */
function isCountryBlocked(status: number, text: string): boolean {
  if (status !== 400 && status !== 403) return false;
  const lower = text.toLowerCase();
  return (
    lower.includes("not available in your country") ||
    lower.includes("user location is not supported")
  );
}

/** 400 "Aspect ratio is not enabled for this model" → oransız tekrar dene. */
function isAspectRatioRejected(status: number, text: string): boolean {
  return status === 400 && text.toLowerCase().includes("aspect ratio");
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

/** 200 gelse bile gövdede inlineData yoksa görsel yok (finishReason NO_IMAGE). */
function hasInlineImage(text: string): boolean {
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch (_) {
    return false;
  }
  const candidates = asRecord(decoded)?.candidates;
  if (!Array.isArray(candidates)) return false;
  for (const candidate of candidates) {
    const parts = asRecord(asRecord(candidate)?.content)?.parts;
    if (!Array.isArray(parts)) continue;
    for (const part of parts) {
      const p = asRecord(part);
      const inline = asRecord(p?.inlineData) ?? asRecord(p?.inline_data);
      if (inline && String(inline.data ?? "").length > 0) return true;
    }
  }
  return false;
}

type ImageAttempt = { model: string; modalities: string[] };

/** Model × modalite. Bazı sürümler yalnız ["IMAGE"], bazıları
 *  ["TEXT","IMAGE"] ile görsel döndürür; ikisini de dene. */
function imageAttempts(requested: string): ImageAttempt[] {
  const models: string[] = [];
  if (isImageModel(requested) && !SKIP_HANG_MODELS.has(requested)) {
    models.push(requested);
  }
  for (const m of IMAGE_FALLBACK_MODELS) {
    if (!m || SKIP_HANG_MODELS.has(m) || models.includes(m)) continue;
    models.push(m);
  }
  const attempts: ImageAttempt[] = [];
  for (const model of models) {
    attempts.push({ model, modalities: ["IMAGE"] });
    attempts.push({ model, modalities: ["TEXT", "IMAGE"] });
  }
  return attempts;
}

function imageGenerationConfig(
  payload: Record<string, unknown>,
  modalities: string[],
  dropAspectRatio: boolean,
): Record<string, unknown> {
  const source = asRecord(payload.generationConfig) ??
    asRecord(payload.generation_config) ?? {};
  const given = { ...source };
  // Metin yolundan sızabilen JSON zorlaması görsel çıktısını bozar.
  delete given.responseMimeType;
  delete given.response_mime_type;
  delete given.responseModalities;
  delete given.response_modalities;
  delete given.imageConfig;
  delete given.image_config;

  const imageConfig: Record<string, unknown> = {
    imageSize: "1K",
    ...(asRecord(source.imageConfig) ?? asRecord(source.image_config) ?? {}),
  };
  if (dropAspectRatio) delete imageConfig.aspectRatio;

  return { ...given, responseModalities: modalities, imageConfig };
}

function textGenerationConfig(payload: Record<string, unknown>): unknown {
  return (
    payload.generationConfig ??
    payload.generation_config ?? {
      temperature: 0.1,
      maxOutputTokens: 4096,
      responseMimeType: "application/json",
    }
  );
}

async function generateOnce(
  model: string,
  key: string,
  body: string,
  timeoutMs: number,
): Promise<{ ok: boolean; status: number; text: string }> {
  const gUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(key)}`;
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const upstream = await fetch(gUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: ac.signal,
    });
    const text = await upstream.text();
    return { ok: upstream.ok, status: upstream.status, text };
  } catch (e) {
    const msg = String(e);
    const aborted =
      (e instanceof DOMException && e.name === "AbortError") ||
      msg.toLowerCase().includes("abort");
    return {
      ok: false,
      status: aborted ? 504 : 502,
      text: JSON.stringify({
        error: {
          message: aborted ? "model timeout" : msg,
          status: "UNAVAILABLE",
        },
      }),
    };
  } finally {
    clearTimeout(timer);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, {
      error: { message: "POST only", status: "INVALID_ARGUMENT" },
    });
  }

  const key = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
  if (!key) {
    return json(503, { error: "GEMINI_API_KEY missing" });
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return json(400, {
      error: { message: "JSON gövde okunamadı", status: "INVALID_ARGUMENT" },
    });
  }

  const imageOut = wantsImage(payload);
  const modelRaw = String(
    payload.model || (imageOut ? DEFAULT_IMAGE_MODEL : DEFAULT_MODEL),
  );
  const requested = modelRaw.replace(/[^a-zA-Z0-9._-]/g, "") ||
    (imageOut ? DEFAULT_IMAGE_MODEL : DEFAULT_MODEL);
  const contents = buildContents(payload);
  if (!contents) {
    return json(400, {
      error: {
        message: "prompt veya contents gerekli",
        status: "INVALID_ARGUMENT",
      },
    });
  }

  try {
    if (imageOut) return await runImage(contents, payload, requested, key);
    return await runText(contents, payload, requested, key);
  } catch (e) {
    return json(502, {
      error: {
        message: `Gemini upstream: ${e}`,
        status: "UNAVAILABLE",
      },
    });
  }
});

/** Fotoğraf → çizgi film. Yalnız *-image modelleri; metin modeline düşme. */
async function runImage(
  contents: unknown,
  payload: Record<string, unknown>,
  requested: string,
  key: string,
): Promise<Response> {
  const deadline = Date.now() + IMAGE_TOTAL_MS;
  let lastFailStatus = 0;
  let lastFailText = "";
  let dropAspectRatio = false;

  for (const attempt of imageAttempts(requested)) {
    if (Date.now() >= deadline) break;
    const generationConfig = imageGenerationConfig(
      payload,
      attempt.modalities,
      dropAspectRatio,
    );
    const body = JSON.stringify({ contents, generationConfig });
    const result = await generateOnce(
      attempt.model,
      key,
      body,
      IMAGE_PER_MODEL_MS,
    );

    if (result.ok && hasInlineImage(result.text)) {
      return new Response(result.text, {
        status: result.status,
        headers: {
          ...cors,
          "Content-Type": "application/json; charset=utf-8",
          "x-ec-image-model": attempt.model,
          "x-ec-region": SB_REGION,
        },
      });
    }

    // Ülke kısıtı: başka model denemek boşuna, bölge değişmeli.
    if (isCountryBlocked(result.status, result.text)) {
      return json(451, {
        error: {
          message: `${COUNTRY_BLOCK_TR} (bölge: ${SB_REGION})`,
          status: "COUNTRY_BLOCKED",
          region: SB_REGION,
        },
      });
    }

    if (isAspectRatioRejected(result.status, result.text) && !dropAspectRatio) {
      dropAspectRatio = true;
      lastFailStatus = result.status;
      lastFailText = result.text;
      continue;
    }

    lastFailStatus = result.ok ? 200 : result.status;
    lastFailText = result.ok
      ? '{"error":{"message":"model görsel döndürmedi (NO_IMAGE)"}}'
      : result.text;
    // 200 ama görselsiz, 404, 429, 5xx, timeout → sıradaki model/modalite.
  }

  const clip = lastFailText.replace(/\s+/g, " ").trim().slice(0, 180);
  return json(503, {
    error: {
      message: clip ? `${EXHAUSTED_TR} ${clip}` : EXHAUSTED_TR,
      status: "UNAVAILABLE",
      lastStatus: lastFailStatus || 503,
      region: SB_REGION,
    },
  });
}

async function runText(
  contents: unknown,
  payload: Record<string, unknown>,
  requested: string,
  key: string,
): Promise<Response> {
  const models: string[] = [];
  // Çalışan modeller önce. 3.6 asılır — istekte gelse bile atla.
  for (const m of [...FALLBACK_MODELS, requested]) {
    if (!m || SKIP_HANG_MODELS.has(m) || models.includes(m)) continue;
    models.push(m);
  }

  const body = JSON.stringify({
    contents,
    generationConfig: textGenerationConfig(payload),
  });
  let lastFailStatus = 0;
  let lastFailText = "";
  for (const model of models) {
    const result = await generateOnce(model, key, body, PER_MODEL_MS);
    if (result.ok) {
      return new Response(result.text, {
        status: result.status,
        headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
      });
    }
    lastFailStatus = result.status;
    lastFailText = result.text;
    if (!shouldTryNextModel(result.status, result.text)) {
      return new Response(result.text, {
        status: result.status,
        headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
      });
    }
    // Model 404 / timeout / 429 / 503 / 5xx → sonraki. Fonksiyon-yok 404 değil.
  }
  const clip = lastFailText.replace(/\s+/g, " ").trim().slice(0, 180);
  return json(503, {
    error: {
      message: clip ? `${EXHAUSTED_TR} ${clip}` : EXHAUSTED_TR,
      status: "UNAVAILABLE",
      lastStatus: lastFailStatus || 503,
    },
  });
}
