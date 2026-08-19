// Admin: ilan kind değiştir (service role — RLS bypass)
// Deploy: supabase functions deploy admin-ilan-kind
//
// Body: { id, kind, category?, uzmanlik? }

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

function normalizeKind(raw: string): string | null {
  const k = raw.trim().toLowerCase();
  return k === "uzman" || k === "bakici" || k === "ikinciel" ? k : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: "Supabase env eksik." });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return json(401, { error: "Giriş gerekli." });
  }
  const email = (userData.user.email ?? "").trim().toLowerCase();
  if (!ADMIN_EMAILS.has(email)) {
    return json(403, { error: "Yalnızca admin." });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Geçersiz JSON." });
  }

  const id = Number(body.id ?? 0);
  const kind = normalizeKind(String(body.kind ?? ""));
  const category = String(body.category ?? "").trim() || "Diğer";
  const uzmanlik = String(body.uzmanlik ?? "").trim() || "Uzman";

  if (!id || id <= 0) return json(400, { error: "Geçersiz ilan id." });
  if (!kind) return json(400, { error: "Geçersiz kind." });

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: row, error: fetchErr } = await admin
    .from("ilanlar")
    .select(
      "photos, budget, price, condition, brand, emoji, uzmanlik, category",
    )
    .eq("id", id)
    .maybeSingle();

  if (fetchErr) return json(500, { error: fetchErr.message });
  if (!row) return json(404, { error: "İlan bulunamadı." });

  const payload: Record<string, unknown> = { kind };

  const photos = row.photos;
  const photoList = Array.isArray(photos) ? photos : [];

  if (kind === "ikinciel") {
    payload.category = category;
    const price = String(row.price ?? "").trim();
    const budget = String(row.budget ?? "").trim();
    if (!price && budget) payload.price = budget;
    if (!String(row.condition ?? "").trim()) payload.condition = "İyi";
    if (!String(row.brand ?? "").trim()) payload.brand = "—";
    if (!String(row.emoji ?? "").trim()) payload.emoji = "📦";
  }

  if (kind === "uzman") {
    payload.uzmanlik = uzmanlik;
  }

  if (kind === "uzman" || kind === "bakici") {
    const budget = String(row.budget ?? "").trim();
    const price = String(row.price ?? "").trim();
    if (!budget && price) payload.budget = price;
    if (photoList.length > 2) payload.photos = photoList.slice(0, 2);
  }

  const { data: updated, error: updErr } = await admin
    .from("ilanlar")
    .update(payload)
    .eq("id", id)
    .select()
    .single();

  if (updErr) return json(500, { error: updErr.message });
  return json(200, { row: updated });
});
