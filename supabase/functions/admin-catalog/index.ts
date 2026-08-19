// Admin katalog kategorisi ekle (service role — RLS bypass)
// Deploy:
//   supabase functions deploy admin-catalog
//
// Body: { id, scope, label, icon?, sort_order?, meta? }

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

  const id = String(body.id ?? "").trim();
  const scope = String(body.scope ?? "").trim();
  const label = String(body.label ?? "").trim();
  const icon = String(body.icon ?? "").trim() || "📁";
  const sortOrder = Math.max(Number(body.sort_order ?? 0) || 0, 0);
  const meta = body.meta && typeof body.meta === "object"
    ? body.meta
    : {};

  if (!id || !scope || !label) {
    return json(400, { error: "id, scope, label gerekli." });
  }

  const admin = createClient(supabaseUrl, serviceKey);

  const { data: row, error: upsertErr } = await admin
    .from("app_categories")
    .upsert({
      id,
      scope,
      label,
      icon,
      sort_order: sortOrder,
      active: true,
      meta,
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (upsertErr) {
    return json(500, { error: upsertErr.message });
  }

  const { data: verRow } = await admin
    .from("app_catalog_versions")
    .select("version")
    .eq("name", "categories")
    .maybeSingle();

  const nextVer = (Number(verRow?.version ?? 0) || 0) + 1;
  await admin.from("app_catalog_versions").upsert({
    name: "categories",
    version: nextVer,
    updated_at: new Date().toISOString(),
  });

  return json(200, { row });
});
