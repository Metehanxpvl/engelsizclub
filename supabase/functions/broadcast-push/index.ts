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
const ADMIN_USER_IDS = new Set(["61a14e10-f11b-40e7-8005-fa6c9d830a7f"]);

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
  const alertBody = body || title;
  const base: Record<string, unknown> = {
    priority: "high",
    notification: {
      title,
      body: alertBody,
      sound: "default",
      ...(safeImage ? { image: safeImage } : {}),
    },
    android: {
      priority: "high",
      notification: {
        channel_id: "engelsizclub_default",
        sound: "default",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        ...(safeImage ? { image: safeImage } : {}),
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          alert: {
            title,
            body: alertBody,
          },
          sound: "default",
          badge: 1,
          ...(safeImage ? { "mutable-content": 1 } : {}),
        },
      },
      ...(safeImage ? { fcm_options: { image: safeImage } } : {}),
    },
    data: {
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      title,
      body: alertBody,
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

function addTokens(
  seen: Set<string>,
  rows: { token?: string }[] | null,
) {
  for (const r of rows ?? []) {
    const t = (r.token ?? "").trim();
    if (t.length > 20) seen.add(t);
  }
}

async function loadTokensForEmail(
  admin: ReturnType<typeof createClient>,
  toEmail: string,
): Promise<{ tokens: string[]; ownerId: string; notifications: Record<string, unknown> }> {
  const seen = new Set<string>();

  const { data: byEmail, error: e1 } = await admin
    .from("user_push_tokens")
    .select("token, owner_id")
    .eq("owner_email", toEmail);
  if (e1) throw e1;
  addTokens(seen, byEmail);

  const { data: profile } = await admin
    .from("user_profiles")
    .select("notifications, owner_id")
    .eq("owner_email", toEmail)
    .maybeSingle();

  let ownerId = String(profile?.owner_id ?? "").trim();
  if (!ownerId) {
    const first = (byEmail ?? []).find((r: { owner_id?: string }) =>
      String(r.owner_id ?? "").trim()
    );
    ownerId = String(first?.owner_id ?? "").trim();
  }
  if (!ownerId) {
    try {
      const { data: au } = await admin.auth.admin.getUserByEmail(toEmail);
      ownerId = String(au?.user?.id ?? "").trim();
    } catch (_) {}
  }

  let notifications = (profile?.notifications ?? {}) as Record<string, unknown>;
  if (ownerId) {
    const { data: byId, error: e2 } = await admin
      .from("user_push_tokens")
      .select("token")
      .eq("owner_id", ownerId);
    if (e2) throw e2;
    addTokens(seen, byId);

    if (!profile) {
      const { data: p2 } = await admin
        .from("user_profiles")
        .select("notifications")
        .eq("owner_id", ownerId)
        .maybeSingle();
      notifications = (p2?.notifications ?? notifications) as Record<string, unknown>;
    }
  }

  return { tokens: [...seen], ownerId, notifications };
}

async function sendPersonal(
  serverKey: string,
  admin: ReturnType<typeof createClient>,
  opts: {
    toEmail: string;
    ownerId?: string;
    title: string;
    body: string;
    prefKey: string;
    data: Record<string, string>;
  },
): Promise<Response> {
  const toEmail = (opts.toEmail ?? "").trim().toLowerCase();
  const loaded = toEmail
    ? await loadTokensForEmail(admin, toEmail)
    : { tokens: [] as string[], ownerId: "", notifications: {} as Record<string, unknown> };
  const seen = new Set(loaded.tokens);
  const ownerId = (opts.ownerId || loaded.ownerId || "").trim();
  if (ownerId) {
    const { data: byId } = await admin
      .from("user_push_tokens")
      .select("token")
      .eq("owner_id", ownerId);
    addTokens(seen, byId);
    if (!loaded.notifications || Object.keys(loaded.notifications).length === 0) {
      const { data: p2 } = await admin
        .from("user_profiles")
        .select("notifications")
        .eq("owner_id", ownerId)
        .maybeSingle();
      loaded.notifications = (p2?.notifications ?? {}) as Record<string, unknown>;
    }
  }
  const allowedPrefs = new Set(["forum", "mesajlar", "ilanlar", "duyurular"]);
  if (allowedPrefs.has(opts.prefKey) && loaded.notifications[opts.prefKey] === false) {
    return json(200, { ok: true, skipped: "pref_off" });
  }
  if (seen.size === 0) {
    return json(200, { ok: true, skipped: "no_token" });
  }
  const chunk = [...seen].slice(0, 100);
  const result = await sendFcm(
    serverKey,
    buildFcmPayload({
      to: chunk,
      title: opts.title,
      body: opts.body,
      safeImage: "",
      data: opts.data,
    }),
  );
  if (!result.ok) {
    return json(502, { error: "FCM hata", detail: result.detail });
  }
  return json(200, { ok: true, sent: chunk.length, fcm: result.detail });
}

async function sendBroadcastAll(
  serverKey: string,
  admin: ReturnType<typeof createClient>,
  opts: {
    title: string;
    body: string;
    safeImage: string;
    data: Record<string, string>;
    prefKey: string;
  },
): Promise<Response> {
  const { data: profiles } = await admin
    .from("user_profiles")
    .select("owner_id, owner_email, notifications");
  const blocked = new Set<string>();
  for (const p of profiles ?? []) {
    const n = (p as { notifications?: Record<string, unknown> }).notifications ??
      {};
    if (n[opts.prefKey] === false) {
      const oid = String((p as { owner_id?: string }).owner_id ?? "").trim();
      const em = String((p as { owner_email?: string }).owner_email ?? "")
        .trim()
        .toLowerCase();
      if (oid) blocked.add(oid);
      if (em) blocked.add(em);
    }
  }
  const { data: rows, error } = await admin
    .from("user_push_tokens")
    .select("token, owner_id, owner_email");
  if (error) throw error;
  const seen = new Set<string>();
  for (const r of rows ?? []) {
    const oid = String(r.owner_id ?? "").trim();
    const em = String(r.owner_email ?? "").trim().toLowerCase();
    if ((oid && blocked.has(oid)) || (em && blocked.has(em))) continue;
    const t = String(r.token ?? "").trim();
    if (t.length > 20) seen.add(t);
  }
  if (seen.size === 0) {
    return json(200, { ok: true, skipped: "no_token" });
  }
  const all = [...seen];
  let sent = 0;
  let lastDetail: unknown = null;
  for (let i = 0; i < all.length; i += 100) {
    const chunk = all.slice(i, i + 100);
    const result = await sendFcm(
      serverKey,
      buildFcmPayload({
        to: chunk,
        title: opts.title,
        body: opts.body,
        safeImage: opts.safeImage,
        data: opts.data,
      }),
    );
    lastDetail = result.detail;
    if (!result.ok) {
      return json(502, {
        error: "FCM hata",
        detail: result.detail,
        sent,
      });
    }
    sent += chunk.length;
  }
  return json(200, { ok: true, sent, fcm: lastDetail });
}

function asRecord(raw: unknown): Record<string, unknown> {
  if (raw && typeof raw === "object") return raw as Record<string, unknown>;
  return {};
}

function isStale(createdAt: unknown, maxMs = 5 * 60 * 1000): boolean {
  const created = Date.parse(String(createdAt ?? ""));
  return Number.isFinite(created) && Date.now() - created > maxMs;
}

async function resolveEmailByOwnerId(
  admin: ReturnType<typeof createClient>,
  ownerId: string,
): Promise<string> {
  const id = ownerId.trim();
  if (!id) return "";
  const { data: prof } = await admin
    .from("user_profiles")
    .select("owner_email")
    .eq("owner_id", id)
    .maybeSingle();
  let email = String(prof?.owner_email ?? "").trim().toLowerCase();
  if (!email) {
    try {
      const { data: au } = await admin.auth.admin.getUserById(id);
      email = String(au?.user?.email ?? "").trim().toLowerCase();
    } catch (_) {}
  }
  return email;
}

async function sendTopicAlert(
  serverKey: string,
  opts: {
    topic: string;
    title: string;
    body: string;
    image?: string;
    data: Record<string, string>;
  },
): Promise<Response> {
  const img = (opts.image ?? "").trim();
  const safeImage = img.startsWith("https://") ? img : "";
  const result = await sendFcm(
    serverKey,
    buildFcmPayload({
      to: `/topics/${opts.topic}`,
      title: opts.title,
      body: opts.body,
      safeImage,
      data: opts.data,
    }),
  );
  if (!result.ok) return json(502, { error: "FCM hata", detail: result.detail });
  return json(200, { ok: true, fcm: result.detail });
}

async function handleDbPush(
  payload: Record<string, unknown>,
): Promise<Response> {
  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!fcmConfigured()) {
    return json(500, { error: "FCM_SERVER_KEY eksik." });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!serviceKey) {
    return json(500, { error: "SERVICE_ROLE eksik." });
  }
  const admin = createClient(supabaseUrl, serviceKey);
  const table = String(payload.table ?? "").trim();
  const record = asRecord(payload.record ?? payload);
  if (!table) {
    return json(200, { ok: true, skipped: "bad_row" });
  }

  if (table === "admin_push") {
    const title = String(record.title ?? "").trim() || "Bunu biliyor muydunuz?";
    const body = String(record.body ?? "").trim() || title;
    const extra = asRecord(record.data);
    const data: Record<string, string> = {};
    for (const [k, v] of Object.entries(extra)) {
      if (v != null) data[k] = String(v);
    }
    if (!data.type) data.type = "biliyor_muydunuz";
    if (!data.text) data.text = body;
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title,
      body,
      data,
    });
  }

  if (table === "kariyer_overrides") {
    const jobId = String(record.job_id ?? record.id ?? "").trim();
    if (!jobId) return json(200, { ok: true, skipped: "bad_row" });
    const { data: row } = await admin
      .from("kariyer_overrides")
      .select("job_id, title, city, hidden, custom")
      .eq("job_id", jobId)
      .maybeSingle();
    if (!row || row.hidden === true) {
      return json(200, { ok: true, skipped: "hidden" });
    }
    const custom = row.custom === true || jobId.startsWith("custom-");
    if (!custom) return json(200, { ok: true, skipped: "catalog" });
    const title = String(row.title ?? "").trim() || "Yeni iş ilanı";
    const city = String(row.city ?? "").trim();
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title: "Engelsiz Kariyer",
      body: city ? `${title} · ${city}` : title,
      data: { type: "kariyer", id: jobId },
    });
  }

  const id = Number(record.id ?? 0);
  if (id <= 0) {
    return json(200, { ok: true, skipped: "bad_row" });
  }

  if (table === "sohbet_mesajlari") {
    const { data: row } = await admin
      .from("sohbet_mesajlari")
      .select("id, receiver_email, sender_email, body, sohbet_key, created_at")
      .eq("id", id)
      .maybeSingle();
    if (!row) return json(200, { ok: true, skipped: "missing_row" });
    const created = Date.parse(String(row.created_at ?? ""));
    if (Number.isFinite(created) && Date.now() - created > 5 * 60 * 1000) {
      return json(200, { ok: true, skipped: "stale" });
    }
    const msgBody = String(row.body ?? "");
    if (msgBody.toLowerCase().includes("teklif verdim")) {
      return json(200, { ok: true, skipped: "teklif" });
    }
    const toEmail = String(row.receiver_email ?? "").trim().toLowerCase();
    const fromEmail = String(row.sender_email ?? "").trim().toLowerCase();
    if (!toEmail || toEmail === fromEmail) {
      return json(200, { ok: true, skipped: "self" });
    }
    const preview = msgBody.length > 90 ? `${msgBody.slice(0, 90)}…` : msgBody;
    return await sendPersonal(serverKey, admin, {
      toEmail,
      title: "Yeni mesaj",
      body: preview || "Yeni mesajınız var",
      prefKey: "mesajlar",
      data: {
        type: "mesaj",
        id: String(row.id ?? ""),
        sohbet_key: String(row.sohbet_key ?? ""),
        actor_email: fromEmail,
      },
    });
  }

  if (table === "forum_comments") {
    const { data: row } = await admin
      .from("forum_comments")
      .select("id, post_id, owner_email, body, parent_id, created_at")
      .eq("id", id)
      .maybeSingle();
    if (!row) return json(200, { ok: true, skipped: "missing_row" });
    const created = Date.parse(String(row.created_at ?? ""));
    if (Number.isFinite(created) && Date.now() - created > 5 * 60 * 1000) {
      return json(200, { ok: true, skipped: "stale" });
    }
    const postId = Number(row.post_id ?? 0);
    const { data: post } = await admin
      .from("forum_posts")
      .select("id, title, owner_email, owner_id")
      .eq("id", postId)
      .maybeSingle();
    let toEmail = String(post?.owner_email ?? "").trim().toLowerCase();
    if (!toEmail && post?.owner_id) {
      const { data: prof } = await admin
        .from("user_profiles")
        .select("owner_email")
        .eq("owner_id", post.owner_id)
        .maybeSingle();
      toEmail = String(prof?.owner_email ?? "").trim().toLowerCase();
      if (!toEmail) {
        try {
          const { data: au } = await admin.auth.admin.getUserById(
            String(post.owner_id),
          );
          toEmail = String(au?.user?.email ?? "").trim().toLowerCase();
        } catch (_) {}
      }
    }
    const fromEmail = String(row.owner_email ?? "").trim().toLowerCase();
    const ownerId = String(post?.owner_id ?? "").trim();
    if ((!toEmail && !ownerId) || (toEmail && toEmail === fromEmail)) {
      return json(200, { ok: true, skipped: "self" });
    }
    const preview = String(row.body ?? "").trim();
    return await sendPersonal(serverKey, admin, {
      toEmail,
      ownerId,
      title: "Gönderinize yorum yapıldı",
      body: preview || "Gönderinize yorum yapıldı",
      prefKey: "forum",
      data: {
        type: "forum_comment",
        id: String(postId),
        post_id: String(postId),
        sohbet_key: `c:${row.id}`,
        actor_email: fromEmail,
      },
    });
  }

  if (table === "forum_comment_likes") {
    const { data: like } = await admin
      .from("forum_comment_likes")
      .select("id, comment_id, owner_email, owner_id, created_at")
      .eq("id", id)
      .maybeSingle();
    if (!like) return json(200, { ok: true, skipped: "missing_row" });
    const created = Date.parse(String(like.created_at ?? ""));
    if (Number.isFinite(created) && Date.now() - created > 5 * 60 * 1000) {
      return json(200, { ok: true, skipped: "stale" });
    }
    const commentId = Number(like.comment_id ?? 0);
    if (commentId <= 0) return json(200, { ok: true, skipped: "bad_comment" });
    const { data: comment } = await admin
      .from("forum_comments")
      .select("id, post_id, owner_email, owner_id, body")
      .eq("id", commentId)
      .maybeSingle();
    if (!comment) return json(200, { ok: true, skipped: "missing_comment" });
    let toEmail = String(comment.owner_email ?? "").trim().toLowerCase();
    const ownerId = String(comment.owner_id ?? "").trim();
    if (!toEmail && ownerId) {
      const { data: prof } = await admin
        .from("user_profiles")
        .select("owner_email")
        .eq("owner_id", ownerId)
        .maybeSingle();
      toEmail = String(prof?.owner_email ?? "").trim().toLowerCase();
      if (!toEmail) {
        try {
          const { data: au } = await admin.auth.admin.getUserById(ownerId);
          toEmail = String(au?.user?.email ?? "").trim().toLowerCase();
        } catch (_) {}
      }
    }
    const fromEmail = String(like.owner_email ?? "").trim().toLowerCase();
    const fromId = String(like.owner_id ?? "").trim();
    if (ownerId && fromId && ownerId === fromId) {
      return json(200, { ok: true, skipped: "self" });
    }
    if (toEmail && fromEmail && toEmail === fromEmail) {
      return json(200, { ok: true, skipped: "self" });
    }
    if (!toEmail && !ownerId) {
      return json(200, { ok: true, skipped: "self" });
    }
    const preview = String(comment.body ?? "").trim();
    return await sendPersonal(serverKey, admin, {
      toEmail,
      ownerId,
      title: "Yorumunuz beğenildi",
      body: preview || "Yorumunuz beğenildi",
      prefKey: "forum",
      data: {
        type: "forum_like",
        id: String(comment.post_id ?? ""),
        post_id: String(comment.post_id ?? ""),
        sohbet_key: `c:${commentId}`,
        actor_email: fromEmail,
      },
    });
  }

  if (table === "forum_likes") {
    const { data: like } = await admin
      .from("forum_likes")
      .select("id, post_id, owner_email, owner_id, created_at")
      .eq("id", id)
      .maybeSingle();
    if (!like) return json(200, { ok: true, skipped: "missing_row" });
    if (isStale(like.created_at)) {
      return json(200, { ok: true, skipped: "stale" });
    }
    const postId = Number(like.post_id ?? 0);
    if (postId <= 0) return json(200, { ok: true, skipped: "bad_post" });
    const { data: post } = await admin
      .from("forum_posts")
      .select("id, title, owner_email, owner_id")
      .eq("id", postId)
      .maybeSingle();
    if (!post) return json(200, { ok: true, skipped: "missing_post" });
    let toEmail = String(post.owner_email ?? "").trim().toLowerCase();
    const ownerId = String(post.owner_id ?? "").trim();
    if (!toEmail && ownerId) {
      toEmail = await resolveEmailByOwnerId(admin, ownerId);
    }
    const fromEmail = String(like.owner_email ?? "").trim().toLowerCase();
    const fromId = String(like.owner_id ?? "").trim();
    if (ownerId && fromId && ownerId === fromId) {
      return json(200, { ok: true, skipped: "self" });
    }
    if (toEmail && fromEmail && toEmail === fromEmail) {
      return json(200, { ok: true, skipped: "self" });
    }
    if (!toEmail && !ownerId) {
      return json(200, { ok: true, skipped: "self" });
    }
    const preview = String(post.title ?? "").trim();
    return await sendPersonal(serverKey, admin, {
      toEmail,
      ownerId,
      title: "Gönderiniz beğenildi",
      body: preview || "Gönderiniz beğenildi",
      prefKey: "forum",
      data: {
        type: "forum_like",
        id: String(postId),
        post_id: String(postId),
        actor_email: fromEmail,
      },
    });
  }

  if (table === "etkinlikler") {
    const { data: row } = await admin
      .from("etkinlikler")
      .select("id, title, description, city, image_url, is_active, status, source")
      .eq("id", id)
      .maybeSingle();
    if (!row || row.is_active === false) {
      return json(200, { ok: true, skipped: "inactive" });
    }
    if (String(row.source ?? "").trim() === "avm_scrape") {
      return json(200, { ok: true, skipped: "scrape" });
    }
    const status = String(row.status ?? "").trim().toLowerCase();
    if (status === "pending" || status === "rejected") {
      return json(200, { ok: true, skipped: "pending" });
    }
    const title = String(row.title ?? "").trim() || "Etkinlik var";
    const loc = String(row.city ?? "").trim();
    const desc = String(row.description ?? "").trim();
    const body = loc || desc || "Etkinlik var";
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title,
      body,
      image: String(row.image_url ?? ""),
      data: { type: "etkinlik", id: String(row.id) },
    });
  }

  if (table === "gezi_rehberi") {
    const { data: row } = await admin
      .from("gezi_rehberi")
      .select("id, title, city_name, description, image_url, is_active")
      .eq("id", id)
      .maybeSingle();
    if (!row || row.is_active === false) {
      return json(200, { ok: true, skipped: "inactive" });
    }
    const city = String(row.city_name ?? "").trim();
    const title = String(row.title ?? "").trim() || "Gezi Rehberi";
    const body = city
      ? `Gezi Rehberi’nde bugün ${city} ilinde gezebileceğiniz yerler için lütfen göz atın.`
      : (String(row.description ?? "").trim() || title);
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title: "Gezi Rehberi",
      body,
      image: String(row.image_url ?? ""),
      data: { type: "gezi", id: String(row.id), city },
    });
  }

  if (table === "kampanyalar") {
    const { data: row } = await admin
      .from("kampanyalar")
      .select("id, title, description, city, image_url, is_active")
      .eq("id", id)
      .maybeSingle();
    if (!row || row.is_active === false) {
      return json(200, { ok: true, skipped: "inactive" });
    }
    const title = String(row.title ?? "").trim() || "Yeni kampanya";
    const body = String(row.description ?? "").trim() || title;
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title,
      body,
      image: String(row.image_url ?? ""),
      data: { type: "kampanya", id: String(row.id) },
    });
  }

  if (table === "gelisim_etkinlikleri") {
    const { data: row } = await admin
      .from("gelisim_etkinlikleri")
      .select("id, title, description, is_active")
      .eq("id", id)
      .maybeSingle();
    if (!row || row.is_active === false) {
      return json(200, { ok: true, skipped: "inactive" });
    }
    const title = String(row.title ?? "").trim() || "Yeni gelişim etkinliği";
    const body = String(row.description ?? "").trim() || title;
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title,
      body,
      data: { type: "gelisim", id: String(row.id) },
    });
  }

  if (table === "admin_broadcasts") {
    const { data: row } = await admin
      .from("admin_broadcasts")
      .select("id, title, body, data, created_at")
      .eq("id", id)
      .maybeSingle();
    if (!row) return json(200, { ok: true, skipped: "missing_row" });
    if (isStale(row.created_at)) {
      return json(200, { ok: true, skipped: "stale" });
    }
    const title = String(row.title ?? "").trim() || "Bunu biliyor muydunuz?";
    const body = String(row.body ?? "").trim() || title;
    const extra = asRecord(row.data);
    const data: Record<string, string> = {};
    for (const [k, v] of Object.entries(extra)) {
      if (v != null) data[k] = String(v);
    }
    if (!data.type) data.type = "biliyor_muydunuz";
    if (!data.text) data.text = body;
    return await sendTopicAlert(serverKey, {
      topic: "duyurular",
      title,
      body,
      data,
    });
  }

  if (table === "forum_posts") {
    const { data: row } = await admin
      .from("forum_posts")
      .select("id, title, content")
      .eq("id", id)
      .maybeSingle();
    if (!row) return json(200, { ok: true, skipped: "missing_row" });
    const title = String(row.title ?? "").trim() || "Yeni forum paylaşımı";
    const result = await sendFcm(
      serverKey,
      buildFcmPayload({
        to: "/topics/forum",
        title: "Yeni forum paylaşımı",
        body: title,
        safeImage: "",
        data: { type: "forum", id: String(row.id), post_id: String(row.id) },
      }),
    );
    if (!result.ok) return json(502, { error: "FCM hata", detail: result.detail });
    return json(200, { ok: true, fcm: result.detail });
  }

  if (table === "duyurular") {
    const { data: row } = await admin
      .from("duyurular")
      .select("id, title, body, is_active, is_popup, image_url, source_url")
      .eq("id", id)
      .maybeSingle();
    if (!row || row.is_active === false) {
      return json(200, { ok: true, skipped: "inactive" });
    }
    const title = String(row.title ?? "").trim() || "Yeni duyuru";
    const body = String(row.body ?? "").trim() || title;
    const img = String(row.image_url ?? "").trim();
    const safeImage = img.startsWith("https://") ? img : "";
    const src = String(row.source_url ?? "").trim();
    const isDidYouKnow = src === "did_you_know" ||
      title === "Bunu biliyor musunuz?";
    const data = isDidYouKnow
      ? { type: "biliyor_muydunuz", text: body, id: String(row.id) }
      : { type: "duyuru", id: String(row.id) };
    if (isDidYouKnow) {
      const topicRes = await sendTopicAlert(serverKey, {
        topic: "duyurular",
        title,
        body,
        image: img,
        data,
      });
      const all = await sendBroadcastAll(serverKey, admin, {
        title,
        body,
        safeImage,
        data,
        prefKey: "duyurular",
      });
      if (all.status === 200) return all;
      return topicRes;
    }
    const result = await sendFcm(
      serverKey,
      buildFcmPayload({
        to: "/topics/duyurular",
        title,
        body,
        safeImage,
        data,
      }),
    );
    if (!result.ok) return json(502, { error: "FCM hata", detail: result.detail });
    return json(200, { ok: true, fcm: result.detail });
  }

  if (table === "ilanlar") {
    const { data: row } = await admin
      .from("ilanlar")
      .select("id, title, kind")
      .eq("id", id)
      .maybeSingle();
    if (!row) return json(200, { ok: true, skipped: "missing_row" });
    const title = String(row.title ?? "").trim() || "Yeni ilan";
    const kind = String(row.kind ?? "uzman").trim().toLowerCase() || "uzman";
    const topic = kind === "uzman" || kind === "bakici"
      ? "ilanlar_prof"
      : "ilanlar";
    const result = await sendFcm(
      serverKey,
      buildFcmPayload({
        to: `/topics/${topic}`,
        title: "Yeni ilan",
        body: title,
        safeImage: "",
        data: { type: "ilan", id: String(row.id), kind },
      }),
    );
    if (!result.ok) return json(502, { error: "FCM hata", detail: result.detail });
    return json(200, { ok: true, fcm: result.detail });
  }

  return json(200, { ok: true, skipped: "unknown_table" });
}

