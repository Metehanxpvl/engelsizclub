import { useState } from "react";
import { X, CheckCircle, ArrowRight, RotateCcw, FileText } from "lucide-react";
import { allRights, COZGER_GRUPLARI } from "../data/rights";

type WizardStep = "yas" | "cozger" | "rate" | "age" | "income" | "results";

export function RightsSihirbazi({ onClose }: { onClose: () => void }) {
  const [step, setStep] = useState<WizardStep>("yas");
  const [yasGrubu, setYasGrubu] = useState<"" | "18alti" | "18ustu">("");
  const [cozgerGrup, setCozgerGrup] = useState("");
  const [rate, setRate]   = useState<"" | "40-69" | "70-89" | "90+">("");
  const [age,  setAge]    = useState<"" | "0-6" | "7-17" | "18+">("");
  const [income, setIncome] = useState<"" | "low" | "mid" | "high">("");

  const getRateNum = () => rate === "40-69" ? 55 : rate === "70-89" ? 80 : 95;
  const getAgeNum  = () => age === "0-6" ? 3 : age === "7-17" ? 12 : 20;
  const matchedRights = allRights.filter((r) => {
    if (yasGrubu === "18alti") {
      const minOran = cozgerGrup === "%20–39" ? 20 : cozgerGrup === "%40–49" ? 40 : cozgerGrup === "%50–59" ? 50 : cozgerGrup === "%60–69" ? 60 : cozgerGrup === "%70–79" ? 70 : cozgerGrup === "%80–89" ? 80 : 90;
      if (minOran < r.minRate) return false;
      if (getAgeNum() > r.maxAge) return false;
    } else {
      if (!rate) return false;
      if (getRateNum() < r.minRate) return false;
      if (getAgeNum() > r.maxAge) return false;
      if (r.incomeLimit && income === "high") return false;
    }
    return true;
  });

  const stepCount = yasGrubu === "18alti" ? 3 : 4;
  const stepIndex = step === "yas" ? 0 : step === "cozger" ? 1 : step === "age" ? 2 : step === "rate" ? 1 : step === "income" ? 2 : stepCount - 1;

  // Sonuçlar ekranı
  if (step === "results") return (
    <div className="absolute inset-0 z-50 bg-background flex flex-col">
      <div className="px-4 pt-6 pb-4 flex items-center gap-3 border-b border-border shrink-0">
        <button onClick={onClose} className="w-9 h-9 rounded-full bg-muted flex items-center justify-center"><X size={18} /></button>
        <h2 className="text-base font-extrabold text-foreground">Başvurabileceğiniz Haklar</h2>
      </div>
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        <div className="flex items-center gap-2 rounded-2xl px-4 py-3" style={{ background: "#1a6b4a12" }}>
          <CheckCircle size={16} className="text-primary shrink-0" />
          <p className="text-xs text-primary font-bold">{matchedRights.length} hak bulundu — seçimlerinize göre filtrelendi</p>
        </div>
        {yasGrubu === "18alti" && (
          <div className="rounded-2xl p-4 border" style={{ background: "#f5eefb", borderColor: "#d4b3f0" }}>
            <p className="text-xs font-extrabold text-purple-800 mb-1">🧒 18 Yaş Altı — ÇÖZGER Sistemi</p>
            <p className="text-xs text-purple-700 leading-relaxed">
              Seçilen grup: <strong>{cozgerGrup} — {COZGER_GRUPLARI.find(g => g.range === cozgerGrup)?.label}</strong>
              {COZGER_GRUPLARI.find(g => g.range === cozgerGrup)?.agir && " · Ağır engelli kapsamında değerlendirilir."}
            </p>
          </div>
        )}
        {matchedRights.map((r) => (
          <div key={r.id} className="bg-card border border-border rounded-2xl p-4 shadow-sm">
            <div className="flex items-start gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0" style={{ background: r.bg }}>{r.icon}</div>
              <div className="flex-1">
                <div className="flex items-start justify-between gap-2">
                  <p className="text-sm font-extrabold text-foreground">{r.title}</p>
                  <span className="text-xs font-bold px-2 py-0.5 rounded-full shrink-0" style={{ background: r.bg, color: r.color }}>{r.amount}</span>
                </div>
                <p className="text-xs text-muted-foreground mt-1">{r.desc.split("\n\n")[0]}</p>
              </div>
            </div>
            <ol className="space-y-1.5 mb-3">
              {r.steps.map((s, i) => (
                <li key={i} className="flex items-start gap-2 text-xs text-muted-foreground">
                  <span className="w-4 h-4 rounded-full text-white flex items-center justify-center shrink-0 font-bold" style={{ background: r.color, fontSize: 9 }}>{i + 1}</span>{s}
                </li>
              ))}
            </ol>
            <div className="flex items-center gap-2 rounded-xl px-3 py-2 text-xs font-bold" style={{ background: r.bg, color: r.color }}>
              <FileText size={11} />{r.where}
            </div>
          </div>
        ))}
        <button onClick={() => { setStep("yas"); setYasGrubu(""); setCozgerGrup(""); setRate(""); setAge(""); setIncome(""); }}
          className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl border border-border text-sm font-bold text-foreground">
          <RotateCcw size={14} /> Yeniden Sorgula
        </button>
      </div>
    </div>
  );

  return (
    <div className="absolute inset-0 z-50 bg-background flex flex-col">
      <div className="px-4 pt-6 pb-4 flex items-center gap-3 border-b border-border shrink-0">
        <button onClick={onClose} className="w-9 h-9 rounded-full bg-muted flex items-center justify-center"><X size={18} /></button>
        <div className="flex-1">
          <h2 className="text-base font-extrabold text-foreground">Hak Sorgulama Sihirbazı</h2>
          <div className="flex gap-1.5 mt-1.5">
            {Array.from({ length: stepCount }).map((_, i) => (
              <div key={i} className="h-1.5 flex-1 rounded-full transition-colors"
                style={{ background: i <= stepIndex ? "#1a6b4a" : "#dceee4" }} />
            ))}
          </div>
        </div>
      </div>
      <div className="flex-1 overflow-y-auto px-4 py-6">

        {/* ADIM 1: Yaş grubu seçimi */}
        {step === "yas" && (
          <div>
            <div className="text-5xl text-center mb-3">🎂</div>
            <h3 className="text-xl font-extrabold text-foreground text-center mb-1">Kaç yaşında?</h3>
            <p className="text-sm text-muted-foreground text-center mb-8">Hak sistemi yaşa göre farklılaşır</p>
            <div className="space-y-3">
              <button onClick={() => setYasGrubu("18alti")}
                className="w-full flex items-center justify-between rounded-2xl border-2 px-5 py-4 transition-all"
                style={yasGrubu === "18alti" ? { borderColor: "#1a6b4a", background: "#1a6b4a12" } : { borderColor: "#dceee4", background: "#fff" }}>
                <div className="text-left">
                  <p className="text-base font-extrabold text-foreground">18 Yaş Altı</p>
                  <p className="text-xs text-muted-foreground mt-0.5">ÇÖZGER sistemi geçerli — özel gereksinim raporu</p>
                </div>
                <div className="w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0"
                  style={{ borderColor: yasGrubu === "18alti" ? "#1a6b4a" : "#dceee4", background: yasGrubu === "18alti" ? "#1a6b4a" : "transparent" }}>
                  {yasGrubu === "18alti" && <CheckCircle size={14} className="text-white" />}
                </div>
              </button>
              <button onClick={() => setYasGrubu("18ustu")}
                className="w-full flex items-center justify-between rounded-2xl border-2 px-5 py-4 transition-all"
                style={yasGrubu === "18ustu" ? { borderColor: "#1a6b4a", background: "#1a6b4a12" } : { borderColor: "#dceee4", background: "#fff" }}>
                <div className="text-left">
                  <p className="text-base font-extrabold text-foreground">18 Yaş ve Üzeri</p>
                  <p className="text-xs text-muted-foreground mt-0.5">Engel oranına göre sağlık kurulu raporu</p>
                </div>
                <div className="w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0"
                  style={{ borderColor: yasGrubu === "18ustu" ? "#1a6b4a" : "#dceee4", background: yasGrubu === "18ustu" ? "#1a6b4a" : "transparent" }}>
                  {yasGrubu === "18ustu" && <CheckCircle size={14} className="text-white" />}
                </div>
              </button>
            </div>
            <button disabled={!yasGrubu} onClick={() => setStep(yasGrubu === "18alti" ? "cozger" : "rate")}
              className="mt-8 w-full py-4 rounded-2xl font-extrabold text-base text-white flex items-center justify-center gap-2 transition-opacity"
              style={{ background: "#1a6b4a", opacity: yasGrubu ? 1 : 0.4 }}>
              Devam <ArrowRight size={18} />
            </button>
          </div>
        )}

        {/* ADIM 2a: ÇÖZGER grubu (18 altı) */}
        {step === "cozger" && (
          <div>
            <div className="text-5xl text-center mb-3">📋</div>
            <h3 className="text-xl font-extrabold text-foreground text-center mb-1">ÇÖZGER Rapor Grubu</h3>
            <p className="text-sm text-muted-foreground text-center mb-2">Raporunuzdaki gereksinim düzeyi</p>
            <div className="bg-purple-50 border border-purple-200 rounded-2xl px-4 py-3 mb-5 text-xs text-purple-800 leading-relaxed">
              18 yaş altında geleneksel engellilik oranı kaldırılmıştır. Yerine <strong>ÇÖZGER</strong> (Çocuklar İçin Özel Gereksinim Raporu) sistemi kullanılmaktadır.
            </div>
            <div className="space-y-2">
              {COZGER_GRUPLARI.map((g) => (
                <button key={g.range} onClick={() => setCozgerGrup(g.range)}
                  className="w-full flex items-center justify-between rounded-2xl border-2 px-4 py-3 transition-all"
                  style={cozgerGrup === g.range ? { borderColor: g.color, background: g.bg } : { borderColor: "#dceee4", background: "#fff" }}>
                  <div className="text-left flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-extrabold" style={{ color: cozgerGrup === g.range ? g.color : "#0d2b1f" }}>{g.range}</span>
                      {g.agir && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-red-50 text-red-600">Ağır Engelli</span>}
                    </div>
                    <p className="text-xs text-muted-foreground mt-0.5 leading-snug">{g.label} <span className="font-bold">({g.kisa})</span></p>
                  </div>
                  <div className="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-2"
                    style={{ borderColor: cozgerGrup === g.range ? g.color : "#dceee4", background: cozgerGrup === g.range ? g.color : "transparent" }}>
                    {cozgerGrup === g.range && <CheckCircle size={12} className="text-white" />}
                  </div>
                </button>
              ))}
            </div>
            <button disabled={!cozgerGrup} onClick={() => setStep("age")}
              className="mt-6 w-full py-4 rounded-2xl font-extrabold text-base text-white flex items-center justify-center gap-2 transition-opacity"
              style={{ background: "#1a6b4a", opacity: cozgerGrup ? 1 : 0.4 }}>
              Devam <ArrowRight size={18} />
            </button>
          </div>
        )}

        {/* ADIM 2b: Engel oranı (18 üstü) */}
        {step === "rate" && (
          <div>
            <div className="text-5xl text-center mb-3">📊</div>
            <h3 className="text-xl font-extrabold text-foreground text-center mb-1">Engel oranı nedir?</h3>
            <p className="text-sm text-muted-foreground text-center mb-8">Sağlık Kurulu Raporu&apos;ndaki yüzde</p>
            <div className="space-y-3">
              {[{ val: "40-69" as const, label: "%40 – %69", desc: "Orta düzey" }, { val: "70-89" as const, label: "%70 – %89", desc: "Ağır" }, { val: "90+" as const, label: "%90 ve üzeri", desc: "Tam bağımlı" }].map((opt) => (
                <button key={opt.val} onClick={() => setRate(opt.val)}
                  className="w-full flex items-center justify-between rounded-2xl border-2 px-5 py-4 transition-all"
                  style={rate === opt.val ? { borderColor: "#1a6b4a", background: "#1a6b4a12" } : { borderColor: "#dceee4", background: "#fff" }}>
                  <div className="text-left">
                    <p className="text-base font-extrabold text-foreground">{opt.label}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{opt.desc}</p>
                  </div>
                  <div className="w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0"
                    style={{ borderColor: rate === opt.val ? "#1a6b4a" : "#dceee4", background: rate === opt.val ? "#1a6b4a" : "transparent" }}>
                    {rate === opt.val && <CheckCircle size={14} className="text-white" />}
                  </div>
                </button>
              ))}
            </div>
            <button disabled={!rate} onClick={() => setStep("income")}
              className="mt-8 w-full py-4 rounded-2xl font-extrabold text-base text-white flex items-center justify-center gap-2 transition-opacity"
              style={{ background: "#1a6b4a", opacity: rate ? 1 : 0.4 }}>
              Devam <ArrowRight size={18} />
            </button>
          </div>
        )}

        {/* ADIM 3a: Yaş (18 altı) */}
        {step === "age" && (
          <div>
            <div className="text-5xl text-center mb-3">🎈</div>
            <h3 className="text-xl font-extrabold text-foreground text-center mb-1">Çocuğun yaşı?</h3>
            <p className="text-sm text-muted-foreground text-center mb-8">Destekler yaşa göre farklılaşıyor</p>
            <div className="space-y-3">
              {[{ val: "0-6" as const, label: "0 – 6 yaş", desc: "Erken çocukluk" }, { val: "7-17" as const, label: "7 – 17 yaş", desc: "Okul çağı" }].map((opt) => (
                <button key={opt.val} onClick={() => setAge(opt.val)}
                  className="w-full flex items-center justify-between rounded-2xl border-2 px-5 py-4 transition-all"
                  style={age === opt.val ? { borderColor: "#1a6b4a", background: "#1a6b4a12" } : { borderColor: "#dceee4", background: "#fff" }}>
                  <div className="text-left">
                    <p className="text-base font-extrabold text-foreground">{opt.label}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{opt.desc}</p>
                  </div>
                  <div className="w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0"
                    style={{ borderColor: age === opt.val ? "#1a6b4a" : "#dceee4", background: age === opt.val ? "#1a6b4a" : "transparent" }}>
                    {age === opt.val && <CheckCircle size={14} className="text-white" />}
                  </div>
                </button>
              ))}
            </div>
            <button disabled={!age} onClick={() => setStep("results")}
              className="mt-8 w-full py-4 rounded-2xl font-extrabold text-base text-white flex items-center justify-center gap-2 transition-opacity"
              style={{ background: "#1a6b4a", opacity: age ? 1 : 0.4 }}>
              Haklarımı Göster <ArrowRight size={18} />
            </button>
          </div>
        )}

        {/* ADIM 3b: Gelir (18 üstü) */}
        {step === "income" && (
          <div>
            <div className="text-5xl text-center mb-3">💰</div>
            <h3 className="text-xl font-extrabold text-foreground text-center mb-1">Hane kişi başı gelir?</h3>
            <p className="text-sm text-muted-foreground text-center mb-8">Net aylık yaklaşık</p>
            <div className="space-y-3">
              {[{ val: "low" as const, label: "₺0 – ₺5.000", desc: "Asgari ücretin altı" }, { val: "mid" as const, label: "₺5.000 – ₺15.000", desc: "Orta" }, { val: "high" as const, label: "₺15.000+", desc: "Yüksek" }].map((opt) => (
                <button key={opt.val} onClick={() => setIncome(opt.val)}
                  className="w-full flex items-center justify-between rounded-2xl border-2 px-5 py-4 transition-all"
                  style={income === opt.val ? { borderColor: "#1a6b4a", background: "#1a6b4a12" } : { borderColor: "#dceee4", background: "#fff" }}>
                  <div className="text-left">
                    <p className="text-base font-extrabold text-foreground">{opt.label}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{opt.desc}</p>
                  </div>
                  <div className="w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0"
                    style={{ borderColor: income === opt.val ? "#1a6b4a" : "#dceee4", background: income === opt.val ? "#1a6b4a" : "transparent" }}>
                    {income === opt.val && <CheckCircle size={14} className="text-white" />}
                  </div>
                </button>
              ))}
            </div>
            <button disabled={!income} onClick={() => setStep("results")}
              className="mt-8 w-full py-4 rounded-2xl font-extrabold text-base text-white flex items-center justify-center gap-2 transition-opacity"
              style={{ background: "#1a6b4a", opacity: income ? 1 : 0.4 }}>
              Haklarımı Göster <ArrowRight size={18} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
