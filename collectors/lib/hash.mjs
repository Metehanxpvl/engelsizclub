import { createHash } from 'node:crypto';

export function stripHtml(raw) {
  const text = String(raw ?? '');
  if (!text) return '';
  return text
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_, n) => {
      const code = Number(n);
      return Number.isFinite(code) ? String.fromCharCode(code) : ' ';
    })
    .replace(/\s+/g, ' ')
    .trim();
}

export function usefulContentHash({ title, summary, sourceUrl }) {
  const normalized = [
    String(title ?? '').trim().toLowerCase(),
    String(summary ?? '').trim().toLowerCase(),
    String(sourceUrl ?? '').trim().toLowerCase(),
  ].join('|');
  return createHash('sha256').update(normalized, 'utf8').digest('hex');
}

export function titleSourceFingerprint(title, sourceName) {
  const t = foldTr(title)
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .slice(0, 96);
  const s = foldTr(sourceName).slice(0, 48);
  return t && s ? `${t}|${s}` : '';
}

export function isDuplicate(
  existing,
  { sourceUrl, contentHash, externalId, title, sourceName },
) {
  const url = String(sourceUrl ?? '').trim();
  const hash = String(contentHash ?? '').trim();
  const ext = String(externalId ?? '').trim();
  if (url && existing.urls.has(url)) return true;
  if (hash && existing.hashes.has(hash)) return true;
  if (ext && existing.externalIds.has(ext)) return true;
  const fp = titleSourceFingerprint(title, sourceName);
  if (fp && existing.titleKeys && existing.titleKeys.has(fp)) return true;
  return false;
}