async function sendFcm(
  serverKey: string,
  payload: Record<string, unknown>,
): Promise<{ ok: boolean; detail: unknown }> {
  const sa = loadServiceAccount();
  if (!serverKey && sa) {
    return await sendFcmV1(sa, payload);
  }
  if (!serverKey) {
    return { ok: false, detail: "FCM_SERVER_KEY eksik." };
  }
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

type FirebaseServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

let cachedGoogleToken: { token: string; exp: number } | null = null;

function loadServiceAccount(): FirebaseServiceAccount | null {
  const raw = (Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "").trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as FirebaseServiceAccount;
    if (parsed.project_id && parsed.client_email && parsed.private_key) {
      return parsed;
    }
  } catch (_) {}
  return null;
}

function fcmConfigured(): boolean {
  return Boolean((Deno.env.get("FCM_SERVER_KEY") ?? "").trim() || loadServiceAccount());
}

async function googleAccessToken(
  sa: FirebaseServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedGoogleToken && cachedGoogleToken.exp - 60 > now) {
    return cachedGoogleToken.token;
  }
  const { SignJWT, importPKCS8 } = await import("https://esm.sh/jose@5.9.6");
  const pem = String(sa.private_key).replace(/\\n/g, "\n");
  const key = await importPKCS8(pem, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(String(sa.client_email))
    .setSubject(String(sa.client_email))
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = asRecord(await res.json());
  const token = String(data.access_token ?? "").trim();
  if (!token) throw new Error("Google access token alınamadı.");
  cachedGoogleToken = { token, exp: now + 3500 };
  return token;
}

