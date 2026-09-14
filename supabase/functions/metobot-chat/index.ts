// MetoBot. Secret: GEMINI_API_KEY (same as gemini-proxy).
// Grounding: tools.google_search when off-catalog or time-sensitive
// (tutar/yıl/mevzuat). Search is optional: any tool/quota/timeout failure
// retries the same model without tools so the user still gets a Turkish
// answer. JWT on.
// Deploy: npx supabase functions deploy metobot-chat --project-ref qycrkqwqrysypvqaipqn

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function istanbulDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Istanbul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

/**
 * ÖTV 2026 tavanı (uydurma değil):
 * - ÖTV (II) Sayılı Liste Uygulama Genel Tebliği Değişiklik (Seri No: 16),
 *   Resmî Gazete 31.12.2025, 33124 (5. Mükerrer), yürürlük 1/1/2026:
 *   87.03 vergiler dâhil tavan 2.290.200 TL → 2.873.900 TL.
 * - Aynı 2.873.900 TL, 22.04.2026 Resmî Gazete Seri No: 17'de de geçerli:
 *   https://www.resmigazete.gov.tr/eskiler/2026/04/20260422-3.htm
 * Uygulama metni: Engelsiz Club haklar kartı `otv-muafiyet` (rights_data.dart).
 */
type RouteHint = { route: string; title: string; needles: string[] };

