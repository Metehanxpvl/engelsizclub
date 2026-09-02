/**
 * Engelsiz Club — R2 etiket yükleme (presigned PUT) + Gemini CORS proxy.
 * Flutter sır tutmaz; üretimde bu Worker kullanılır (Firebase Blaze gerekmez).
 *
 * Cloudflare Dashboard → Workers → bu dosyayı yapıştırın
 * veya: npx wrangler deploy  (cloudflare/wrangler.toml)
 *
 * Secrets (değerleri git'e koymayın):
 *   wrangler secret put GEMINI_API_KEY
 *   wrangler secret put R2_ACCOUNT_ID
 *   wrangler secret put R2_ACCESS_KEY_ID
 *   wrangler secret put R2_SECRET_ACCESS_KEY
 *   wrangler secret put R2_BUCKET
 *   wrangler secret put R2_PUBLIC_BASE_URL
 *
 * Flutter:
 *   --dart-define=R2_WORKER_URL=https://engelsizclub-r2.<hesap>.workers.dev
 *   --dart-define=GEMINI_PROXY_URL=https://engelsizclub-r2.<hesap>.workers.dev/gemini
 *
 * CORS: bucket public GET + bu origin PUT / POST.
 */

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "content-type, authorization",
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function sanitizeKey(raw) {
  let s = String(raw || "").replace(/\\/g, "/").replace(/\.\./g, "");
  s = s.replace(/[^a-zA-Z0-9._/-]/g, "_").replace(/^\/+/, "");
  if (!s) s = `product-labels/unknown/${Date.now()}.jpg`;
  return s.slice(0, 200);
}

async function hmac(key, data) {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, data);
  return new Uint8Array(sig);
}

function toHex(buf) {
  return [...buf].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(data) {
  const hash = await crypto.subtle.digest("SHA-256", data);
  return toHex(new Uint8Array(hash));
}

function amzDate(d) {
  return d.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

/**
 * R2 S3-compatible presigned PUT (SigV4, UNSIGNED-PAYLOAD).
 */
async function presignPut({
  accountId,
  accessKeyId,
  secretAccessKey,
  bucket,
  key,
  contentType,
  expires = 300,
}) {
  const host = `${accountId}.r2.cloudflarestorage.com`;
  const urlPath = `/${bucket}/${key.split("/").map(encodeURIComponent).join("/")}`;
  const now = new Date();
  const amz = amzDate(now);
  const datestamp = amz.slice(0, 8);
  const region = "auto";
  const service = "s3";
  const credential = `${accessKeyId}/${datestamp}/${region}/${service}/aws4_request`;

  const signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date";
  const payloadHash = "UNSIGNED-PAYLOAD";
  const query = new URLSearchParams({
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": credential,
    "X-Amz-Date": amz,
    "X-Amz-Expires": String(expires),
    "X-Amz-SignedHeaders": signedHeaders,
  });

  const canonicalQuery = [...query.entries()]
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .sort()
    .join("&");

  const canonicalHeaders =
    `content-type:${contentType}\n` +
    `host:${host}\n` +
    `x-amz-content-sha256:${payloadHash}\n` +
    `x-amz-date:${amz}\n`;

  const canonicalRequest = [
    "PUT",
    urlPath,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");

  const enc = new TextEncoder();
  const canonicalHash = await sha256Hex(enc.encode(canonicalRequest));
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amz,
    `${datestamp}/${region}/${service}/aws4_request`,
    canonicalHash,
  ].join("\n");

  let k = enc.encode(`AWS4${secretAccessKey}`);
  k = await hmac(k, enc.encode(datestamp));
  k = await hmac(k, enc.encode(region));
  k = await hmac(k, enc.encode(service));
  k = await hmac(k, enc.encode("aws4_request"));
  const signature = toHex(await hmac(k, enc.encode(stringToSign)));

  return `https://${host}${urlPath}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

function buildGeminiContents(payload) {
  if (payload.contents) return payload.contents;
  const prompt = String(payload.prompt || "").trim();
  if (!prompt) return null;
  const parts = [{ text: prompt }];
  const imageRaw = String(payload.imageBase64 || payload.image_base64 || "").trim();
  if (imageRaw) {
    let data = imageRaw;
    const marker = data.indexOf("base64,");
    if (data.startsWith("data:") && marker >= 0) data = data.slice(marker + 7).trim();
    const mimeRaw = String(payload.mimeType || payload.mime_type || "image/jpeg")
      .trim()
      .toLowerCase();
    parts.push({
      inlineData: {
        mimeType: mimeRaw.startsWith("image/") ? mimeRaw : "image/jpeg",
        data,
      },
    });
  }
  return [{ role: "user", parts }];
}

const DEFAULT_GEMINI_MODEL = "gemini-flash-latest";
const GEMINI_FALLBACK_MODELS = [
  "gemini-flash-latest",
  "gemini-3.8-flash",
  "gemini-flash-lite-latest",
  "gemini-3.6-flash",
];
const GEMINI_PER_MODEL_MS = 12000;
const GEMINI_EXHAUSTED_TR =
  "Analiz modeli şu an yanıt vermedi, tekrar deneyin.";

function isGoogleModel404(status, text) {
  const lower = String(text || "").toLowerCase();
  if (lower.includes("requested function was not found")) return false;
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

function shouldTryNextGemini(status, text) {
  if (isGoogleModel404(status, text)) return true;
  if (status === 408 || status === 429 || status === 502 || status === 504) {
    return true;
  }
  const lower = String(text || "").toLowerCase();
  return lower.includes("timeout") || lower.includes("abort") || lower.includes("timed out");
}

async function generateGeminiOnce(model, key, body) {
  const gUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(key)}`;
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), GEMINI_PER_MODEL_MS);
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
    const msg = String(e && e.message ? e.message : e);
    const aborted = msg.toLowerCase().includes("abort");
    return {
      ok: false,
      status: aborted ? 504 : 502,
      text: JSON.stringify({
        error: { message: aborted ? "model timeout" : msg, status: "UNAVAILABLE" },
      }),
    };
  } finally {
    clearTimeout(timer);
  }
}

