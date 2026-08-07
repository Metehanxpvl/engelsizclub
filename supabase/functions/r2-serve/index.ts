// Public R2 image proxy — Flutter web CORS sorununu çözer.
// Deploy: supabase functions deploy r2-serve --no-verify-jwt
//
// GET /r2-serve?key=ilanlar/...   veya  /r2-serve/ilanlar/...

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, range",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Expose-Headers":
    "content-length, content-type, content-range, accept-ranges, etag",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response(JSON.stringify({ error: "GET gerekli." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
  const bucket = Deno.env.get("R2_BUCKET_NAME") ?? "engelsizclub-ilanlar";
  const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "";
  if (!accessKeyId || !secretAccessKey || !accountId) {
    return new Response(JSON.stringify({ error: "R2 secrets eksik." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  let key = (url.searchParams.get("key") ?? "").trim();
  if (!key) {
    // path: /r2-serve/ilanlar/...
    const parts = url.pathname.split("/r2-serve/");
    if (parts.length > 1) key = decodeURIComponent(parts[1]).replace(/^\/+/, "");
  }
  key = key.replace(/^\/+/, "");
  if (!key || key.includes("..") || !key.startsWith("ilanlar/")) {
    return new Response(JSON.stringify({ error: "Geçersiz key." }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const endpoint =
      `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`;
    const aws = new AwsClient({
      accessKeyId,
      secretAccessKey,
      service: "s3",
      region: "auto",
    });

    const headers: Record<string, string> = {};
    const range = req.headers.get("range");
    if (range) headers["Range"] = range;

    const upstream = await aws.fetch(endpoint, {
      method: req.method,
      headers,
    });

    if (!upstream.ok && upstream.status !== 206) {
      const text = await upstream.text();
      return new Response(
        JSON.stringify({
          error: `R2 okuma başarısız (${upstream.status})`,
          detail: text.slice(0, 200),
        }),
        {
          status: upstream.status === 404 ? 404 : 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const out = new Headers(corsHeaders);
    const pass = [
      "content-type",
      "content-length",
      "content-range",
      "accept-ranges",
      "etag",
      "last-modified",
      "cache-control",
    ];
    for (const h of pass) {
      const v = upstream.headers.get(h);
      if (v) out.set(h, v);
    }
    if (!out.has("cache-control")) {
      out.set("Cache-Control", "public, max-age=86400");
    }

    if (req.method === "HEAD") {
      return new Response(null, { status: upstream.status, headers: out });
    }
    return new Response(upstream.body, {
      status: upstream.status,
      headers: out,
    });
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({
        error: e instanceof Error ? e.message : "Proxy hatası",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
