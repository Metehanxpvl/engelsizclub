import "leaflet/dist/leaflet.css";
import { useState, useEffect, useRef } from "react";
import { MapPin, Search, Star, Clock, Phone, ChevronRight, ShoppingBag, X } from "lucide-react";
import { centers, turkishCities, medicalVendors } from "../data/centers";

export type CenterItem = typeof centers[number];

function OpenStreetMapView({ centers, selectedCenter, onSelectCenter, userLat, userLng, focusLat, focusLng }: {
  centers: (CenterItem & { distKm?: number })[];
  selectedCenter: CenterItem | null;
  onSelectCenter: (c: CenterItem) => void;
  userLat?: number | null;
  userLng?: number | null;
  focusLat: number;
  focusLng: number;
}) {
  const mapRef = useRef<HTMLDivElement>(null);
  const leafletMap = useRef<import("leaflet").Map | null>(null);
  const markersRef = useRef<import("leaflet").Marker[]>([]);
  const userMarkerRef = useRef<import("leaflet").Marker | null>(null);

  useEffect(() => {
    if (!mapRef.current || leafletMap.current) return;
    import("leaflet").then((L) => {
      const map = L.map(mapRef.current!, {
        center: [focusLat, focusLng],
        zoom: 12,
        zoomControl: true,
        attributionControl: false,
      });
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19 }).addTo(map);
      centers.forEach((c) => {
        const icon = L.divIcon({
          html: `<div style="width:30px;height:30px;border-radius:50%;background:${c.color};border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.35);display:flex;align-items:center;justify-content:center;color:white;font-size:11px;font-weight:800;">🏥</div>`,
          className: "",
          iconSize: [30, 30],
          iconAnchor: [15, 15],
        });
        const marker = L.marker([c.lat, c.lng], { icon }).addTo(map);
        marker.bindPopup(`<b style="font-size:12px">${c.name}</b><br/><span style="font-size:11px;color:#666">${c.ilce}</span>`);
        marker.on("click", () => onSelectCenter(c));
        markersRef.current.push(marker);
      });
      leafletMap.current = map;
    });
    return () => {
      if (leafletMap.current) {
        leafletMap.current.remove();
        leafletMap.current = null;
        markersRef.current = [];
        userMarkerRef.current = null;
      }
    };
  }, []);

  // Şehir/konum değişince haritayı yeniden oluştur
  useEffect(() => {
    if (!leafletMap.current) return;
    import("leaflet").then((L) => {
      markersRef.current.forEach((m) => m.remove());
      markersRef.current = [];
      centers.forEach((c) => {
        const icon = L.divIcon({
          html: `<div style="width:30px;height:30px;border-radius:50%;background:${c.color};border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.35);display:flex;align-items:center;justify-content:center;color:white;font-size:11px;font-weight:800;">🏥</div>`,
          className: "",
          iconSize: [30, 30],
          iconAnchor: [15, 15],
        });
        const marker = L.marker([c.lat, c.lng], { icon }).addTo(leafletMap.current!);
        marker.bindPopup(`<b style="font-size:12px">${c.name}</b><br/><span style="font-size:11px;color:#666">${c.ilce}</span>`);
        marker.on("click", () => onSelectCenter(c));
        markersRef.current.push(marker);
      });
    });
  }, [centers.map((c) => c.id).join(",")]);

  useEffect(() => {
    if (!leafletMap.current) return;
    leafletMap.current.setView([focusLat, focusLng], 12, { animate: true });
  }, [focusLat, focusLng]);

  useEffect(() => {
    if (!leafletMap.current) return;
    import("leaflet").then((L) => {
      if (userMarkerRef.current) { userMarkerRef.current.remove(); userMarkerRef.current = null; }
      if (userLat && userLng) {
        const icon = L.divIcon({
          html: `<div style="width:22px;height:22px;border-radius:50%;background:#2563eb;border:3px solid white;box-shadow:0 2px 8px rgba(37,99,235,0.5);"></div>`,
          className: "",
          iconSize: [22, 22],
          iconAnchor: [11, 11],
        });
        userMarkerRef.current = L.marker([userLat, userLng], { icon }).addTo(leafletMap.current!);
        userMarkerRef.current.bindPopup("<b>Konumunuz</b>");
      }
    });
  }, [userLat, userLng]);

  useEffect(() => {
    if (!leafletMap.current || !selectedCenter) return;
    leafletMap.current.setView([selectedCenter.lat, selectedCenter.lng], 14, { animate: true });
  }, [selectedCenter]);

  return (
    <div className="mx-4 mb-3 rounded-2xl overflow-hidden border border-border shadow-sm" style={{ height: 190 }}>
      <div ref={mapRef} style={{ width: "100%", height: "100%" }} />
    </div>
  );
}

