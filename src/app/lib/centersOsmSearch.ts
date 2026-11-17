import { haystackMatchesQuery, normTr, searchTokens } from "./trNorm";

// Photon free-text + city harvest for the web Harita tab.

export type OsmCenter = {
  id: number;
  city: string;
  ilce: string;
  name: string;
  category: string;
  address: string;
  phone: string;
  hours: string;
  services: string[];
  rating: number;
  reviews: number;
  color: string;
  lat: number;
  lng: number;
};

const UA = "EngelsizClub/1.0 (https://engelsizclub-e5842.web.app)";

const NEGATIVES = ["otel", "hotel", "restoran", "restaurant", "market", "banka", "cami", "mosque", "benzin"];

function categoryFromName(name: string): string {
  const n = normTr(name);
  if (n.includes("medikal") || n.includes("ortoped") || n.includes("ortez") || n.includes("protez")) {
    return "Medikal";
  }
  if (n.includes("fizyo") || n.includes("fizik")) return "Fizik Tedavi & Rehabilitasyon";
  if (n.includes("dil") || n.includes("konusma")) return "Dil & Konuşma Terapisi";
  if (n.includes("noro") || n.includes("neuro")) return "Çocuk Nörolojisi";
  return "Özel Eğitim & Rehabilitasyon";
}

function colorFor(category: string): string {
  if (category.includes("Özel")) return "#e07a5f";
  if (category.includes("Medikal")) return "#f4a832";
  if (category.includes("Fizik")) return "#1a6b4a";
  if (category.includes("Dil")) return "#9c6db3";
  if (category.includes("Nöro")) return "#6b9ac4";
  return "#1a6b4a";
}

function servicesFor(category: string): string[] {
  if (category.includes("Özel")) return ["Özel Eğitim", "Destek Eğitimi"];
  if (category.includes("Medikal")) return ["Medikal Malzeme"];
  if (category.includes("Fizik")) return ["Fizik Tedavi", "Rehabilitasyon"];
  if (category.includes("Dil")) return ["Konuşma Terapisi"];
  if (category.includes("Nöro")) return ["Nöroloji"];
  return ["Rehabilitasyon"];
}

function isUsefulHit(name: string, query: string, props: Record<string, unknown>): boolean {
  const hay = [
    name,
    String(props.street ?? ""),
    String(props.city ?? ""),
    String(props.district ?? ""),
    String(props.locality ?? ""),
    String(props.osm_value ?? ""),
    String(props.osm_key ?? ""),
  ].join(" ");
  const n = normTr(hay);
  const q = normTr(query);
  if (NEGATIVES.some((x) => n.includes(x)) && !NEGATIVES.some((x) => q.includes(x))) {
    return false;
  }
  const tokens = searchTokens(query);
  if (tokens.length > 0 && tokens.some((t) => n.includes(t))) return true;
  // Harvest-style positives when free-text is empty / city browse.
  const positives = [
    "ozel egitim",
    "rehabilitasyon",
    "fizik tedavi",
    "fizyoterapi",
    "medikal",
    "ortoped",
    "physiotherapist",
    "special school",
  ];
  return positives.some((p) => n.includes(p));
}

function featureToCenter(
  feature: { properties?: Record<string, unknown>; geometry?: { coordinates?: number[] } },
  city: string,
  id: number,
): OsmCenter | null {
  const props = feature.properties ?? {};
  const name = String(props.name ?? props.osm_value ?? "").trim();
  if (!name) return null;
  const coords = feature.geometry?.coordinates;
  if (!coords || coords.length < 2) return null;
  const lng = Number(coords[0]);
  const lat = Number(coords[1]);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

  const country = String(props.country ?? props.countrycode ?? "").toLowerCase();
  if (country && country !== "turkey" && country !== "türkiye" && country !== "tr") {
    return null;
  }

  const ilce = String(props.district ?? props.suburb ?? props.city ?? props.county ?? "Merkez").trim();
  const street = props.street ? String(props.street) : "";
  const no = props.housenumber ? String(props.housenumber) : "";
  const addressParts: string[] = [];
  if (street) addressParts.push(no ? `${street} No:${no}` : street);
  addressParts.push(`${ilce} / ${city}`);
  const category = categoryFromName(name);

  return {
    id,
    city,
    ilce: ilce || "Merkez",
    name,
    category,
    address: addressParts.join(", "),
    phone: props.phone ? String(props.phone) : "—",
    hours: "Saat bilgisi yok",
    services: servicesFor(category),
    rating: 0,
    reviews: 0,
    color: colorFor(category),
    lat,
    lng,
  };
}

