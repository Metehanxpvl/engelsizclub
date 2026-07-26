import { useState, useRef } from "react";
import { Volume2, X, Edit3, Plus } from "lucide-react";
import { needCards, duyguYuzler } from "../data/cards";

type CustomCard = {
  id: number;
  label: string;
  emoji: string;
  color: string;
  bg: string;
  category: string;
  desc?: string;
  photo?: string; // base64 data URL
  isCustom?: boolean;
};

const PALETTE_COLORS = [
  { color: "#1a6b4a", bg: "#e8f5ee" },
  { color: "#5b8dd9", bg: "#e3f2fd" },
  { color: "#e07a5f", bg: "#fdf0ec" },
  { color: "#f4a832", bg: "#fff8ed" },
  { color: "#9c6db3", bg: "#f5eefb" },
  { color: "#e53935", bg: "#ffebee" },
  { color: "#00897b", bg: "#e0f2f1" },
  { color: "#f06292", bg: "#fce4ec" },
];

const EMOJIS = ["🍕","🍎","🍌","🧃","🍪","🎈","⚽","🚗","🐕","🐱","🦋","🌸","⭐","🎯","🎨","📚","🎵","🚀","🌈","❤️","😊","🙌","👏","🏠","🛁","👕","🎒","✏️","🎮","📱"];

