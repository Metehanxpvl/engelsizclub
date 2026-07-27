import { useState, useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";
import appIcon from "@/imports/119686.png";
import heroPhoto from "@/imports/118547.png";
import heroPhoto2 from "@/imports/118587-1.png";
import heroPhoto3 from "@/imports/118600.png";
import { ImageWithFallback } from "@/app/components/figma/ImageWithFallback";
import { diseases, nadirHastaliklar } from "@/app/data/diseases";
import { forumPosts } from "@/app/data/forum";
import { allRights } from "@/app/data/rights";
import { uzmanIlanlar, bakiciIlanlar, ikincielIlanlar, uzmanRenk } from "@/app/data/ilanlar";
import type { IlanReview, IlanPoster } from "@/app/data/ilanlar";
import { KartlarTab } from "@/app/components/KartlarTab";
import { MerkezlerTab } from "@/app/components/MerkezlerTab";
import { RightsSihirbazi } from "@/app/components/RightsSihirbazi";
import {
  Home,
  MapPin,
  LayoutGrid,
  MessageCircle,
  User,
  Search,
  ChevronRight,
  Heart,
  Star,
  Phone,
  Clock,
  Volume2,
  ThumbsUp,
  Shield,
  BookOpen,
  Stethoscope,
  ShoppingBag,
  ChevronDown,
  ChevronUp,
  X,
  AlertCircle,
  CheckCircle,
  MessageSquare,
  Users,
  Package,
  Scale,
  Wand2,
  ArrowRight,
  RotateCcw,
  FileText,
  ExternalLink,
  Briefcase,
  Coins,
  BadgeCheck,
  Send,
  MapPinned,
  CalendarDays,
  Sparkles,
  Plus,
  Eye,
  Edit3,
} from "lucide-react";

type Tab = "home" | "merkezler" | "kartlar" | "forum" | "haklar" | "ilanlar" | "profil";
type InfoSection = "bilgi" | "medikal";


// ─── COMPONENTS ─────────────────────────────────────────────────────────────

function DisclaimerBanner() {
  return (
    <div className="mx-4 mb-4 flex items-start gap-2 rounded-xl bg-amber-50 border border-amber-200 p-3">
      <AlertCircle size={16} className="text-amber-600 mt-0.5 shrink-0" />
      <p className="text-xs text-amber-700 leading-relaxed">
        Bu uygulama yalnızca bilgilendirme amaçlıdır. Tanı, tedavi veya tıbbi tavsiye yerine geçmez. Her zaman uzman bir sağlık profesyoneline başvurun.
      </p>
    </div>
  );
}

// Türkçe tıbbi terimler sözlüğü — anında çeviri için
const TR_EN_DICT: Record<string, string> = {
  "otizm": "autism", "otizmli": "autism", "otistik": "autistic",
  "serebral palsi": "cerebral palsy", "sp": "cerebral palsy",
  "down sendromu": "down syndrome", "down": "down syndrome",
  "dehb": "ADHD", "dikkat eksikliği": "attention deficit",
  "hiperaktivite": "hyperactivity", "hiperaktif": "hyperactive",
  "epilepsi": "epilepsy", "sara": "epilepsy", "nöbet": "seizure",
  "fizyoterapi": "physiotherapy", "fizik tedavi": "physical therapy",
  "ergoterapi": "occupational therapy", "ergoterapist": "occupational therapist",
  "dil terapisi": "speech therapy", "konuşma terapisi": "speech therapy",
  "aba terapisi": "ABA therapy", "aba": "applied behavior analysis",
  "özel eğitim": "special education", "zihinsel engel": "intellectual disability",
  "gelişim geriliği": "developmental delay", "gelişimsel": "developmental",
  "nadir hastalık": "rare disease", "genetik": "genetic",
  "spina bifida": "spina bifida", "hidrosefali": "hydrocephalus",
  "rett sendromu": "rett syndrome", "angelman": "angelman syndrome",
  "fragile x": "fragile x syndrome", "williams sendromu": "williams syndrome",
  "duchenne": "duchenne muscular dystrophy", "dmd": "duchenne muscular dystrophy",
  "kas hastalığı": "muscular disease", "nörolojik": "neurological",
  "iletişim bozukluğu": "communication disorder", "aac": "augmentative communication",
  "duyusal işleme": "sensory processing", "duyu bütünleme": "sensory integration",
  "erken müdahale": "early intervention", "davranış terapisi": "behavioral therapy",
  "ilaç": "medication", "tedavi": "treatment", "terapi": "therapy",
  "çocuk": "children", "bebek": "infant", "engelli": "disability",
  "rehabilitasyon": "rehabilitation", "müdahale": "intervention",
  "tanı": "diagnosis", "tarama": "screening", "değerlendirme": "assessment",
};

async function translateToEnglish(text: string): Promise<string> {
  const lower = text.toLowerCase().trim();
  let translated = lower;
  const sorted = Object.keys(TR_EN_DICT).sort((a, b) => b.length - a.length);
  for (const tr of sorted) {
    if (translated.includes(tr)) {
      translated = translated.replace(new RegExp(tr, "gi"), TR_EN_DICT[tr]);
    }
  }
  if (/[çğıöşüÇĞİÖŞÜ]/.test(translated) || translated === lower) {
    try {
      const res = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(lower)}&langpair=tr|en`);
      const data = await res.json();
      const apiResult: string = data?.responseData?.translatedText ?? "";
      if (apiResult && data?.responseStatus === 200) return apiResult;
    } catch { /* sözlük sonucunu kullan */ }
  }
  return translated;
}

async function translateToTurkish(text: string): Promise<string> {
  if (!text || text === "—") return text;
  try {
    const res = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=en|tr`);
    const data = await res.json();
    const result: string = data?.responseData?.translatedText ?? "";
    if (result && data?.responseStatus === 200) return result;
  } catch { /* orijinal metni göster */ }
  return text;
}

type PubMedItem = { pmid: string; title: string; authors: string; journal: string; year: string };
type TrialItem  = { nctId: string; title: string; status: string; phase: string; conditions: string; sponsor: string };

const PUBMED_PAGE_SIZE = 10;
const TRIALS_PAGE_SIZE = 10;