function geoDistance(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function MerkezlerTab() {
  const [filter, setFilter] = useState("Tümü");
  const [selectedCenter, setSelectedCenter] = useState<typeof centers[0] | null>(null);
  const [centerSearch, setCenterSearch] = useState("");
  const [selectedCity, setSelectedCity] = useState("İstanbul");
  const [selectedIlce, setSelectedIlce] = useState("Tümü İlçeler");
  const [userLat, setUserLat] = useState<number | null>(null);
  const [userLng, setUserLng] = useState<number | null>(null);
  const [locStatus, setLocStatus] = useState<"idle" | "loading" | "ok" | "denied">("idle");

  const cityNames = Object.keys(turkishCities);

  function detectLocation() {
    if (!navigator.geolocation) { setLocStatus("denied"); return; }
    setLocStatus("loading");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        setUserLat(lat);
        setUserLng(lng);
        setLocStatus("ok");
        // En yakın şehri bul
        let closest = "İstanbul";
        let minD = Infinity;
        for (const [city, info] of Object.entries(turkishCities)) {
          const d = geoDistance(lat, lng, info.lat, info.lng);
          if (d < minD) { minD = d; closest = city; }
        }
        setSelectedCity(closest);
        setSelectedIlce("Tümü İlçeler");
      },
      () => setLocStatus("denied")
    );
  }

  const cityInfo = turkishCities[selectedCity];
  const mapCenter = userLat && userLng && locStatus === "ok"
    ? { lat: userLat, lng: userLng }
    : { lat: cityInfo.lat, lng: cityInfo.lng };

  const categories = ["Tümü", "Fizik Tedavi", "Özel Eğitim", "Dil Terapisi", "Nöroloji"];

  const withDistance = centers
    .filter((c) => {
      const matchesCity = c.city === selectedCity;
      const matchesIlce = selectedIlce === "Tümü İlçeler" || c.ilce === selectedIlce;
      const matchesCat = filter === "Tümü" || c.services.some((s) => s.toLowerCase().includes(filter.toLowerCase().slice(0, 5)));
      const q = centerSearch.trim().toLowerCase();
      const matchesSearch = !q || [c.name, c.category, c.address, ...c.services].some((f) => f.toLowerCase().includes(q));
      return matchesCity && matchesIlce && matchesCat && matchesSearch;
    })
    .map((c) => ({
      ...c,
      distKm: geoDistance(mapCenter.lat, mapCenter.lng, c.lat, c.lng),
    }))
    .sort((a, b) => a.distKm - b.distKm);

  const mapCenters = withDistance.length > 0 ? withDistance : centers.filter((c) => c.city === selectedCity).map((c) => ({ ...c, distKm: geoDistance(mapCenter.lat, mapCenter.lng, c.lat, c.lng) }));

  if (selectedCenter) {
    const distKm = geoDistance(mapCenter.lat, mapCenter.lng, selectedCenter.lat, selectedCenter.lng);
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div
          className="px-4 pt-6 pb-8"
          style={{ background: `linear-gradient(135deg, ${selectedCenter.color}22, #f2f7f4)` }}
        >
          <button
            onClick={() => setSelectedCenter(null)}
            className="mb-4 flex items-center gap-1 text-sm font-semibold text-primary"
          >
            <ChevronRight size={16} className="rotate-180" /> Geri
          </button>
          <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-white text-xl mb-3 shadow-md"
            style={{ background: selectedCenter.color }}>
            🏥
          </div>
          <h2 className="text-xl font-extrabold text-foreground">{selectedCenter.name}</h2>
          <span className="mt-1 inline-block text-xs font-semibold px-2 py-1 rounded-full text-white"
            style={{ background: selectedCenter.color }}>
            {selectedCenter.category}
          </span>
        </div>

        <div className="px-4 pb-6 space-y-3">
          {[
            { icon: MapPin, label: "Adres", value: selectedCenter.address },
            { icon: Phone, label: "Telefon", value: selectedCenter.phone },
            { icon: Clock, label: "Çalışma Saatleri", value: selectedCenter.hours },
          ].map((item) => (
            <div key={item.label} className="bg-card rounded-2xl p-4 border border-border flex items-start gap-3 shadow-sm">
              <div className="w-8 h-8 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: selectedCenter.color + "22" }}>
                <item.icon size={15} style={{ color: selectedCenter.color }} />
              </div>
              <div>
                <p className="text-xs text-muted-foreground">{item.label}</p>
                <p className="text-sm font-semibold text-foreground">{item.value}</p>
              </div>
            </div>
          ))}

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm">
            <p className="text-xs text-muted-foreground mb-2">Sunulan Hizmetler</p>
            <div className="flex flex-wrap gap-2">
              {selectedCenter.services.map((s) => (
                <span key={s} className="text-xs px-3 py-1.5 rounded-full font-semibold"
                  style={{ background: selectedCenter.color + "22", color: selectedCenter.color }}>
                  {s}
                </span>
              ))}
            </div>
          </div>

          <div className="bg-card rounded-2xl p-4 border border-border shadow-sm flex items-center justify-between">
            <div>
              <p className="text-xs text-muted-foreground">Değerlendirme</p>
              <div className="flex items-center gap-1 mt-1">
                <Star size={16} className="fill-amber-400 text-amber-400" />
                <span className="text-lg font-extrabold text-foreground">{selectedCenter.rating}</span>
                <span className="text-xs text-muted-foreground">({selectedCenter.reviews} yorum)</span>
              </div>
            </div>
            <div className="text-right">
              <p className="text-xs text-muted-foreground">Uzaklık</p>
              <p className="text-sm font-bold text-primary">{distKm < 1 ? `${Math.round(distKm * 1000)} m` : `${distKm.toFixed(1)} km`}</p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <button
              className="py-3.5 rounded-2xl font-bold text-sm bg-primary text-primary-foreground shadow-sm"
              onClick={() => window.open(`https://www.openstreetmap.org/directions?from=${mapCenter.lat},${mapCenter.lng}&to=${selectedCenter.lat},${selectedCenter.lng}`, "_blank")}
            >
              Yol Tarifi
            </button>
            <button className="py-3.5 rounded-2xl font-bold text-sm border-2 border-primary text-primary bg-transparent">
              Randevu Al
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-5 pb-3">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="text-xl font-extrabold text-foreground leading-tight">Yakındaki Merkezler</h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {locStatus === "ok" ? "📍 Konumunuza göre sıralandı" : `${selectedCity} · ${selectedIlce}`}
            </p>
          </div>
          <button
            onClick={detectLocation}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold shadow-sm transition-all"
            style={locStatus === "ok"
              ? { background: "#1a6b4a", color: "white" }
              : { background: "#dceee4", color: "#1a6b4a" }}
          >
            {locStatus === "loading" ? (
              <><div className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" /> Alınıyor</>
            ) : (
              <><MapPin size={13} /> {locStatus === "ok" ? "Konumum" : "Konumumu Bul"}</>
            )}
          </button>
        </div>

        {/* İl / İlçe seçimi */}
        <div className="flex gap-2 mb-3">
          <select
            value={selectedCity}
            onChange={(e) => { setSelectedCity(e.target.value); setSelectedIlce("Tümü İlçeler"); setLocStatus("idle"); setUserLat(null); setUserLng(null); }}
            className="flex-1 bg-card border border-border rounded-xl px-3 py-2 text-sm font-semibold text-foreground outline-none"
          >
            {cityNames.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
          <select
            value={selectedIlce}
            onChange={(e) => setSelectedIlce(e.target.value)}
            className="flex-1 bg-card border border-border rounded-xl px-3 py-2 text-sm font-semibold text-foreground outline-none"
          >
            {cityInfo.ilceler.map((i) => <option key={i} value={i}>{i}</option>)}
          </select>
        </div>

        {/* Arama */}
        <div className="flex items-center gap-2 bg-card border border-border rounded-xl px-3 py-2.5 shadow-sm">
          <Search size={15} className="text-muted-foreground shrink-0" />
          <input
            value={centerSearch}
            onChange={(e) => setCenterSearch(e.target.value)}
            placeholder="Merkez adı veya hizmet ara..."
            className="flex-1 bg-transparent text-sm text-foreground placeholder:text-muted-foreground outline-none"
          />
          {centerSearch && (
            <button onClick={() => setCenterSearch("")} className="text-muted-foreground shrink-0"><X size={14} /></button>
          )}
        </div>
      </div>

      {/* OpenStreetMap (Leaflet) */}
      <OpenStreetMapView
        centers={mapCenters}
        selectedCenter={selectedCenter}
        onSelectCenter={setSelectedCenter}
        userLat={userLat}
        userLng={userLng}
        focusLat={mapCenter.lat}
        focusLng={mapCenter.lng}
      />

      {/* Category filters */}
      <div className="flex gap-2 px-4 mb-3 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setFilter(cat)}
            className="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-colors"
            style={
              filter === cat
                ? { background: "#1a6b4a", color: "#fff" }
                : { background: "#dceee4", color: "#4d7a62" }
            }
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-3">
        {withDistance.length === 0 && (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <div className="w-14 h-14 rounded-full bg-muted flex items-center justify-center mb-4">
              <Search size={22} className="text-muted-foreground" />
            </div>
            <p className="text-sm font-bold text-foreground mb-1">Merkez bulunamadı</p>
            <p className="text-xs text-muted-foreground">Bu bölgede kayıtlı merkez yok.</p>
          </div>
        )}
        {withDistance.map((center) => (
          <button
            key={center.id}
            onClick={() => setSelectedCenter(center)}
            className="w-full bg-card border border-border rounded-2xl p-4 shadow-sm text-left hover:shadow-md transition-shadow active:scale-[0.99]"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-start gap-3">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
                  style={{ background: center.color + "22" }}
                >
                  🏥
                </div>
                <div>
                  <p className="font-bold text-foreground text-sm">{center.name}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">{center.category}</p>
                  <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
                    <MapPin size={10} /> {center.ilce} · {center.city}
                  </p>
                </div>
              </div>
              <div className="text-right shrink-0">
                <div className="flex items-center gap-1 justify-end">
                  <Star size={12} className="fill-amber-400 text-amber-400" />
                  <span className="text-xs font-bold text-foreground">{center.rating}</span>
                </div>
                <p className="text-xs text-primary font-semibold mt-1">{center.distKm < 1 ? `${Math.round(center.distKm * 1000)} m` : `${center.distKm.toFixed(1)} km`}</p>
              </div>
            </div>
            <div className="mt-3 flex flex-wrap gap-1.5">
              {center.services.map((s) => (
                <span
                  key={s}
                  className="text-xs px-2 py-0.5 rounded-full font-semibold"
                  style={{ background: center.color + "18", color: center.color }}
                >
                  {s}
                </span>
              ))}
            </div>
          </button>
        ))}

        {/* Medical vendors section */}
        <div className="pt-4">
          <h3 className="text-base font-extrabold text-foreground mb-3 flex items-center gap-2">
            <ShoppingBag size={16} className="text-accent" />
            Medikal Cihaz Firmaları
          </h3>

          <div className="flex gap-2 mb-3 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
            {["Tümü", "SGK'lı", "Kargo Var", "İstanbul"].map((f) => (
              <span key={f} className="shrink-0 px-3 py-1.5 rounded-full text-xs font-bold bg-secondary text-secondary-foreground">
                {f}
              </span>
            ))}
          </div>

          <div className="space-y-3">
            {medicalVendors.map((v) => (
              <div key={v.id} className="bg-card border border-border rounded-2xl p-4 shadow-sm">
                <div className="flex items-start gap-3">
                  <div
                    className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0"
                    style={{ background: v.color + "22" }}
                  >
                    {v.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-bold text-foreground text-sm">{v.name}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {v.city} / {v.district}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {v.sgk && (
                        <span className="text-xs px-2 py-0.5 rounded-full font-bold bg-green-100 text-green-700">SGK</span>
                      )}
                      {v.cargo && (
                        <span className="text-xs px-2 py-0.5 rounded-full font-bold bg-blue-100 text-blue-700">Kargo</span>
                      )}
                      {v.products.slice(0, 2).map((p) => (
                        <span key={p} className="text-xs px-2 py-0.5 rounded-full font-semibold"
                          style={{ background: v.color + "18", color: v.color }}>
                          {p}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <button className="flex-1 py-2 rounded-xl text-xs font-bold bg-primary text-primary-foreground">
                    Ara: {v.phone}
                  </button>
                  <button className="py-2 px-3 rounded-xl text-xs font-bold border border-border text-foreground">
                    Detay
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