export function KartlarTab() {
  const [activeCard, setActiveCard] = useState<CustomCard | null>(null);
  const [activeCategory, setActiveCategory] = useState("tümü");
  const [editMode, setEditMode] = useState(false);
  const [editingCard, setEditingCard] = useState<CustomCard | null>(null);
  const [addingNew, setAddingNew] = useState(false);
  const [customCards, setCustomCards] = useState<CustomCard[]>(() => {
    try { return JSON.parse(localStorage.getItem("engelsiz_custom_cards") || "[]"); } catch { return []; }
  });
  const [overrides, setOverrides] = useState<Record<number, Partial<CustomCard>>>(() => {
    try { return JSON.parse(localStorage.getItem("engelsiz_card_overrides") || "{}"); } catch { return {}; }
  });

  const photoInputRef = useRef<HTMLInputElement>(null);
  const newPhotoInputRef = useRef<HTMLInputElement>(null);

  function saveCustomCards(cards: CustomCard[]) {
    setCustomCards(cards);
    localStorage.setItem("engelsiz_custom_cards", JSON.stringify(cards));
  }

  function saveOverrides(ovr: Record<number, Partial<CustomCard>>) {
    setOverrides(ovr);
    localStorage.setItem("engelsiz_card_overrides", JSON.stringify(ovr));
  }

  const categories = [
    { id: "tümü", label: "Tümü" },
    { id: "temel", label: "Temel İhtiyaç" },
    { id: "duygu", label: "Duygular" },
    { id: "istek", label: "İstekler" },
    { id: "kisi", label: "Kişiler" },
    { id: "cevap", label: "Cevaplar" },
    { id: "rutin", label: "Günlük Rutin" },
    { id: "sosyal", label: "Sosyal" },
    { id: "okul", label: "Okul" },
    { id: "ozel", label: "⭐ Özel" },
  ];

  const allCards: CustomCard[] = [
    ...needCards.map((c) => ({ ...c, ...overrides[c.id] })),
    ...customCards,
  ];

  const filtered = activeCategory === "tümü"
    ? allCards
    : activeCategory === "ozel"
    ? customCards
    : allCards.filter((c) => c.category === activeCategory);

  function saveCardEdit() {
    if (!editingCard) return;
    if (editingCard.isCustom) {
      saveCustomCards(customCards.map((c) => c.id === editingCard.id ? editingCard : c));
    } else {
      const { id, ...rest } = editingCard;
      saveOverrides({ ...overrides, [id]: rest });
    }
    setEditingCard(null);
  }

  function deleteCard(card: CustomCard) {
    if (card.isCustom) {
      saveCustomCards(customCards.filter((c) => c.id !== card.id));
    } else {
      const newOvr = { ...overrides };
      delete newOvr[card.id];
      saveOverrides(newOvr);
    }
    setEditingCard(null);
  }

  function addNewCard(card: CustomCard) {
    const newId = Date.now();
    saveCustomCards([...customCards, { ...card, id: newId, isCustom: true }]);
    setAddingNew(false);
    setEditingCard(null);
  }

  // Edit modal
  const EditModal = ({ card, onSave, onClose, onDelete, isNew }: {
    card: CustomCard; onSave: (c: CustomCard) => void; onClose: () => void; onDelete?: () => void; isNew?: boolean;
  }) => {
    const [draft, setDraft] = useState({ ...card });
    const fileRef = useRef<HTMLInputElement>(null);

    function handlePhoto(file: File) {
      const reader = new FileReader();
      reader.onload = (e) => setDraft((d) => ({ ...d, photo: e.target?.result as string }));
      reader.readAsDataURL(file);
    }

    return (
      <div className="fixed inset-0 z-50 flex flex-col" style={{ background: "rgba(0,0,0,0.6)" }} onClick={onClose}>
        <div
          className="mt-auto w-full rounded-t-3xl bg-card flex flex-col max-h-[88vh] overflow-y-auto"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-border">
            <p className="text-base font-extrabold text-foreground">{isNew ? "Yeni Kart Ekle" : "Kartı Düzenle"}</p>
            <button onClick={onClose} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
              <X size={15} className="text-muted-foreground" />
            </button>
          </div>

          <div className="px-5 pt-4 pb-6 space-y-4">
            {/* Fotoğraf alanı */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-2">Fotoğraf (isteğe bağlı)</p>
              <div
                className="w-full h-32 rounded-2xl border-2 border-dashed flex flex-col items-center justify-center cursor-pointer relative overflow-hidden"
                style={{ borderColor: draft.color, background: draft.bg }}
                onClick={() => fileRef.current?.click()}
              >
                {draft.photo ? (
                  <>
                    <img src={draft.photo} alt="" className="absolute inset-0 w-full h-full object-cover" />
                    <div className="absolute inset-0 flex items-end justify-end p-2">
                      <button
                        className="bg-white/90 rounded-full p-1.5 shadow"
                        onClick={(e) => { e.stopPropagation(); setDraft((d) => ({ ...d, photo: undefined })); }}
                      >
                        <X size={12} className="text-red-500" />
                      </button>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="text-3xl mb-1">{draft.emoji}</div>
                    <p className="text-xs font-semibold" style={{ color: draft.color }}>Fotoğraf ekle</p>
                    <p className="text-[10px] text-muted-foreground">Galeriden seç</p>
                  </>
                )}
              </div>
              <input ref={fileRef} type="file" accept="image/*" className="hidden"
                onChange={(e) => { if (e.target.files?.[0]) handlePhoto(e.target.files[0]); }} />
            </div>

            {/* İfade / etiket */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">İfade (Kart yazısı)</p>
              <input
                value={draft.label}
                onChange={(e) => setDraft((d) => ({ ...d, label: e.target.value }))}
                placeholder="Örn: Elma, Salıncak, Dede..."
                className="w-full bg-muted rounded-xl px-4 py-3 text-sm font-semibold text-foreground outline-none"
              />
            </div>

            {/* Açıklama */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Açıklama (isteğe bağlı)</p>
              <textarea
                value={draft.desc || ""}
                onChange={(e) => setDraft((d) => ({ ...d, desc: e.target.value }))}
                placeholder="Bu kartın ne anlama geldiğini yazın..."
                rows={2}
                className="w-full bg-muted rounded-xl px-4 py-3 text-sm text-foreground outline-none resize-none"
              />
            </div>

            {/* Emoji seçici */}
            {!draft.photo && (
              <div>
                <p className="text-xs font-bold text-muted-foreground mb-2">Simge</p>
                <div className="flex flex-wrap gap-2">
                  {EMOJIS.map((em) => (
                    <button
                      key={em}
                      onClick={() => setDraft((d) => ({ ...d, emoji: em }))}
                      className="w-9 h-9 rounded-xl flex items-center justify-center text-xl transition-transform active:scale-90"
                      style={{ background: draft.emoji === em ? draft.color + "33" : "#f3f4f6", border: draft.emoji === em ? `2px solid ${draft.color}` : "2px solid transparent" }}
                    >
                      {em}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Renk seçici */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-2">Renk</p>
              <div className="flex gap-2 flex-wrap">
                {PALETTE_COLORS.map((p) => (
                  <button
                    key={p.color}
                    onClick={() => setDraft((d) => ({ ...d, color: p.color, bg: p.bg }))}
                    className="w-9 h-9 rounded-full border-4 transition-transform active:scale-90"
                    style={{
                      background: p.color,
                      borderColor: draft.color === p.color ? "white" : "transparent",
                      boxShadow: draft.color === p.color ? `0 0 0 3px ${p.color}` : "none",
                    }}
                  />
                ))}
              </div>
            </div>

            {/* Kategori */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-1.5">Kategori</p>
              <select
                value={draft.category}
                onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))}
                className="w-full bg-muted rounded-xl px-4 py-3 text-sm font-semibold text-foreground outline-none"
              >
                {[["temel","Temel İhtiyaç"],["duygu","Duygular"],["istek","İstekler"],["kisi","Kişiler"],["rutin","Günlük Rutin"],["sosyal","Sosyal"],["okul","Okul"],["ozel","⭐ Özel"]].map(([v,l]) => (
                  <option key={v} value={v}>{l}</option>
                ))}
              </select>
            </div>

            {/* Önizleme */}
            <div>
              <p className="text-xs font-bold text-muted-foreground mb-2">Önizleme</p>
              <div className="flex justify-center">
                <div
                  className="w-24 flex flex-col items-center justify-center rounded-2xl p-2 shadow-sm"
                  style={{ background: draft.bg, border: `3px solid ${draft.color}`, minHeight: 90 }}
                >
                  {draft.photo ? (
                    <img src={draft.photo} alt="" className="w-14 h-14 rounded-xl object-cover mb-1" />
                  ) : (
                    <span className="text-4xl mb-1">{draft.emoji}</span>
                  )}
                  <span className="text-[11px] font-extrabold text-center leading-tight px-1" style={{ color: draft.color }}>
                    {draft.label || "İfade"}
                  </span>
                </div>
              </div>
            </div>

            {/* Butonlar */}
            <div className="space-y-2 pt-1">
              <button
                onClick={() => { if (draft.label.trim()) onSave(draft); }}
                disabled={!draft.label.trim()}
                className="w-full py-3.5 rounded-2xl font-bold text-white text-sm shadow-sm disabled:opacity-40"
                style={{ background: draft.color }}
              >
                {isNew ? "Kartı Ekle" : "Değişiklikleri Kaydet"}
              </button>
              {onDelete && (
                <button
                  onClick={onDelete}
                  className="w-full py-3 rounded-2xl font-bold text-sm border-2 border-red-200 text-red-500 bg-red-50"
                >
                  {card.isCustom ? "Kartı Sil" : "Özelleştirmeyi Sıfırla"}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex flex-col h-full">
      {/* Card view overlay */}
      {activeCard && !editMode && (
        <div
          className="fixed inset-0 z-50 flex flex-col items-center justify-center px-8"
          style={{ background: "rgba(0,0,0,0.55)" }}
          onClick={() => setActiveCard(null)}
        >
          <div
            className="w-full max-w-[280px] rounded-3xl flex flex-col items-center py-8 px-6 shadow-2xl relative"
            style={{ background: activeCard.bg, border: `5px solid ${activeCard.color}` }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setActiveCard(null)}
              className="absolute top-3 right-3 w-8 h-8 rounded-full flex items-center justify-center"
              style={{ background: activeCard.color + "22" }}
            >
              <X size={16} style={{ color: activeCard.color }} />
            </button>
            {activeCard.photo ? (
              <img src={activeCard.photo} alt={activeCard.label} className="w-40 h-40 rounded-2xl object-cover mb-4 shadow-md" />
            ) : duyguYuzler[activeCard.id] ? (
              <div className="w-36 h-36 mb-4" dangerouslySetInnerHTML={{ __html: duyguYuzler[activeCard.id] }} />
            ) : (
              <div className="text-8xl mb-4">{activeCard.emoji}</div>
            )}
            <div className="text-3xl font-extrabold mb-3 text-center" style={{ color: activeCard.color }}>
              {activeCard.label}
            </div>
            {activeCard.desc && (
              <p className="text-sm text-center leading-relaxed mb-5 px-2" style={{ color: activeCard.color + "cc" }}>
                {activeCard.desc}
              </p>
            )}
            <button
              onClick={() => {
                const u = new SpeechSynthesisUtterance(activeCard.label);
                u.lang = "tr-TR";
                window.speechSynthesis.speak(u);
              }}
              className="flex items-center gap-2 px-6 py-3 rounded-full font-bold text-white shadow-lg"
              style={{ background: activeCard.color }}
            >
              <Volume2 size={18} />
              Sesli Oku
            </button>
            <p className="mt-4 text-xs" style={{ color: activeCard.color + "99" }}>Kartı kapatmak için dışarıya dokun</p>
          </div>
        </div>
      )}

      {/* Edit modal */}
      {editingCard && (
        <EditModal
          card={editingCard}
          onSave={(c) => {
            if (addingNew) {
              addNewCard(c);
            } else if (c.isCustom) {
              saveCustomCards(customCards.map((x) => x.id === c.id ? c : x));
            } else {
              const { id, ...rest } = c;
              saveOverrides({ ...overrides, [id]: rest });
            }
            setEditingCard(null);
            setAddingNew(false);
          }}
          onClose={() => { setEditingCard(null); setAddingNew(false); }}
          onDelete={!addingNew ? () => { deleteCard(editingCard); setEditingCard(null); } : undefined}
          isNew={addingNew}
        />
      )}


      {/* Header */}
      <div className="px-4 pt-5 pb-3 flex items-center justify-between">
        <div>
          <h2 className="text-xl font-extrabold text-foreground mb-0.5">İletişim Kartları</h2>
          <p className="text-xs text-muted-foreground">
            {editMode ? "Düzenleme modu — bir karta dokunarak özelleştir" : "Karta dokunarak sesli okut"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => { setEditMode(!editMode); setActiveCard(null); }}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold transition-all"
            style={editMode
              ? { background: "#1a6b4a", color: "white" }
              : { background: "#dceee4", color: "#1a6b4a" }}
          >
            {editMode ? <><X size={13} /> Bitti</> : <><Edit3 size={13} /> Düzenle</>}
          </button>
        </div>
      </div>

      {/* Category filter */}
      <div className="flex gap-2 px-4 mb-3 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {categories.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-colors"
            style={
              activeCategory === cat.id
                ? { background: "#1a6b4a", color: "#fff" }
                : { background: "#dceee4", color: "#4d7a62" }
            }
          >
            {cat.label}
          </button>
        ))}
      </div>

      <div className="flex-1 overflow-y-auto px-4 pb-6">
        <div className="grid grid-cols-3 gap-3">
          {filtered.map((card) => (
            <button
              key={card.id}
              onClick={() => {
                if (editMode) {
                  setEditingCard({ ...card });
                  setAddingNew(false);
                } else {
                  setActiveCard(card);
                }
              }}
              className="flex flex-col items-center justify-center rounded-2xl p-2 shadow-sm active:scale-95 transition-all relative"
              style={{ background: card.bg, border: `3px solid ${card.color}`, minHeight: 90 }}
            >
              {editMode && (
                <div className="absolute top-1 right-1 w-5 h-5 rounded-full flex items-center justify-center"
                  style={{ background: card.color }}>
                  <Edit3 size={9} color="white" />
                </div>
              )}
              {card.photo ? (
                <img src={card.photo} alt={card.label} className="w-14 h-14 rounded-xl object-cover mb-1" />
              ) : duyguYuzler[card.id] ? (
                <div className="w-14 h-14 mb-1" dangerouslySetInnerHTML={{ __html: duyguYuzler[card.id] }} />
              ) : (
                <span className="text-4xl mb-1.5">{card.emoji}</span>
              )}
              <span className="text-[11px] font-extrabold leading-tight text-center px-1" style={{ color: card.color }}>
                {card.label}
              </span>
              {card.isCustom && (
                <span className="mt-0.5 text-[8px] font-bold" style={{ color: card.color + "99" }}>özel</span>
              )}
            </button>
          ))}

          {/* Yeni kart ekle butonu */}
          {editMode && (
            <button
              onClick={() => {
                const blank: CustomCard = { id: 0, label: "", emoji: "⭐", color: "#1a6b4a", bg: "#e8f5ee", category: "ozel", isCustom: true };
                setEditingCard(blank);
                setAddingNew(true);
              }}
              className="flex flex-col items-center justify-center rounded-2xl p-2 shadow-sm active:scale-95 transition-all border-2 border-dashed"
              style={{ borderColor: "#1a6b4a", background: "#f0f9f4", minHeight: 90 }}
            >
              <Plus size={24} color="#1a6b4a" className="mb-1" />
              <span className="text-[11px] font-extrabold text-center" style={{ color: "#1a6b4a" }}>Yeni Kart</span>
            </button>
          )}
        </div>

        {!editMode && (
          <>
            <div className="mt-5 bg-card rounded-2xl p-4 border border-border shadow-sm">
              <div className="flex items-center gap-2 mb-2">
                <Volume2 size={16} className="text-primary" />
                <p className="text-sm font-bold text-foreground">Sesli Okuma</p>
              </div>
              <p className="text-xs text-muted-foreground leading-relaxed">
                Karta dokunduğunuzda tam ekran açılır ve Türkçe sesli okuma başlar.
              </p>
            </div>

            <div className="mt-3 bg-primary/5 rounded-2xl p-4 border border-primary/20">
              <p className="text-xs font-bold text-primary mb-1 flex items-center gap-1.5">
                <Edit3 size={12} /> Kartları Kişiselleştir
              </p>
              <p className="text-xs text-muted-foreground leading-relaxed">
                Sağ üstteki <b>Düzenle</b> butonuna basarak kartlara fotoğraf ekleyebilir, yazıyı değiştirebilir veya yeni kartlar oluşturabilirsiniz.
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