/** Fold TR letters + İ→i so "Özel Gereksinimli" matches "ozel gereksinim". */
export function foldTr(text) {
  return String(text ?? '')
    .toLowerCase()
    .replace(/\u0130/g, 'i')
    .replace(/\u0307/g, '')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    .replace(/[''`´’]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export const DISABILITY_CORE_KEYWORDS = [
  'engelli',
  'engelsiz',
  'engeli',
  'ozel gereksinim',
  'ozel egitim',
  'ozel yetenek',
  'ozurlu',
  'otizm',
  'asperger',
  'otizm spektrum',
  'osbli',
  'osb tani',
  'osb ogrenci',
  'osb cocuk',
  'osb spektrum',
  'osb bozuk',
  'down sendrom',
  'down syndrome',
  'mongolizm',
  'trizomi 21',
  'trisomi 21',
  'trisomy 21',
  'serebral pal',
  'serebral palsi',
  'serebral paldi',
  'cerebral palsy',
  'cerebral pal',
  'erisilebilir',
  'evde egitim',
  'bakim ayligi',
  'engelli maasi',
  'otv muaf',
  'rehberlik arastirma',
  'isitme engel',
  'gorme engel',
  'bedensel engel',
  'zihinsel engel',
  'bedensel yetersiz',
  'zihinsel yetersiz',
  'isitme yetersiz',
  'gorme yetersiz',
  'gelisim gerili',
  'dil konusma',
  'dil ve konusma',
  'tekerlekli sandalye',
  'nadir hastalik',
  'protez ortez',
  'kaynastirma',
  'bireyselestirilmis egitim',
  'destek egitim odasi',
  'cozger',
  'erozger',
  'isaret dili',
  'ekpss',
  'korumali isyeri',
  'disleksi',
  'braille',
  'paralimpik',
  'meb orgm',
  'evde bakim yardimi',
  'engelli kimlik',
  'eyhgm',
  'shcek',
  'tidyes',
];

const CORE_WORD_RE = [
  /\bsma\b/i,
  /\bdehb\b/i,
  /\badhd\b/i,
  /\bcvi\b/i,
  /\bram\b/i,
  /\bbep\b/i,
  /\boyc\b/i,
  /\borgm\b/i,
  // SP'li / SPli — not bare \bsp\b (too many false hits)
  /\bspli\b/i,
];

export const RELEVANCE_KEYWORDS = DISABILITY_CORE_KEYWORDS;

/** burs/bursu/burslar/scholarship — not the city "Bursa". Alone this is NOT enough. */
const SCHOLARSHIP_RE = [
  /\bburs(u|lar|lari)?\b/,
  /\bscholarship\b/,
  /ogrenim burs/,
];

export function hasScholarshipTerm(text) {
  const hay = foldTr(text);
  if (!hay) return false;
  return SCHOLARSHIP_RE.some((re) => re.test(hay));
}

export function hasDisabilityCore(text) {
  const hay = foldTr(text);
  if (!hay) return false;
  if (DISABILITY_CORE_KEYWORDS.some((k) => hay.includes(k))) return true;
  if (CORE_WORD_RE.some((re) => re.test(hay))) return true;
  return false;
}

export function hasRelevanceKeyword(text) {
  return isDisabilityOpportunity(text);
}

/**
 * Keep disability/özel gereksinim news (with or without burs).
 * burs + core (engellilere burs, özel gereksinimli öğrencilere burs) is KEEP
 * because of the core term — never because burs stands alone.
 */
export function isDisabilityOpportunity(text) {
  const raw = String(text ?? '');
  if (!raw.trim()) return false;
  return hasDisabilityCore(raw);
}

/** Direct keep extras that are still disability/device-specific. */
const DIRECT_EXTRA_KEYWORDS = [
  'tibbi cihaz',
  'medikal cihaz',
  'isitme cihazi',
  'engelli araci',
  'engelli ramp',
  'otv muafiyet',
];

export const POTENTIAL_FAMILY_KEYWORDS = [
  'sosyal yardim',
  'nakdi yardim',
  'nakdi destek',
  'maddi destek',
  'maddi yardim',
  'dar gelirli',
  'dusuk gelirli',
  'ucretsiz kurs',
  'ucretsiz ulasim',
  'ucretsiz otobus',
  'ucretsiz servis',
  'gida yardimi',
  'yakacak yardimi',
  'kira yardimi',
  'egitim yardimi',
  'sosyal destek',
  'yardim basvuru',
  'sosyal hizmet',
  'askida fatura',
  'basvurular basladi',
  'basvuru basladi',
  'basvurular acildi',
  'basvuruya acildi',
  'basvuru alimi basladi',
  'online basvuru alimi',
];

const HARD_REJECT_KEYWORDS = [
  'asfalt',
  'yol calismasi',
  'yol calisma',
  'yol onarim',
  'kazi calismasi',
  'personel atama',
  'atama kararnamesi',
  'memur alimi',
  'sozlesmeli personel',
  'imar plani',
  'imar degisikligi',
  'ihale ilan',
  'hava durumu',
  'kar yagis',
  'trafik duzenleme',
  'spor galibiyet',
  'belediyespor',
  'konser',
  'miting',
  'parti grup',
  'personel basvuru',
  'is basvurusu',
];

const HARD_REJECT_RE = [
  /\bbaskan\b.{0,40}\baciklama/,
  /\bbaskan\b.{0,40}\bacikladi/,
  /\bgenel acilis\b/,
  /\bacilis toren/,
  /\bsiyasi\b/,
];

export const CATEGORY_LABELS = [
  'firsat',
  'destek',
  'hak',
  'burs',
  'egitim',
  'istihdam',
  'sosyal_yardim',
  'nakdi_yardim',
  'ulasim',
  'cihaz',
  'saglik',
  'barinma',
  'etkinlik',
  'basvuru',
  'bakim',
  'erisilebilirlik',
  'ozel_egitim',
  'kultur',
  'otv',
  'diger',
];

const PRIMARY_CATEGORY_MAP = {
  sosyal_yardim: 'destek',
  nakdi_yardim: 'destek',
  ulasim: 'destek',
  cihaz: 'hak',
  saglik: 'hak',
  barinma: 'destek',
  etkinlik: 'firsat',
  basvuru: 'firsat',
  bakim: 'destek',
  erisilebilirlik: 'hak',
  ozel_egitim: 'egitim',
  kultur: 'firsat',
  otv: 'hak',
};

const UI_CATEGORIES = new Set([
  'firsat',
  'destek',
  'hak',
  'burs',
  'egitim',
  'istihdam',
  'diger',
]);

export function isHardReject(text) {
  const hay = foldTr(text);
  if (!hay) return false;
  if (HARD_REJECT_KEYWORDS.some((k) => hay.includes(k))) return true;
  return HARD_REJECT_RE.some((re) => re.test(hay));
}

const WEAK_POTENTIAL_RE = /\bbasvuru|\bburs(u|lar|lari)?\b|\bscholarship\b/;

export function hasPotentialFamilyBenefit(text) {
  const hay = foldTr(text);
  if (!hay) return false;
  if (POTENTIAL_FAMILY_KEYWORDS.some((k) => hay.includes(k))) return true;
  if (hasScholarshipTerm(text)) return true;
  return WEAK_POTENTIAL_RE.test(hay);
}

export function hasStrongFamilyBenefit(text) {
  const hay = foldTr(text);
  if (!hay) return false;
  return POTENTIAL_FAMILY_KEYWORDS.some(
    (k) => !k.includes('basvuru') && hay.includes(k),
  );
}

export function hasDirectKeep(text) {
  if (hasDisabilityCore(text)) return true;
  const hay = foldTr(text);
  return DIRECT_EXTRA_KEYWORDS.some((k) => hay.includes(k));
}

/**
 * direct = disability / özel gereksinim / cihaz-ÖTV.
 * potential = aile faydası (sosyal yardım, burs, ücretsiz kurs, başvuru)
 *   even without “engelli” — AVM etkinlikleri gibi.
 * null = asfalt / atama / siyasi / genel açılış.
 */
export function classifyKeep(text) {
  const raw = String(text ?? '');
  if (!raw.trim()) return null;
  if (hasDirectKeep(raw)) return 'direct';
  const potential = hasPotentialFamilyBenefit(raw);
  if (isHardReject(raw)) {
    return hasStrongFamilyBenefit(raw) ? 'potential' : null;
  }
  if (potential) return 'potential';
  return null;
}

export function shouldKeepCandidate(text) {
  return classifyKeep(text) != null;
}

export function primaryCategory(labels) {
  const list = (Array.isArray(labels) ? labels : [labels])
    .map((v) => String(v || '').trim().toLowerCase())
    .filter(Boolean);
  const ui = list.find((l) => UI_CATEGORIES.has(l));
  if (ui) return ui;
  for (const l of list) {
    if (PRIMARY_CATEGORY_MAP[l]) return PRIMARY_CATEGORY_MAP[l];
  }
  return 'diger';
}

export function normalizeCategoryLabels(raw) {
  const parts = Array.isArray(raw)
    ? raw
    : String(raw || '')
        .split(/[,|/]+/)
        .map((s) => s.trim().toLowerCase());
  const known = [];
  const seen = new Set();
  for (const p of parts) {
    if (!CATEGORY_LABELS.includes(p) || seen.has(p)) continue;
    seen.add(p);
    known.push(p);
  }
  return known.length ? known : ['diger'];
}
