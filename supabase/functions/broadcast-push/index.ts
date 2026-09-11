// Deploy:
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat sa.json)"
//   supabase secrets set FCM_SERVER_KEY="AAAA..."   # yedek, legacy
//   supabase functions deploy broadcast-push
//
// Topic: { topic, title, body, imageUrl?, data? }
// User:  { toEmail, title, body, imageUrl?, data?, prefKey? }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  deleteInvalidTokens,
  sendFcmToTokens,
  sendFcmToTopic,
} from "../_shared/fcm.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ADMIN_EMAILS = new Set(["sakir.caykara@gmail.com"]);

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }

  const hasV1 = !!(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "").trim();
  const hasLegacy = !!(Deno.env.get("FCM_SERVER_KEY") ?? "").trim();
  if (!hasV1 && !hasLegacy) {
    return json(500, {
      error:
        "FCM secret eksik. FIREBASE_SERVICE_ACCOUNT_JSON (önerilen) veya FCM_SERVER_KEY ayarlayın.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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
      return json(401, { error: "Oturum geçersiz." });
    }
    const email = (userData.user.email ?? "").trim().toLowerCase();

    const payload = await req.json();
    const title = String(payload.title ?? "").trim();
    const body = String(payload.body ?? "").trim();
    const data = (payload.data && typeof payload.data === "object")
      ? payload.data as Record<string, string>
      : {};

    if (!title) {
      return json(400, { error: "title gerekli." });
    }

    const toEmail = String(payload.toEmail ?? "").trim().toLowerCase();
    if (toEmail) {
      if (!serviceKey) {
        return json(500, { error: "SERVICE_ROLE eksik." });
      }
      if (toEmail === email) {
        return json(200, { ok: true, skipped: "self" });
      }

      const admin = createClient(supabaseUrl, serviceKey);
      const prefKey = String(payload.prefKey ?? "forum").trim().toLowerCase();
      const allowedPrefs = new Set(["forum", "mesajlar", "ilanlar", "duyurular"]);
      if (allowedPrefs.has(prefKey)) {
        const { data: profile } = await admin
          .from("user_profiles")
          .select("notifications")
          .eq("owner_email", toEmail)
          .maybeSingle();
        const notif = (profile?.notifications ?? {}) as Record<string, unknown>;
        if (notif[prefKey] === false) {
          return json(200, { ok: true, skipped: "pref_off" });
        }
      }

      const { data: rows, error: tokErr } = await admin
        .from("user_push_tokens")
        .select("token")
        .eq("owner_email", toEmail);
      if (tokErr) {
        return json(500, { error: tokErr.message });
      }
      const tokens = (rows ?? [])
        .map((r: { token?: string }) => (r.token ?? "").trim())
        .filter((t: string) => t.length > 20);
      if (tokens.length === 0) {
        return json(200, { ok: true, skipped: "no_token" });
      }

      const result = await sendFcmToTokens({ tokens, title, body, data });
      await deleteInvalidTokens(admin, result.invalidTokens);
      return json(200, {
        ok: true,
        sent: result.sent,
        failed: result.failed,
        cleaned: result.invalidTokens.length,
        fcm: result.detail,
      });
    }

    const topic = String(payload.topic ?? "").trim().toLowerCase();
    const allowed = new Set(["duyurular", "ilanlar", "forum", "mesajlar"]);
    if (!allowed.has(topic)) {
      return json(400, { error: "Geçersiz topic veya toEmail." });
    }

    if (topic === "duyurular" && !ADMIN_EMAILS.has(email)) {
      return json(403, { error: "Duyuru bildirimi için admin gerekli." });
    }

    const result = await sendFcmToTopic({ topic, title, body, data });
    if (result.failed > 0 && result.sent === 0) {
      return json(502, { error: "FCM hata", detail: result.detail });
    }
    return json(200, { ok: true, fcm: result.detail });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
