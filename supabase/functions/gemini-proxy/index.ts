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
// Canlı Google (2026-09): gemini-flash-latest → gemini-3.8-flash → lite 200.
// gemini-3.6-flash asılıyor — zincire alma. Model başına 12s; 503’te sonraki.
// Görsel: model başına 45s. 2.5 / 2.0 / 1.5-flash emekli 404.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_MODEL = "gemini-flash-latest";
/** flash-latest → 3.8 → lite. gemini-3.6-flash asılır; zincire alma. */
const FALLBACK_MODELS = [
  "gemini-flash-latest",
  "gemini-3.8-flash",
  "gemini-flash-lite-latest",
];
const SKIP_HANG_MODELS = new Set(["gemini-3.6-flash"]);

const DEFAULT_IMAGE_MODEL = "gemini-3.1-flash-image";
const IMAGE_FALLBACK_MODELS = [
  "gemini-3.1-flash-image",
  "gemini-3.1-flash-lite-image",
];

const PER_MODEL_MS = 12_000;
const IMAGE_PER_MODEL_MS = 45_000;
const EXHAUSTED_TR = "Analiz modeli şu an yanıt vermedi, tekrar deneyin.";

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

function shouldTryNextModel(
  status: number,
  text: string,
  imageOut = false,
): boolean {
  if (isGoogleModel404(status, text)) return true;
  // Google overload 503'ü iletme — sonraki modeli dene (12s skip hang).
  if (
    status === 408 ||
    status === 429 ||
    status === 502 ||
    status === 503 ||
    status === 504 ||
    (imageOut && status === 400)
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

function imageGenerationConfig(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const given = (payload.generationConfig ?? payload.generation_config) as
    | Record<string, unknown>
    | undefined;
  const imageConfig = {
    imageSize: "1K",
    ...((given?.imageConfig ?? given?.image_config) as
      | Record<string, unknown>
      | undefined),
  };
  return {
    responseModalities: ["IMAGE"],
    ...given,
    imageConfig,
  };
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
  const generationConfig = imageOut
    ? imageGenerationConfig(payload)
    : textGenerationConfig(payload);
  if (!contents) {
    return json(400, {
      error: {
        message: "prompt veya contents gerekli",
        status: "INVALID_ARGUMENT",
      },
    });
  }

  const models: string[] = [];
  if (imageOut) {
    // Metin flash modelleri IMAGE üretemez (400). Yalnız *-image.
    if (isImageModel(requested) && !SKIP_HANG_MODELS.has(requested)) {
      models.push(requested);
    }
    for (const m of IMAGE_FALLBACK_MODELS) {
      if (!m || SKIP_HANG_MODELS.has(m) || models.includes(m)) continue;
      models.push(m);
    }
  } else {
    // Çalışan modeller önce. 3.6 asılır — istekte gelse bile atla.
    for (const m of [...FALLBACK_MODELS, requested]) {
      if (!m || SKIP_HANG_MODELS.has(m) || models.includes(m)) continue;
      models.push(m);
    }
  }

  const googleBody = JSON.stringify({ contents, generationConfig });
  const timeoutMs = imageOut ? IMAGE_PER_MODEL_MS : PER_MODEL_MS;
  let lastFailStatus = 0;
  let lastFailText = "";
  try {
    for (const model of models) {
      const result = await generateOnce(model, key, googleBody, timeoutMs);
      if (result.ok) {
        return new Response(result.text, {
          status: result.status,
          headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
        });
      }
      lastFailStatus = result.status;
      lastFailText = result.text;
      if (!shouldTryNextModel(result.status, result.text, imageOut)) {
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
  } catch (e) {
    return json(502, {
      error: {
        message: `Gemini upstream: ${e}`,
        status: "UNAVAILABLE",
      },
    });
  }
});