function PubMedSearchBar({ placeholder = "Hastalık veya tedavi araştır..." }: { placeholder?: string }) {
  const [query, setQuery]               = useState("");
  const [activeTab, setActiveTab]       = useState<"pubmed" | "trials">("pubmed");
  const [loading, setLoading]           = useState(false);
  const [loadingMore, setLoadingMore]   = useState(false);
  const [searched, setSearched]         = useState(false);
  const [translatedQ, setTranslatedQ]   = useState("");
  const [pubmedItems, setPubmedItems]   = useState<PubMedItem[]>([]);
  const [trialItems,  setTrialItems]    = useState<TrialItem[]>([]);
  const [expanded, setExpanded]         = useState<string | null>(null);
  const [pubmedPage, setPubmedPage]     = useState(1);
  const [trialsPage, setTrialsPage]     = useState(1);
  const [pubmedTotal, setPubmedTotal]   = useState(0);
  const [trialsNextToken, setTrialsNextToken] = useState<string | null>(null);
  const [trialsHasMore, setTrialsHasMore]     = useState(false);
  const allIdsRef = useRef<string[]>([]);
  const engRef    = useRef("");

  async function fetchPubMedPage(allIds: string[], page: number): Promise<PubMedItem[]> {
    const start = (page - 1) * PUBMED_PAGE_SIZE;
    const pageIds = allIds.slice(start, start + PUBMED_PAGE_SIZE);
    if (!pageIds.length) return [];
    const sumR = await fetch(`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=${pageIds.join(",")}&retmode=json`);
    const sum  = await sumR.json();
    const raw  = pageIds.map((id): PubMedItem => {
      const d = sum.result?.[id];
      return {
        pmid:    id,
        title:   d?.title ?? "—",
        authors: d?.authors?.map((a: { name: string }) => a.name).slice(0, 2).join(", ") ?? "",
        journal: d?.fulljournalname ?? d?.source ?? "",
        year:    d?.pubdate?.slice(0, 4) ?? "",
      };
    });
    return Promise.all(raw.map(async (item) => ({ ...item, title: await translateToTurkish(item.title) })));
  }

  async function handleSearch() {
    const raw = query.trim();
    if (!raw) return;
    setLoading(true);
    setSearched(true);
    setPubmedItems([]);
    setTrialItems([]);
    setExpanded(null);
    setPubmedPage(1);
    setTrialsPage(1);
    setTrialsNextToken(null);
    setTrialsHasMore(false);
    allIdsRef.current = [];

    const eng = await translateToEnglish(raw);
    setTranslatedQ(eng);
    engRef.current = eng;

    await Promise.all([
      (async () => {
        try {
          const sr  = await fetch(`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${encodeURIComponent(eng + " children special needs")}&retmax=200&retmode=json&sort=relevance`);
          const sd  = await sr.json();
          const ids: string[] = sd.esearchresult?.idlist ?? [];
          const total = parseInt(sd.esearchresult?.count ?? "0", 10);
          setPubmedTotal(Math.min(total, ids.length));
          allIdsRef.current = ids;
          const first = await fetchPubMedPage(ids, 1);
          setPubmedItems(first);
        } catch { /* boş bırak */ }
      })(),
      (async () => {
        try {
          const r = await fetch(`https://clinicaltrials.gov/api/v2/studies?query.term=${encodeURIComponent(eng)}&pageSize=${TRIALS_PAGE_SIZE}&format=json`);
          const d = await r.json();
          const nextToken = d.nextPageToken ?? null;
          setTrialsNextToken(nextToken);
          setTrialsHasMore(!!nextToken);
          const rawTrials = (d.studies ?? []).map((s: Record<string, unknown>): TrialItem => {
            const p    = (s.protocolSection as Record<string, unknown>) ?? {};
            const id   = (p.identificationModule      as Record<string, unknown>) ?? {};
            const st   = (p.statusModule               as Record<string, unknown>) ?? {};
            const des  = (p.designModule               as Record<string, unknown>) ?? {};
            const cond = (p.conditionsModule           as Record<string, unknown>) ?? {};
            const sp   = (p.sponsorCollaboratorsModule as Record<string, unknown>) ?? {};
            return {
              nctId:      (id.nctId      as string) ?? "",
              title:      (id.briefTitle as string) ?? "—",
              status:     (st.overallStatus as string) ?? "",
              phase:      ((des.phases as string[]) ?? []).join(", ") || "—",
              conditions: ((cond.conditions as string[]) ?? []).slice(0, 2).join(", "),
              sponsor:    ((sp.leadSponsor as Record<string, string>)?.name) ?? "",
            };
          });
          const translated = await Promise.all(rawTrials.map(async (t: TrialItem) => ({
            ...t,
            title:      await translateToTurkish(t.title),
            conditions: t.conditions ? await translateToTurkish(t.conditions) : "",
          })));
          setTrialItems(translated);
        } catch { /* boş bırak */ }
      })(),
    ]);

    setLoading(false);
  }

  async function loadMorePubMed() {
    const nextPage = pubmedPage + 1;
    const start = (nextPage - 1) * PUBMED_PAGE_SIZE;
    if (start >= allIdsRef.current.length) return;
    setLoadingMore(true);
    const more = await fetchPubMedPage(allIdsRef.current, nextPage);
    setPubmedItems((prev) => [...prev, ...more]);
    setPubmedPage(nextPage);
    setLoadingMore(false);
  }

  async function loadMoreTrials() {
    if (!trialsNextToken) return;
    setLoadingMore(true);
    try {
      const r = await fetch(`https://clinicaltrials.gov/api/v2/studies?query.term=${encodeURIComponent(engRef.current)}&pageSize=${TRIALS_PAGE_SIZE}&pageToken=${trialsNextToken}&format=json`);
      const d = await r.json();
      const nextToken = d.nextPageToken ?? null;
      setTrialsNextToken(nextToken);
      setTrialsHasMore(!!nextToken);
      setTrialsPage((p) => p + 1);
      const rawTrials = (d.studies ?? []).map((s: Record<string, unknown>): TrialItem => {
        const p    = (s.protocolSection as Record<string, unknown>) ?? {};
        const id   = (p.identificationModule      as Record<string, unknown>) ?? {};
        const st   = (p.statusModule               as Record<string, unknown>) ?? {};
        const des  = (p.designModule               as Record<string, unknown>) ?? {};
        const cond = (p.conditionsModule           as Record<string, unknown>) ?? {};
        const sp   = (p.sponsorCollaboratorsModule as Record<string, unknown>) ?? {};
        return {
          nctId:      (id.nctId      as string) ?? "",
          title:      (id.briefTitle as string) ?? "—",
          status:     (st.overallStatus as string) ?? "",
          phase:      ((des.phases as string[]) ?? []).join(", ") || "—",
          conditions: ((cond.conditions as string[]) ?? []).slice(0, 2).join(", "),
          sponsor:    ((sp.leadSponsor as Record<string, string>)?.name) ?? "",
        };
      });
      const translated = await Promise.all(rawTrials.map(async (t: TrialItem) => ({
        ...t,
        title:      await translateToTurkish(t.title),
        conditions: t.conditions ? await translateToTurkish(t.conditions) : "",
      })));
      setTrialItems((prev) => [...prev, ...translated]);
    } catch { /* boş bırak */ }
    setLoadingMore(false);
  }

  const trialStatusLabel = (s: string) => ({ RECRUITING: "Katılımcı Aranıyor", COMPLETED: "Tamamlandı", ACTIVE_NOT_RECRUITING: "Aktif", NOT_YET_RECRUITING: "Yakında" }[s] ?? s);
  const trialStatusStyle = (s: string) => s === "RECRUITING" ? { bg: "#dcfce7", color: "#166534" } : s === "COMPLETED" ? { bg: "#dbeafe", color: "#1e40af" } : { bg: "#f3f4f6", color: "#6b7280" };
  const hasAny = pubmedItems.length > 0 || trialItems.length > 0;
  const pubmedHasMore = allIdsRef.current.length > pubmedPage * PUBMED_PAGE_SIZE;

  return (
    <div>
      {/* Input */}
      <div className="flex items-center gap-2 bg-card border border-border rounded-xl px-3 py-3 shadow-sm">
        <Search size={16} className="text-muted-foreground shrink-0" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
          placeholder={placeholder}
          className="flex-1 bg-transparent text-sm text-foreground placeholder:text-muted-foreground outline-none"
        />
        {query && (
          <button onClick={() => { setQuery(""); setPubmedItems([]); setTrialItems([]); setSearched(false); setTranslatedQ(""); allIdsRef.current = []; }}
            className="text-muted-foreground shrink-0"><X size={14} /></button>
        )}
        <button onClick={handleSearch}
          className="shrink-0 px-3 py-1.5 rounded-lg bg-primary text-primary-foreground text-xs font-bold">
          Ara
        </button>
      </div>

      {/* Kaynak etiketleri */}
      <div className="flex items-center gap-1.5 mt-1.5 px-1">
        <ExternalLink size={10} className="text-muted-foreground shrink-0" />
        <span className="text-[10px] text-muted-foreground">PubMed / NCBI · ClinicalTrials.gov · Türkçe→İngilizce otomatik çeviri</span>
      </div>

      {/* Yükleniyor */}
      {loading && (
        <div className="mt-4 flex flex-col items-center gap-2 py-8">
          <div className="w-6 h-6 rounded-full border-2 border-primary border-t-transparent animate-spin" />
          <span className="text-xs text-muted-foreground font-semibold">Aranıyor ve Türkçe'ye çevriliyor...</span>
          <span className="text-[10px] text-muted-foreground">PubMed · ClinicalTrials.gov</span>
        </div>
      )}

      {/* Boş durum */}
      {!loading && searched && !hasAny && (
        <div className="mt-4 text-center py-8">
          <p className="text-sm font-bold text-foreground">Sonuç bulunamadı</p>
          <p className="text-xs text-muted-foreground mt-1">
            {translatedQ && translatedQ !== query.toLowerCase() && (
              <span>İngilizce olarak &quot;<strong>{translatedQ}</strong>&quot; arandı. </span>
            )}
            Farklı bir kelime deneyin.
          </p>
        </div>
      )}

      {/* Sonuçlar */}
      {!loading && hasAny && (
        <div className="mt-3">
          {/* Çeviri bildirimi */}
          {translatedQ && translatedQ.toLowerCase() !== query.toLowerCase() && (
            <div className="flex items-center gap-1.5 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2 mb-3">
              <span className="text-sm">🌐</span>
              <p className="text-[11px] text-amber-800">
                <strong>&quot;{query}&quot;</strong> → İngilizce: <strong>&quot;{translatedQ}&quot;</strong> olarak arandı
              </p>
            </div>
          )}

          {/* Sekmeler */}
          <div className="flex gap-2 mb-3">
            <button onClick={() => setActiveTab("pubmed")}
              className="flex-1 py-2 rounded-xl text-xs font-extrabold transition-all"
              style={activeTab === "pubmed" ? { background: "#1a6b4a", color: "#fff" } : { background: "#dceee4", color: "#4d7a62" }}>
              📄 PubMed {pubmedTotal > 0 && `(${pubmedTotal} sonuç)`}
            </button>
            <button onClick={() => setActiveTab("trials")}
              className="flex-1 py-2 rounded-xl text-xs font-extrabold transition-all"
              style={activeTab === "trials" ? { background: "#1a6b4a", color: "#fff" } : { background: "#dceee4", color: "#4d7a62" }}>
              🧪 Klinik Çalışmalar {trialItems.length > 0 && `(${trialItems.length}${trialsHasMore ? "+" : ""})`}
            </button>
          </div>

          {/* PubMed kartları */}
          {activeTab === "pubmed" && (
            <div className="space-y-2">
              {pubmedItems.length === 0
                ? <p className="text-xs text-muted-foreground text-center py-4">PubMed&apos;de sonuç bulunamadı.</p>
                : <>
                  <p className="text-[10px] text-muted-foreground px-1 mb-2">
                    {pubmedItems.length} / {pubmedTotal} sonuç gösteriliyor
                  </p>
                  {pubmedItems.map((r) => (
                    <div key={r.pmid} className="bg-card border border-border rounded-2xl p-3 shadow-sm">
                      <button className="w-full text-left" onClick={() => setExpanded(expanded === r.pmid ? null : r.pmid)}>
                        <p className="text-xs font-extrabold text-foreground leading-snug line-clamp-2">{r.title}</p>
                        <div className="flex items-center gap-2 mt-1.5 flex-wrap">
                          {r.year    && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-primary/10 text-primary">{r.year}</span>}
                          {r.journal && <span className="text-[10px] text-muted-foreground truncate max-w-[150px]">{r.journal}</span>}
                        </div>
                        {r.authors && <p className="text-[10px] text-muted-foreground mt-0.5">{r.authors}</p>}
                      </button>
                      {expanded === r.pmid && (
                        <div className="mt-2 pt-2 border-t border-border">
                          <a href={`https://pubmed.ncbi.nlm.nih.gov/${r.pmid}/`} target="_blank" rel="noreferrer"
                            className="flex items-center gap-1.5 text-xs font-bold text-primary">
                            <ExternalLink size={11} /> PubMed&apos;de Aç (PMID: {r.pmid})
                          </a>
                        </div>
                      )}
                    </div>
                  ))}
                  {pubmedHasMore && (
                    <button
                      onClick={loadMorePubMed}
                      disabled={loadingMore}
                      className="w-full py-3 rounded-2xl text-xs font-extrabold border-2 border-primary text-primary flex items-center justify-center gap-2 disabled:opacity-50"
                    >
                      {loadingMore
                        ? <><div className="w-3.5 h-3.5 border-2 border-primary border-t-transparent rounded-full animate-spin" /> Yükleniyor...</>
                        : <>Daha Fazla Göster ({Math.min(PUBMED_PAGE_SIZE, allIdsRef.current.length - pubmedItems.length)} sonuç daha)</>
                      }
                    </button>
                  )}
                </>
              }
            </div>
          )}

          {/* ClinicalTrials kartları */}
          {activeTab === "trials" && (
            <div className="space-y-2">
              {trialItems.length === 0
                ? <p className="text-xs text-muted-foreground text-center py-4">ClinicalTrials.gov&apos;da sonuç bulunamadı.</p>
                : <>
                  <p className="text-[10px] text-muted-foreground px-1 mb-2">
                    {trialItems.length}{trialsHasMore ? "+" : ""} sonuç gösteriliyor
                  </p>
                  {trialItems.map((t) => {
                    const sc = trialStatusStyle(t.status);
                    return (
                      <div key={t.nctId} className="bg-card border border-border rounded-2xl p-3 shadow-sm">
                        <button className="w-full text-left" onClick={() => setExpanded(expanded === t.nctId ? null : t.nctId)}>
                          <p className="text-xs font-extrabold text-foreground leading-snug line-clamp-2">{t.title}</p>
                          <div className="flex items-center gap-2 mt-1.5 flex-wrap">
                            {t.status && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full" style={{ background: sc.bg, color: sc.color }}>{trialStatusLabel(t.status)}</span>}
                            {t.phase !== "—" && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-purple-50 text-purple-700">{t.phase}</span>}
                          </div>
                          {t.conditions && <p className="text-[10px] text-muted-foreground mt-0.5">{t.conditions}</p>}
                          {t.sponsor    && <p className="text-[10px] text-muted-foreground">{t.sponsor}</p>}
                        </button>
                        {expanded === t.nctId && (
                          <div className="mt-2 pt-2 border-t border-border">
                            <a href={`https://clinicaltrials.gov/study/${t.nctId}`} target="_blank" rel="noreferrer"
                              className="flex items-center gap-1.5 text-xs font-bold text-primary">
                              <ExternalLink size={11} /> ClinicalTrials.gov&apos;da Aç ({t.nctId})
                            </a>
                          </div>
                        )}
                      </div>
                    );
                  })}
                  {trialsHasMore && (
                    <button
                      onClick={loadMoreTrials}
                      disabled={loadingMore}
                      className="w-full py-3 rounded-2xl text-xs font-extrabold border-2 border-primary text-primary flex items-center justify-center gap-2 disabled:opacity-50"
                    >
                      {loadingMore
                        ? <><div className="w-3.5 h-3.5 border-2 border-primary border-t-transparent rounded-full animate-spin" /> Yükleniyor...</>
                        : <>Daha Fazla Göster</>
                      }
                    </button>
                  )}
                </>
              }
            </div>
          )}

          <p className="text-[10px] text-muted-foreground text-center pt-2">Bilgi amaçlıdır, tıbbi tavsiye değildir.</p>
        </div>
      )}
    </div>
  );
}

function HomeTab() {
  const [activeDisease, setActiveDisease] = useState<string | null>(null);
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null);
  const [heroIdx, setHeroIdx] = useState(0);

  const heroSlides = [
    { src: heroPhoto,  alt: "Terapist ve özel gereksinimli çocuk yürüyüş terapisinde" },
    { src: heroPhoto2, alt: "Gökkuşağı altında mutlu iki çocuk" },
    { src: heroPhoto3, alt: "Anne ve yeni doğan bebeği hastanede" },
  ];

  useEffect(() => {
    const t = setInterval(() => setHeroIdx((p) => (p + 1) % heroSlides.length), 4000);
    return () => clearInterval(t);
  }, []);

  const selected = diseases.find((d) => d.id === activeDisease);

  if (activeDisease === "nadir") {
    return (
      <div className="flex flex-col h-full">
        <div className="px-4 pt-6 pb-6" style={{ background: "linear-gradient(135deg, #1a1a2e, #2d1b69)" }}>
          <button onClick={() => { setActiveDisease(null); setExpandedFaq(null); }}
            className="mb-4 flex items-center gap-1 text-sm font-semibold text-white/80">
            <ChevronRight size={16} className="rotate-180" /> Geri
          </button>
          <div className="text-4xl mb-2">🔬</div>
          <h2 className="text-2xl font-extrabold text-white leading-tight">Nadir Hastalıklar</h2>
          <p className="text-sm text-white/60 mt-1">Dünyada 7.000+ nadir hastalık tanımlanmıştır. Her biri 200.000'den az kişiyi etkiler.</p>
        </div>
        <div className="flex-1 overflow-y-auto px-4 pb-6">
          <DisclaimerBanner />
          <div className="mb-4 bg-purple-50 border border-purple-200 rounded-2xl p-3 flex items-start gap-2">
            <AlertCircle size={14} className="text-purple-600 shrink-0 mt-0.5" />
            <p className="text-xs text-purple-700 leading-relaxed">Nadir hastalıklarda erken tanı hayati önem taşır. Şikayetleriniz için genetik hastalıklar uzmanına başvurun.</p>
          </div>
          <div className="space-y-3">
            {nadirHastaliklar.map((h) => (
              <div key={h.name} className="bg-card border border-border rounded-2xl p-4 shadow-sm flex items-start gap-3">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0" style={{ background: "#f0eeff" }}>{h.icon}</div>
                <div>
                  <p className="text-sm font-extrabold text-foreground">{h.name}</p>
                  <p className="text-xs text-muted-foreground mt-1 leading-relaxed">{h.desc}</p>
                  <button className="mt-2 text-xs font-bold text-purple-600 flex items-center gap-1">
                    Detay <ChevronRight size={11} />
                  </button>
                </div>
              </div>
            ))}
          </div>
          <div className="mt-4 bg-card border border-border rounded-2xl p-4 shadow-sm">
            <p className="text-xs font-extrabold text-foreground mb-2">Faydalı Kaynaklar</p>
            <div className="space-y-2">
              {["NORD — Nadir Hastalıklar Örgütü", "Orphanet Türkiye", "TÜBİTAK Nadir Hastalıklar Portalı"].map((r) => (
                <div key={r} className="flex items-center gap-2 text-xs text-primary font-semibold">
                  <ExternalLink size={11} />{r}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (selected) {
    return (
      <div className="flex flex-col h-full">
        <div
          className="px-4 pt-6 pb-8 relative"
          style={{ background: `linear-gradient(135deg, ${selected.color}22, ${selected.bg})` }}
        >
          <button
            onClick={() => { setActiveDisease(null); setExpandedFaq(null); }}
            className="mb-4 flex items-center gap-1 text-sm font-semibold"
            style={{ color: selected.color }}
          >
            <ChevronRight size={16} className="rotate-180" /> Geri
          </button>
          {(selected as any).photo ? (
            <img src={(selected as any).photo} alt={selected.name}
              className="w-24 h-24 mb-3 rounded-2xl object-cover mx-auto shadow-md" />
          ) : selected.illustration ? (
            <div className="w-20 h-20 mb-3 rounded-2xl overflow-hidden mx-auto"
              dangerouslySetInnerHTML={{ __html: selected.illustration }} />
          ) : (
            <div className="text-4xl mb-2">{selected.icon}</div>
          )}
          <h2 className="text-2xl font-extrabold text-foreground leading-tight">{selected.name}</h2>
          <p className="text-sm text-muted-foreground mt-2 leading-relaxed">{selected.desc}</p>
        </div>

        <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-4">
          <DisclaimerBanner />

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm">
            <h3 className="font-bold text-foreground mb-3 flex items-center gap-2">
              <span className="w-6 h-6 rounded-full flex items-center justify-center text-white text-xs" style={{ background: selected.color }}>!</span>
              Belirtiler
            </h3>
            <ul className="space-y-2">
              {selected.symptoms.map((s, i) => (
                <li key={i} className="flex items-center gap-2 text-sm text-foreground">
                  <CheckCircle size={14} style={{ color: selected.color }} />
                  {s}
                </li>
              ))}
            </ul>
          </div>

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm">
            <h3 className="font-bold text-foreground mb-2 flex items-center gap-2">
              <Stethoscope size={16} style={{ color: selected.color }} /> Tanı Süreci
            </h3>
            <p className="text-sm text-muted-foreground leading-relaxed">{selected.diagnosis}</p>
          </div>

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm">
            <h3 className="font-bold text-foreground mb-3 flex items-center gap-2">
              <Heart size={16} style={{ color: selected.color }} /> Destek Yolları
            </h3>
            <div className="flex flex-wrap gap-2">
              {selected.support.map((s, i) => (
                <span
                  key={i}
                  className="text-xs px-3 py-1.5 rounded-full font-semibold"
                  style={{ background: selected.bg, color: selected.color }}
                >
                  {s}
                </span>
              ))}
            </div>
          </div>

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm">
            <h3 className="font-bold text-foreground mb-3 flex items-center gap-2">
              <BookOpen size={16} style={{ color: selected.color }} /> Sık Sorulan Sorular
            </h3>
            <div className="space-y-2">
              {selected.faq.map((item, i) => (
                <div key={i} className="border border-border rounded-xl overflow-hidden">
                  <button
                    className="w-full text-left px-3 py-3 flex items-center justify-between gap-2"
                    onClick={() => setExpandedFaq(expandedFaq === i ? null : i)}
                  >
                    <span className="text-sm font-semibold text-foreground">{item.q}</span>
                    {expandedFaq === i ? <ChevronUp size={14} className="text-muted-foreground shrink-0" /> : <ChevronDown size={14} className="text-muted-foreground shrink-0" />}
                  </button>
                  {expandedFaq === i && (
                    <div className="px-3 pb-3">
                      <p className="text-sm text-muted-foreground leading-relaxed">{item.a}</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full overflow-y-auto">

      {/* Engelsiz Club başlık */}
      <div className="w-full px-4 pt-4 pb-3 flex items-center justify-between shrink-0"
        style={{ background: "linear-gradient(135deg, #0d2b1f 0%, #1a6b4a 100%)" }}>
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl overflow-hidden bg-white shrink-0 flex items-center justify-center shadow-md">
            <ImageWithFallback src={appIcon} alt="EngelsizClub" className="w-full h-full object-cover scale-150 origin-center translate-y-2" />
          </div>
          <h1 className="text-xl font-extrabold text-white leading-tight tracking-tight">Engelsiz Club</h1>
        </div>
        <div className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
          style={{ background: "rgba(255,255,255,0.12)" }}>
          <span className="text-xl">🦸</span>
        </div>
      </div>

      {/* Hero photo slider */}
      <div className="relative w-full shrink-0 overflow-hidden" style={{ height: 260 }}>
        {heroSlides.map((slide, i) => (
          <div key={i} className="absolute inset-0 transition-opacity duration-700"
            style={{ opacity: i === heroIdx ? 1 : 0 }}>
            <ImageWithFallback
              src={slide.src}
              alt={slide.alt}
              className="w-full h-full object-cover scale-150 origin-center translate-y-2"
            />
          </div>
        ))}

        {/* Dark gradient overlay */}
        <div className="absolute inset-0 pointer-events-none"
          style={{ background: "linear-gradient(to bottom, rgba(13,43,31,0.18) 0%, rgba(13,43,31,0.72) 100%)" }} />

        {/* Text */}
        <div className="absolute bottom-0 left-0 right-0 px-4 pb-4">
          <div className="flex items-center gap-1.5 mb-1">
            <span className="text-base">👋</span>
            <p className="text-xs font-semibold text-white/80">Hoş geldiniz</p>
          </div>
          <h1 className="text-xl font-extrabold text-white leading-snug">
            Destek, bilgi ve<br />topluluk bir arada
          </h1>
          <div className="flex items-center gap-2 mt-2">
            <div className="flex items-center gap-1.5 bg-white/20 backdrop-blur-sm rounded-full px-3 py-1">
              <Users size={12} className="text-white" />
              <span className="text-xs font-extrabold text-white">4.200+ Aile</span>
            </div>
            <div className="flex items-center gap-1.5 bg-white/20 backdrop-blur-sm rounded-full px-3 py-1">
              <BadgeCheck size={12} className="text-white" />
              <span className="text-xs font-extrabold text-white">Uzman Onaylı</span>
            </div>
          </div>
        </div>

        {/* Dot indicators */}
        <div className="absolute bottom-3 right-4 flex items-center gap-1.5">
          {heroSlides.map((_, i) => (
            <button key={i} onClick={() => setHeroIdx(i)}
              className="rounded-full transition-all"
              style={{
                width: i === heroIdx ? 16 : 6,
                height: 6,
                background: i === heroIdx ? "#fff" : "rgba(255,255,255,0.45)",
              }} />
          ))}
        </div>
      </div>

      {/* PubMed search bar — below photo */}
      <div className="px-4 pt-4 pb-3 bg-background">
        <PubMedSearchBar placeholder="Hastalık veya tedavi araştır (PubMed)..." />
      </div>

      <DisclaimerBanner />

      {/* Disease library */}
      <div className="px-4 mb-6">
        <h2 className="text-base font-extrabold text-foreground mb-3">Hastalıklar & Durumlar</h2>
        <div className="grid grid-cols-2 gap-3">
          {diseases.map((d) => (
            <button
              key={d.id}
              onClick={() => setActiveDisease(d.id)}
              className="bg-card border border-border rounded-2xl p-3 text-left shadow-sm hover:shadow-md transition-shadow active:scale-[0.98] overflow-hidden"
            >
              {(d as any).photo ? (
                <img src={(d as any).photo} alt={d.name}
                  className="w-full h-20 mb-2 rounded-xl object-cover" />
              ) : d.illustration ? (
                <div className="w-full h-20 mb-2 rounded-xl overflow-hidden flex items-center justify-center"
                  style={{ background: d.bg }}
                  dangerouslySetInnerHTML={{ __html: d.illustration }}
                />
              ) : (
                <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl mb-3" style={{ background: d.bg }}>
                  {d.icon}
                </div>
              )}
              <p className="text-sm font-bold text-foreground leading-tight">{d.name}</p>
              <div className="mt-1.5 flex items-center gap-1" style={{ color: d.color }}>
                <span className="text-xs font-semibold">Daha fazla</span>
                <ChevronRight size={12} />
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Upcoming feature teaser */}
      <div className="mx-4 mb-6 rounded-2xl overflow-hidden border border-primary/20 bg-primary/5">
        <div className="p-4">
          <div className="flex items-center gap-2 mb-2">
            <Shield size={16} className="text-primary" />
            <span className="text-xs font-bold text-primary uppercase tracking-wide">Yakında</span>
          </div>
          <p className="text-sm font-bold text-foreground">Uzman Canlı Danışmanlık</p>
          <p className="text-xs text-muted-foreground mt-1">Çocuk psikiyatristi ve terapistlerle video görüşmesi yapın.</p>
          <button className="mt-3 text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full">Bildirim Al</button>
        </div>
      </div>
    </div>
  );
}

function ForumTab() {
  const [selectedPost, setSelectedPost] = useState<typeof forumPosts[0] | null>(null);
  const [newPost, setNewPost] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState("Tümü");

  const categoryColors: Record<string, string> = {
    Otizm: "#5b8dd9",
    Uzman: "#1a6b4a",
    "Serebral Palsi": "#1a6b4a",
    DEHB: "#6b9ac4",
  };

  if (newPost) {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="px-4 pt-6 pb-4 flex items-center gap-3">
          <button onClick={() => setNewPost(false)}>
            <ChevronRight size={20} className="rotate-180 text-primary" />
          </button>
          <h2 className="text-lg font-extrabold text-foreground">Yeni Gönderi</h2>
        </div>
        <div className="px-4 space-y-4">
          <div>
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Kategori</label>
            <select className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm text-foreground">
              {["Otizm", "Serebral Palsi", "Down Sendromu", "DEHB", "Genel", "İkinci El Ürün"].map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Başlık</label>
            <input
              className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground"
              placeholder="Paylaşmak istediğiniz konuyu yazın..."
            />
          </div>
          <div>
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">İçerik</label>
            <textarea
              rows={5}
              className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground resize-none"
              placeholder="Deneyimlerinizi veya sorunuzu paylaşın..."
            />
          </div>
          <div className="flex items-center gap-2 bg-muted rounded-xl px-3 py-2.5">
            <input type="checkbox" id="anon" className="rounded" />
            <label htmlFor="anon" className="text-sm text-foreground">Anonim paylaş</label>
          </div>
          <div className="bg-amber-50 rounded-xl p-3 border border-amber-200">
            <p className="text-xs text-amber-700">
              <strong>Topluluk Kuralları:</strong> Tıbbi tavsiye vermekten kaçının, diğer üyelere saygılı olun, mahremiyet haklarına dikkat edin.
            </p>
          </div>
          <button className="w-full py-3.5 rounded-2xl font-bold text-sm bg-primary text-primary-foreground shadow-sm">
            Paylaş
          </button>
        </div>
      </div>
    );
  }

  if (selectedPost) {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="px-4 pt-6 pb-4">
          <button onClick={() => setSelectedPost(null)} className="flex items-center gap-1 text-sm font-semibold text-primary mb-4">
            <ChevronRight size={16} className="rotate-180" /> Geri
          </button>
          <div className="flex items-center gap-2 mb-3">
            <div
              className="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-bold shrink-0"
              style={{ background: selectedPost.avatarColor }}
            >
              {selectedPost.avatar}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <p className="text-sm font-bold text-foreground">{selectedPost.author}</p>
                {selectedPost.expert && (
                  <span className="text-xs px-2 py-0.5 rounded-full bg-primary text-primary-foreground font-bold">Uzman</span>
                )}
              </div>
              <p className="text-xs text-muted-foreground">{selectedPost.time}</p>
            </div>
          </div>
          <span
            className="text-xs font-bold px-2 py-1 rounded-full text-white mb-3 inline-block"
            style={{ background: categoryColors[selectedPost.category] || "#1a6b4a" }}
          >
            {selectedPost.category}
          </span>
          <h2 className="text-lg font-extrabold text-foreground mt-2">{selectedPost.title}</h2>
          <p className="text-sm text-foreground/80 mt-3 leading-relaxed">{selectedPost.content}</p>
          <div className="flex items-center gap-4 mt-4 pb-4 border-b border-border">
            <button className="flex items-center gap-1.5 text-sm text-muted-foreground">
              <ThumbsUp size={16} /> {selectedPost.likes}
            </button>
            <button className="flex items-center gap-1.5 text-sm text-muted-foreground">
              <MessageSquare size={16} /> {selectedPost.comments}
            </button>
          </div>
        </div>
        <div className="px-4 pb-4">
          <p className="text-sm font-bold text-foreground mb-3">Yorumlar</p>
          {[
            { name: "Zeynep A.", text: "Bizim için de çok faydalı oldu, teşekkürler!", time: "1 saat önce", color: "#f4a832" },
            { name: "Ali R.", text: "Hangi merkezde ABA terapisi aldınız?", time: "3 saat önce", color: "#5ba882" },
          ].map((c, i) => (
            <div key={i} className="flex gap-3 mb-4">
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0"
                style={{ background: c.color }}>
                {c.name.split(" ").map(n => n[0]).join("")}
              </div>
              <div className="bg-muted rounded-2xl px-3 py-2 flex-1">
                <p className="text-xs font-bold text-foreground">{c.name}</p>
                <p className="text-xs text-foreground/80 mt-0.5">{c.text}</p>
                <p className="text-xs text-muted-foreground mt-1">{c.time}</p>
              </div>
            </div>
          ))}
          <div className="flex gap-2 mt-2">
            <input
              className="flex-1 bg-card border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground"
              placeholder="Yorum yaz..."
            />
            <button className="px-4 py-2.5 rounded-xl bg-primary text-primary-foreground text-sm font-bold">Gönder</button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-6 pb-4 flex items-center justify-between">
        <div>
          <h2 className="text-xl font-extrabold text-foreground">Topluluk</h2>
          <p className="text-sm text-muted-foreground">Aileler birbirini destekliyor</p>
        </div>
        <button
          onClick={() => setNewPost(true)}
          className="px-3 py-2 rounded-xl bg-primary text-primary-foreground text-xs font-bold shadow-sm"
        >
          + Paylaş
        </button>
      </div>

      {/* Search bar */}
      <div className="px-4 mb-3">
        <div className="flex items-center gap-2 bg-card border border-border rounded-xl px-3 py-2.5 shadow-sm">
          <Search size={15} className="text-muted-foreground shrink-0" />
          <input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Konularda ara..."
            className="flex-1 bg-transparent text-sm text-foreground placeholder:text-muted-foreground outline-none"
          />
          {searchQuery && (
            <button onClick={() => setSearchQuery("")} className="text-muted-foreground">
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Topic chips */}
      <div className="flex gap-2 px-4 mb-4 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {["Tümü", "Otizm", "Serebral Palsi", "DEHB", "Uzman", "İkinci El"].map((cat) => (
          <span
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold cursor-pointer transition-colors"
            style={
              cat === activeCategory
                ? { background: "#1a6b4a", color: "#fff" }
                : { background: "#dceee4", color: "#4d7a62" }
            }
          >
            {cat}
          </span>
        ))}
      </div>

      <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-3">
        {(() => {
          const q = searchQuery.trim().toLowerCase();
          const filtered = forumPosts.filter((p) => {
            const matchesCat = activeCategory === "Tümü" || p.category === activeCategory;
            const matchesQ = !q || [p.title, p.content, p.author, p.category].some((f) =>
              f.toLowerCase().includes(q)
            );
            return matchesCat && matchesQ;
          });

          if (filtered.length === 0) {
            return (
              <div className="flex flex-col items-center justify-center py-16 text-center">
                <div className="w-14 h-14 rounded-full bg-muted flex items-center justify-center mb-4">
                  <Search size={24} className="text-muted-foreground" />
                </div>
                <p className="text-sm font-bold text-foreground mb-1">Sonuç bulunamadı</p>
                <p className="text-xs text-muted-foreground leading-relaxed">
                  &quot;{searchQuery}&quot; için eşleşen konu yok.<br />Farklı bir kelime deneyin.
                </p>
              </div>
            );
          }

          return filtered.map((post) => (
            <button
              key={post.id}
              onClick={() => setSelectedPost(post)}
              className="w-full bg-card border border-border rounded-2xl p-4 shadow-sm text-left hover:shadow-md transition-shadow active:scale-[0.99]"
            >
              {post.pinned && (
                <div className="flex items-center gap-1 mb-2">
                  <Shield size={11} className="text-primary" />
                  <span className="text-xs font-bold text-primary">Öne Çıkan</span>
                </div>
              )}
              <div className="flex items-center gap-2 mb-2">
                <div
                  className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0"
                  style={{ background: post.avatarColor }}
                >
                  {post.avatar}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <p className="text-xs font-bold text-foreground">{post.author}</p>
                    {post.expert && (
                      <span className="text-xs px-1.5 py-0.5 rounded-full bg-primary/10 text-primary font-bold">Uzman</span>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground">{post.time}</p>
                </div>
                <span
                  className="text-xs font-bold px-2 py-0.5 rounded-full text-white shrink-0"
                  style={{ background: categoryColors[post.category] || "#1a6b4a" }}
                >
                  {post.category}
                </span>
              </div>
              <p className="text-sm font-bold text-foreground">{post.title}</p>
              <p className="text-xs text-muted-foreground mt-1 leading-relaxed line-clamp-2">{post.content}</p>
              <div className="flex items-center gap-4 mt-3">
                <span className="flex items-center gap-1 text-xs text-muted-foreground">
                  <ThumbsUp size={12} /> {post.likes}
                </span>
                <span className="flex items-center gap-1 text-xs text-muted-foreground">
                  <MessageCircle size={12} /> {post.comments}
                </span>
              </div>
            </button>
          ));
        })()}
      </div>
    </div>
  );
}

function IletisimModal({ onClose }: { onClose: () => void }) {
  const [type, setType]       = useState<"dilek" | "sikayet" | "oneri" | "diger">("dilek");
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("");
  const [sent, setSent]       = useState(false);

  const types = [
    { id: "dilek",   label: "Dilek",    emoji: "🌟" },
    { id: "sikayet", label: "Şikayet",  emoji: "⚠️" },
    { id: "oneri",   label: "Öneri",    emoji: "💡" },
    { id: "diger",   label: "Diğer",    emoji: "📝" },
  ] as const;

  function handleSend() {
    if (!subject.trim() || !message.trim()) return;
    setSent(true);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center" style={{ background: "rgba(0,0,0,0.45)" }} onClick={onClose}>
      <div className="w-full max-w-sm bg-card rounded-t-3xl shadow-2xl pb-safe" onClick={(e) => e.stopPropagation()}>
        {/* Tutamaç */}
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-border" />
        </div>

        {/* Başlık */}
        <div className="flex items-center justify-between px-5 pt-2 pb-4 border-b border-border">
          <div>
            <p className="font-extrabold text-foreground">İletişim</p>
            <p className="text-xs text-muted-foreground mt-0.5">Dilek, şikayet ve önerilerinizi iletin</p>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
            <X size={15} className="text-muted-foreground" />
          </button>
        </div>

        {sent ? (
          <div className="flex flex-col items-center gap-3 py-12 px-6 text-center">
            <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center text-3xl">✅</div>
            <p className="font-extrabold text-foreground">İletildi!</p>
            <p className="text-sm text-muted-foreground">Mesajınız ekibimize ulaştı. En kısa sürede dönüş yapacağız.</p>
            <button onClick={onClose}
              className="mt-2 px-6 py-2.5 rounded-2xl text-sm font-extrabold text-primary-foreground"
              style={{ background: "#1a6b4a" }}>
              Kapat
            </button>
          </div>
        ) : (
          <div className="px-5 pt-4 pb-6 space-y-4 overflow-y-auto max-h-[70vh]">
            {/* Tür seçimi */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-2">Mesaj Türü</p>
              <div className="grid grid-cols-4 gap-2">
                {types.map((t) => (
                  <button key={t.id} onClick={() => setType(t.id)}
                    className="flex flex-col items-center gap-1 py-2.5 rounded-2xl text-xs font-bold border-2 transition-all"
                    style={type === t.id
                      ? { borderColor: "#1a6b4a", background: "#dceee4", color: "#1a6b4a" }
                      : { borderColor: "transparent", background: "var(--muted)", color: "var(--muted-foreground)" }}>
                    <span className="text-lg">{t.emoji}</span>
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Konu */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Konu <span className="text-red-400">*</span></p>
              <input
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="Kısaca konuyu yazın..."
                maxLength={80}
                className="w-full bg-muted border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors"
              />
            </div>

            {/* Mesaj */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Mesajınız <span className="text-red-400">*</span></p>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Detaylı olarak açıklayın..."
                rows={5}
                maxLength={1000}
                className="w-full bg-muted border border-border rounded-xl px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors resize-none"
              />
              <p className="text-[10px] text-muted-foreground text-right mt-0.5">{message.length} / 1000</p>
            </div>

            {/* İletişim bilgisi notu */}
            <div className="flex items-start gap-2 bg-primary/8 rounded-xl px-3 py-2.5">
              <span className="text-sm mt-0.5">📧</span>
              <p className="text-[11px] text-primary/80 leading-relaxed">
                Yanıt için hesabınızdaki e-posta adresiniz kullanılacaktır. Lütfen güncel tutun.
              </p>
            </div>

            {/* Gönder */}
            <button
              onClick={handleSend}
              disabled={!subject.trim() || !message.trim()}
              className="w-full py-3.5 rounded-2xl text-sm font-extrabold text-primary-foreground disabled:opacity-40 transition-opacity"
              style={{ background: "#1a6b4a" }}>
              Gönder
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function AileProfilSection({ user, initials, onLogout }: { user: { name: string; email: string; avatarColor: string; userType: string }; initials: string; onLogout: () => void }) {
  const [showIletisim, setShowIletisim] = useState(false);
  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {showIletisim && <IletisimModal onClose={() => setShowIletisim(false)} />}

      {/* Profil başlığı */}
      <div className="px-6 pt-8 pb-6 flex flex-col items-center text-center"
        style={{ background: "linear-gradient(160deg, #e8f5ee 0%, #f2f7f4 100%)" }}>
        <div className="w-20 h-20 rounded-3xl flex items-center justify-center text-2xl font-extrabold text-white shadow-lg mb-3"
          style={{ background: user.avatarColor }}>{initials}</div>
        <p className="text-xl font-extrabold text-foreground">{user.name}</p>
        <div className="flex items-center gap-1.5 mt-1">
          <GoogleIcon size={13} />
          <p className="text-xs text-muted-foreground">{user.email}</p>
        </div>
        <div className="flex items-center gap-2 mt-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-primary/10">
            <BadgeCheck size={13} className="text-primary" />
            <span className="text-xs font-bold text-primary">Google ile doğrulandı</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-50">
            <span className="text-xs">👨‍👩‍👧</span>
            <span className="text-xs font-bold text-amber-700">Aile</span>
          </div>
        </div>
      </div>

      {/* İstatistikler */}
      <div className="px-6 py-4 grid grid-cols-3 gap-3">
        {[{ val: "3", label: "Kredi" }, { val: "2", label: "İlan" }, { val: "8", label: "Favori" }].map((s) => (
          <div key={s.label} className="bg-card border border-border rounded-2xl p-3 text-center shadow-sm">
            <p className="text-xl font-extrabold text-primary">{s.val}</p>
            <p className="text-xs text-muted-foreground">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Menü öğeleri */}
      <div className="px-6 space-y-2 pb-6">
        {[
          { emoji: "👶", label: "Çocuk Profilim", sub: "Tanı ve gelişim bilgileri" },
          { emoji: "📋", label: "İlanlarım", sub: "2 aktif ilan" },
          { emoji: "❤️", label: "Kaydedilenler", sub: "8 ilan favorilendi" },
          { emoji: "🪙", label: "Kredilerim", sub: "3 kredi · Satın Al" },
          { emoji: "🔔", label: "Bildirimler", sub: "Açık" },
          { emoji: "🔒", label: "Gizlilik & Güvenlik", sub: "Ayarlarınız" },
        ].map((item) => (
          <button key={item.label}
            className="w-full flex items-center gap-4 bg-card border border-border rounded-2xl px-4 py-3.5 text-left shadow-sm">
            <span className="text-xl shrink-0">{item.emoji}</span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-extrabold text-foreground">{item.label}</p>
              <p className="text-xs text-muted-foreground">{item.sub}</p>
            </div>
            <ChevronRight size={16} className="text-muted-foreground shrink-0" />
          </button>
        ))}

        {/* Dilek, Şikayet & Öneri */}
        <button
          onClick={() => setShowIletisim(true)}
          className="w-full flex items-center gap-4 border-2 rounded-2xl px-4 py-3.5 text-left shadow-sm"
          style={{ background: "linear-gradient(135deg, #f0faf5, #e8f5ee)", borderColor: "#1a6b4a55" }}>
          <span className="text-xl shrink-0">💬</span>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-extrabold text-foreground">Dilek, Şikayet & Öneri</p>
            <p className="text-xs text-muted-foreground">Görüşlerinizi ekibimizle paylaşın</p>
          </div>
          <ChevronRight size={16} className="text-primary shrink-0" />
        </button>

        <button onClick={onLogout}
          className="w-full flex items-center gap-4 bg-red-50 border border-red-100 rounded-2xl px-4 py-3.5 text-left shadow-sm mt-2">
          <span className="text-xl shrink-0">🚪</span>
          <p className="text-sm font-extrabold text-red-600">Çıkış Yap</p>
        </button>
      </div>
    </div>
  );
}

function ProfilTab() {
  const [showIletisim, setShowIletisim] = useState(false);

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {showIletisim && <IletisimModal onClose={() => setShowIletisim(false)} />}

      <div className="px-4 pt-6 pb-4">
        <h2 className="text-xl font-extrabold text-foreground mb-4">Profilim</h2>
        <div className="bg-card border border-border rounded-2xl p-5 shadow-sm flex items-center gap-4 mb-4">
          <div className="w-16 h-16 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-2xl font-extrabold shrink-0">
            AK
          </div>
          <div>
            <p className="font-extrabold text-foreground">Ayşe Karataş</p>
            <p className="text-xs text-muted-foreground mt-0.5">İstanbul · Ebeveyn</p>
            <div className="flex gap-2 mt-2">
              <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-semibold">Otizm</span>
              <span className="text-xs px-2 py-0.5 rounded-full bg-secondary text-secondary-foreground font-semibold">DEHB</span>
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 space-y-3 pb-6">
        {[
          { label: "Çocuk Profilim", icon: Users, desc: "Tanı ve gelişim bilgileri" },
          { label: "Kayıtlı Merkezler", icon: MapPin, desc: "3 merkez kayıtlı" },
          { label: "Forum Gönderilerim", icon: MessageSquare, desc: "12 gönderi" },
          { label: "Bildirimler", icon: AlertCircle, desc: "Etkin" },
          { label: "Gizlilik & Güvenlik", icon: Shield, desc: "Profil gizli · Verileriniz şifreli" },
        ].map((item) => (
          <div key={item.label} className="bg-card border border-border rounded-2xl px-4 py-3.5 shadow-sm flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center">
                <item.icon size={16} className="text-primary" />
              </div>
              <div>
                <p className="text-sm font-bold text-foreground">{item.label}</p>
                <p className="text-xs text-muted-foreground">{item.desc}</p>
              </div>
            </div>
            <ChevronRight size={16} className="text-muted-foreground" />
          </div>
        ))}

        {/* İletişim / Dilek & Şikayet */}
        <button
          onClick={() => setShowIletisim(true)}
          className="w-full bg-card border-2 border-primary/30 rounded-2xl px-4 py-4 shadow-sm flex items-center justify-between"
          style={{ background: "linear-gradient(135deg, #f0faf5, #e8f5ee)" }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0"
              style={{ background: "#1a6b4a20" }}>
              💬
            </div>
            <div className="text-left">
              <p className="text-sm font-extrabold text-foreground">Dilek, Şikayet & Öneri</p>
              <p className="text-xs text-muted-foreground mt-0.5">Görüşlerinizi ekibimizle paylaşın</p>
            </div>
          </div>
          <ChevronRight size={16} className="text-primary" />
        </button>

        <div className="bg-muted rounded-2xl p-4 mt-2">
          <p className="text-xs text-muted-foreground text-center">
            EngelsizClub v1.0 · Tıbbi bilgiler yalnızca bilgilendirme amaçlıdır.<br />
            <span className="text-primary font-semibold">Gizlilik Politikası</span> · <span className="text-primary font-semibold">Kullanım Şartları</span>
          </p>
        </div>
      </div>
    </div>
  );
}

function HaklarTab() {
  const [showWizard, setShowWizard] = useState(false);
  const [activeCategory, setActiveCategory] = useState("tümü");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const cats = [
    { id: "tümü", label: "Tümü", icon: "📋" }, { id: "maddi", label: "Maddi", icon: "💰" },
    { id: "vergi", label: "Vergi & Araç", icon: "🚗" }, { id: "egitim", label: "Eğitim", icon: "📚" },
    { id: "ulasim", label: "Ulaşım", icon: "🚌" },
  ];
  const filtered = activeCategory === "tümü" ? allRights : allRights.filter((r) => r.category === activeCategory);
  return (
    <div className="flex flex-col h-full relative">
      {showWizard && <RightsSihirbazi onClose={() => setShowWizard(false)} />}
      <div className="px-4 pt-6 pb-3">
        <h2 className="text-xl font-extrabold text-foreground mb-0.5">Devlet Destekleri</h2>
        <p className="text-xs text-muted-foreground">Yasal haklar, maaşlar ve başvuru rehberleri</p>
      </div>
      <div className="mx-4 mb-4 rounded-2xl overflow-hidden shadow-md" style={{ background: "linear-gradient(135deg, #1a6b4a, #1a5c51)" }}>
        <div className="p-4 flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-white/15 flex items-center justify-center shrink-0"><Wand2 size={28} className="text-white" /></div>
          <div className="flex-1">
            <p className="text-white font-extrabold text-sm">Hak Sorgulama Sihirbazı</p>
            <p className="text-white/70 text-xs mt-0.5">3 soruya yanıt verin — size özel haklar listelensin</p>
          </div>
        </div>
        <button onClick={() => setShowWizard(true)} className="w-full py-3 bg-white/15 text-white text-sm font-extrabold flex items-center justify-center gap-2 border-t border-white/20 hover:bg-white/25 transition-colors">
          Sihirbazı Başlat <ArrowRight size={16} />
        </button>
      </div>
      <div className="flex gap-2 px-4 mb-4 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {cats.map((cat) => (
          <button key={cat.id} onClick={() => setActiveCategory(cat.id)}
            className="shrink-0 flex items-center gap-1.5 px-3.5 py-2 rounded-2xl text-xs font-bold transition-all"
            style={activeCategory === cat.id ? { background: "#1a6b4a", color: "#fff", boxShadow: "0 2px 8px #1a6b4a44" } : { background: "#dceee4", color: "#4d7a62" }}>
            {cat.icon} {cat.label}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-3">
        {filtered.map((r) => (
          <div key={r.id} className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm">
            <button className="w-full flex items-center gap-3 p-4 text-left" onClick={() => setExpandedId(expandedId === r.id ? null : r.id)}>
              <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0" style={{ background: r.bg }}>{r.icon}</div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-extrabold text-foreground">{r.title}</p>
                <p className="text-xs font-bold mt-0.5" style={{ color: r.color }}>{r.amount}</p>
              </div>
              {expandedId === r.id ? <ChevronUp size={16} className="text-muted-foreground shrink-0" /> : <ChevronDown size={16} className="text-muted-foreground shrink-0" />}
            </button>
            {expandedId === r.id && (
              <div className="px-4 pb-4 border-t border-border">
                <div className="mt-3 mb-3 space-y-1.5">
                  {r.desc.split("\n\n").map((para, pi) => (
                    <p key={pi} className="text-xs text-muted-foreground leading-relaxed">{para}</p>
                  ))}
                </div>
                <p className="text-xs font-extrabold text-foreground mb-2">Başvuru Adımları:</p>
                <ol className="space-y-2 mb-3">
                  {r.steps.map((s, i) => (
                    <li key={i} className="flex items-start gap-2.5 text-xs text-foreground/80">
                      <span className="w-5 h-5 rounded-full text-white flex items-center justify-center shrink-0 font-extrabold" style={{ background: r.color, fontSize: 10 }}>{i + 1}</span>{s}
                    </li>
                  ))}
                </ol>
                <div className="flex items-center gap-2 rounded-xl px-3 py-2.5 text-xs font-bold" style={{ background: r.bg, color: r.color }}>
                  <FileText size={12} />{r.where}
                </div>
              </div>
            )}
          </div>
        ))}
        <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4">
          <div className="flex items-start gap-2">
            <AlertCircle size={14} className="text-amber-600 shrink-0 mt-0.5" />
            <p className="text-xs text-amber-700 leading-relaxed">Belirtilen tutarlar yaklaşık değerlerdir. Güncel miktarlar için resmi kurum web sitelerine başvurun.</p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── İLANLAR TAB ─────────────────────────────────────────────────────────────

type IlanKategori = "uzmanlar" | "bakici" | "ikinciel";

function StarRow({ rating, size = 14 }: { rating: number; size?: number }) {
  return (
    <span className="flex items-center gap-0.5">
      {[1,2,3,4,5].map((s) => (
        <svg key={s} width={size} height={size} viewBox="0 0 24 24" fill={s <= Math.round(rating) ? "#f4a832" : "#e5e0d8"}>
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
        </svg>
      ))}
    </span>
  );
}

function RatingBreakdown({ reviews }: { reviews: IlanReview[] }) {
  const counts = [5,4,3,2,1].map((s) => ({ star: s, count: reviews.filter((r) => r.rating === s).length }));
  const max = Math.max(...counts.map((c) => c.count), 1);
  return (
    <div className="space-y-1">
      {counts.map(({ star, count }) => (
        <div key={star} className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground w-3 text-right">{star}</span>
          <svg width={10} height={10} viewBox="0 0 24 24" fill="#f4a832"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
          <div className="flex-1 h-1.5 rounded-full bg-muted overflow-hidden">
            <div className="h-full rounded-full bg-amber-400 transition-all" style={{ width: `${(count / max) * 100}%` }} />
          </div>
          <span className="text-xs text-muted-foreground w-3">{count}</span>
        </div>
      ))}
    </div>
  );
}

function ProfilDrawer({ poster, onClose, onKrediTap, ctaLabel }: {
  poster: IlanPoster; onClose: () => void; onKrediTap: () => void; ctaLabel: string;
}) {
  const [yorumYaz, setYorumYaz] = useState(false);
  const [myRating, setMyRating] = useState(0);
  const [myText, setMyText] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [localReviews, setLocalReviews] = useState<IlanReview[]>(poster.reviews);

  function submitReview() {
    if (myRating === 0 || myText.trim() === "") return;
    const newR: IlanReview = { author: "Sen", avatar: "BN", avatarColor: "#1a6b4a", rating: myRating, date: "Az önce", text: myText.trim() };
    setLocalReviews((p) => [newR, ...p]);
    setSubmitted(true);
    setYorumYaz(false);
  }

  const avgRating = localReviews.length ? (localReviews.reduce((s, r) => s + r.rating, 0) / localReviews.length) : poster.rating;

  return (
    <div className="absolute inset-0 z-40 flex items-end bg-black/50" onClick={onClose}>
      <div className="w-full bg-card rounded-t-3xl max-h-[88%] flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="w-10 h-1 rounded-full bg-muted mx-auto mt-3 mb-1 shrink-0" />

        <div className="overflow-y-auto flex-1 px-5 pb-4">
          {/* Profile header */}
          <div className="flex items-center gap-4 pt-3 pb-4 border-b border-border">
            <div className="relative shrink-0">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-xl font-extrabold text-white"
                style={{ background: poster.avatarColor }}>{poster.avatar}</div>
              <span className="absolute -bottom-1.5 -right-1.5 text-sm bg-white rounded-full shadow px-1">🏠</span>
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p className="font-extrabold text-foreground text-base">{poster.name}</p>
                <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-blue-50 text-blue-600 border border-blue-100">Aile</span>
              </div>
              <div className="flex items-center gap-1.5 mt-0.5">
                <StarRow rating={avgRating} size={13} />
                <span className="text-xs font-bold text-foreground">{avgRating.toFixed(1)}</span>
                <span className="text-xs text-muted-foreground">({localReviews.length} uzman yorumu)</span>
              </div>
              <div className="flex flex-wrap gap-1 mt-1.5">
                {poster.tags.map((t) => (
                  <span key={t} className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground font-semibold">{t}</span>
                ))}
              </div>
            </div>
          </div>

          {/* Bio */}
          <div className="py-4 border-b border-border">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-1.5">Aile Hakkında</p>
            <p className="text-sm text-foreground leading-relaxed">{poster.bio}</p>
          </div>

          {/* Rating breakdown */}
          <div className="py-4 border-b border-border">
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Puan Dağılımı</p>
              <div className="flex items-center gap-1">
                <span className="text-2xl font-extrabold text-foreground">{avgRating.toFixed(1)}</span>
                <span className="text-xs text-muted-foreground">/ 5</span>
              </div>
            </div>
            <RatingBreakdown reviews={localReviews} />
          </div>

          {/* Reviews */}
          <div className="pt-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Yorumlar</p>
              {!yorumYaz && !submitted && (
                <button onClick={() => setYorumYaz(true)}
                  className="text-xs font-extrabold text-primary bg-primary/10 px-3 py-1.5 rounded-full">+ Yorum Yaz</button>
              )}
              {submitted && <span className="text-xs font-bold text-green-600">✓ Yorumunuz eklendi</span>}
            </div>

            {yorumYaz && (
              <div className="bg-muted rounded-2xl p-4 mb-4 space-y-3">
                <p className="text-xs font-bold text-foreground">Puanınız</p>
                <div className="flex items-center gap-1">
                  {[1,2,3,4,5].map((s) => (
                    <button key={s} onClick={() => setMyRating(s)}>
                      <svg width={28} height={28} viewBox="0 0 24 24" fill={s <= myRating ? "#f4a832" : "#e5e0d8"}>
                        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                      </svg>
                    </button>
                  ))}
                </div>
                <textarea rows={3} value={myText} onChange={(e) => setMyText(e.target.value)}
                  className="w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground resize-none"
                  placeholder="Deneyiminizi paylaşın..." />
                <div className="flex gap-2">
                  <button onClick={submitReview}
                    className="flex-1 py-2.5 rounded-xl bg-primary text-primary-foreground font-extrabold text-xs">Gönder</button>
                  <button onClick={() => setYorumYaz(false)}
                    className="px-4 py-2.5 rounded-xl bg-card border border-border font-bold text-xs text-muted-foreground">İptal</button>
                </div>
              </div>
            )}

            <div className="space-y-3">
              {localReviews.map((r, i) => (
                <div key={i} className="bg-muted/60 rounded-2xl p-3.5">
                  <div className="flex items-center gap-2.5 mb-2">
                    <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-extrabold text-white shrink-0"
                      style={{ background: r.avatarColor }}>{r.avatar}</div>
                    <div>
                      <p className="text-xs font-extrabold text-foreground">{r.author}</p>
                      <div className="flex items-center gap-1">
                        <StarRow rating={r.rating} size={11} />
                        <span className="text-xs text-muted-foreground">{r.date}</span>
                      </div>
                    </div>
                  </div>
                  <p className="text-xs text-foreground leading-relaxed">{r.text}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Sticky CTA */}
        <div className="px-5 pb-5 pt-3 border-t border-border shrink-0">
          <button onClick={() => { onClose(); onKrediTap(); }}
            className="w-full py-4 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm flex items-center justify-center gap-2 shadow-lg">
            <Coins size={16} /> {ctaLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

function KrediModal({ onClose, onUnlocked, userKredi = 0 }: { onClose: () => void; onUnlocked?: () => void; userKredi?: number }) {
  const [unlocked, setUnlocked] = useState(false);
  const hasCredit = userKredi >= 1;

  function handleUnlock() {
    if (!hasCredit) return;
    setUnlocked(true);
  }

  if (unlocked) return (
    <div className="absolute inset-0 z-50 flex items-end bg-black/40">
      <div className="w-full bg-card rounded-t-3xl p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center"><CheckCircle size={24} className="text-green-600" /></div>
          <div>
            <p className="font-extrabold text-foreground">Teklif Gönderildi!</p>
            <p className="text-xs text-muted-foreground">1 kredi harcandı · Sohbet hazır</p>
          </div>
        </div>
        <div className="bg-muted rounded-2xl p-4 mb-4 space-y-2">
          <div className="flex items-center gap-2"><MessageSquare size={14} className="text-primary" /><p className="text-sm font-bold text-foreground">Karşı taraf bilgilendirildi</p></div>
          <div className="flex items-center gap-2"><MessageCircle size={14} className="text-primary" /><p className="text-sm text-foreground">Sohbeti başlatmak için devam edin</p></div>
        </div>
        <button
          onClick={() => { if (onUnlocked) onUnlocked(); else onClose(); }}
          className="w-full py-3.5 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm flex items-center justify-center gap-2">
          <MessageCircle size={16} /> Sohbete Git
        </button>
      </div>
    </div>
  );

  return (
    <div className="absolute inset-0 z-50 flex items-end bg-black/40" onClick={onClose}>
      <div className="w-full bg-card rounded-t-3xl p-6" onClick={(e) => e.stopPropagation()}>
        <div className="w-10 h-1 rounded-full bg-muted mx-auto mb-5" />
        <div className="flex items-center justify-between mb-5">
          <div>
            <p className="text-lg font-extrabold text-foreground">İletişim Bilgisini Aç</p>
            <p className="text-xs text-muted-foreground mt-0.5">1 kredi harcayarak iletişim bilgisine ulaş</p>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-100">
            <Coins size={14} className="text-amber-600" />
            <span className="text-sm font-extrabold text-amber-700">{userKredi} kredi</span>
          </div>
        </div>
        <div className="bg-muted rounded-2xl p-4 mb-4">
          <p className="text-xs font-bold text-foreground mb-3">Açıldığında ne görürsünüz:</p>
          <div className="space-y-2">
            {[
              { icon: Phone, label: "Telefon numarası" },
              { icon: MessageSquare, label: "E-posta adresi" },
              { icon: MapPinned, label: "Kesin adres / semt" },
              { icon: CalendarDays, label: "Uygun saat bilgisi" },
            ].map((item) => (
              <div key={item.label} className="flex items-center gap-2 text-xs text-foreground">
                <item.icon size={13} className="text-primary shrink-0" />{item.label}
              </div>
            ))}
          </div>
        </div>
        {!hasCredit && (
          <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-2xl px-4 py-3 mb-3">
            <span className="text-base">⚠️</span>
            <p className="text-xs text-red-700 font-semibold">Krediniz yetersiz. Teklif vermek için kredi yükleyin.<br/><span className="font-normal">1 kredi = ₺49,90</span></p>
          </div>
        )}
        <button onClick={handleUnlock} disabled={!hasCredit}
          className="w-full py-4 rounded-2xl font-extrabold text-base flex items-center justify-center gap-2 shadow-lg mb-3 disabled:opacity-50 transition-opacity"
          style={{ background: hasCredit ? "#1a6b4a" : "#9ca3af", color: "#fff" }}>
          <Coins size={18} /> {hasCredit ? "1 Kredi Harca — Teklif Ver" : "Kredi Yetersiz"}
        </button>
        <button onClick={onClose} className="w-full py-3 text-sm font-bold text-muted-foreground">Vazgeç</button>
      </div>
    </div>
  );
}

// ─── SOHBET MODAL ────────────────────────────────────────────────────────────
type SohbetKisi = { ad: string; avatar: string; avatarColor: string; isOnline: boolean; sonGorus?: string };

function SohbetModal({ kisi, onClose, onNewMessage }: { kisi: SohbetKisi; onClose: () => void; onNewMessage?: (text: string) => void }) {
  const [messages, setMessages] = useState<{ from: "ben" | "karsi"; text: string; time: string; isNew?: boolean }[]>([
    { from: "karsi", text: "Merhaba! İlanınızı inceledim, müsait olduğumda görüşebiliriz.", time: "10:32" },
  ]);
  const [draft, setDraft] = useState("");
  const [karsiYaziyor, setKarsiYaziyor] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, karsiYaziyor]);

  function now() {
    const d = new Date();
    return `${d.getHours().toString().padStart(2, "0")}:${d.getMinutes().toString().padStart(2, "0")}`;
  }

  function gonder() {
    if (!draft.trim()) return;
    const msg = draft.trim();
    setDraft("");
    setMessages((prev) => [...prev, { from: "ben", text: msg, time: now() }]);
    setKarsiYaziyor(true);
    setTimeout(() => {
      setKarsiYaziyor(false);
      const yanıtlar = [
        "Tabii, detayları konuşabiliriz.",
        "Uygun saatler için takvimimi paylaşabilirim.",
        "Referanslarımı da iletebilirim.",
        "Tecrübem hakkında daha fazla bilgi vermekten memnuniyet duyarım.",
        "Peki, ne zaman uygun olursunuz?",
        "Anladım, size en kısa sürede döneyim.",
      ];
      const reply = yanıtlar[Math.floor(Math.random() * yanıtlar.length)];
      setMessages((prev) => [...prev, { from: "karsi", text: reply, time: now(), isNew: true }]);
      onNewMessage?.(reply);
    }, 1400);
  }

  return (
    <div className="absolute inset-0 z-50 flex flex-col bg-background">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-border bg-card shadow-sm">
        <button onClick={onClose} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0">
          <ChevronRight size={16} className="rotate-180" />
        </button>
        <div className="relative shrink-0">
          <div className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-extrabold text-white"
            style={{ background: kisi.avatarColor }}>{kisi.avatar}</div>
          {kisi.isOnline && (
            <span className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-green-500 border-2 border-card" />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-extrabold text-foreground truncate">{kisi.ad}</p>
          {kisi.isOnline ? (
            <p className="text-xs text-green-600 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block" /> Çevrimiçi
            </p>
          ) : (
            <p className="text-xs text-muted-foreground">{kisi.sonGorus ?? "Son görülme bilinmiyor"}</p>
          )}
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <button className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
            <Phone size={14} className="text-foreground" />
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        <p className="text-center text-[10px] text-muted-foreground bg-muted/60 rounded-full px-3 py-1 mx-auto w-fit">
          Teklif kabul edildi · Sohbet açıldı
        </p>
        {messages.map((m, i) => (
          <div key={i}
            className={`flex ${m.from === "ben" ? "justify-end" : "justify-start"}`}
            style={m.isNew ? { animation: "slideInUp 0.22s ease-out" } : undefined}>
            {m.from === "karsi" && (
              <div className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-extrabold text-white mr-2 shrink-0 self-end"
                style={{ background: kisi.avatarColor }}>{kisi.avatar}</div>
            )}
            <div className={`max-w-[72%] px-3.5 py-2.5 rounded-2xl ${m.from === "ben"
              ? "bg-primary text-primary-foreground rounded-br-sm"
              : "bg-card border border-border text-foreground rounded-bl-sm"}`}>
              <p className="text-sm leading-snug">{m.text}</p>
              <p className={`text-[10px] mt-1 ${m.from === "ben" ? "text-primary-foreground/60" : "text-muted-foreground"}`}>{m.time}</p>
            </div>
          </div>
        ))}
        {karsiYaziyor && (
          <div className="flex justify-start items-end gap-2">
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-extrabold text-white shrink-0"
              style={{ background: kisi.avatarColor }}>{kisi.avatar}</div>
            <div className="bg-card border border-border rounded-2xl rounded-bl-sm px-4 py-3 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "0ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "150ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "300ms" }} />
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-4 py-3 border-t border-border bg-card flex items-end gap-2">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); gonder(); } }}
          rows={1}
          placeholder="Mesaj yaz…"
          className="flex-1 resize-none bg-muted rounded-2xl px-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground outline-none leading-snug"
        />
        <button onClick={gonder}
          className="w-10 h-10 rounded-full bg-primary flex items-center justify-center shrink-0 shadow-md">
          <Send size={15} className="text-white" />
        </button>
      </div>
    </div>
  );
}

// Bakıcı CV profil drawer
function BakiciCVDrawer({ ilan, onClose, onKrediTap }: {
  ilan: typeof bakiciIlanlar[0]; onClose: () => void; onKrediTap: () => void;
}) {
  const [tab, setTab] = useState<"profil" | "cv">("profil");
  const [yorumYaz, setYorumYaz] = useState(false);
  const [myRating, setMyRating] = useState(0);
  const [myText, setMyText] = useState("");
  const [localReviews, setLocalReviews] = useState(ilan.poster.reviews);
  const avgR = localReviews.reduce((s, r) => s + r.rating, 0) / (localReviews.length || 1);

  function submitReview() {
    if (myRating === 0 || !myText.trim()) return;
    setLocalReviews((p) => [{ author: "Sen", avatar: "BN", avatarColor: "#1a6b4a", rating: myRating, date: "Az önce", text: myText.trim() }, ...p]);
    setYorumYaz(false); setMyText(""); setMyRating(0);
  }

  return (
    <div className="absolute inset-0 z-40 flex items-end bg-black/50" onClick={onClose}>
      <div className="w-full bg-card rounded-t-3xl max-h-[92%] flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="w-10 h-1 rounded-full bg-muted mx-auto mt-3 mb-1 shrink-0" />
        {/* Header */}
        <div className="px-5 pt-3 pb-4 border-b border-border shrink-0">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-lg font-extrabold text-white shrink-0"
              style={{ background: ilan.poster.avatarColor }}>{ilan.poster.avatar}</div>
            <div className="flex-1 min-w-0">
              <p className="font-extrabold text-foreground text-base">{ilan.poster.name}</p>
              <div className="flex items-center gap-1.5 mt-0.5">
                <StarRow rating={avgR} size={12} />
                <span className="text-xs font-bold text-foreground">{avgR.toFixed(1)}</span>
                <span className="text-xs text-muted-foreground">({localReviews.length} yorum)</span>
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">{ilan.city} · {ilan.district}</p>
            </div>
          </div>
          {/* Sekmeler */}
          <div className="flex gap-2 mt-3">
            {(["profil", "cv"] as const).map((t) => (
              <button key={t} onClick={() => setTab(t)}
                className="flex-1 py-1.5 rounded-xl text-xs font-extrabold transition-all"
                style={tab === t ? { background: "#1a6b4a", color: "#fff" } : { background: "#dceee4", color: "#4d7a62" }}>
                {t === "profil" ? "👤 Profil" : "📄 Özgeçmiş"}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-y-auto flex-1 px-5 pb-5">
          {tab === "profil" && (
            <>
              <div className="mt-4 space-y-2">
                {ilan.poster.tags.map((tag) => (
                  <span key={tag} className="inline-block mr-2 mb-1 text-xs px-3 py-1 rounded-full bg-primary/10 text-primary font-bold">{tag}</span>
                ))}
              </div>
              <p className="text-sm text-muted-foreground mt-3 leading-relaxed">{ilan.poster.bio}</p>
              <div className="mt-4 bg-muted rounded-2xl p-3 space-y-2">
                <p className="text-xs font-extrabold text-foreground">İlan Detayları</p>
                <p className="text-xs text-muted-foreground flex items-center gap-1"><CalendarDays size={11}/> {ilan.hours}</p>
                <p className="text-xs text-muted-foreground">💰 {ilan.budget}</p>
                <p className="text-xs text-muted-foreground">🧒 {ilan.tanı} · {ilan.age}</p>
              </div>
              {/* Yorumlar */}
              <div className="mt-4">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-sm font-extrabold text-foreground">Yorumlar</p>
                  <button onClick={() => setYorumYaz(!yorumYaz)}
                    className="text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full">
                    {yorumYaz ? "Vazgeç" : "+ Yorum Yaz"}
                  </button>
                </div>
                {yorumYaz && (
                  <div className="bg-muted rounded-2xl p-3 mb-3 space-y-2">
                    <div className="flex gap-1">
                      {[1,2,3,4,5].map((s) => (
                        <button key={s} onClick={() => setMyRating(s)}>
                          <svg width={22} height={22} viewBox="0 0 24 24" fill={s <= myRating ? "#f4a832" : "#e5e0d8"}>
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                          </svg>
                        </button>
                      ))}
                    </div>
                    <textarea rows={3} value={myText} onChange={(e) => setMyText(e.target.value)}
                      className="w-full bg-card border border-border rounded-xl px-3 py-2 text-sm placeholder:text-muted-foreground resize-none"
                      placeholder="Deneyiminizi paylaşın..." />
                    <button onClick={submitReview}
                      className="w-full py-2.5 rounded-xl bg-primary text-primary-foreground text-xs font-bold">Gönder</button>
                  </div>
                )}
                <RatingBreakdown reviews={localReviews} />
                <div className="mt-3 space-y-3">
                  {localReviews.map((r, i) => (
                    <div key={i} className="flex gap-3">
                      <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0"
                        style={{ background: r.avatarColor }}>{r.avatar}</div>
                      <div className="flex-1 bg-muted rounded-2xl px-3 py-2">
                        <div className="flex items-center justify-between">
                          <p className="text-xs font-bold text-foreground">{r.author}</p>
                          <StarRow rating={r.rating} size={10} />
                        </div>
                        <p className="text-xs text-muted-foreground mt-0.5">{r.text}</p>
                        <p className="text-[10px] text-muted-foreground mt-1">{r.date}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}

          {tab === "cv" && (
            <div className="mt-4 space-y-4">
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold text-primary mb-2 flex items-center gap-1.5"><BookOpen size={13}/> Eğitim</p>
                <p className="text-sm font-bold text-foreground">{ilan.poster.cv?.bolum ?? "Çocuk Gelişimi"}</p>
                <p className="text-xs text-muted-foreground">{ilan.poster.cv?.okul ?? "Anadolu Üniversitesi"} · {ilan.poster.cv?.mezunYil ?? "2018"}</p>
              </div>
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold text-primary mb-2 flex items-center gap-1.5"><Briefcase size={13}/> Deneyim</p>
                <p className="text-sm font-bold text-foreground">{ilan.poster.cv?.deneyimYil ?? "5"} yıl deneyim</p>
                <p className="text-xs text-muted-foreground mt-1">{ilan.poster.cv?.deneyimAlani ?? "Otizm, Down Sendromu, Serebral Palsi tanılı çocuklarla çalışma deneyimi"}</p>
              </div>
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold text-primary mb-2 flex items-center gap-1.5"><Shield size={13}/> Sertifikalar</p>
                {(ilan.poster.cv?.sertifikalar ?? ["İlk Yardım Sertifikası", "Özel Gereksinimli Çocuk Bakımı"]).map((s: string) => (
                  <div key={s} className="flex items-center gap-2 mb-1">
                    <CheckCircle size={11} className="text-primary shrink-0" />
                    <p className="text-xs text-foreground">{s}</p>
                  </div>
                ))}
              </div>
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold text-primary mb-2">Hakkında</p>
                <p className="text-xs text-muted-foreground leading-relaxed">{ilan.poster.bio}</p>
              </div>
            </div>
          )}
        </div>

        {/* CTA */}
        <div className="px-5 pb-5 pt-3 border-t border-border shrink-0">
          <button onClick={onKrediTap}
            className="w-full py-3.5 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm flex items-center justify-center gap-2 shadow-md">
            <Coins size={16} /> 1 Kredi Harca — Teklif Ver &amp; Sohbet Aç
          </button>
        </div>
      </div>
    </div>
  );
}

// Uzman CV profil drawer (genişletilmiş)
function UzmanCVDrawer({ ilan, onClose, onKrediTap }: {
  ilan: typeof uzmanIlanlar[0]; onClose: () => void; onKrediTap: () => void;
}) {
  const [tab, setTab] = useState<"profil" | "cv">("profil");
  const [yorumYaz, setYorumYaz] = useState(false);
  const [myRating, setMyRating] = useState(0);
  const [myText, setMyText] = useState("");
  const [localReviews, setLocalReviews] = useState(ilan.poster.reviews);
  const avgR = localReviews.reduce((s, r) => s + r.rating, 0) / (localReviews.length || 1);
  const renk = uzmanRenk[ilan.uzmanlik] ?? { color: "#1a6b4a", bg: "#e8f5ee", emoji: "👤" };

  function submitReview() {
    if (myRating === 0 || !myText.trim()) return;
    setLocalReviews((p) => [{ author: "Sen", avatar: "BN", avatarColor: "#1a6b4a", rating: myRating, date: "Az önce", text: myText.trim() }, ...p]);
    setYorumYaz(false); setMyText(""); setMyRating(0);
  }

  const uzmanCV: Record<string, { bolum: string; okul: string; mezunYil: string; deneyimYil: string; deneyimAlani: string; sertifikalar: string[] }> = {
    "Fizyoterapist":          { bolum: "Fizyoterapi ve Rehabilitasyon", okul: "Hacettepe Üniversitesi", mezunYil: "2015", deneyimYil: "8", deneyimAlani: "Serebral Palsi, nörolojik rehabilitasyon, yürüme analizi", sertifikalar: ["Bobath Sertifikası", "NDT Eğitimi", "Pediatrik Fizyoterapi"] },
    "Ergoterapist":           { bolum: "Ergoterapi", okul: "İstanbul Üniversitesi", mezunYil: "2017", deneyimYil: "6", deneyimAlani: "Duyu bütünleme, günlük yaşam aktiviteleri, adaptif cihaz kullanımı", sertifikalar: ["Ayres Duyu Bütünleme Sertifikası", "El Rehabilitasyonu"] },
    "Özel Eğitim Öğretmeni": { bolum: "Özel Eğitim Öğretmenliği", okul: "Ankara Üniversitesi", mezunYil: "2016", deneyimYil: "7", deneyimAlani: "Otizm, zihinsel yetersizlik, DEHB, bireyselleştirilmiş eğitim planı", sertifikalar: ["ABA Sertifikası", "PECS Eğitimi", "Sosyal Beceri Terapisi"] },
    "Dil Terapisti":          { bolum: "Dil ve Konuşma Terapisi", okul: "Anadolu Üniversitesi", mezunYil: "2018", deneyimYil: "5", deneyimAlani: "Gecikmiş dil gelişimi, otizm, kekemelik, yutma terapisi", sertifikalar: ["PROMPT Sertifikası", "AAC Uzmanı", "Erken Müdahale"] },
  };
  const cv = uzmanCV[ilan.uzmanlik] ?? uzmanCV["Fizyoterapist"];

  return (
    <div className="absolute inset-0 z-40 flex items-end bg-black/50" onClick={onClose}>
      <div className="w-full bg-card rounded-t-3xl max-h-[92%] flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="w-10 h-1 rounded-full bg-muted mx-auto mt-3 mb-1 shrink-0" />
        <div className="px-5 pt-3 pb-4 border-b border-border shrink-0">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-lg font-extrabold text-white shrink-0"
              style={{ background: ilan.poster.avatarColor }}>{ilan.poster.avatar}</div>
            <div className="flex-1 min-w-0">
              <p className="font-extrabold text-foreground text-base">{ilan.poster.name}</p>
              <span className="text-xs font-bold px-2 py-0.5 rounded-full" style={{ background: renk.bg, color: renk.color }}>{renk.emoji} {ilan.uzmanlik}</span>
              <div className="flex items-center gap-1.5 mt-1">
                <StarRow rating={avgR} size={12} />
                <span className="text-xs font-bold text-foreground">{avgR.toFixed(1)}</span>
                <span className="text-xs text-muted-foreground">({localReviews.length} yorum)</span>
              </div>
            </div>
          </div>
          <div className="flex gap-2 mt-3">
            {(["profil", "cv"] as const).map((t) => (
              <button key={t} onClick={() => setTab(t)}
                className="flex-1 py-1.5 rounded-xl text-xs font-extrabold transition-all"
                style={tab === t ? { background: renk.color, color: "#fff" } : { background: "#dceee4", color: "#4d7a62" }}>
                {t === "profil" ? "👤 Profil" : "📄 Özgeçmiş"}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-y-auto flex-1 px-5 pb-5">
          {tab === "profil" && (
            <>
              <div className="mt-3 flex flex-wrap gap-2">
                {ilan.poster.tags.map((tag) => (
                  <span key={tag} className="text-xs px-3 py-1 rounded-full font-bold" style={{ background: renk.bg, color: renk.color }}>{tag}</span>
                ))}
              </div>
              <p className="text-sm text-muted-foreground mt-3 leading-relaxed">{ilan.poster.bio}</p>
              <div className="mt-4">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-sm font-extrabold text-foreground">Yorumlar</p>
                  <button onClick={() => setYorumYaz(!yorumYaz)}
                    className="text-xs font-bold text-primary bg-primary/10 px-3 py-1.5 rounded-full">
                    {yorumYaz ? "Vazgeç" : "+ Yorum Yaz"}
                  </button>
                </div>
                {yorumYaz && (
                  <div className="bg-muted rounded-2xl p-3 mb-3 space-y-2">
                    <div className="flex gap-1">
                      {[1,2,3,4,5].map((s) => (
                        <button key={s} onClick={() => setMyRating(s)}>
                          <svg width={22} height={22} viewBox="0 0 24 24" fill={s <= myRating ? "#f4a832" : "#e5e0d8"}>
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                          </svg>
                        </button>
                      ))}
                    </div>
                    <textarea rows={3} value={myText} onChange={(e) => setMyText(e.target.value)}
                      className="w-full bg-card border border-border rounded-xl px-3 py-2 text-sm placeholder:text-muted-foreground resize-none"
                      placeholder="Deneyiminizi paylaşın..." />
                    <button onClick={submitReview}
                      className="w-full py-2.5 rounded-xl bg-primary text-primary-foreground text-xs font-bold">Gönder</button>
                  </div>
                )}
                <RatingBreakdown reviews={localReviews} />
                <div className="mt-3 space-y-3">
                  {localReviews.map((r, i) => (
                    <div key={i} className="flex gap-3">
                      <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white shrink-0"
                        style={{ background: r.avatarColor }}>{r.avatar}</div>
                      <div className="flex-1 bg-muted rounded-2xl px-3 py-2">
                        <div className="flex items-center justify-between">
                          <p className="text-xs font-bold text-foreground">{r.author}</p>
                          <StarRow rating={r.rating} size={10} />
                        </div>
                        <p className="text-xs text-muted-foreground mt-0.5">{r.text}</p>
                        <p className="text-[10px] text-muted-foreground mt-1">{r.date}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}
          {tab === "cv" && (
            <div className="mt-4 space-y-4">
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold mb-2 flex items-center gap-1.5" style={{ color: renk.color }}><BookOpen size={13}/> Eğitim</p>
                <p className="text-sm font-bold text-foreground">{cv.bolum}</p>
                <p className="text-xs text-muted-foreground">{cv.okul} · {cv.mezunYil}</p>
              </div>
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold mb-2 flex items-center gap-1.5" style={{ color: renk.color }}><Briefcase size={13}/> Deneyim</p>
                <p className="text-sm font-bold text-foreground">{cv.deneyimYil} yıl deneyim</p>
                <p className="text-xs text-muted-foreground mt-1">{cv.deneyimAlani}</p>
              </div>
              <div className="bg-card border border-border rounded-2xl p-4">
                <p className="text-xs font-extrabold mb-2 flex items-center gap-1.5" style={{ color: renk.color }}><Shield size={13}/> Sertifikalar</p>
                {cv.sertifikalar.map((s) => (
                  <div key={s} className="flex items-center gap-2 mb-1">
                    <CheckCircle size={11} className="text-primary shrink-0" />
                    <p className="text-xs text-foreground">{s}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
        <div className="px-5 pb-5 pt-3 border-t border-border shrink-0">
          <button onClick={onKrediTap}
            className="w-full py-3.5 rounded-2xl font-extrabold text-sm flex items-center justify-center gap-2 shadow-md text-white"
            style={{ background: renk.color }}>
            <Coins size={16} /> 1 Kredi Harca — Teklif Ver
          </button>
        </div>
      </div>
    </div>
  );
}

type SortMode = "varsayilan" | "tarih" | "yakinlik";
type ActiveSohbet = { id: string; kisi: SohbetKisi; unread: number; lastMsg: string; lastTime: string };

function postedToSeconds(p: string): number {
  const m = p.match(/(\d+)\s*(dakika|saat|gün|hafta)/);
  if (!m) return 9999999;
  const n = parseInt(m[1]);
  if (m[2] === "dakika") return n * 60;
  if (m[2] === "saat")   return n * 3600;
  if (m[2] === "gün")    return n * 86400;
  return n * 604800;
}

function IlanlarTab({ onUnreadChange, userKredi, onKrediHarca }: { onUnreadChange?: (n: number) => void; userKredi?: number; onKrediHarca?: () => void }) {
  const [kategori, setKategori] = useState<IlanKategori>("uzmanlar");
  const [sortMode, setSortMode] = useState<SortMode>("varsayilan");
  const [showKredi, setShowKredi] = useState(false);
  const [showVerForm, setShowVerForm] = useState(false);
  const [selectedPoster, setSelectedPoster] = useState<{ poster: IlanPoster; ctaLabel: string } | null>(null);
  const [selectedBakici, setSelectedBakici] = useState<typeof bakiciIlanlar[0] | null>(null);
  const [selectedUzman, setSelectedUzman] = useState<typeof uzmanIlanlar[0] | null>(null);
  const [sohbetKisi, setSohbetKisi] = useState<SohbetKisi | null>(null);
  const [pendingSohbet, setPendingSohbet] = useState<SohbetKisi | null>(null);
  const [activeSohbetler, setActiveSohbetler] = useState<ActiveSohbet[]>([]);
  const [formKategori, setFormKategori] = useState("Uzman");
  const [formPhotos, setFormPhotos] = useState<string[]>([]);
  const [formAciklama, setFormAciklama] = useState("");
  const [aciklamaUyari, setAciklamaUyari] = useState("");
  const [kmFilter, setKmFilter] = useState(500);

  const totalUnread = activeSohbetler.reduce((s, c) => s + c.unread, 0);
  useEffect(() => { onUnreadChange?.(totalUnread); }, [totalUnread, onUnreadChange]);

  function handleAciklamaChange(val: string) {
    const phoneRegex = /(\+?\d[\d\s\-().]{7,}\d)/g;
    const emailRegex = /[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/g;
    const cleaned = val.replace(phoneRegex, "***").replace(emailRegex, "***");
    if (cleaned !== val) {
      setAciklamaUyari("İletişim bilgileri (telefon/e-posta) ilanda görünmez — kredi sistemi bu bilgileri korur.");
    } else {
      setAciklamaUyari("");
    }
    setFormAciklama(cleaned);
  }

  function handlePhotoAdd() {
    const colors = ["#dce8f5","#e8f0dc","#f5e8dc","#f0dce8","#dce5f0","#e8f5ee","#f5f0dc"];
    const maxPhotos = formKategori === "2. El Alet" ? 6 : 2;
    if (formPhotos.length < maxPhotos) {
      setFormPhotos((p) => [...p, colors[p.length % colors.length]]);
    }
  }

  // Mock km distances for listings
  const uzmanKm: Record<number, number> = { 1: 3, 2: 12, 3: 28, 4: 45, 5: 180, 6: 320 };
  const bakiciKm: Record<number, number> = { 10: 5, 11: 95, 12: 220, 13: 8 };

  const filteredUzman = uzmanIlanlar.filter((u) => (uzmanKm[u.id] ?? 50) <= kmFilter);
  const filteredBakici = bakiciIlanlar.filter((b) => (bakiciKm[b.id] ?? 50) <= kmFilter);

  const kategoriler: { id: IlanKategori; label: string; emoji: string; count: number }[] = [
    { id: "uzmanlar", label: "Uzmanlar", emoji: "🏃", count: filteredUzman.length },
    { id: "bakici", label: "Bakıcı", emoji: "🤝", count: filteredBakici.length },
    { id: "ikinciel", label: "2. El Aletler", emoji: "♻️", count: ikincielIlanlar.length },
  ];

  if (showVerForm) return (
    <div className="flex flex-col h-full overflow-y-auto">
      <div className="px-4 pt-6 pb-4 flex items-center gap-3">
        <button onClick={() => setShowVerForm(false)} className="w-9 h-9 rounded-full bg-muted flex items-center justify-center"><ChevronRight size={18} className="rotate-180" /></button>
        <h2 className="text-base font-extrabold text-foreground">Yeni İlan Ver</h2>
      </div>
      <div className="px-4 pb-6 space-y-4">
        {/* Category select */}
        <div>
          <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">İlan Kategorisi</label>
          <select
            value={formKategori}
            onChange={(e) => { setFormKategori(e.target.value); setFormPhotos([]); }}
            className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm text-foreground"
          >
            {["Uzman", "Bakıcı", "2. El Alet"].map((c) => <option key={c}>{c}</option>)}
          </select>
        </div>

        {[
          { label: "Başlık", placeholder: "İlanınıza kısa bir başlık" },
          { label: "Şehir / İlçe", placeholder: "İstanbul / Kadıköy" },
          { label: formKategori === "2. El Alet" ? "Fiyat" : "Bütçe", placeholder: formKategori === "2. El Alet" ? "₺2.000" : "₺300–500/seans" },
        ].map((f) => (
          <div key={f.label}>
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">{f.label}</label>
            <input className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground" placeholder={f.placeholder} />
          </div>
        ))}

        {/* Photo upload — uzman / bakıcı max 2, 2. el max 6 */}
        {(formKategori === "2. El Alet" || formKategori === "Uzman" || formKategori === "Bakıcı") && (
          <div>
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">
              Fotoğraflar
            </label>
            <p className="text-xs text-muted-foreground mt-0.5 mb-2">
              En fazla {formKategori === "2. El Alet" ? 6 : 2} fotoğraf ekleyebilirsiniz. İlk fotoğraf kapak olur.
            </p>
            <div className="flex flex-wrap gap-2">
              {formPhotos.map((bg, i) => (
                <div key={i} className="relative w-20 h-20 rounded-xl overflow-hidden border-2 border-border"
                  style={{ background: bg }}>
                  <div className="absolute inset-0 flex items-center justify-center text-2xl opacity-40">📷</div>
                  {i === 0 && (
                    <span className="absolute bottom-1 left-1 text-[9px] font-bold bg-primary text-white px-1.5 py-0.5 rounded-full">Kapak</span>
                  )}
                  <button
                    onClick={() => setFormPhotos((p) => p.filter((_, idx) => idx !== i))}
                    className="absolute top-1 right-1 w-5 h-5 rounded-full bg-black/60 flex items-center justify-center"
                  >
                    <X size={10} className="text-white" />
                  </button>
                </div>
              ))}
              {formPhotos.length < (formKategori === "2. El Alet" ? 6 : 2) && (
                <button
                  onClick={handlePhotoAdd}
                  className="w-20 h-20 rounded-xl border-2 border-dashed border-border bg-muted flex flex-col items-center justify-center gap-1 text-muted-foreground hover:border-primary hover:text-primary transition-colors"
                >
                  <Plus size={20} />
                  <span className="text-[10px] font-bold">Ekle</span>
                </button>
              )}
            </div>
            {formPhotos.length === 0 && (
              <p className="text-xs text-amber-600 mt-2 flex items-center gap-1">
                <AlertCircle size={11} />{" "}
                {formKategori === "2. El Alet"
                  ? "Fotoğraf eklemek satışı hızlandırır"
                  : "İsteğe bağlı: en fazla 2 fotoğraf ekleyebilirsiniz"}
              </p>
            )}
          </div>
        )}

        <div>
          <label className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Açıklama</label>
          <textarea
            rows={4}
            value={formAciklama}
            onChange={(e) => handleAciklamaChange(e.target.value)}
            className="mt-1 w-full bg-card border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground resize-none"
            placeholder="Detaylı bilgi, tercihleriniz... (telefon/e-posta yazmayın)" />
          {aciklamaUyari ? (
            <div className="mt-2 flex items-start gap-1.5 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2">
              <AlertCircle size={13} className="text-amber-600 shrink-0 mt-0.5" />
              <p className="text-xs text-amber-700 leading-relaxed">{aciklamaUyari}</p>
            </div>
          ) : null}
        </div>
        <div className="bg-muted rounded-2xl p-4">
          <div className="flex items-start gap-2">
            <Shield size={14} className="text-primary shrink-0 mt-0.5" />
            <p className="text-xs text-muted-foreground leading-relaxed">Telefon, e-posta ve adres bilgileri otomatik olarak engellenir. İletişim yalnızca kredi sistemi üzerinden kurulur.</p>
          </div>
        </div>
        <button className="w-full py-4 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm shadow-md flex items-center justify-center gap-2">
          <Plus size={18} /> İlanı Yayınla — Ücretsiz
        </button>
      </div>
    </div>
  );

  function openTeklif(kisi: SohbetKisi) {
    setPendingSohbet(kisi);
    setShowKredi(true);
  }

  function openSohbet(kisi: SohbetKisi) {
    setSohbetKisi(kisi);
    setActiveSohbetler((prev) => prev.map((c) => c.id === kisi.ad ? { ...c, unread: 0 } : c));
  }

  function onSohbetNewMsg(kisi: SohbetKisi, text: string) {
    const now = new Date();
    const time = `${now.getHours().toString().padStart(2,"0")}:${now.getMinutes().toString().padStart(2,"0")}`;
    setActiveSohbetler((prev) => {
      const exists = prev.find((c) => c.id === kisi.ad);
      if (exists) return prev.map((c) => c.id === kisi.ad ? { ...c, unread: c.unread + 1, lastMsg: text, lastTime: time } : c);
      return [...prev, { id: kisi.ad, kisi, unread: 1, lastMsg: text, lastTime: time }];
    });
  }

  return (
    <div className="flex flex-col h-full relative">
      {sohbetKisi && <SohbetModal kisi={sohbetKisi}
        onClose={() => { setSohbetKisi(null); setActiveSohbetler((prev) => prev.map((c) => c.id === sohbetKisi.ad ? { ...c, unread: 0 } : c)); }}
        onNewMessage={(text) => onSohbetNewMsg(sohbetKisi, text)}
      />}
      {showKredi && (
        <KrediModal
          userKredi={userKredi ?? 0}
          onClose={() => setShowKredi(false)}
          onUnlocked={() => {
            setShowKredi(false);
            onKrediHarca?.();
            if (pendingSohbet) {
              const kisi = pendingSohbet;
              setSohbetKisi(kisi);
              setPendingSohbet(null);
              const now = new Date();
              const time = `${now.getHours()}:${String(now.getMinutes()).padStart(2,"0")}`;
              setActiveSohbetler((prev) => prev.find((c) => c.id === kisi.ad) ? prev : [...prev, { id: kisi.ad, kisi, unread: 0, lastMsg: "Teklif kabul edildi", lastTime: time }]);
            }
          }}
        />
      )}
      {selectedPoster && (
        <ProfilDrawer
          poster={selectedPoster.poster}
          ctaLabel={selectedPoster.ctaLabel}
          onClose={() => setSelectedPoster(null)}
          onKrediTap={() => {
            setSelectedPoster(null);
            openTeklif({ ad: selectedPoster.poster.name, avatar: selectedPoster.poster.avatar, avatarColor: selectedPoster.poster.avatarColor, isOnline: Math.random() > 0.4, sonGorus: "Son görülme: 1 saat önce" });
          }}
        />
      )}
      {selectedBakici && (
        <BakiciCVDrawer
          ilan={selectedBakici}
          onClose={() => setSelectedBakici(null)}
          onKrediTap={() => {
            setSelectedBakici(null);
            openTeklif({ ad: selectedBakici.poster.name, avatar: selectedBakici.poster.avatar, avatarColor: selectedBakici.poster.avatarColor, isOnline: Math.random() > 0.4, sonGorus: "Son görülme: 2 saat önce" });
          }}
        />
      )}
      {selectedUzman && (
        <UzmanCVDrawer
          ilan={selectedUzman}
          onClose={() => setSelectedUzman(null)}
          onKrediTap={() => {
            setSelectedUzman(null);
            openTeklif({ ad: selectedUzman.poster.name, avatar: selectedUzman.poster.avatar, avatarColor: selectedUzman.poster.avatarColor, isOnline: Math.random() > 0.4, sonGorus: "Son görülme: 1 saat önce" });
          }}
        />
      )}

      {/* Header */}
      <div className="px-4 pt-5 pb-3 flex items-center justify-between">
        <div>
          <h2 className="text-xl font-extrabold text-foreground">İlanlar</h2>
          <p className="text-xs text-muted-foreground">Uzman · Bakıcı · 2. El Malzeme</p>
        </div>
        <div className="flex items-center gap-2">
          {totalUnread > 0 && (
            <button onClick={() => { /* scroll to mesajlar */ }}
              className="relative flex items-center gap-1.5 px-3 py-2 rounded-xl bg-red-500 text-white text-xs font-extrabold shadow-md">
              <MessageCircle size={13} />
              <span>{totalUnread} yeni</span>
              <span className="absolute -top-1 -right-1 w-2.5 h-2.5 rounded-full bg-red-300 animate-ping" />
            </button>
          )}
          <button onClick={() => setShowVerForm(true)}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-primary text-primary-foreground text-xs font-extrabold shadow-sm">
            <Plus size={14} /> İlan Ver
          </button>
        </div>
      </div>

      {/* Mesajlarım */}
      {activeSohbetler.length > 0 && (
        <div className="mx-4 mb-3 bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
          <div className="px-4 pt-3 pb-2 flex items-center justify-between border-b border-border">
            <div className="flex items-center gap-2">
              <MessageCircle size={14} className="text-primary" />
              <p className="text-sm font-extrabold text-foreground">Mesajlarım</p>
            </div>
            {totalUnread > 0 && (
              <span className="min-w-[20px] h-5 px-1.5 rounded-full bg-red-500 text-white text-[11px] font-extrabold flex items-center justify-center">
                {totalUnread}
              </span>
            )}
          </div>
          <div className="divide-y divide-border">
            {activeSohbetler.map((s) => (
              <button key={s.id} onClick={() => openSohbet(s.kisi)}
                className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-muted/40 transition-colors">
                <div className="relative shrink-0">
                  <div className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-extrabold text-white"
                    style={{ background: s.kisi.avatarColor }}>{s.kisi.avatar}</div>
                  {s.kisi.isOnline && (
                    <span className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-green-500 border-2 border-card" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-extrabold text-foreground truncate">{s.kisi.ad}</p>
                    <span className="text-[10px] text-muted-foreground shrink-0 ml-2">{s.lastTime}</span>
                  </div>
                  <p className="text-xs text-muted-foreground truncate mt-0.5">{s.lastMsg}</p>
                </div>
                {s.unread > 0 && (
                  <span className="shrink-0 min-w-[20px] h-5 px-1.5 rounded-full bg-red-500 text-white text-[11px] font-extrabold flex items-center justify-center shadow-sm">
                    {s.unread}
                  </span>
                )}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Category tabs */}
      <div className="px-4 mb-3 grid grid-cols-3 gap-2">
        {kategoriler.map((k) => (
          <button key={k.id} onClick={() => setKategori(k.id)}
            className="flex flex-col items-center py-2.5 rounded-2xl border-2 transition-all"
            style={kategori === k.id
              ? { borderColor: "#1a6b4a", background: "#e8f5ee" }
              : { borderColor: "transparent", background: "#fff" }}>
            <span className="text-xl mb-0.5">{k.emoji}</span>
            <span className="text-xs font-extrabold" style={{ color: kategori === k.id ? "#1a6b4a" : "#4d7a62" }}>{k.label}</span>
            <span className="text-xs" style={{ color: kategori === k.id ? "#1a6b4a" : "#b0a899" }}>{k.count} ilan</span>
          </button>
        ))}
      </div>

      {/* Credit bar */}
      <div className="mx-4 mb-3 flex items-center justify-between bg-amber-50 border border-amber-200 rounded-2xl px-4 py-2.5">
        <div className="flex items-center gap-2">
          <Coins size={15} className="text-amber-600" />
          <div>
            <p className="text-xs font-extrabold text-amber-800">3 krediniz var</p>
            <p className="text-xs text-amber-600">1 kredi = iletişim bilgisi</p>
          </div>
        </div>
        <button className="text-xs font-extrabold text-primary bg-primary/10 px-3 py-1.5 rounded-full">Satın Al</button>
      </div>

      {/* Mesafe filtresi — sadece uzman ve bakıcı için */}
      {kategori !== "ikinciel" && (
        <div className="mx-4 mb-3 bg-card border border-border rounded-2xl px-4 py-3 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-1.5">
              <MapPin size={13} className="text-primary shrink-0" />
              <p className="text-xs font-extrabold text-foreground">Maksimum Mesafe</p>
            </div>
            <span className="text-xs font-extrabold text-primary bg-primary/10 px-2 py-0.5 rounded-full">
              {kmFilter === 500 ? "Tümü" : `${kmFilter} km`}
            </span>
          </div>
          <input
            type="range"
            min={5} max={500} step={5}
            value={kmFilter}
            onChange={(e) => setKmFilter(Number(e.target.value))}
            className="w-full appearance-none cursor-pointer"
            style={{
              height: 8,
              borderRadius: 999,
              accentColor: "#1a6b4a",
              background: `linear-gradient(to right, #1a6b4a 0%, #1a6b4a ${((kmFilter - 5) / 495) * 100}%, #dceee4 ${((kmFilter - 5) / 495) * 100}%, #dceee4 100%)`,
              outline: "none",
            }}
          />
          <div className="flex justify-between mt-1">
            <span className="text-[10px] text-muted-foreground">0 km</span>
            <span className="text-[10px] text-muted-foreground">500 km</span>
          </div>
        </div>
      )}

      {/* Sıralama */}
      <div className="mx-4 mb-3 flex items-center gap-2">
        <span className="text-xs text-muted-foreground font-semibold shrink-0">Sırala:</span>
        {([
          { id: "varsayilan", label: "Varsayılan", icon: "⚡" },
          { id: "tarih",      label: "En Yeni",    icon: "🕐" },
          { id: "yakinlik",   label: "En Yakın",   icon: "📍" },
        ] as const).map((s) => (
          <button key={s.id} onClick={() => setSortMode(s.id)}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl text-xs font-bold transition-all"
            style={sortMode === s.id
              ? { background: "#1a6b4a", color: "#fff" }
              : { background: "#dceee4", color: "#4d7a62" }}>
            <span>{s.icon}</span>{s.label}
          </button>
        ))}
      </div>

      {/* Lists */}
      <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-3">

        {/* UZMANLAR */}
        {kategori === "uzmanlar" && (() => {
          let list = [...filteredUzman];
          if (sortMode === "tarih")    list.sort((a, b) => postedToSeconds(a.posted) - postedToSeconds(b.posted));
          if (sortMode === "yakinlik") list.sort((a, b) => (uzmanKm[a.id] ?? 999) - (uzmanKm[b.id] ?? 999));
          return list;
        })().map((ilan) => {
          const renk = uzmanRenk[ilan.uzmanlik] ?? { color: "#1a6b4a", bg: "#e8f5ee", emoji: "👤" };
          const avgR = ilan.poster.reviews.reduce((s, r) => s + r.rating, 0) / (ilan.poster.reviews.length || 1);
          const km = uzmanKm[ilan.id] ?? 50;
          return (
            <div key={ilan.id} className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
              <div className="p-4">
                {/* Top row: avatar + title */}
                <div className="flex items-start gap-3 mb-2">
                  <button className="shrink-0" onClick={() => setSelectedUzman(ilan)}>
                    <div className="w-11 h-11 rounded-xl flex items-center justify-center text-sm font-extrabold text-white"
                      style={{ background: ilan.poster.avatarColor }}>{ilan.poster.avatar}</div>
                  </button>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-1.5">
                      <div className="flex items-start gap-1 flex-1 min-w-0">
                        {ilan.urgent && <Sparkles size={12} className="text-red-500 shrink-0 mt-0.5" />}
                        <p className="text-sm font-extrabold text-foreground leading-tight">{ilan.title}</p>
                      </div>
                      <span className="text-xs font-bold px-2 py-0.5 rounded-full shrink-0" style={{ background: renk.bg, color: renk.color }}>
                        {renk.emoji} {ilan.uzmanlik}
                      </span>
                    </div>
                    <button className="flex items-center gap-1.5 mt-0.5" onClick={() => setSelectedUzman(ilan)}>
                      <StarRow rating={avgR} size={11} />
                      <span className="text-xs font-bold text-foreground">{avgR.toFixed(1)}</span>
                      <span className="text-xs text-muted-foreground">({ilan.poster.reviewCount} yorum)</span>
                    </button>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 text-xs text-muted-foreground mb-2">
                  <span className="flex items-center gap-1"><MapPin size={10} />{ilan.district}, {ilan.city}</span>
                  <span className="flex items-center gap-1"><CalendarDays size={10} />{ilan.frequency}</span>
                  <span className="flex items-center gap-1"><Eye size={10} />{ilan.views}</span>
                  {uzmanKm[ilan.id] !== undefined && (
                    <span className="flex items-center gap-1 font-semibold text-primary"><MapPin size={10} />{uzmanKm[ilan.id]} km uzakta</span>
                  )}
                </div>
                <span className="inline-block text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground mb-2">{ilan.tanı}</span>
                <p className="text-xs text-muted-foreground line-clamp-2 leading-relaxed">{ilan.note}</p>
              </div>
              <div className="flex items-center justify-between px-4 pb-3 pt-1 gap-3">
                <div>
                  <p className="text-xs font-extrabold text-foreground">{ilan.budget}</p>
                  <p className="text-xs text-muted-foreground">{ilan.offers} teklif · {ilan.posted}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setSelectedUzman(ilan)}
                    className="px-3 py-2 rounded-xl text-xs font-extrabold border border-border text-foreground shrink-0">Profil</button>
                  <button onClick={() => openTeklif({ ad: ilan.poster.name, avatar: ilan.poster.avatar, avatarColor: ilan.poster.avatarColor, isOnline: Math.random() > 0.4, sonGorus: "Son görülme: 1 saat önce" })}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-extrabold text-white shrink-0"
                    style={{ background: "#1a6b4a" }}>
                    <Coins size={12} /> Teklif Ver
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {/* BAKICI */}
        {kategori === "bakici" && (() => {
          let list = [...filteredBakici];
          if (sortMode === "tarih")    list.sort((a, b) => postedToSeconds(a.posted) - postedToSeconds(b.posted));
          if (sortMode === "yakinlik") list.sort((a, b) => (bakiciKm[a.id] ?? 999) - (bakiciKm[b.id] ?? 999));
          return list;
        })().map((ilan) => {
          const avgR = ilan.poster.reviews.reduce((s, r) => s + r.rating, 0) / (ilan.poster.reviews.length || 1);
          return (
            <div key={ilan.id} className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
              <div className="p-4">
                <div className="flex items-start gap-3 mb-2">
                  <button className="shrink-0" onClick={() => setSelectedBakici(ilan)}>
                    <div className="w-11 h-11 rounded-xl flex items-center justify-center text-sm font-extrabold text-white"
                      style={{ background: ilan.poster.avatarColor }}>{ilan.poster.avatar}</div>
                  </button>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-1.5">
                      <div className="flex items-start gap-1 flex-1 min-w-0">
                        {ilan.urgent && <Sparkles size={12} className="text-red-500 shrink-0 mt-0.5" />}
                        <p className="text-sm font-extrabold text-foreground leading-tight">{ilan.title}</p>
                      </div>
                      <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 shrink-0">🤝 Bakıcı</span>
                    </div>
                    <button className="flex items-center gap-1.5 mt-0.5" onClick={() => setSelectedBakici(ilan)}>
                      <StarRow rating={avgR} size={11} />
                      <span className="text-xs font-bold text-foreground">{avgR.toFixed(1)}</span>
                      <span className="text-xs text-muted-foreground">({ilan.poster.reviewCount} yorum)</span>
                    </button>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2 text-xs text-muted-foreground mb-2">
                  <span className="flex items-center gap-1"><MapPin size={10} />{ilan.district}, {ilan.city}</span>
                  <span className="flex items-center gap-1"><Eye size={10} />{ilan.views}</span>
                  {bakiciKm[ilan.id] !== undefined && (
                    <span className="flex items-center gap-1 font-semibold text-primary"><MapPin size={10} />{bakiciKm[ilan.id]} km uzakta</span>
                  )}
                </div>
                <div className="flex flex-wrap gap-1.5 mb-2">
                  <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground">{ilan.tanı}</span>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground">{ilan.age}</span>
                </div>
                <p className="text-xs text-muted-foreground mb-1 flex items-center gap-1"><CalendarDays size={10} />{ilan.hours}</p>
                <p className="text-xs text-muted-foreground line-clamp-2 leading-relaxed">{ilan.note}</p>
              </div>
              <div className="flex items-center justify-between px-4 pb-3 pt-1 gap-3">
                <div>
                  <p className="text-xs font-extrabold text-foreground">{ilan.budget}</p>
                  <p className="text-xs text-muted-foreground">{ilan.posted}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setSelectedBakici(ilan)}
                    className="px-3 py-2 rounded-xl text-xs font-extrabold border border-border text-foreground shrink-0">Profil</button>
                  <button onClick={() => openTeklif({ ad: ilan.poster.name, avatar: ilan.poster.avatar, avatarColor: ilan.poster.avatarColor, isOnline: [10,13].includes(ilan.id), sonGorus: "Son görülme: 3 saat önce" })}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-extrabold text-white shrink-0"
                    style={{ background: "#1a6b4a" }}>
                    <Coins size={12} /> Teklif Ver
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {/* 2. EL */}
        {kategori === "ikinciel" && (() => {
          let list = [...ikincielIlanlar];
          if (sortMode === "tarih") list.sort((a, b) => postedToSeconds(a.posted) - postedToSeconds(b.posted));
          return list;
        })().map((ilan) => {
          const avgR = ilan.poster.reviews.reduce((s, r) => s + r.rating, 0) / (ilan.poster.reviews.length || 1);
          return (
            <div key={ilan.id} className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
              {/* Photo strip */}
              {ilan.photos && ilan.photos.length > 0 && (
                <div className="flex gap-1 p-2 pb-0">
                  {ilan.photos.map((bg, pi) => (
                    <div
                      key={pi}
                      className="flex-1 rounded-xl overflow-hidden flex items-center justify-center"
                      style={{ height: pi === 0 ? 110 : 52, background: bg }}
                    >
                      {pi === 0 && <span className="text-4xl select-none">{ilan.emoji}</span>}
                      {pi > 0 && <span className="text-xl select-none opacity-50">{ilan.emoji}</span>}
                    </div>
                  ))}
                </div>
              )}
              <div className="p-4">
                <div className="flex items-start gap-3 mb-2">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-extrabold text-foreground leading-tight">{ilan.title}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{ilan.brand} · {ilan.category}</p>
                  </div>
                  <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-green-50 text-green-700 shrink-0">{ilan.condition}</span>
                </div>
                {/* Seller row */}
                <button className="flex items-center gap-2 mb-2" onClick={() => setSelectedPoster({ poster: ilan.poster, ctaLabel: "Satıcıyla İletişime Geç" })}>
                  <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-extrabold text-white shrink-0"
                    style={{ background: ilan.poster.avatarColor }}>{ilan.poster.avatar}</div>
                  <span className="text-xs font-semibold text-foreground">{ilan.poster.name}</span>
                  <StarRow rating={avgR} size={10} />
                  <span className="text-xs font-bold text-foreground">{avgR.toFixed(1)}</span>
                  <span className="text-xs text-muted-foreground">({ilan.poster.reviewCount})</span>
                </button>
                <div className="flex flex-wrap gap-2 text-xs text-muted-foreground mb-2">
                  <span className="flex items-center gap-1"><MapPin size={10} />{ilan.district}, {ilan.city}</span>
                  <span className="flex items-center gap-1"><Eye size={10} />{ilan.views}</span>
                  <span>{ilan.posted}</span>
                </div>
                <p className="text-xs text-muted-foreground line-clamp-2 leading-relaxed">{ilan.note}</p>
              </div>
              <div className="flex items-center justify-between px-4 pb-3 pt-1 gap-3">
                <div>
                  <p className="text-base font-extrabold text-primary">{ilan.price}</p>
                  <p className="text-xs text-muted-foreground line-through">{ilan.originalPrice}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setSelectedPoster({ poster: ilan.poster, ctaLabel: "Satıcıyla İletişime Geç" })}
                    className="px-3 py-2 rounded-xl text-xs font-extrabold border border-border text-foreground shrink-0">Profil</button>
                  <button onClick={() => setShowKredi(true)}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-extrabold text-white shrink-0"
                    style={{ background: "#1a6b4a" }}>
                    <Coins size={12} /> İletişim
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {/* Footer stats */}
        <div className="rounded-2xl border border-border bg-card p-4 shadow-sm">
          <p className="text-xs font-extrabold text-foreground mb-3 flex items-center gap-2"><Briefcase size={14} className="text-primary" /> Platform İstatistikleri</p>
          <div className="grid grid-cols-3 gap-2 text-center">
            {[{ val: "1.240", label: "Aktif İlan" }, { val: "320", label: "Uzman" }, { val: "94%", label: "Eşleşme" }].map((s) => (
              <div key={s.label}>
                <p className="text-base font-extrabold text-primary">{s.val}</p>
                <p className="text-xs text-muted-foreground">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────

type AuthUser = { name: string; email: string; avatar: string; avatarColor: string; photo?: string; userType?: "aile" | "uzman" | "bakici" };

const GOOGLE_ACCOUNTS: AuthUser[] = [
  { name: "Ayşe Kaya", email: "ayse.kaya@gmail.com", avatar: "AK", avatarColor: "#e07a5f" },
  { name: "Mehmet Demir", email: "mehmet.demir@gmail.com", avatar: "MD", avatarColor: "#1a6b4a" },
  { name: "Fatma Yılmaz", email: "fatma.yilmaz@gmail.com", avatar: "FY", avatarColor: "#9c6db3" },
];

function GoogleIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  );
}

function AuthScreen({ onLogin }: { onLogin: (user: AuthUser) => void }) {
  const [step, setStep] = useState<"splash" | "signin" | "choosing" | "loading">("splash");
  const [authTab, setAuthTab] = useState<"giris" | "kayit">("giris");
  const [kayitAd, setKayitAd] = useState("");
  const [kayitEmail, setKayitEmail] = useState("");
  const [kayitSifre, setKayitSifre] = useState("");
  const [kayitSifre2, setKayitSifre2] = useState("");
  const [kayitTip, setKayitTip] = useState<"aile" | "uzman">("aile");
  const [kayitSozlesme, setKayitSozlesme] = useState(false);
  const [kayitLoading, setKayitLoading] = useState(false);
  const [girisEmail, setGirisEmail] = useState("");
  const [girisSifre, setGirisSifre] = useState("");
  const [girisHesapTip, setGirisHesapTip] = useState<"" | "aile" | "uzman" | "bakici">("");

  function handleGoogleTap() { setStep("choosing"); }
  function handleAccountSelect(account: AuthUser) {
    setStep("loading");
    setTimeout(() => onLogin(account), 1800);
  }

  if (step === "splash") return (
    <div className="flex flex-col h-full bg-background">
      <div className="shrink-0 relative h-64 overflow-hidden">
        <div className="absolute inset-0" style={{
          background: "linear-gradient(145deg, #1a6b4a 0%, #124a34 60%, #f4a832 120%)",
          borderBottomLeftRadius: "60% 30%",
          borderBottomRightRadius: "60% 30%",
        }} />
        <div className="absolute inset-0 flex flex-col items-center justify-center pt-6">
          <div className="w-28 h-28 rounded-3xl bg-white/95 flex items-center justify-center mb-4 shadow-xl overflow-hidden">
            <ImageWithFallback src={appIcon} alt="EngelsizClub" className="w-full h-full object-cover scale-150 origin-center translate-y-2" />
          </div>
          <p className="text-2xl font-extrabold text-white tracking-tight">EngelsizClub</p>
          <p className="text-sm text-white/70 mt-1">Özel gereksinimli kahramanlarımız için rehber</p>
        </div>
      </div>
      <div className="flex-1 px-6 pt-8 pb-4 flex flex-col gap-5">
        {[
          { emoji: "🏥", title: "Hastalık & Tanı Bilgisi", desc: "100+ tanı için güvenilir rehber" },
          { emoji: "🗺️", title: "Yakınımdaki Merkezler", desc: "Terapi merkezi ve uzman bul" },
          { emoji: "🗣️", title: "AAC İletişim Kartları", desc: "Görsel iletişim desteği" },
          { emoji: "⚖️", title: "Yasal Haklar & Destek", desc: "Devlet yardımlarına kolayca ulaş" },
        ].map((f) => (
          <div key={f.title} className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center text-xl shrink-0">{f.emoji}</div>
            <div>
              <p className="text-sm font-extrabold text-foreground">{f.title}</p>
              <p className="text-xs text-muted-foreground">{f.desc}</p>
            </div>
          </div>
        ))}
      </div>
      <div className="px-6 pb-8 space-y-3 shrink-0">
        <button onClick={() => setStep("signin")}
          className="w-full py-4 rounded-2xl bg-primary text-primary-foreground font-extrabold text-base shadow-lg">
          Başlayalım
        </button>
        <p className="text-center text-xs text-muted-foreground">Ücretsiz · Reklamsız · Güvenli</p>
      </div>
    </div>
  );

  if (step === "loading") return (
    <div className="flex flex-col h-full bg-background items-center justify-center gap-5">
      <div className="w-24 h-24 rounded-3xl bg-white flex items-center justify-center overflow-hidden shadow-lg">
        <ImageWithFallback src={appIcon} alt="EngelsizClub" className="w-full h-full object-cover scale-150 origin-center translate-y-2" />
      </div>
      <div className="flex flex-col items-center gap-2">
        <p className="text-lg font-extrabold text-foreground">Giriş yapılıyor…</p>
        <p className="text-sm text-muted-foreground">Hesabınız doğrulanıyor</p>
      </div>
      <div className="flex items-center gap-1.5">
        {[0,1,2].map((i) => (
          <div key={i} className="w-2 h-2 rounded-full bg-primary animate-bounce" style={{ animationDelay: `${i*0.15}s` }} />
        ))}
      </div>
    </div>
  );

  if (step === "choosing") return (
    <div className="flex flex-col h-full bg-background">
      <div className="px-6 pt-10 pb-6 flex items-center gap-3">
        <button onClick={() => setStep("signin")} className="w-9 h-9 rounded-full bg-muted flex items-center justify-center">
          <ChevronRight size={18} className="rotate-180 text-foreground" />
        </button>
        <div>
          <p className="font-extrabold text-foreground">Hesap seçin</p>
          <p className="text-xs text-muted-foreground">EngelsizClub uygulamasına giriş için</p>
        </div>
      </div>
      <div className="mx-6 mb-4 flex items-center gap-2 bg-muted/60 rounded-2xl px-4 py-3">
        <GoogleIcon size={16} />
        <p className="text-xs font-semibold text-foreground">Google Hesaplarım</p>
      </div>
      <div className="px-6 space-y-2">
        {GOOGLE_ACCOUNTS.map((acc) => (
          <button key={acc.email} onClick={() => handleAccountSelect(acc)}
            className="w-full flex items-center gap-4 bg-card border border-border rounded-2xl px-4 py-3.5 text-left transition-all active:scale-[0.98] shadow-sm">
            <div className="w-11 h-11 rounded-full flex items-center justify-center text-sm font-extrabold text-white shrink-0"
              style={{ background: acc.avatarColor }}>{acc.avatar}</div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-extrabold text-foreground">{acc.name}</p>
              <p className="text-xs text-muted-foreground">{acc.email}</p>
            </div>
            <ChevronRight size={16} className="text-muted-foreground shrink-0" />
          </button>
        ))}
        <button className="w-full flex items-center gap-4 bg-card border border-dashed border-border rounded-2xl px-4 py-3.5 text-left">
          <div className="w-11 h-11 rounded-full bg-muted flex items-center justify-center shrink-0">
            <Plus size={18} className="text-muted-foreground" />
          </div>
          <p className="text-sm font-semibold text-muted-foreground">Başka bir hesap kullan</p>
        </button>
      </div>
      <div className="px-6 mt-6">
        <p className="text-xs text-muted-foreground text-center leading-relaxed">
          Devam ederek <span className="text-primary font-semibold">Kullanım Koşulları</span>{" "}ve{" "}
          <span className="text-primary font-semibold">Gizlilik Politikası</span>{"'"}nı kabul etmiş olursunuz.
        </p>
      </div>
    </div>
  );

  // step === "signin" — Giriş / Kayıt Ol tabbed screen
  return (
    <div className="flex flex-col h-full bg-background">
      <div className="shrink-0 relative h-44 overflow-hidden">
        <div className="absolute inset-0" style={{
          background: "linear-gradient(145deg, #1a6b4a 0%, #124a34 60%, #f4a832 130%)",
          borderBottomLeftRadius: "60% 30%",
          borderBottomRightRadius: "60% 30%",
        }} />
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <div className="w-16 h-16 rounded-2xl bg-white/95 flex items-center justify-center mb-2 shadow-lg overflow-hidden">
            <ImageWithFallback src={appIcon} alt="EngelsizClub" className="w-full h-full object-cover scale-150 origin-center translate-y-2" />
          </div>
          <p className="text-xl font-extrabold text-white">EngelsizClub</p>
          <p className="text-xs text-white/70 mt-0.5">Özel gereksinimli kahramanlarımız için</p>
        </div>
      </div>

      {/* Tab switcher */}
      <div className="px-5 pt-5 pb-3 shrink-0">
        <div className="flex rounded-2xl bg-muted p-1 gap-1">
          {(["giris","kayit"] as const).map((t) => (
            <button key={t} onClick={() => setAuthTab(t)}
              className="flex-1 py-2.5 rounded-xl text-sm font-extrabold transition-all"
              style={authTab === t
                ? { background: "#1a6b4a", color: "#fff", boxShadow: "0 2px 8px #1a6b4a44" }
                : { color: "#4d7a62" }}>
              {t === "giris" ? "Giriş Yap" : "Üye Ol"}
            </button>
          ))}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pb-4">
        {authTab === "giris" ? (
          <div className="space-y-3">
            {/* Hesap tipi seçimi — her zaman görünür */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Hesap Türü</p>
              <div className="flex gap-2">
                {([
                  { id: "aile" as const, emoji: "👨‍👩‍👧", label: "Aile", desc: "Destek ara" },
                  { id: "uzman" as const, emoji: "🏥", label: "Uzman", desc: "Hizmet ver" },
                  { id: "bakici" as const, emoji: "🤲", label: "Bakıcı", desc: "Bakım ver" },
                ]).map((t) => (
                  <button key={t.id} onClick={() => setGirisHesapTip(t.id)}
                    className="flex-1 flex flex-col items-center py-2.5 px-1 rounded-xl border-2 text-xs font-bold transition-all"
                    style={girisHesapTip === t.id
                      ? { borderColor: "#1a6b4a", background: "#e8f5ee", color: "#1a6b4a" }
                      : { borderColor: "rgba(26,107,74,0.2)", color: "#4d7a62" }}>
                    <span className="text-xl mb-0.5">{t.emoji}</span>
                    <span className="font-extrabold">{t.label}</span>
                    <span className="font-normal text-[10px]">{t.desc}</span>
                  </button>
                ))}
              </div>
            </div>

            {girisHesapTip && (
              <>
                <button onClick={handleGoogleTap}
                  className="w-full flex items-center justify-center gap-3 bg-white border border-[#dadce0] rounded-2xl py-3.5 shadow-sm active:scale-[0.98] transition-all">
                  <GoogleIcon size={20} />
                  <span className="text-sm font-bold text-[#3c4043]">Google ile devam et</span>
                </button>
                <div className="flex items-center gap-3">
                  <div className="flex-1 h-px bg-border" />
                  <span className="text-xs text-muted-foreground">veya e-posta ile</span>
                  <div className="flex-1 h-px bg-border" />
                </div>
                <input value={girisEmail} onChange={(e) => setGirisEmail(e.target.value)} className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none" placeholder="E-posta adresiniz" type="email" />
                <input value={girisSifre} onChange={(e) => setGirisSifre(e.target.value)} className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none" placeholder="Şifre" type="password" />
                <button className="w-full py-4 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm shadow-md active:scale-[0.98] transition-all">
                  Giriş Yap
                </button>
                <p className="text-center text-xs text-muted-foreground">
                  Şifrenizi mi unuttunuz? <span className="text-primary font-extrabold">Sıfırla</span>
                </p>
              </>
            )}
            {!girisHesapTip && (
              <p className="text-center text-xs text-muted-foreground pt-2">
                Devam etmek için lütfen hesap türünüzü seçin.
              </p>
            )}
          </div>
        ) : (
          <div className="space-y-3">
            <button onClick={handleGoogleTap}
              className="w-full flex items-center justify-center gap-3 bg-white border border-[#dadce0] rounded-2xl py-3.5 shadow-sm active:scale-[0.98] transition-all">
              <GoogleIcon size={20} />
              <span className="text-sm font-bold text-[#3c4043]">Google ile hızlı kayıt</span>
            </button>
            <div className="flex items-center gap-3">
              <div className="flex-1 h-px bg-border" />
              <span className="text-xs text-muted-foreground">veya formu doldurun</span>
              <div className="flex-1 h-px bg-border" />
            </div>

            {/* Hesap tipi */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Hesap Türü</p>
              <div className="flex gap-2">
                {([
                  { id: "aile" as const, emoji: "👨‍👩‍👧", label: "Aile", desc: "Uzman & destek ara" },
                  { id: "uzman" as const, emoji: "🏥", label: "Uzman", desc: "İlan ver & teklif al" },
                ]).map((t) => (
                  <button key={t.id} onClick={() => setKayitTip(t.id)}
                    className="flex-1 flex flex-col items-center py-3 px-2 rounded-xl border-2 text-xs font-bold transition-all"
                    style={kayitTip === t.id
                      ? { borderColor: "#1a6b4a", background: "#e8f5ee", color: "#1a6b4a" }
                      : { borderColor: "rgba(26,107,74,0.2)", color: "#4d7a62" }}>
                    <span className="text-xl mb-0.5">{t.emoji}</span>
                    <span className="font-extrabold">{t.label}</span>
                    <span className="font-normal text-[10px] mt-0.5 text-center">{t.desc}</span>
                  </button>
                ))}
              </div>
            </div>

            <input value={kayitAd} onChange={(e) => setKayitAd(e.target.value)}
              className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none"
              placeholder="Ad Soyad" type="text" />
            <input value={kayitEmail} onChange={(e) => setKayitEmail(e.target.value)}
              className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none"
              placeholder="E-posta adresiniz" type="email" />
            <input value={kayitSifre} onChange={(e) => setKayitSifre(e.target.value)}
              className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none"
              placeholder="Şifre (en az 8 karakter)" type="password" />
            <input value={kayitSifre2} onChange={(e) => setKayitSifre2(e.target.value)}
              className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm placeholder:text-muted-foreground outline-none"
              placeholder="Şifreyi tekrar girin" type="password" />

            {kayitTip === "uzman" && (
              <select className="w-full bg-card border border-border rounded-xl px-4 py-3.5 text-sm text-foreground outline-none">
                <option value="">Uzmanlık Alanı Seçin</option>
                {["Fizyoterapist","Ergoterapist","Dil ve Konuşma Terapisti","Özel Eğitim Öğretmeni","Çocuk Psikologu","Çocuk Psikiyatristi","Nörolog","Bakıcı"].map((u) => <option key={u}>{u}</option>)}
              </select>
            )}

            {/* KVKK onay */}
            <label className="flex items-start gap-2.5 cursor-pointer">
              <button onClick={() => setKayitSozlesme(!kayitSozlesme)}
                className="w-5 h-5 rounded-md border-2 flex items-center justify-center shrink-0 mt-0.5 transition-all"
                style={kayitSozlesme ? { background: "#1a6b4a", borderColor: "#1a6b4a" } : { borderColor: "#4d7a62" }}>
                {kayitSozlesme && <CheckCircle size={11} className="text-white" />}
              </button>
              <p className="text-xs text-muted-foreground leading-relaxed">
                <span className="text-primary font-semibold">Kullanım Koşulları</span>{"'"}nı,{" "}
                <span className="text-primary font-semibold">Gizlilik Politikası</span>{"'"}nı ve{" "}
                <span className="text-primary font-semibold">KVKK Aydınlatma Metni</span>{"'"}ni okudum, kabul ediyorum.
              </p>
            </label>

            {/* Güven göstergesi */}
            <div className="bg-muted rounded-2xl px-4 py-3 flex items-center gap-3">
              <Shield size={16} className="text-primary shrink-0" />
              <div>
                <p className="text-xs font-extrabold text-foreground">Kişisel verileriniz güvende</p>
                <p className="text-[10px] text-muted-foreground">256-bit şifreleme · KVKK uyumlu · Reklam yok</p>
              </div>
            </div>

            <button
              onClick={() => {
                if (!kayitAd || !kayitEmail || !kayitSifre || !kayitSozlesme) return;
                setKayitLoading(true);
                setTimeout(() => {
                  setKayitLoading(false);
                  const initials = kayitAd.split(" ").map((w: string) => w[0]).join("").slice(0,2).toUpperCase();
                  onLogin({ name: kayitAd, email: kayitEmail, avatar: initials, avatarColor: "#1a6b4a", userType: kayitTip });
                }, 1600);
              }}
              disabled={!kayitSozlesme || kayitLoading}
              className="w-full py-4 rounded-2xl font-extrabold text-sm shadow-md flex items-center justify-center gap-2 transition-all active:scale-[0.98]"
              style={{ background: kayitSozlesme ? "#1a6b4a" : "#dceee4", color: kayitSozlesme ? "#fff" : "#4d7a62" }}>
              {kayitLoading
                ? <><div className="w-4 h-4 rounded-full border-2 border-white/40 border-t-white animate-spin" /> Hesap Oluşturuluyor…</>
                : "Hesap Oluştur"}
            </button>
          </div>
        )}
      </div>

      <div className="px-5 pb-5 shrink-0">
        <p className="text-xs text-muted-foreground text-center">
          Ücretsiz · Reklamsız · <span className="text-primary font-semibold">Güvenli</span>
        </p>
      </div>
    </div>
  );
}

// ─── UZMAN PROFİL ────────────────────────────────────────────────────────────

const uzmanProfilData = {
  uzmanlik: "Fizyoterapist",
  deneyim: "8 yıl",
  sehir: "Ankara",
  ilceler: ["Çankaya", "Yenimahalle", "Keçiören"],
  rating: 4.9,
  reviewCount: 47,
  completedJobs: 124,
  responseTime: "~2 saat",
  acceptRate: "%91",
  bio: "Çocuk nörolojik fizyoterapisi alanında 8 yıllık deneyime sahibim. NDT (Bobath) ve Vojta sertifikalarım bulunmaktadır. Serebral palsi, Down sendromu ve gelişimsel gecikme tanılı çocuklarla yoğun olarak çalışmaktayım. Evde ve merkezde seans verebiliyorum.",
  sertifikalar: ["NDT / Bobath Sertifikası", "Vojta Terapi Sertifikası", "Hacettepe Üni. Fizyoterapi Böl.", "Pediatrik FTR Uzmanlık Kursu"],
  hizmetler: [
    { ad: "Evde Bireysel Seans", sure: "50 dk", fiyat: "₺550", aciklama: "Evinizde birebir fizyoterapi seansı" },
    { ad: "Merkez Seansı", sure: "50 dk", fiyat: "₺400", aciklama: "Kliniğimizde bireysel seans" },
    { ad: "Online Değerlendirme", sure: "30 dk", fiyat: "₺200", aciklama: "Video görüşmesiyle ilk değerlendirme" },
    { ad: "Ev Egzersiz Programı", sure: "Paket", fiyat: "₺350", aciklama: "Aileye özel aylık egzersiz planı" },
  ],
  reviews: [
    { author: "Ayşe Y.", avatar: "AY", avatarColor: "#e07a5f", rating: 5, date: "1 hafta önce", text: "Oğlumun SP tanısından bu yana çalıştığımız en iyi fizyoterapist. Hem çok bilgili hem de çocuklarla iletişimi mükemmel." },
    { author: "Fatma K.", avatar: "FK", avatarColor: "#9c6db3", rating: 5, date: "3 hafta önce", text: "NDT sertifikası gerçekten fark yaratıyor. 3 ay içinde kızımda gözle görülür gelişme oldu." },
    { author: "Kemal D.", avatar: "KD", avatarColor: "#6b9ac4", rating: 5, date: "1 ay önce", text: "Evde seans imkanı harika. Zamanında geliyor, aile olarak bizimle de çok iyi iletişim kuruyor." },
    { author: "Selin M.", avatar: "SM", avatarColor: "#f4a832", rating: 4, date: "2 ay önce", text: "Çok profesyonel, randevu esnekliği biraz kısıtlı olabiliyor ama kalitesi tartışılmaz." },
  ],
  aktifIlanlar: [
    { baslik: "Evde Fizyoterapist — SP Deneyimli", sehir: "Ankara / Çankaya", tarih: "Aktif", teklifler: 2 },
    { baslik: "NDT Sertifikalı FTR Uzmanı", sehir: "Ankara / Yenimahalle", tarih: "Aktif", teklifler: 5 },
  ],
};

function UzmanProfil({ user, initials, onLogout }: { user: AuthUser; initials: string; onLogout: () => void }) {
  const [activeSection, setActiveSection] = useState<"profil" | "ilanlar" | "teklifler">("profil");
  const [showYeniHizmet, setShowYeniHizmet] = useState(false);
  const d = uzmanProfilData;

  const avgR = d.reviews.reduce((s, r) => s + r.rating, 0) / d.reviews.length;

  return (
    <div className="flex flex-col h-full overflow-y-auto">

      {/* ── Header banner ── */}
      <div className="relative shrink-0" style={{ background: "linear-gradient(145deg, #1a6b4a 0%, #124a34 100%)" }}>
        <div className="px-5 pt-6 pb-5">
          <div className="flex items-start justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-xl font-extrabold text-white shadow-lg border-2 border-white/30"
                style={{ background: user.avatarColor }}>{initials}</div>
              <div>
                <div className="flex items-center gap-2">
                  <p className="text-lg font-extrabold text-white">{user.name}</p>
                  <BadgeCheck size={16} className="text-emerald-300" />
                </div>
                <p className="text-sm text-white/70">{d.uzmanlik} · {d.deneyim}</p>
                <div className="flex items-center gap-1 mt-0.5">
                  <StarRow rating={avgR} size={12} />
                  <span className="text-xs font-bold text-white">{avgR.toFixed(1)}</span>
                  <span className="text-xs text-white/60">({d.reviewCount})</span>
                </div>
              </div>
            </div>
            <button className="px-3 py-1.5 rounded-xl bg-white/15 border border-white/20 text-xs font-bold text-white">
              Düzenle
            </button>
          </div>

          {/* Key stats */}
          <div className="grid grid-cols-3 gap-2">
            {[
              { val: d.completedJobs, label: "Tamamlanan İş" },
              { val: d.responseTime, label: "Yanıt Süresi" },
              { val: d.acceptRate, label: "Kabul Oranı" },
            ].map((s) => (
              <div key={s.label} className="bg-white/10 rounded-2xl py-2.5 px-2 text-center">
                <p className="text-base font-extrabold text-white">{s.val}</p>
                <p className="text-xs text-white/60 leading-tight">{s.label}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Segmented control */}
        <div className="flex border-t border-white/15">
          {([["profil", "Profil"], ["ilanlar", "İlanlarım"], ["teklifler", "Teklifler"]] as const).map(([id, label]) => (
            <button key={id} onClick={() => setActiveSection(id)}
              className="flex-1 py-3 text-xs font-extrabold transition-all"
              style={activeSection === id
                ? { color: "#fff", borderBottom: "2px solid #fff" }
                : { color: "rgba(255,255,255,0.5)" }}>
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* ── PROFİL SEKMESİ ── */}
      {activeSection === "profil" && (
        <div className="px-4 pb-6 space-y-4 pt-4">

          {/* Konum */}
          <div className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-2">Hizmet Bölgesi</p>
            <div className="flex items-center gap-2 mb-2">
              <MapPin size={14} className="text-primary shrink-0" />
              <p className="text-sm font-bold text-foreground">{d.sehir}</p>
            </div>
            <div className="flex flex-wrap gap-1.5">
              {d.ilceler.map((i) => (
                <span key={i} className="text-xs px-2.5 py-1 rounded-full bg-primary/10 text-primary font-semibold">{i}</span>
              ))}
            </div>
          </div>

          {/* Bio */}
          <div className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-2">Hakkımda</p>
            <p className="text-sm text-foreground leading-relaxed">{d.bio}</p>
          </div>

          {/* Sertifikalar */}
          <div className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-3">Sertifikalar & Eğitim</p>
            <div className="space-y-2">
              {d.sertifikalar.map((s) => (
                <div key={s} className="flex items-center gap-2.5">
                  <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                    <BadgeCheck size={13} className="text-primary" />
                  </div>
                  <p className="text-sm text-foreground font-semibold">{s}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Hizmetler & Fiyatlar — Armut tarzı */}
          <div className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm">
            <div className="flex items-center justify-between px-4 pt-4 pb-3 border-b border-border">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Hizmetler & Fiyatlar</p>
              <button onClick={() => setShowYeniHizmet(!showYeniHizmet)}
                className="text-xs font-extrabold text-primary bg-primary/10 px-2.5 py-1 rounded-full">
                + Ekle
              </button>
            </div>
            {showYeniHizmet && (
              <div className="px-4 py-3 bg-muted/50 border-b border-border space-y-2">
                <input className="w-full bg-card border border-border rounded-xl px-3 py-2 text-sm placeholder:text-muted-foreground" placeholder="Hizmet adı" />
                <div className="flex gap-2">
                  <input className="flex-1 bg-card border border-border rounded-xl px-3 py-2 text-sm placeholder:text-muted-foreground" placeholder="Süre (dk)" />
                  <input className="flex-1 bg-card border border-border rounded-xl px-3 py-2 text-sm placeholder:text-muted-foreground" placeholder="Fiyat (₺)" />
                </div>
                <button className="w-full py-2.5 rounded-xl bg-primary text-primary-foreground font-extrabold text-xs">Kaydet</button>
              </div>
            )}
            <div className="divide-y divide-border">
              {d.hizmetler.map((h) => (
                <div key={h.ad} className="px-4 py-3.5 flex items-center justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-extrabold text-foreground">{h.ad}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{h.aciklama} · {h.sure}</p>
                  </div>
                  <div className="text-right shrink-0">
                    <p className="text-base font-extrabold text-primary">{h.fiyat}</p>
                    <p className="text-xs text-muted-foreground">seans</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Puan dağılımı */}
          <div className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide">Yorumlar</p>
              <div className="flex items-center gap-1">
                <span className="text-2xl font-extrabold text-foreground">{avgR.toFixed(1)}</span>
                <span className="text-xs text-muted-foreground">/ 5</span>
              </div>
            </div>
            <RatingBreakdown reviews={d.reviews} />
          </div>

          <div className="space-y-3">
            {d.reviews.map((r, i) => (
              <div key={i} className="bg-card border border-border rounded-2xl p-4 shadow-sm">
                <div className="flex items-center gap-2.5 mb-2">
                  <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-extrabold text-white shrink-0"
                    style={{ background: r.avatarColor }}>{r.avatar}</div>
                  <div>
                    <p className="text-xs font-extrabold text-foreground">{r.author}</p>
                    <div className="flex items-center gap-1">
                      <StarRow rating={r.rating} size={11} />
                      <span className="text-xs text-muted-foreground">{r.date}</span>
                    </div>
                  </div>
                </div>
                <p className="text-xs text-foreground leading-relaxed">{r.text}</p>
              </div>
            ))}
          </div>

          <button onClick={onLogout}
            className="w-full flex items-center gap-4 bg-red-50 border border-red-100 rounded-2xl px-4 py-3.5 text-left shadow-sm">
            <span className="text-xl shrink-0">🚪</span>
            <p className="text-sm font-extrabold text-red-600">Çıkış Yap</p>
          </button>
        </div>
      )}

      {/* ── İLANLARIM SEKMESİ ── */}
      {activeSection === "ilanlar" && (
        <div className="px-4 pb-6 pt-4 space-y-3">
          <div className="flex items-center justify-between mb-1">
            <p className="text-sm font-extrabold text-foreground">Aktif İlanlarım</p>
            <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-primary text-primary-foreground text-xs font-extrabold">
              <Plus size={13} /> Yeni İlan
            </button>
          </div>

          {d.aktifIlanlar.map((ilan, i) => (
            <div key={i} className="bg-card border border-border rounded-2xl p-4 shadow-sm">
              <div className="flex items-start justify-between gap-2 mb-3">
                <p className="text-sm font-extrabold text-foreground leading-tight flex-1">{ilan.baslik}</p>
                <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-green-50 text-green-700 shrink-0">● Aktif</span>
              </div>
              <div className="flex items-center gap-3 text-xs text-muted-foreground mb-3">
                <span className="flex items-center gap-1"><MapPin size={10} />{ilan.sehir}</span>
                <span className="flex items-center gap-1"><Coins size={10} />{ilan.teklifler} teklif</span>
              </div>
              <div className="flex gap-2">
                <button className="flex-1 py-2 rounded-xl border border-border text-xs font-bold text-foreground">Düzenle</button>
                <button className="flex-1 py-2 rounded-xl bg-primary/10 text-xs font-bold text-primary">Teklifleri Gör</button>
              </div>
            </div>
          ))}

          {/* Yeni ilan formu */}
          <div className="bg-card border border-dashed border-primary/30 rounded-2xl p-4">
            <p className="text-sm font-extrabold text-foreground mb-1">Yeni İlan Ver</p>
            <p className="text-xs text-muted-foreground mb-3">Aile ilanlarına görünür olun, teklif verin.</p>
            <div className="space-y-2 mb-3">
              <input className="w-full bg-background border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground" placeholder="İlan başlığı" />
              <div className="flex gap-2">
                <input className="flex-1 bg-background border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground" placeholder="Şehir" />
                <input className="flex-1 bg-background border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground" placeholder="İlçe" />
              </div>
              <input className="w-full bg-background border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground" placeholder="Seans ücreti (₺)" />
              <textarea rows={3} className="w-full bg-background border border-border rounded-xl px-3 py-2.5 text-sm placeholder:text-muted-foreground resize-none"
                placeholder="Kendinizi tanıtın, uzmanlık alanlarınızı yazın..." />
            </div>
            <button className="w-full py-3.5 rounded-2xl bg-primary text-primary-foreground font-extrabold text-sm shadow-md flex items-center justify-center gap-2">
              <Send size={15} /> İlanı Yayınla
            </button>
          </div>
        </div>
      )}

      {/* ── TEKLİFLER SEKMESİ ── */}
      {activeSection === "teklifler" && (
        <div className="px-4 pb-6 pt-4 space-y-3">
          <p className="text-sm font-extrabold text-foreground mb-1">Gelen Talepler</p>

          {[
            { aile: "Ayşe Y.", avatar: "AY", color: "#e07a5f", tanı: "Serebral Palsi", lokasyon: "Çankaya, Ankara", seans: "Haftada 3", butce: "₺400–600", aciliyet: true, sure: "2 saat önce" },
            { aile: "Mehmet K.", avatar: "MK", color: "#6b9ac4", tanı: "Down Sendromu", lokasyon: "Yenimahalle, Ankara", seans: "Haftada 2", butce: "₺350–500", aciliyet: false, sure: "5 saat önce" },
            { aile: "Leyla D.", avatar: "LD", color: "#9c6db3", tanı: "Gelişim Geriliği", lokasyon: "Keçiören, Ankara", seans: "Haftada 4", butce: "₺450–650", aciliyet: false, sure: "1 gün önce" },
          ].map((t, i) => (
            <div key={i} className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
              <div className="p-4">
                <div className="flex items-start gap-3 mb-3">
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center text-sm font-extrabold text-white shrink-0"
                    style={{ background: t.color }}>{t.avatar}</div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-extrabold text-foreground">{t.aile} ailesi</p>
                      {t.aciliyet && <span className="text-xs font-bold text-red-500 flex items-center gap-0.5"><Sparkles size={10} />Acil</span>}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1"><MapPin size={9} />{t.lokasyon}</span>
                      <span>·</span>
                      <span>{t.sure}</span>
                    </div>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 mb-3">
                  {[
                    { label: "Tanı", val: t.tanı },
                    { label: "Seans Sıklığı", val: t.seans },
                    { label: "Bütçe", val: t.butce + "/seans" },
                    { label: "Konum", val: t.lokasyon.split(",")[0] },
                  ].map((item) => (
                    <div key={item.label} className="bg-muted/60 rounded-xl px-3 py-2">
                      <p className="text-xs text-muted-foreground">{item.label}</p>
                      <p className="text-xs font-bold text-foreground">{item.val}</p>
                    </div>
                  ))}
                </div>
              </div>
              <div className="flex gap-2 px-4 pb-4">
                <button className="flex-1 py-2.5 rounded-xl border border-border text-xs font-bold text-muted-foreground">Reddet</button>
                <button className="flex-1 py-2.5 rounded-xl bg-primary text-primary-foreground text-xs font-extrabold flex items-center justify-center gap-1.5 shadow-sm">
                  <Send size={12} /> Teklif Ver
                </button>
              </div>
            </div>
          ))}

          {/* Kazanç özeti */}
          <div className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-3 flex items-center gap-2">
              <Coins size={13} className="text-primary" /> Bu Ay
            </p>
            <div className="grid grid-cols-3 gap-2 text-center">
              {[{ val: "₺8.400", label: "Kazanç" }, { val: "18", label: "Seans" }, { val: "6", label: "Müşteri" }].map((s) => (
                <div key={s.label}>
                  <p className="text-base font-extrabold text-primary">{s.val}</p>
                  <p className="text-xs text-muted-foreground">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── MAIN APP ────────────────────────────────────────────────────────────────

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>("home");
  const [user, setUser] = useState<AuthUser | null>(null);

  const tabs: { id: Tab; label: string; icon: typeof Home }[] = [
    { id: "home", label: "Anasayfa", icon: Home },
    { id: "merkezler", label: "Harita", icon: MapPin },
    { id: "ilanlar", label: "İlanlar", icon: Briefcase },
    { id: "forum", label: "Forum", icon: MessageCircle },
    { id: "haklar", label: "Haklar", icon: Scale },
    { id: "kartlar", label: "Kartlar", icon: LayoutGrid },
  ];

  const [ilanlarUnread, setIlanlarUnread] = useState(0);
  const initials = user ? user.name.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase() : "?";
  const [showProfilPanel, setShowProfilPanel] = useState(false);
  const [krediSatin, setKrediSatin] = useState(false);
  const [krediStep, setKrediStep] = useState<"paket" | "kart" | "basarili">("paket");
  const [seciliPaket, setSeciliPaket] = useState<{ adet: number; fiyat: string } | null>(null);
  const [userKredi, setUserKredi] = useState(0);
  const [krediHosBonusGosterildi, setKrediHosBonusGosterildi] = useState(false);
  const [kartNo, setKartNo]     = useState("");
  const [kartAd, setKartAd]     = useState("");
  const [kartSkt, setKartSkt]   = useState("");
  const [kartCvv, setKartCvv]   = useState("");
  const [odemeYukleniyor, setOdemeYukleniyor] = useState(false);

  function formatKartNo(v: string) {
    return v.replace(/\D/g, "").slice(0, 16).replace(/(.{4})/g, "$1 ").trim();
  }
  function formatSkt(v: string) {
    return v.replace(/\D/g, "").slice(0, 4).replace(/^(.{2})(.+)/, "$1/$2");
  }
  function kartValid() {
    return kartNo.replace(/\s/g, "").length === 16 && kartAd.trim().length > 3 && kartSkt.length === 5 && kartCvv.length >= 3;
  }
  function handleOde() {
    if (!kartValid() || !seciliPaket) return;
    setOdemeYukleniyor(true);
    setTimeout(() => {
      setUserKredi((k) => k + seciliPaket.adet);
      setOdemeYukleniyor(false);
      setKrediStep("basarili");
    }, 1800);
  }
  function resetKredi() {
    setKrediSatin(false);
    setKrediStep("paket");
    setSeciliPaket(null);
    setKartNo(""); setKartAd(""); setKartSkt(""); setKartCvv("");
  }

  const krediPaketleri = [
    { adet: 1,  fiyat: "₺49,90",  birim: "₺49,90/kredi", desc: "Tek teklif için" },
    { adet: 5,  fiyat: "₺199,90", birim: "₺39,98/kredi", desc: "En çok tercih edilen · %20 indirim", popular: true },
    { adet: 10, fiyat: "₺349,90", birim: "₺34,99/kredi", desc: "Avantajlı paket · %30 indirim" },
  ];

  return (
    <div
      className="flex justify-center items-center min-h-screen bg-muted/40"
      style={{ fontFamily: "'Nunito', sans-serif" }}
    >
      <div
        className="relative flex flex-col bg-background overflow-hidden shadow-2xl"
        style={{
          width: "min(420px, 100vw)",
          height: "min(860px, 100dvh)",
          borderRadius: "clamp(0px, 2vw, 2rem)",
        }}
      >
        {!user ? (
          <AuthScreen onLogin={(u) => {
            setUser(u);
            setActiveTab("home");
            const isProf = u.userType === "uzman" || u.userType === "bakici";
            setUserKredi(isProf ? 10 : 3);
            if (isProf) setKrediHosBonusGosterildi(false);
          }} />
        ) : (
          <>
            {/* Status bar */}
            <div className="flex items-center justify-between px-4 pt-3 pb-1 shrink-0">
              <div className="flex items-center gap-1.5">
                <div className="w-5 h-5 rounded-md overflow-hidden shrink-0 bg-white flex items-center justify-center">
                  <ImageWithFallback src={appIcon} alt="EngelsizClub" className="w-full h-full object-cover scale-150 origin-center translate-y-2" />
                </div>
                <span className="text-xs font-bold text-foreground">9:41</span>
              </div>
              <div className="flex items-center gap-3">
                <span className="text-xs font-bold text-foreground">●●●</span>
                <button onClick={() => setShowProfilPanel(true)}
                  className="w-7 h-7 rounded-full flex items-center justify-center text-primary-foreground text-xs font-extrabold ring-2 ring-white/60"
                  style={{ background: user.avatarColor }}>
                  {initials}
                </button>
              </div>
            </div>

            {/* Profil Panel Overlay */}
            {showProfilPanel && (
              <div className="absolute inset-0 z-50 flex flex-col" style={{ borderRadius: "inherit" }}>
                <div className="absolute inset-0 bg-black/40" onClick={() => { setShowProfilPanel(false); setKrediSatin(false); }} />
                <div className="relative mt-auto bg-card rounded-t-3xl max-h-[90%] flex flex-col shadow-2xl" onClick={(e) => e.stopPropagation()}>
                  {/* Handle */}
                  <div className="w-10 h-1 rounded-full bg-muted mx-auto mt-3 mb-1 shrink-0" />

                  <div className="overflow-y-auto flex-1 px-5 pb-6">
                    {!krediSatin ? (
                      <>
                        {/* Avatar + isim */}
                        <div className="flex items-center gap-4 pt-4 pb-5 border-b border-border">
                          <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-2xl font-extrabold text-white shadow-md shrink-0"
                            style={{ background: user.avatarColor }}>
                            {initials}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-base font-extrabold text-foreground">{user.name}</p>
                            <div className="flex items-center gap-1 mt-0.5">
                              <GoogleIcon size={12} />
                              <p className="text-xs text-muted-foreground truncate">{user.email}</p>
                            </div>
                            <div className="flex items-center gap-1.5 mt-1.5">
                              <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-bold">
                                {user.userType === "aile" ? "👨‍👩‍👧 Aile" : "💼 Uzman"}
                              </span>
                              <span className="text-xs px-2 py-0.5 rounded-full bg-green-50 text-green-700 font-bold flex items-center gap-1">
                                <BadgeCheck size={10} /> Doğrulandı
                              </span>
                            </div>
                          </div>
                        </div>

                        {/* Hoş geldin bonus bildirimi — uzman/bakıcı */}
                        {(user.userType === "uzman" || user.userType === "bakici") && !krediHosBonusGosterildi && (
                          <div className="mt-4 rounded-2xl p-4 flex items-start gap-3 shadow-md"
                            style={{ background: "linear-gradient(135deg,#f4a832,#e8932a)" }}>
                            <span className="text-2xl shrink-0">🎁</span>
                            <div className="flex-1">
                              <p className="text-sm font-extrabold text-white">Hoş Geldin Hediyesi!</p>
                              <p className="text-xs text-white/85 mt-0.5">Sisteme kayıt olduğunuz için hesabınıza <strong>10 ücretsiz kredi</strong> tanımlandı.</p>
                              <p className="text-[10px] text-white/70 mt-1">1 kredi = 1 teklif = ₺49,90 değerinde</p>
                            </div>
                            <button onClick={() => setKrediHosBonusGosterildi(true)}
                              className="shrink-0 w-6 h-6 rounded-full bg-white/20 flex items-center justify-center">
                              <X size={12} className="text-white" />
                            </button>
                          </div>
                        )}

                        {/* Kredi bilgisi */}
                        <div className="mt-4 bg-gradient-to-r from-primary to-[#124a34] rounded-2xl p-4 flex items-center justify-between shadow-md">
                          <div>
                            <p className="text-xs text-white/70 font-semibold">Mevcut Krediniz</p>
                            <p className="text-3xl font-extrabold text-white mt-0.5">{userKredi} <span className="text-base font-bold">kredi</span></p>
                            <p className="text-xs text-white/60 mt-0.5">1 kredi = 1 teklif · ₺49,90 değerinde</p>
                          </div>
                          <div className="w-14 h-14 rounded-2xl bg-white/15 flex items-center justify-center text-3xl shrink-0">
                            🪙
                          </div>
                        </div>

                        <button
                          onClick={() => setKrediSatin(true)}
                          className="w-full mt-3 py-3.5 rounded-2xl bg-amber-500 text-white font-extrabold text-sm flex items-center justify-center gap-2 shadow-md"
                        >
                          <Coins size={16} /> Kredi Yükle
                        </button>

                        {/* Profil menüsü */}
                        <div className="mt-4 space-y-2">
                          {[
                            { emoji: "👶", label: "Çocuk Profilim", sub: "Tanı ve gelişim bilgileri" },
                            { emoji: "📋", label: "İlanlarım", sub: "2 aktif ilan" },
                            { emoji: "❤️", label: "Kaydedilenler", sub: "8 ilan favorilendi" },
                            { emoji: "🔔", label: "Bildirimler", sub: "Açık" },
                            { emoji: "🔒", label: "Gizlilik & Güvenlik", sub: "Ayarlarınız" },
                          ].map((item) => (
                            <button key={item.label}
                              className="w-full flex items-center gap-4 bg-background border border-border rounded-2xl px-4 py-3 text-left">
                              <span className="text-xl shrink-0">{item.emoji}</span>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-extrabold text-foreground">{item.label}</p>
                                <p className="text-xs text-muted-foreground">{item.sub}</p>
                              </div>
                              <ChevronRight size={15} className="text-muted-foreground shrink-0" />
                            </button>
                          ))}
                          <button onClick={() => { setUser(null); setActiveTab("home"); setShowProfilPanel(false); }}
                            className="w-full flex items-center gap-4 bg-red-50 border border-red-100 rounded-2xl px-4 py-3 text-left mt-1">
                            <span className="text-xl">🚪</span>
                            <p className="text-sm font-extrabold text-red-600">Çıkış Yap</p>
                          </button>
                        </div>
                      </>
                    ) : (
                      <>
                        {/* Kredi yükleme — başlık */}
                        <div className="flex items-center gap-3 pt-4 pb-4 border-b border-border">
                          <button
                            onClick={() => { if (krediStep === "kart") setKrediStep("paket"); else resetKredi(); }}
                            className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0">
                            <ChevronRight size={16} className="rotate-180 text-foreground" />
                          </button>
                          <p className="text-base font-extrabold text-foreground">
                            {krediStep === "paket" ? "Kredi Yükle" : krediStep === "kart" ? "Kart Bilgileri" : "Ödeme Başarılı"}
                          </p>
                          {krediStep !== "basarili" && (
                            <span className="ml-auto text-xs font-bold text-muted-foreground">
                              {krediStep === "paket" ? "1/2" : "2/2"}
                            </span>
                          )}
                        </div>

                        {/* ADIM 1 — Paket seç */}
                        {krediStep === "paket" && (
                          <>
                            <div className="mt-4 bg-muted rounded-2xl px-4 py-3 flex items-center justify-between mb-5">
                              <p className="text-sm text-muted-foreground">Mevcut krediniz</p>
                              <p className="text-lg font-extrabold text-primary flex items-center gap-1.5"><Coins size={16} /> {userKredi} kredi</p>
                            </div>
                            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wide mb-3">Paket Seç</p>
                            <div className="space-y-3">
                              {krediPaketleri.map((p) => (
                                <button
                                  key={p.adet}
                                  onClick={() => { setSeciliPaket(p); setKrediStep("kart"); }}
                                  className="w-full flex items-center justify-between border-2 rounded-2xl px-4 py-3.5 transition-all"
                                  style={p.popular ? { borderColor: "#1a6b4a", background: "#e8f5ee" } : { borderColor: "rgba(26,107,74,0.18)", background: "#fff" }}
                                >
                                  <div className="text-left">
                                    <div className="flex items-center gap-2">
                                      <p className="text-base font-extrabold text-foreground">{p.adet} Kredi</p>
                                      {p.popular && <span className="text-xs px-2 py-0.5 rounded-full bg-primary text-white font-bold">Popüler</span>}
                                    </div>
                                    <p className="text-xs text-muted-foreground mt-0.5">{p.desc}</p>
                                    <p className="text-[10px] text-primary/70 font-semibold mt-0.5">{p.birim}</p>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <div className="text-right">
                                      <p className="text-base font-extrabold text-primary">{p.fiyat}</p>
                                    </div>
                                    <ChevronRight size={15} className="text-muted-foreground" />
                                  </div>
                                </button>
                              ))}
                            </div>
                            <div className="flex items-center justify-center gap-2 mt-4">
                              <span className="text-base">🔒</span>
                              <p className="text-xs text-muted-foreground">256-bit SSL şifreli güvenli ödeme</p>
                            </div>
                          </>
                        )}

                        {/* ADIM 2 — Kart bilgileri */}
                        {krediStep === "kart" && seciliPaket && (
                          <>
                            {/* Seçilen paket özeti */}
                            <div className="mt-4 rounded-2xl px-4 py-3 flex items-center justify-between mb-4"
                              style={{ background: "linear-gradient(135deg,#1a6b4a,#1a5c51)" }}>
                              <div>
                                <p className="text-xs text-white/70 font-semibold">Seçilen Paket</p>
                                <p className="text-base font-extrabold text-white mt-0.5">{seciliPaket.adet} Kredi</p>
                              </div>
                              <p className="text-2xl font-extrabold text-white">{seciliPaket.fiyat}</p>
                            </div>

                            <div className="space-y-3">
                              {/* Kart numarası */}
                              <div>
                                <p className="text-xs font-bold text-muted-foreground mb-1.5">Kart Numarası</p>
                                <div className="relative">
                                  <input
                                    value={kartNo}
                                    onChange={(e) => setKartNo(formatKartNo(e.target.value))}
                                    placeholder="0000 0000 0000 0000"
                                    inputMode="numeric"
                                    className="w-full bg-muted border border-border rounded-xl px-3 py-3 text-sm font-bold text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors tracking-widest pr-12"
                                  />
                                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-lg">
                                    {kartNo.startsWith("4") ? "💳" : kartNo.startsWith("5") ? "🟠" : "💳"}
                                  </span>
                                </div>
                              </div>

                              {/* Kart üzerindeki ad */}
                              <div>
                                <p className="text-xs font-bold text-muted-foreground mb-1.5">Kart Üzerindeki Ad</p>
                                <input
                                  value={kartAd}
                                  onChange={(e) => setKartAd(e.target.value.toUpperCase())}
                                  placeholder="AD SOYAD"
                                  className="w-full bg-muted border border-border rounded-xl px-3 py-3 text-sm font-bold text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors tracking-wide"
                                />
                              </div>

                              {/* SKT + CVV yan yana */}
                              <div className="grid grid-cols-2 gap-3">
                                <div>
                                  <p className="text-xs font-bold text-muted-foreground mb-1.5">Son Kullanma</p>
                                  <input
                                    value={kartSkt}
                                    onChange={(e) => setKartSkt(formatSkt(e.target.value))}
                                    placeholder="AA/YY"
                                    inputMode="numeric"
                                    className="w-full bg-muted border border-border rounded-xl px-3 py-3 text-sm font-bold text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors"
                                  />
                                </div>
                                <div>
                                  <p className="text-xs font-bold text-muted-foreground mb-1.5">CVV</p>
                                  <input
                                    value={kartCvv}
                                    onChange={(e) => setKartCvv(e.target.value.replace(/\D/g, "").slice(0, 4))}
                                    placeholder="•••"
                                    inputMode="numeric"
                                    type="password"
                                    className="w-full bg-muted border border-border rounded-xl px-3 py-3 text-sm font-bold text-foreground placeholder:text-muted-foreground outline-none focus:border-primary transition-colors"
                                  />
                                </div>
                              </div>
                            </div>

                            {/* Güvenlik rozetleri */}
                            <div className="flex items-center justify-center gap-4 mt-4 py-3 bg-muted rounded-2xl">
                              {["🔒 SSL", "🛡️ 3D Secure", "✅ PCI DSS"].map((b) => (
                                <span key={b} className="text-[10px] font-bold text-muted-foreground">{b}</span>
                              ))}
                            </div>

                            {/* Ödeme butonu */}
                            <button
                              onClick={handleOde}
                              disabled={!kartValid() || odemeYukleniyor}
                              className="w-full mt-4 py-4 rounded-2xl font-extrabold text-sm text-white flex items-center justify-center gap-2 shadow-lg disabled:opacity-40 transition-opacity"
                              style={{ background: "#1a6b4a" }}
                            >
                              {odemeYukleniyor
                                ? <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> İşleniyor...</>
                                : <><span>🔒</span> {seciliPaket.fiyat} Öde · {seciliPaket.adet} Kredi Al</>
                              }
                            </button>
                            <p className="text-[10px] text-muted-foreground text-center mt-2">
                              Kredi satın alındıktan sonra iade edilmez.
                            </p>
                          </>
                        )}

                        {/* ADIM 3 — Başarılı */}
                        {krediStep === "basarili" && seciliPaket && (
                          <div className="flex flex-col items-center text-center py-8 gap-4">
                            <div className="w-20 h-20 rounded-full bg-green-100 flex items-center justify-center text-4xl shadow-md">✅</div>
                            <div>
                              <p className="text-xl font-extrabold text-foreground">Ödeme Başarılı!</p>
                              <p className="text-sm text-muted-foreground mt-1">{seciliPaket.adet} kredi hesabınıza eklendi.</p>
                            </div>
                            <div className="bg-muted rounded-2xl px-6 py-4 w-full flex items-center justify-between">
                              <p className="text-sm text-muted-foreground">Yeni bakiyeniz</p>
                              <p className="text-2xl font-extrabold text-primary flex items-center gap-2">
                                <Coins size={20} /> {userKredi} kredi
                              </p>
                            </div>
                            <button
                              onClick={() => { resetKredi(); setShowProfilPanel(false); }}
                              className="w-full py-3.5 rounded-2xl font-extrabold text-sm text-white"
                              style={{ background: "#1a6b4a" }}>
                              Tamam
                            </button>
                          </div>
                        )}
                      </>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* Content area */}
            <div className="flex-1 overflow-hidden">
              {activeTab === "home" && <HomeTab />}
              {activeTab === "merkezler" && <MerkezlerTab />}
              {activeTab === "kartlar" && <KartlarTab />}
              {activeTab === "forum" && <ForumTab />}
              {activeTab === "haklar" && <HaklarTab />}
              {activeTab === "ilanlar" && <IlanlarTab onUnreadChange={setIlanlarUnread} userKredi={userKredi} onKrediHarca={() => setUserKredi((k) => Math.max(0, k - 1))} />}
              {activeTab === "profil" && user.userType === "aile" && (
                <AileProfilSection
                  user={user}
                  initials={initials}
                  onLogout={() => { setUser(null); setActiveTab("home"); }}
                />
              )}

              {activeTab === "profil" && user.userType === "uzman" && (
                <UzmanProfil user={user} initials={initials} onLogout={() => { setUser(null); setActiveTab("home"); }} />
              )}
            </div>

            {/* Bottom navigation */}
            <div className="shrink-0 bg-card border-t border-border px-1 pb-3 pt-1.5 shadow-[0_-6px_24px_rgba(0,0,0,0.08)]">
              <div className="flex items-end justify-around">
                {tabs.map((tab) => {
                  const active = activeTab === tab.id;
                  const badge = tab.id === "ilanlar" ? ilanlarUnread : 0;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => { setActiveTab(tab.id); if (tab.id === "ilanlar") setIlanlarUnread(0); }}
                      className="flex flex-col items-center gap-1 px-1 py-0.5 rounded-2xl transition-all"
                      style={{ minWidth: 52 }}
                    >
                      <div className="relative flex items-center justify-center rounded-2xl transition-all"
                        style={{
                          width: 48, height: 36,
                          background: active ? "#1a6b4a" : "transparent",
                          boxShadow: active ? "0 3px 14px #1a6b4a55" : "none",
                        }}>
                        <tab.icon
                          size={active ? 23 : 22}
                          strokeWidth={active ? 2.4 : 1.7}
                          style={{ color: active ? "#ffffff" : "#4d7a62" }}
                        />
                        {/* Mesaj bildirimi badge */}
                        {badge > 0 && !active && (
                          <span className="absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] rounded-full bg-red-500 text-white text-[10px] font-extrabold flex items-center justify-center px-1 border-2 border-card shadow-md z-10">
                            {badge > 9 ? "9+" : badge}
                          </span>
                        )}
                        {active && badge === 0 && (
                          <span className="absolute -top-0.5 -right-0.5 w-2.5 h-2.5 rounded-full bg-amber-400 border-2 border-card" />
                        )}
                      </div>
                      <span
                        className="text-[10px] font-bold leading-none tracking-tight"
                        style={{ color: active ? "#1a6b4a" : "#4d7a62" }}
                      >
                        {tab.label}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