async function sendFcmV1(
  sa: FirebaseServiceAccount,
  payload: Record<string, unknown>,
): Promise<{ ok: boolean; detail: unknown }> {
  const notification = asRecord(payload.notification);
  const data = asRecord(payload.data);
  const title = String(notification.title ?? data.title ?? "");
  const body = String(notification.body ?? data.body ?? title);
  const image = String(notification.image ?? data.image ?? "");
  const stringData: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v != null) stringData[k] = String(v);
  }
  const targets: Array<{ token?: string; topic?: string }> = [];
  const ids = payload.registration_ids;
  if (Array.isArray(ids)) {
    for (const t of ids) {
      const token = String(t ?? "").trim();
      if (token) targets.push({ token });
    }
  } else {
    const to = String(payload.to ?? "").trim();
    if (to.startsWith("/topics/")) {
      targets.push({ topic: to.slice("/topics/".length) });
    } else if (to) {
      targets.push({ token: to });
    }
  }
  if (targets.length === 0) {
    return { ok: false, detail: "no_target" };
  }
  const access = await googleAccessToken(sa);
  const url =
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(String(sa.project_id))}/messages:send`;
  const imageHttps = image.startsWith("https://") ? image : "";
  const details: unknown[] = [];
  let okAny = false;
  const sendOne = async (target: { token?: string; topic?: string }) => {
    const message: Record<string, unknown> = {
      ...(target.token ? { token: target.token } : {}),
      ...(target.topic ? { topic: target.topic } : {}),
      notification: {
        title,
        body,
        ...(imageHttps ? { image: imageHttps } : {}),
      },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: "engelsizclub_default",
          sound: "default",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...(imageHttps ? { image: imageHttps } : {}),
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        },
        ...(imageHttps
          ? { fcm_options: { image: imageHttps } }
          : {}),
      },
      data: stringData,
    };
    const fcmRes = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${access}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    });
    const fcmText = await fcmRes.text();
    let fcmJson: unknown = fcmText;
    try {
      fcmJson = JSON.parse(fcmText);
    } catch (_) {}
    return { ok: fcmRes.ok, detail: fcmJson };
  };
  for (let i = 0; i < targets.length; i += 20) {
    const chunk = targets.slice(i, i + 20);
    const results = await Promise.all(chunk.map(sendOne));
    for (const r of results) {
      details.push(r.detail);
      if (r.ok) okAny = true;
    }
  }
  return { ok: okAny, detail: details.length === 1 ? details[0] : { sent: details.length, sample: details[0] } };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }

  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!fcmConfigured()) {
    return json(500, {
      error:
        "FCM_SERVER_KEY eksik. Firebase Console → Project settings → Cloud Messaging → Server key",
    });
  }

  let payload: Record<string, unknown>;
  try {
    const raw = await req.json();
    payload = asRecord(raw);
  } catch {
    return json(400, { error: "JSON gerekli." });
  }

  if (String(payload.source ?? "") === "db") {
    try {
      return await handleDbPush(payload);
    } catch (e) {
      return json(500, { error: String(e) });
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json(401, { error: "Giriş gerekli." });
  }

  try {
    const jwt = authHeader.slice(7).trim();
    let user: { id: string; email?: string | null } | null = null;

    const tryGetUser = async (
      client: ReturnType<typeof createClient>,
      token?: string,
    ) => {
      try {
        const { data } = token
          ? await client.auth.getUser(token)
          : await client.auth.getUser();
        return data.user;
      } catch {
        return null;
      }
    };

    if (serviceKey && jwt && !jwt.startsWith("sb_")) {
      const adminAuth = createClient(supabaseUrl, serviceKey);
      user = await tryGetUser(adminAuth, jwt);
    }
    if (!user && jwt && !jwt.startsWith("sb_")) {
      const supabase = createClient(supabaseUrl, supabaseAnon, {
        global: { headers: { Authorization: authHeader } },
      });
      user = await tryGetUser(supabase, jwt);
      if (!user) user = await tryGetUser(supabase);
    }
    if (!user) {
      return json(401, { error: "Oturum geçersiz." });
    }

    let email = (user.email ?? "").trim().toLowerCase();
    if ((!ADMIN_EMAILS.has(email) || !email) && serviceKey && user.id) {
      const resolved = await resolveEmailByOwnerId(
        createClient(supabaseUrl, serviceKey),
        user.id,
      );
      if (resolved) email = resolved;
    }
    const isAdmin =
      ADMIN_EMAILS.has(email) || ADMIN_USER_IDS.has(String(user.id ?? ""));

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
      let tokens: string[];
      let notifications: Record<string, unknown>;
      try {
        const loaded = await loadTokensForEmail(admin, toEmail);
        tokens = loaded.tokens;
        notifications = loaded.notifications;
      } catch (tokErr) {
        return json(500, { error: String((tokErr as { message?: string })?.message ?? tokErr) });
      }
      if (allowedPrefs.has(prefKey) && notifications[prefKey] === false) {
        return json(200, { ok: true, skipped: "pref_off" });
      }
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
    const allowed = new Set([
      "duyurular",
      "ilanlar",
      "ilanlar_prof",
      "forum",
      "mesajlar",
      "kampanyalar",
    ]);
    if (!allowed.has(topic)) {
      return json(400, { error: "Geçersiz topic veya toEmail." });
    }

    if (topic === "duyurular" && !isAdmin) {
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
