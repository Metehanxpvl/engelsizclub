// Deploy:
//   supabase secrets set FCM_SERVER_KEY="AAAA..."
//   supabase functions deploy broadcast-push
//
// Topic: { topic, title, body, imageUrl?, data? }
// User:  { toEmail, title, body, imageUrl?, data?, prefKey? }
//        prefKey: forum | mesajlar | ilanlar | duyurular (user_profiles.notifications)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

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

function buildFcmPayload(opts: {
  to: string | string[];
  title: string;
  body: string;
  safeImage: string;
  data: Record<string, string>;
}): Record<string, unknown> {
  const { to, title, body, safeImage, data } = opts;
  const base: Record<string, unknown> = {
    priority: "high",
    notification: {
      title,
      body: body || title,
      ...(safeImage ? { image: safeImage } : {}),
    },
    android: {
      priority: "high",
      notification: {
        channel_id: "engelsizclub_default",
        sound: "default",
        ...(safeImage ? { image: safeImage } : {}),
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          "mutable-content": 1,
        },
      },
      ...(safeImage ? { fcm_options: { image: safeImage } } : {}),
    },
    data: {
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      ...(safeImage ? { image: safeImage } : {}),
    },
  };
  if (Array.isArray(to)) {
    base.registration_ids = to;
  } else {
    base.to = to;
  }
  return base;
}

async function sendFcm(
  serverKey: string,
  payload: Record<string, unknown>,
): Promise<{ ok: boolean; detail: unknown }> {
  const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${serverKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const fcmText = await fcmRes.text();
  let fcmJson: unknown = fcmText;
  try {
    fcmJson = JSON.parse(fcmText);
  } catch (_) {}
  return { ok: fcmRes.ok, detail: fcmJson };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }

  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!serverKey) {
    return json(500, {
      error:
        "FCM_SERVER_KEY eksik. Firebase Console → Project settings → Cloud Messaging → Server key",
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
    const imageUrl = String(payload.imageUrl ?? "").trim();
    const data = (payload.data && typeof payload.data === "object")
      ? payload.data as Record<string, string>
      : {};
    const safeImage = imageUrl.startsWith("https://") ? imageUrl : "";

    if (!title) {
      return json(400, { error: "title gerekli." });
    }

    // ── Kişisel push (forum yanıtı vb.) ──────────────────────────────────
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

      // FCM legacy: en fazla 1000 registration_ids
      const chunk = tokens.slice(0, 100);
      const fcmBody = buildFcmPayload({
        to: chunk,
        title,
        body,
        safeImage,
        data,
      });
      const result = await sendFcm(serverKey, fcmBody);
      if (!result.ok) {
        return json(502, { error: "FCM hata", detail: result.detail });
      }
      return json(200, { ok: true, sent: chunk.length, fcm: result.detail });
    }

    // ── Topic broadcast ──────────────────────────────────────────────────
    const topic = String(payload.topic ?? "").trim().toLowerCase();
    const allowed = new Set(["duyurular", "ilanlar", "forum", "mesajlar"]);
    if (!allowed.has(topic)) {
      return json(400, { error: "Geçersiz topic veya toEmail." });
    }

    if (topic === "duyurular" && !ADMIN_EMAILS.has(email)) {
      return json(403, { error: "Duyuru bildirimi için admin gerekli." });
    }

    const fcmBody = buildFcmPayload({
      to: `/topics/${topic}`,
      title,
      body,
      safeImage,
      data,
    });
    const result = await sendFcm(serverKey, fcmBody);
    if (!result.ok) {
      return json(502, { error: "FCM hata", detail: result.detail });
    }
    return json(200, { ok: true, fcm: result.detail });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