/** Free-text search biased to lat/lng. */
export async function searchCentersOsm(opts: {
  query: string;
  lat: number;
  lng: number;
  city: string;
  limit?: number;
}): Promise<OsmCenter[]> {
  const q = opts.query.trim();
  if (q.length < 2) return [];
  const variants = [q, `${q} ${opts.city}`, `${q} Türkiye`];
  const seen = new Set<string>();
  const out: OsmCenter[] = [];
  let id = 910000;

  for (const variant of variants) {
    const url = new URL("https://photon.komoot.io/api/");
    url.searchParams.set("q", variant);
    url.searchParams.set("lat", String(opts.lat));
    url.searchParams.set("lon", String(opts.lng));
    url.searchParams.set("limit", String(opts.limit ?? 20));
    url.searchParams.set("lang", "en");
    url.searchParams.set("location_bias_scale", "0.6");

    const res = await fetch(url.toString(), {
      headers: { Accept: "application/json", "User-Agent": UA },
    });
    if (!res.ok) continue;
    const body = (await res.json()) as {
      features?: Array<{ properties?: Record<string, unknown>; geometry?: { coordinates?: number[] } }>;
    };
    for (const f of body.features ?? []) {
      const props = f.properties ?? {};
      const name = String(props.name ?? "").trim();
      if (!name || !isUsefulHit(name, q, props)) continue;
      const c = featureToCenter(f, opts.city, id++);
      if (!c) continue;
      const key = `${normTr(c.name)}|${c.lat.toFixed(4)}|${c.lng.toFixed(4)}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(c);
    }
    if (out.length > 0) break;
  }
  return out;
}

/** City browse harvest when the static catalog is empty. */
export async function harvestCentersOsm(opts: {
  lat: number;
  lng: number;
  city: string;
}): Promise<OsmCenter[]> {
  const queries = [
    `özel eğitim rehabilitasyon ${opts.city}`,
    `fizik tedavi ${opts.city}`,
    `rehabilitasyon merkezi ${opts.city}`,
  ];
  const seen = new Set<string>();
  const out: OsmCenter[] = [];
  let id = 920000;
  for (const q of queries) {
    const url = new URL("https://photon.komoot.io/api/");
    url.searchParams.set("q", q);
    url.searchParams.set("lat", String(opts.lat));
    url.searchParams.set("lon", String(opts.lng));
    url.searchParams.set("limit", "15");
    url.searchParams.set("lang", "en");
    url.searchParams.set("location_bias_scale", "0.8");
    const res = await fetch(url.toString(), {
      headers: { Accept: "application/json", "User-Agent": UA },
    });
    if (!res.ok) continue;
    const body = (await res.json()) as {
      features?: Array<{ properties?: Record<string, unknown>; geometry?: { coordinates?: number[] } }>;
    };
    for (const f of body.features ?? []) {
      const props = f.properties ?? {};
      const name = String(props.name ?? "").trim();
      if (!name || !isUsefulHit(name, q, props)) continue;
      const c = featureToCenter(f, opts.city, id++);
      if (!c) continue;
      const key = `${normTr(c.name)}|${c.lat.toFixed(4)}|${c.lng.toFixed(4)}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(c);
    }
  }
  return out;
}

export function localMatchesSearch(
  center: { name: string; category: string; address: string; ilce?: string; services: string[] },
  query: string,
): boolean {
  const q = query.trim();
  if (!q) return true;
  const hay = [center.name, center.category, center.address, center.ilce ?? "", ...center.services].join(" ");
  return haystackMatchesQuery(hay, q);
}
