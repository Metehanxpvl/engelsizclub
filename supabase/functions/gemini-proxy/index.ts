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

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_MODEL = "gemini-3.6-flash";
// 1.5-flash emekli (Google 404). İstenen model 404 olursa zincir.
const FALLBACK_MODELS = [
  "gemini-3.6-flash",
  "gemini-flash-latest",
  "gemini-2.5-flash",
  "gemini-2.0-flash",
];

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
  if (status === 404) return true;
  const lower = text.toLowerCase();
  return (
    lower.includes("not_found") &&
    (lower.includes("model") || lower.includes("gemini-") || lower.includes("is not found"))
  );
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
    return json(503, {
      error: {
        message: "GEMINI_API_KEY tanımlı değil",
        status: "FAILED_PRECONDITION",
      },
    });
  }

  let payload: Record<string, unknown> = {};
  try {
    payload = (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return json(400, {
      error: { message: "JSON gövde okunamadı", status: "INVALID_ARGUMENT" },
    });
  }

  const modelRaw = String(payload.model || DEFAULT_MODEL);
  const requested = modelRaw.replace(/[^a-zA-Z0-9._-]/g, "") || DEFAULT_MODEL;
  const contents = buildContents(payload);
  const generationConfig =
    payload.generationConfig ??
    payload.generation_config ?? {
      temperature: 0.1,
      maxOutputTokens: 4096,
      responseMimeType: "application/json",
    };
  if (!contents) {
    return json(400, {
      error: {
        message: "prompt veya contents gerekli",
        status: "INVALID_ARGUMENT",
      },
    });
  }

  const models: string[] = [];
  for (const m of [requested, ...FALLBACK_MODELS]) {
    if (m && !models.includes(m)) models.push(m);
  }

  let lastStatus = 502;
  let lastText = "";
  try {
    for (const model of models) {
      const gUrl =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
        `?key=${encodeURIComponent(key)}`;
      const upstream = await fetch(gUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents, generationConfig }),
      });
      const text = await upstream.text();
      lastStatus = upstream.status;
      lastText = text;
      if (upstream.ok) {
        return new Response(text, {
          status: upstream.status,
          headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
        });
      }
      if (!isGoogleModel404(upstream.status, text)) {
        return new Response(text, {
          status: upstream.status,
          headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
        });
      }
      // Model 404 → sonraki. Fonksiyon yok 404 değil.
    }
    return new Response(lastText || JSON.stringify({
      error: { message: "Analiz modeli bulunamadı (404)", status: "NOT_FOUND" },
    }), {
      status: lastStatus,
      headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
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
