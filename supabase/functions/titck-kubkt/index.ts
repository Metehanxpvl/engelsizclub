// TİTCK KÜB/KT kamu araması — anahtar yok.
// titck.gov.tr/kubkt DataTables POST (getkubktviewdatatable).
// CORS için tarayıcıdan çağrılmaz; misafir tarama: verify_jwt = false.
//
//   npx supabase functions deploy titck-kubkt --no-verify-jwt --project-ref qycrkqwqrysypvqaipqn

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PAGE = "https://www.titck.gov.tr/kubkt";
const ENDPOINT = "https://www.titck.gov.tr/getkubktviewdatatable";
const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36";

const COLUMNS = [
  "name",
  "element",
  "firmName",
  "confirmationDateKub",
  "confirmationDateKt",
  "documentPathKub",
  "documentPathKt",
];

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function firstPdf(html: unknown): string | null {
  if (html == null) return null;
  const s = String(html);
  const match = s.match(/href="([^"]+\.pdf)"/i);
  if (!match) return null;
  let href = match[1].replace(/ /g, "%20");
  if (href.startsWith("//")) href = `https:${href}`;
  if (href.startsWith("/")) href = `https://www.titck.gov.tr${href}`;
  try {
    const u = new URL(href);
    if (!u.hostname.toLowerCase().includes("titck.gov.tr")) return null;
    if (u.protocol !== "http:" && u.protocol !== "https:") return null;
    return u.toString();
  } catch {
    return null;
  }
}

function buildForm(token: string, query: string): URLSearchParams {
  const form = new URLSearchParams();
  form.set("_token", token);
  form.set("draw", "1");
  form.set("start", "0");
  form.set("length", "5");
  form.set("search[value]", query);
  form.set("search[regex]", "false");
  form.set("order[0][column]", "0");
  form.set("order[0][dir]", "asc");
  COLUMNS.forEach((col, index) => {
    form.set(`columns[${index}][data]`, col);
    form.set(`columns[${index}][name]`, "");
    form.set(`columns[${index}][searchable]`, "true");
    form.set(`columns[${index}][orderable]`, "true");
    form.set(`columns[${index}][search][value]`, "");
    form.set(`columns[${index}][search][regex]`, "false");
  });
  return form;
}

function cookieHeader(res: Response): string {
  const anyHeaders = res.headers as Headers & { getSetCookie?: () => string[] };
  const list = anyHeaders.getSetCookie?.() ?? [];
  if (list.length > 0) {
    return list.map((c) => c.split(";")[0]).join("; ");
  }
  const raw = res.headers.get("set-cookie");
  if (!raw) return "";
  return raw.split(",").map((c) => c.split(";")[0].trim()).join("; ");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "POST gerekli" });
  }

  let query = "";
  try {
    const body = await req.json();
    query = String(body?.query ?? "").trim();
  } catch {
    return json(400, { ok: false, error: "JSON gerekli" });
  }
  if (query.length < 3 || query.length > 80) {
    return json(400, { ok: false, error: "Sorgu 3–80 karakter" });
  }

  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), 10_000);
  try {
    const page = await fetch(PAGE, {
      headers: { "User-Agent": UA, "Accept": "text/html" },
      signal: ac.signal,
    });
    const html = await page.text();
    const tokenMatch = html.match(/_token:\s*"([^"]+)"/) ||
      html.match(/name="_token"\s+value="([^"]+)"/) ||
      html.match(/csrf-token"\s+content="([^"]+)"/);
    if (!tokenMatch) {
      return json(200, { ok: false, error: "token_yok" });
    }
    const cookies = cookieHeader(page);
    const search = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "User-Agent": UA,
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": PAGE,
        ...(cookies ? { Cookie: cookies } : {}),
      },
      body: buildForm(tokenMatch[1], query).toString(),
      signal: ac.signal,
    });
    if (search.status >= 400) {
      return json(200, { ok: false, error: `http_${search.status}` });
    }
    const payload = await search.json();
    const rows = Array.isArray(payload?.data) ? payload.data : [];
    const row = rows[0];
    if (!row || typeof row !== "object") {
      return json(200, { ok: false, error: "kayit_yok" });
    }
    const kt = firstPdf(row.documentPathKt);
    const kub = firstPdf(row.documentPathKub);
    if (!kt && !kub) {
      return json(200, { ok: false, error: "pdf_yok" });
    }
    return json(200, {
      ok: true,
      name: String(row.name ?? "").replace(/\s+/g, " ").trim(),
      active: String(row.element ?? "").replace(/\s+/g, " ").trim(),
      kt_url: kt,
      kub_url: kub,
    });
  } catch (e) {
    return json(200, {
      ok: false,
      error: e instanceof Error ? e.message : "titck_hata",
    });
  } finally {
    clearTimeout(timer);
  }
});