const SITE_ROUTES: RouteHint[] = [
  {
    route: "haklar",
    title: "Haklar · ÖTV Muafiyetli Araç Alımı",
    needles: [
      "otv",
      "ötv",
      "otvsiz",
      "vergisiz arac",
      "engelli arac",
      "muafiyetli arac",
      "arac alimi",
      "arac muafiyet",
    ],
  },
  {
    route: "haklar",
    title: "Haklar · MTV Muafiyeti",
    needles: ["mtv", "motorlu tasit vergisi", "arac vergisi"],
  },
  {
    route: "haklar",
    title: "Haklar · Evde Bakım Maaşı",
    needles: ["evde bakim", "bakim maasi", "bakima muhtac"],
  },
  {
    route: "haklar",
    title: "Haklar · Engelli Aylığı",
    needles: ["engelli ayligi", "engelli maas", "2022 aylik"],
  },
  {
    route: "haklar",
    title: "Haklar · 18 Yaş Altı Engelli Yakını Aylığı",
    needles: ["yakini ayligi", "cocuk ayligi", "18 yas alti"],
  },
  {
    route: "haklar",
    title: "Haklar · Yardımcı Araç-Gereç Desteği",
    needles: [
      "tekerlekli sandalye",
      "yurutec",
      "ortez",
      "protez",
      "isitme cihazi",
      "yardimci arac",
    ],
  },
  {
    route: "haklar",
    title: "Haklar · Nöbet Muafiyeti & Eğitim/Bakım İzni",
    needles: ["nobet", "bakim izni", "egitim izni"],
  },
  {
    route: "haklar",
    title: "Haklar · Mazeret İzni",
    needles: ["mazeret izni", "suregen"],
  },
  {
    route: "haklar",
    title: "Haklar · Yarı Zamanlı Çalışma Hakkı",
    needles: ["yari zamanli", "kismi calisma"],
  },
  {
    route: "haklar",
    title: "Haklar · Engelli Park Kartı",
    needles: ["park karti", "mavi isaret", "engelli park"],
  },
  {
    route: "haklar",
    title: "Haklar · Engelli Sürücü Belgesi",
    needles: ["engelli ehliyet", "surucu belgesi", "b sinifi"],
  },
  {
    route: "haklar",
    title: "Haklar · KDV İndirimi",
    needles: ["kdv"],
  },
  {
    route: "haklar",
    title: "Haklar · Gelir Vergisi İndirimi",
    needles: ["gelir vergisi"],
  },
  {
    route: "haklar",
    title: "Haklar · Ücretsiz Özel Eğitim",
    needles: ["ucretsiz ozel egitim", "ozel egitim hakki", "bireysel egitim"],
  },
  {
    route: "haklar",
    title: "Haklar · RAM Raporu",
    needles: ["ram raporu", "ram nedir", "rehberlik arastirma"],
  },
  {
    route: "haklar",
    title: "Haklar · Kaynaştırma Eğitimi",
    needles: ["kaynastirma", "butunlestirme"],
  },
  {
    route: "haklar",
    title: "Haklar · Engelli Kimlik Kartı",
    needles: ["engelli kimlik", "kimlik karti"],
  },
  {
    route: "haklar",
    title: "Haklar · Ücretsiz Toplu Taşıma",
    needles: ["ucretsiz ulasim", "toplu tasima", "otobus ucretsiz"],
  },
  {
    route: "haklar",
    title: "Haklar · TCDD & THY İndirimleri",
    needles: ["tcdd", "thy", "tren indirim", "ucak indirim"],
  },
  {
    route: "haklar",
    title: "Haklar · Emlak Vergisi Muafiyeti",
    needles: ["emlak vergisi"],
  },
  {
    route: "haklar",
    title: "Haklar · Su Faturası İndirimi",
    needles: ["su faturasi", "su indirim"],
  },
  {
    route: "haklar",
    title: "Haklar · Telefon & İnternet İndirimi",
    needles: ["telefon indirim", "internet indirim"],
  },
  {
    route: "haklar",
    title: "Haklar · hak sihirbazı",
    needles: ["hangi hak", "haklarim", "hak sihirbaz"],
  },
  {
    route: "harita",
    title: "Engelsiz Haritalar",
    needles: [
      "harita",
      "merkez",
      "rehabilitasyon",
      "yakinimda",
      "nerede",
      "adres",
      "fizyoterapi merkezi",
      "ozel egitim merkezi",
    ],
  },
  {
    route: "kariyer",
    title: "Engelsiz Kariyer",
    needles: ["kariyer", "is ilani", "iskur", "işkur", "istihdam", "is ara"],
  },
  {
    route: "ilanlar",
    title: "İlanlar",
    needles: ["ilan", "bakici", "ikinci el", "2. el", "ilan ver"],
  },
  {
    route: "cvi",
    title: "CVI görsel egzersizleri",
    needles: ["cvi", "kortikal gorme", "gorsel egzersiz"],
  },
  {
    route: "cvi2",
    title: "CVI görsel egzersizleri-2",
    needles: ["cvi2", "cvi 2", "gorsel kesif"],
  },
  {
    route: "mchat",
    title: "Otizm tarama (M-CHAT)",
    needles: ["m-chat", "mchat", "otizm tarama"],
  },
  {
    route: "/bilgi-kutuphanesi/cvi-gorsel-egzersizler",
    title: "Bilgi Kütüphanesi · CVI görsel egzersizler",
    needles: ["cvi makale", "cvi nedir"],
  },
  {
    route: "/bilgi-kutuphanesi/premature-bebek",
    title: "Bilgi Kütüphanesi · Prematüre Bebek",
    needles: ["premature", "prematüre", "erken dogan"],
  },
  {
    route: "/bilgi-kutuphanesi/0-2-yas-gelisim-rehberi",
    title: "Bilgi Kütüphanesi · 0–2 Yaş Gelişim Rehberi",
    needles: ["0-2", "0–2", "bebek gelisim", "iki yas"],
  },
  {
    route: "gelisim",
    title: "Gelişim Etkinlikleri",
    needles: ["gelisim etkinlik", "120 etkinlik"],
  },
  {
    route: "destek_sorgu",
    title: "Destek Sorgu",
    needles: ["destek sorgu", "sut", "sgk katkisi", "yenileme takvim"],
  },
  {
    route: "/evde-egitim",
    title: "Evde Eğitim",
    needles: ["evde egitim", "evde ogrenim"],
  },
  {
    route: "aile_kocu",
    title: "Aile Koçum",
    needles: ["aile kocu", "ilac takibi", "ders takibi"],
  },
  {
    route: "kartlar",
    title: "Kartlar",
    needles: ["gorsel kart", "destek karti", "pecs"],
  },
  {
    route: "barkod",
    title: "Barkod / Ürün Analizi",
    needles: ["barkod", "alerjen", "urun analiz"],
  },
  {
    route: "boyama",
    title: "engelsiz Boyama",
    needles: ["boyama"],
  },
  {
    route: "puzzle",
    title: "Puzzled oyun",
    needles: ["puzzle", "yapboz"],
  },
  {
    route: "kesfet",
    title: "Keşfet",
    needles: ["kesfet"],
  },
  {
    route: "forum",
    title: "Forum",
    needles: ["forum", "topluluk"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · Otizm",
    needles: ["otizm", "osb", "spektrum"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · Serebral Palsi",
    needles: ["serebral", "cp "],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · Down Sendromu",
    needles: ["down sendrom"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · SMA",
    needles: ["sma", "spinal muskul"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · DEHB",
    needles: ["dehb", "dikkat eksikligi"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · Duyu Bütünleme",
    needles: ["duyu butunleme", "duyusal"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · İletişim Bozuklukları",
    needles: ["iletisim bozuk"],
  },
  {
    route: "home",
    title: "Bilgi Kütüphanesi · Nadir Hastalıklar",
    needles: ["nadir hastalik"],
  },
];

function foldTr(raw: string): string {
  return raw
    .toLocaleLowerCase("tr-TR")
    .replaceAll("ı", "i")
    .replaceAll("İ", "i")
    .replaceAll("ş", "s")
    .replaceAll("ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("ö", "o")
    .replaceAll("ç", "c")
    .replaceAll("â", "a")
    .replaceAll("î", "i")
    .replaceAll("û", "u");
}

function suggestRoutes(userText: string): { route: string; title: string }[] {
  const t = foldTr(userText);
  if (!t.trim()) return [];
  const scored: { route: string; title: string; n: number; len: number }[] = [];
  for (const hint of SITE_ROUTES) {
    let n = 0;
    let len = 0;
    for (const needle of hint.needles) {
      const nrm = foldTr(needle);
      if (!nrm || !t.includes(nrm)) continue;
      n += 1;
      if (nrm.length > len) len = nrm.length;
    }
    if (n > 0) scored.push({ route: hint.route, title: hint.title, n, len });
  }
  scored.sort((a, b) => b.len - a.len || b.n - a.n);
  const out: { route: string; title: string }[] = [];
  const seen = new Set<string>();
  for (const row of scored) {
    if (seen.has(row.route)) continue;
    seen.add(row.route);
    out.push({ route: row.route, title: row.title });
    if (out.length >= 2) break;
  }
  return out;
}

function siteCatalog(): string {
  return [
    "YÖNLENDİRME: Önce Engelsiz Club ekranı. Uygulamada kart/makale varken ana CTA 'SGK/İŞKUR/hastane/derneğe gidin' olmasın.",
    "Katalogda YOKSA resmi ve GÜNCEL kaynak kullan: GİB, Resmî Gazete, SGK, MEB, Aile ve Sosyal Hizmetler Bakanlığı, İŞKUR. Kurum adı dipnot + yıl; eski eğitim verisi değil.",
    "Uydurma. Teşhis koyma. M-CHAT tarama teşhis değildir. Acilde 112.",
    "Her yanıtta (varsa) ekranı ada göre söyle ve nasıl açılacağını yaz.",
    "Açılış yolları:",
    "- Haklar: Daha Fazlası → Haklar → kart adı (sihirbaz: 3 soruluk hak listesi).",
    "- Engelsiz Haritalar: alt menü Harita veya Daha Fazlası → Engelsiz Haritalar.",
    "- İlanlar: alt menü İlanlar.",
    "- Engelsiz Kariyer: Ana sayfa → Engelsiz Kariyer (İŞKUR ilanları burada).",
    "- Bilgi Kütüphanesi: Ana sayfa hastalık kartı (Otizm, SP, Down, SMA, DEHB, gelişim geriliği, duyu bütünleme, iletişim, prematüre, 0–2 yaş, nadir hastalıklar).",
    "- CVI / M-CHAT / Puzzle: Daha Fazlası → Taramalar & Egzersizler & Oyun.",
    "- Destek Sorgu: Daha Fazlası → Destek Sorgu (SUT / SGK katkısı bilgisi burada).",
    "- Evde Eğitim: Daha Fazlası → Evde Eğitim.",
    "- Aile Koçum, Kartlar, Gelişim Etkinlikleri, Barkod, Boyama: Daha Fazlası.",
    "- Keşfet ve Forum: alt menü.",
    "Haklar kartları: Evde Bakım Maaşı; Engelli Aylığı; 18 Yaş Altı Engelli Yakını Aylığı; Yardımcı Araç-Gereç Desteği; Nöbet Muafiyeti & Günlük Eğitim/Bakım İzni; Mazeret İzni; Yarı Zamanlı Çalışma; ÖTV Muafiyetli Araç Alımı; MTV Muafiyeti; Engelli Park Kartı; Engelli Sürücü Belgesi; KDV İndirimi; Gelir Vergisi İndirimi; Ücretsiz Özel Eğitim; RAM Raporu; Kaynaştırma; Engelli Kimlik Kartı; Ücretsiz Toplu Taşıma; TCDD & THY; Emlak Vergisi; Su Faturası İndirimi; Telefon & İnternet İndirimi.",
    "Örnek: ÖTV → Daha Fazlası → Haklar → ÖTV Muafiyetli Araç Alımı. Vergi dairesi yalnız başvuru dipnotu.",
    "Bilgi Kütüphanesi: /bilgi-kutuphanesi/premature-bebek ; /bilgi-kutuphanesi/0-2-yas-gelisim-rehberi ; /bilgi-kutuphanesi/cvi-gorsel-egzersizler ; /bilgi-kutuphanesi/cvi-egzersizleri-2 ; /bilgi-kutuphanesi/gelisim-etkinlikleri.html",
  ].join("\n");
}

function isSmallTalk(folded: string): boolean {
  const s = folded.replace(/[?.!,]/g, " ").replace(/\s+/g, " ").trim();
  if (s.length > 28) return false;
  return /^(merhaba|selam|slm|selamlar|hey|hi|hello|nasilsin|naber|tesekkur|tesekkurler|sag ol|saol|ok|tamam|gunaydin|iyi gunler|iyi aksamlar)( lar)?$/.test(s);
}

const TIME_SENSITIVE = [
  "otv",
  "mtv",
  "kdv",
  "sgk",
  "sut",
  "gib",
  "iskur",
  "mevzuat",
  "kanun",
  "teblig",
  "resmi gazete",
  "tavan",
  "tutar",
  "ne kadar",
  "maas",
  "aylik",
  "ucret",
  "limit",
  "muafiyet",
  "asgari",
  "2024",
  "2025",
  "2026",
  "2027",
  "guncel",
  "yururluk",
  "vergi",
  "emeklilik",
  "evde bakim",
  "engelli ayligi",
  "aile bakanligi",
];

function isTimeSensitive(folded: string): boolean {
  return TIME_SENSITIVE.some((n) => folded.includes(foldTr(n)));
}

/** Search costs extra: skip greetings; use for off-catalog or tutar/yıl/mevzuat. */
function wantsLiveSearch(userText: string): boolean {
  const t = foldTr(userText);
  if (!t.trim() || isSmallTalk(t)) return false;
  if (isTimeSensitive(t)) return true;
  return suggestRoutes(userText).length === 0 && t.length >= 12;
}

function searchToolRejected(status: number, text: string): boolean {
  if (status !== 400 && status !== 404) return false;
  const l = text.toLowerCase();
  return (
    l.includes("google_search") ||
    l.includes("googlesearch") ||
    l.includes("google search") ||
    (l.includes("tool") &&
      (l.includes("not supported") ||
        l.includes("unknown") ||
        l.includes("invalid")))
  );
}

function isQuotaStatus(status: number, text: string): boolean {
  if (status === 429) return true;
  const l = text.toLowerCase();
  return (
    l.includes("resource_exhausted") ||
    l.includes("quota") ||
    l.includes("too many requests") ||
    l.includes("rate limit")
  );
}

function searchWasUsed(raw: string): boolean {
  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch {
    return false;
  }
  const root = asRecord(decoded);
  const usage = asRecord(root?.usageMetadata) ?? asRecord(root?.usage_metadata);
  const toolTokens = Number(
    usage?.toolUsePromptTokenCount ?? usage?.tool_use_prompt_token_count ?? 0,
  );
  if (Number.isFinite(toolTokens) && toolTokens > 0) return true;

  const candidates = root?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return false;
  const rec = asRecord(candidates[0]);
  const gm = asRecord(rec?.groundingMetadata) ??
    asRecord(rec?.grounding_metadata);
  if (!gm) return false;
  const queries = gm.webSearchQueries ?? gm.web_search_queries;
  const chunks = gm.groundingChunks ?? gm.grounding_chunks;
  const entry = gm.searchEntryPoint ?? gm.search_entry_point;
  return (Array.isArray(queries) && queries.length > 0) ||
    (Array.isArray(chunks) && chunks.length > 0) ||
    entry != null;
}

function systemPrompt(searchOn: boolean): string {
  const date = istanbulDate();
  const year = date.slice(0, 4);
  return [
    "Sen Engelsiz Club MetoBot'sun. Türkçe, sakin ve nazik konuşursun.",
    "Doktor değilsin. Teşhis koymazsın, tedavi yazmazsın.",
    "Sağlık kararı için hekim/terapist dipnotu yeter; uygulama içi bilgi kartını önce göster.",
    "Acil durumda 112'yi ara, dersin.",
    "Kısa ve anlaşılır yanıt ver.",
    `Bugün (Avrupa/İstanbul): ${date}. Güncel takvim yılı ${year}. Rakamlar her yıl değişir.`,
    "Hak, maaş, tavan ve vergi tutarında yılı her zaman söyle.",
    "2024 veya daha eski ÖTV / maaş / muafiyet rakamını asla güncel kanun gibi sunma.",
    "Emin değilsen sayı uydurma. 2026 rakamı doğrulanamadıysa 2024 yazma; 'güncel resmi kaynağı kontrol edin' de.",
    "2026 engelli araç ÖTV istisnası (ÖTV Kanunu 7/2; GİB ÖTV II Liste Tebliği):",
    "87.03 binek/SUV/panelvan/pick-up/arazi: motor hacmine bakılmaksızın, ÖTV ve diğer her türlü vergiler dâhil bedel 2.873.900 TL'nin altında olmalı.",
    "Bu tavan 1 Ocak 2026'dan geçerlidir (RG 31.12.2025 / 33124 5. Mükerrer, Tebliğ Seri No: 16; Nisan 2026 Seri No: 17 aynı tavanı korur).",
    "87.04 van/kamyonet: motor silindir hacmi en fazla 2800 cm³.",
    "87.11 motosiklet: motor hacmi sınırı yok.",
    "Yerli katkı oranı en az %40.",
    "Hak 10 yılda bir kullanılabilir; araç 5 yıl dolmadan ÖTV ödemeden satılamaz.",
    "ÖTV ayrıntısı: Daha Fazlası → Haklar → ÖTV Muafiyetli Araç Alımı. Arama 2024 tavanı gösterirse onu güncel sanma; uygulama kartındaki 2026 tavan 2.873.900 TL.",
    siteCatalog(),
    searchOn
      ? "Bu turda Google Search aracı açık. Tutar, tavan, yıl ve mevzuat için ara (GİB, Resmî Gazete, SGK, MEB, Aile Bakanlığı, İŞKUR). Eğitim verisindeki eski rakamı kullanma. Kaynağın yılını söyle."
      : "Bu turda web araması kapalı. Katalog ve yukarıdaki 2026 ÖTV bilgisi yeter; katalog dışı tutarda emin değilsen uydurma.",
  ].join("\n");
}

const MODELS = [
  "gemini-flash-latest",
  "gemini-3.8-flash",
  "gemini-flash-lite-latest",
];

const DEFAULT_DAILY = 40;
const DEFAULT_LAST_N = 12;
const DEFAULT_MAX_TOKENS = 512;
const MAX_CONTENT = 1500;
const MIN_GAP_MS = 1500;
const PER_MODEL_MS = 12_000;
/** Client invoke timeout is ~36s; keep search short so a no-tool retry still fits. */
const SEARCH_MODEL_MS = 8_000;
const GOOGLE_SEARCH_TOOLS = [{ google_search: {} }];

const lastHit = new Map<string, number>();

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function istanbulDayStartIso(): string {
  const day = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Istanbul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return `${day}T00:00:00+03:00`;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function positiveInt(raw: unknown, fallback: number): number {
  const n = typeof raw === "number"
    ? raw
    : typeof raw === "string"
    ? Number(raw)
    : NaN;
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return Math.floor(n);
}

type Limits = {
  dailyUserMessages: number;
  maxOutputTokens: number;
  lastN: number;
};

function parseLimits(value: unknown): Limits {
  const rec = asRecord(value);
  if (!rec) {
    if (typeof value === "number" || typeof value === "string") {
      return {
        dailyUserMessages: positiveInt(value, DEFAULT_DAILY),
        maxOutputTokens: DEFAULT_MAX_TOKENS,
        lastN: DEFAULT_LAST_N,
      };
    }
    return {
      dailyUserMessages: DEFAULT_DAILY,
      maxOutputTokens: DEFAULT_MAX_TOKENS,
      lastN: DEFAULT_LAST_N,
    };
  }
  return {
    dailyUserMessages: positiveInt(
      rec.dailyUserMessages ?? rec.daily_user_messages,
      DEFAULT_DAILY,
    ),
    maxOutputTokens: Math.min(
      1024,
      positiveInt(rec.maxOutputTokens ?? rec.max_output_tokens, DEFAULT_MAX_TOKENS),
    ),
    lastN: Math.min(
      20,
      positiveInt(rec.lastN ?? rec.last_n, DEFAULT_LAST_N),
    ),
  };
}

type Turn = { role: "user" | "model"; text: string };

function parseTurns(raw: unknown, lastN: number): Turn[] {
  if (!Array.isArray(raw)) return [];
  const out: Turn[] = [];
  for (const item of raw) {
    const rec = asRecord(item);
    if (!rec) continue;
    const roleRaw = String(rec.role ?? "").trim().toLowerCase();
    const content = String(rec.content ?? rec.text ?? "").trim();
    if (!content) continue;
    const role = roleRaw === "assistant" || roleRaw === "model"
      ? "model"
      : roleRaw === "user"
      ? "user"
      : null;
    if (!role) continue;
    out.push({ role, text: content.slice(0, MAX_CONTENT) });
  }
  return out.length <= lastN ? out : out.slice(-lastN);
}

function extractText(raw: string): string {
  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch {
    return "";
  }
  const candidates = asRecord(decoded)?.candidates;
  if (!Array.isArray(candidates)) return "";
  const parts: string[] = [];
  for (const candidate of candidates) {
    const contentParts = asRecord(asRecord(candidate)?.content)?.parts;
    if (!Array.isArray(contentParts)) continue;
    for (const part of contentParts) {
      const text = String(asRecord(part)?.text ?? "").trim();
      if (text) parts.push(text);
    }
  }
  return parts.join("\n").trim();
}

async function generateOnce(
  model: string,
  key: string,
  body: string,
  timeoutMs = PER_MODEL_MS,
): Promise<{ ok: boolean; status: number; text: string }> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${encodeURIComponent(key)}`;
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const upstream = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: ac.signal,
    });
    const text = await upstream.text();
    return { ok: upstream.ok, status: upstream.status, text };
  } catch (e) {
    const msg = String(e).toLowerCase();
    const aborted = msg.includes("abort");
    return {
      ok: false,
      status: aborted ? 504 : 502,
      text: JSON.stringify({
        error: { message: aborted ? "model timeout" : String(e) },
      }),
    };
  } finally {
    clearTimeout(timer);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json(405, { error: "POST gerekli.", code: "method" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const geminiKey = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
  if (!supabaseUrl || !anonKey) {
    return json(500, { error: "Sunucu ayarı eksik.", code: "config" });
  }
  if (!geminiKey) {
    return json(503, { error: "Şu an yanıt verilemiyor.", code: "config" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return json(401, { error: "Giriş gerekli.", code: "auth" });
  }
  const userId = userData.user.id;

  const now = Date.now();
  const prev = lastHit.get(userId) ?? 0;
  if (now - prev < MIN_GAP_MS) {
    return json(429, {
      error: "Biraz bekleyip tekrar deneyin.",
      code: "rate_limit",
    });
  }
  lastHit.set(userId, now);

  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { error: "Geçersiz istek.", code: "invalid" });
  }

  let limits: Limits = {
    dailyUserMessages: DEFAULT_DAILY,
    maxOutputTokens: DEFAULT_MAX_TOKENS,
    lastN: DEFAULT_LAST_N,
  };
  try {
    const { data } = await userClient
      .from("app_settings")
      .select("value")
      .eq("key", "metobot_limits")
      .maybeSingle();
    if (data?.value != null) limits = parseLimits(data.value);
  } catch {
    // keep defaults
  }

  const turns = parseTurns(body.messages, limits.lastN);
  if (turns.length === 0 || turns[turns.length - 1].role !== "user") {
    return json(400, { error: "Mesaj boş.", code: "empty" });
  }

  try {
    const { count } = await userClient
      .from("metobot_messages")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("role", "user")
      .gte("created_at", istanbulDayStartIso());
    if ((count ?? 0) >= limits.dailyUserMessages) {
      return json(429, {
        error: "Bugünkü mesaj sınırına ulaşıldı.",
        code: "daily_cap",
      });
    }
  } catch {
    // fail-open
  }

  let threadId = String(body.threadId ?? body.thread_id ?? "").trim();
  try {
    if (threadId) {
      const { data: owned } = await userClient
        .from("metobot_threads")
        .select("id")
        .eq("id", threadId)
        .eq("user_id", userId)
        .maybeSingle();
      if (!owned) threadId = "";
    }
    if (!threadId) {
      const { data: created } = await userClient
        .from("metobot_threads")
        .insert({ user_id: userId })
        .select("id")
        .single();
      threadId = String(created?.id ?? "");
    }
  } catch {
    threadId = threadId || "";
  }

  const userText = turns[turns.length - 1].text;
  const useSearch = wantsLiveSearch(userText);
  const contents = turns.map((t) => ({
    role: t.role,
    parts: [{ text: t.text }],
  }));
  const generationConfig = {
    temperature: 0.6,
    maxOutputTokens: limits.maxOutputTokens,
  };
  const payloadPlain = JSON.stringify({
    systemInstruction: { parts: [{ text: systemPrompt(false) }] },
    contents,
    generationConfig,
  });
  const payloadSearch = JSON.stringify({
    systemInstruction: { parts: [{ text: systemPrompt(true) }] },
    contents,
    generationConfig,
    tools: GOOGLE_SEARCH_TOOLS,
  });

  let reply = "";
  let lastStatus = 502;
  let lastRaw = "";
  let searchUsed = false;
  let searchRejected = false;
  for (const model of MODELS) {
    if (useSearch && !searchRejected) {
      const grounded = await generateOnce(
        model,
        geminiKey,
        payloadSearch,
        SEARCH_MODEL_MS,
      );
      lastStatus = grounded.status;
      lastRaw = grounded.text;
      if (grounded.ok) {
        reply = extractText(grounded.text);
        if (reply) {
          searchUsed = searchWasUsed(grounded.text);
          break;
        }
      }
      // Search is optional. 400 tool-schema, 429 quota, timeout, or empty
      // candidates must still get a Turkish answer without tools.
      searchRejected = true;
      if (searchToolRejected(grounded.status, grounded.text)) {
        console.warn("metobot-chat search tool rejected; retrying without search");
      } else if (!grounded.ok) {
        console.warn(
          `metobot-chat search skipped status=${grounded.status}; retrying without search`,
        );
      }
    }
    const result = await generateOnce(model, geminiKey, payloadPlain);
    lastStatus = result.status;
    lastRaw = result.text;
    if (!result.ok) continue;
    reply = extractText(result.text);
    if (reply) break;
  }
  if (!reply) {
    const quota = isQuotaStatus(lastStatus, lastRaw);
    return json(quota ? 429 : lastStatus >= 400 ? lastStatus : 502, {
      error: quota
        ? "Model kotası doldu, biraz sonra deneyin."
        : "Şu an yanıt verilemedi, biraz sonra deneyin.",
      code: quota ? "quota" : "upstream",
    });
  }

  if (threadId) {
    try {
      await userClient.from("metobot_messages").insert({
        thread_id: threadId,
        user_id: userId,
        role: "user",
        content: userText,
      });
      await userClient.from("metobot_messages").insert({
        thread_id: threadId,
        user_id: userId,
        role: "assistant",
        content: reply,
      });
      await userClient
        .from("metobot_threads")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", threadId)
        .eq("user_id", userId);
    } catch {
      // reply still returned
    }
  }

  const suggestedRoutes = suggestRoutes(userText);
  return json(200, {
    reply,
    threadId: threadId || null,
    suggestedRoutes,
    searchOffered: useSearch && !searchRejected,
    searchUsed,
  });
});
