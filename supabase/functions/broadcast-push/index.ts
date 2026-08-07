// Deploy:
//   supabase secrets set FCM_SERVER_KEY="AAAA..."
//   supabase functions deploy broadcast-push
//
// Body: { topic, title, body, imageUrl?, data? }
// Topics: duyurular | ilanlar | forum | mesajlar

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
    if (!ADMIN_EMAILS.has(email)) {
      // Yeni ilan / forum: herhangi bir giriş yapmış kullanıcı topic'e basabilir
      // (spam koruması: yalnızca bilinen topic'ler, rate limit yok — ileride sıkılaştır)
    }

    const payload = await req.json();
    const topic = String(payload.topic ?? "").trim().toLowerCase();
    const title = String(payload.title ?? "").trim();
    const body = String(payload.body ?? "").trim();
    const imageUrl = String(payload.imageUrl ?? "").trim();
    const data = (payload.data && typeof payload.data === "object")
      ? payload.data as Record<string, string>
      : {};

    const allowed = new Set(["duyurular", "ilanlar", "forum", "mesajlar"]);
    if (!allowed.has(topic)) {
      return json(400, { error: "Geçersiz topic." });
    }
    if (!title) {
      return json(400, { error: "title gerekli." });
    }

    // Duyuru görselli push yalnız admin
    if (topic === "duyurular" && !ADMIN_EMAILS.has(email)) {
      return json(403, { error: "Duyuru bildirimi için admin gerekli." });
    }

    const safeImage = imageUrl.startsWith("https://") ? imageUrl : "";

    const fcmBody: Record<string, unknown> = {
      to: `/topics/${topic}`,
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
        ...(safeImage
          ? { fcm_options: { image: safeImage } }
          : {}),
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)]),
        ),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        ...(safeImage ? { image: safeImage } : {}),
      },
    };

    const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        Authorization: `key=${serverKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmBody),
    });
    const fcmText = await fcmRes.text();
    let fcmJson: unknown = fcmText;
    try {
      fcmJson = JSON.parse(fcmText);
    } catch (_) {}

    if (!fcmRes.ok) {
      return json(502, { error: "FCM hata", detail: fcmJson });
    }
    return json(200, { ok: true, fcm: fcmJson });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