async function handleGemini(request, env) {
  const key = String(env.GEMINI_API_KEY || "").trim();
  if (!key) {
    return json(503, {
      error: {
        message: "GEMINI_API_KEY tanımlı değil",
        status: "FAILED_PRECONDITION",
      },
    });
  }
  let payload = {};
  try {
    payload = await request.json();
  } catch (_) {
    return json(400, {
      error: {
        message: "JSON gövde okunamadı",
        status: "INVALID_ARGUMENT",
      },
    });
  }
  const requested =
    String(payload.model || DEFAULT_GEMINI_MODEL).replace(/[^a-zA-Z0-9._-]/g, "") ||
    DEFAULT_GEMINI_MODEL;
  const contents = buildGeminiContents(payload);
  const generationConfig = payload.generationConfig || payload.generation_config;
  if (!contents) {
    return json(400, {
      error: { message: "prompt veya contents gerekli", status: "INVALID_ARGUMENT" },
    });
  }
  const models = [];
  for (const m of [...GEMINI_FALLBACK_MODELS, requested]) {
    if (m && !models.includes(m)) models.push(m);
  }
  const googleBody = JSON.stringify({ contents, generationConfig });
  for (const model of models) {
    const result = await generateGeminiOnce(model, key, googleBody);
    if (result.ok) {
      return new Response(result.text, {
        status: result.status,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    if (!shouldTryNextGemini(result.status, result.text)) {
      return new Response(result.text, {
        status: result.status,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
  }
  return json(503, {
    error: { message: GEMINI_EXHAUSTED_TR, status: "UNAVAILABLE" },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/gemini") {
      return handleGemini(request, env);
    }

    const accountId = env.R2_ACCOUNT_ID || "";
    const accessKeyId = env.R2_ACCESS_KEY_ID || "";
    const secretAccessKey = env.R2_SECRET_ACCESS_KEY || "";
    const bucket = env.R2_BUCKET || env.R2_BUCKET_NAME || "";
    const publicBase = String(env.R2_PUBLIC_BASE_URL || env.R2_PUBLIC_URL || "").replace(
      /\/$/,
      "",
    );

    if (request.method === "POST" && url.pathname === "/sign") {
      if (!accountId || !accessKeyId || !secretAccessKey || !bucket || !publicBase) {
        return json(500, {
          error:
            "R2 secrets eksik. R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL",
        });
      }
      let body = {};
      try {
        body = await request.json();
      } catch (_) {
        body = {};
      }
      const contentType = String(body.contentType || "image/jpeg");
      const key = sanitizeKey(
        body.key || `product-labels/${crypto.randomUUID()}/${Date.now()}.jpg`,
      );
      const uploadUrl = await presignPut({
        accountId,
        accessKeyId,
        secretAccessKey,
        bucket,
        key,
        contentType,
      });
      return json(200, {
        ok: true,
        key,
        uploadUrl,
        publicUrl: `${publicBase}/${key}`,
      });
    }

    return json(404, { error: "POST /sign veya POST /gemini kullanın." });
  },
};
