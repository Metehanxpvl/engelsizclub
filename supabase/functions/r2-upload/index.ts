// Cloudflare R2 (S3) upload — secrets uygulama içinde değil, burada.
// Deploy:
//   supabase secrets set R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... R2_BUCKET_NAME=engelsizclub-ilanlar R2_ACCOUNT_ID=22d8a199f4ecf32ed81795a03f2d3a1c R2_PUBLIC_URL=https://pub-41d8be38e909416fbb3804b3a3e88569.r2.dev
//   supabase functions deploy r2-upload --no-verify-jwt=false
//
// Flutter: supabase.functions.invoke('r2-upload', body: { fileName, contentType, dataBase64 })

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sanitizeName(name: string): string {
  const base = name.split(/[/\\]/).pop() || "photo.jpg";
  return base.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 80) || "photo.jpg";
}

function extFrom(name: string, contentType: string): string {
  const n = name.toLowerCase();
  if (n.endsWith(".png")) return "png";
  if (n.endsWith(".webp")) return "webp";
  if (n.endsWith(".gif")) return "gif";
  if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "jpg";
  if (contentType.includes("png")) return "png";
  if (contentType.includes("webp")) return "webp";
  if (contentType.includes("gif")) return "gif";
  return "jpg";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }

  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
  const bucket = Deno.env.get("R2_BUCKET_NAME") ?? "engelsizclub-ilanlar";
  const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "";
  const publicBase = (Deno.env.get("R2_PUBLIC_URL") ?? "").replace(/\/$/, "");

  if (!accessKeyId || !secretAccessKey || !accountId || !publicBase) {
    return json(500, {
      error:
        "R2 secrets eksik. supabase secrets set R2_ACCESS_KEY_ID ... komutunu çalıştırın.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json(401, { error: "Giriş gerekli." });
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData.user) {
      return json(401, { error: "Oturum geçersiz. Tekrar giriş yapın." });
    }

    const payload = await req.json();
    const fileName = sanitizeName(String(payload.fileName ?? "photo.jpg"));
    const contentType = String(payload.contentType ?? "image/jpeg")
      .trim()
      .toLowerCase();
    const dataBase64 = String(payload.dataBase64 ?? "").trim();
    if (!dataBase64) {
      return json(400, { error: "dataBase64 boş." });
    }
    if (!contentType.startsWith("image/")) {
      return json(400, { error: "Yalnızca görsel yüklenebilir." });
    }

    // data URL gelirse ayıkla
    const b64 = dataBase64.includes(",")
      ? dataBase64.split(",").pop()!
      : dataBase64;
    const binary = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    const maxBytes = 8 * 1024 * 1024;
    if (binary.byteLength === 0) {
      return json(400, { error: "Boş dosya." });
    }
    if (binary.byteLength > maxBytes) {
      return json(413, { error: "Dosya 8 MB sınırını aşıyor." });
    }

    const userId = userData.user.id;
    const stamp = Date.now();
    const rand = crypto.randomUUID().slice(0, 8);
    const ext = extFrom(fileName, contentType);
    const key = `ilanlar/${userId}/${stamp}_${rand}.${ext}`;

    const endpoint =
      `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`;

    const aws = new AwsClient({
      accessKeyId,
      secretAccessKey,
      service: "s3",
      region: "auto",
    });

    const putRes = await aws.fetch(endpoint, {
      method: "PUT",
      headers: {
        "Content-Type": contentType,
        "Content-Length": String(binary.byteLength),
      },
      body: binary,
    });

    if (!putRes.ok) {
      const text = await putRes.text();
      console.error("R2 PUT failed", putRes.status, text);
      return json(502, {
        error: `R2 yükleme başarısız (${putRes.status}).`,
        detail: text.slice(0, 300),
      });
    }

    const publicUrl = `${publicBase}/${key}`;
    const serveBase = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
    const proxyUrl = serveBase
      ? `${serveBase}/functions/v1/r2-serve?key=${encodeURIComponent(key)}`
      : publicUrl;

    return json(200, {
      ok: true,
      url: proxyUrl,
      publicUrl,
      key,
      contentType,
      bytes: binary.byteLength,
    });
  } catch (e) {
    console.error(e);
    return json(500, {
      error: e instanceof Error ? e.message : "Yükleme hatası",
    });
  }
});
