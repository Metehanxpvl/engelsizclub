// Deploy:
//   supabase secrets set NOTIFY_PUSH_SECRET="uzun-rastgele-dize"
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
//   # yedek (eski): supabase secrets set FCM_SERVER_KEY="AAAA..."
//   supabase functions deploy notify-push --no-verify-jwt
//
// Database webhook / pg_net: Authorization: Bearer $NOTIFY_PUSH_SECRET
// Gövde: { id } veya Supabase webhook { type, table, record }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { deleteInvalidTokens, sendFcmToTokens } from "../_shared/fcm.ts";
import { claimPushSend, insertDedupeKey } from "../_shared/push_claim.ts";

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

function authorized(req: Request): boolean {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
  if (!token) return false;
  const secret = (Deno.env.get("NOTIFY_PUSH_SECRET") ?? "").trim();
  const service = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
  return (secret.length > 8 && token === secret) ||
    (service.length > 8 && token === service);
}

type BildirimRow = {
  id?: number;
  owner_email?: string;
  actor_email?: string;
  actor_name?: string;
  type?: string;
  title?: string;
  body?: string;
  ilan_id?: number | null;
  sohbet_key?: string | null;
};

function eventFor(type: string): string | null {
  switch (type) {
    case "forum_like":
      return "COMMENT_LIKED";
    case "forum_follow":
      return "COMMENT_CREATED";
    case "forum_comment":
      return "POST_COMMENTED";
    case "forum_reply":
      return "REPLY_RECEIVED";
    case "mesaj":
      return "MESSAGE_RECEIVED";
    default:
      return null;
  }
}

function prefKeyFor(type: string): string {
  if (type === "mesaj" || type === "teklif") return "mesajlar";
  if (type === "ilan" || type === "ilan_yorum") return "ilanlar";
  return "forum";
}

function commentIdFromKey(key: string): string {
  const k = key.trim();
  if (k.startsWith("c:")) return k.slice(2);
  return "";
}

function fcmCopy(event: string, row: BildirimRow): { title: string; body: string } {
  if (event === "MESSAGE_RECEIVED") {
    return {
      title: "Yeni mesaj",
      body: "Engelsiz Club'da yeni bir mesajınız var.",
    };
  }
  const title = String(row.title ?? "").trim() || "Engelsiz Club";
  const body = String(row.body ?? "").trim() || title;
  return { title, body };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }
  if (!authorized(req)) {
    return json(401, { error: "Yetkisiz." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return json(500, { error: "SUPABASE_SERVICE_ROLE_KEY eksik." });
  }
  const admin = createClient(supabaseUrl, serviceKey);

  try {
    const payload = await req.json();
    const record = (payload.record && typeof payload.record === "object")
      ? payload.record as BildirimRow
      : payload as BildirimRow;
    let row = record;
    const id = Number(payload.id ?? record.id ?? 0);
    if ((!row.type || !row.owner_email) && id > 0) {
      const { data, error } = await admin
        .from("bildirimler")
        .select(
          "id, owner_email, actor_email, actor_name, type, title, body, ilan_id, sohbet_key",
        )
        .eq("id", id)
        .maybeSingle();
      if (error) return json(500, { error: error.message });
      if (!data) return json(200, { ok: true, skipped: "missing_row" });
      row = data as BildirimRow;
    }

    const type = String(row.type ?? "").trim();
    const event = eventFor(type);
    if (!event) {
      return json(200, { ok: true, skipped: "type" });
    }
    const owner = String(row.owner_email ?? "").trim().toLowerCase();
    const actor = String(row.actor_email ?? "").trim().toLowerCase();
    if (!owner) return json(200, { ok: true, skipped: "no_owner" });
    if (actor && owner === actor) {
      return json(200, { ok: true, skipped: "self" });
    }

    const bildirimId = Number(row.id ?? id ?? 0);
    const dedupeKey = String(payload.dedupeKey ?? "").trim() ||
      insertDedupeKey(row);
    const claimed = await claimPushSend(admin, {
      bildirimId,
      event,
      dedupeKey,
    });
    if (claimed === "duplicate") {
      return json(200, { ok: true, skipped: "duplicate" });
    }

    const prefKey = prefKeyFor(type);
    const { data: profile } = await admin
      .from("user_profiles")
      .select("notifications")
      .eq("owner_email", owner)
      .maybeSingle();
    const notif = (profile?.notifications ?? {}) as Record<string, unknown>;
    if (notif[prefKey] === false) {
      return json(200, { ok: true, skipped: "pref_off" });
    }

    const { data: rows, error: tokErr } = await admin
      .from("user_push_tokens")
      .select("token")
      .eq("owner_email", owner);
    if (tokErr) return json(500, { error: tokErr.message });
    const tokens = (rows ?? [])
      .map((r: { token?: string }) => (r.token ?? "").trim())
      .filter((t: string) => t.length > 20);
    if (tokens.length === 0) {
      return json(200, { ok: true, skipped: "no_token" });
    }

    const sohbetKey = String(row.sohbet_key ?? "").trim();
    const postId = row.ilan_id != null ? String(row.ilan_id) : "";
    const commentId = commentIdFromKey(sohbetKey);
    const copy = fcmCopy(event, row);
    const data: Record<string, string> = {
      type,
      event,
      ...(postId ? { id: postId, postId } : {}),
      ...(commentId ? { commentId } : {}),
      ...(sohbetKey ? { sohbet_key: sohbetKey } : {}),
      ...(actor ? { actor_email: actor } : {}),
    };

    const result = await sendFcmToTokens({
      tokens,
      title: copy.title,
      body: copy.body,
      data,
    });
    await deleteInvalidTokens(admin, result.invalidTokens);
    return json(200, {
      ok: true,
      event,
      sent: result.sent,
      failed: result.failed,
      cleaned: result.invalidTokens.length,
    });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
