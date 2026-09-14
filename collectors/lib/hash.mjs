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

export function isDuplicate(existing, { sourceUrl, contentHash, externalId }) {
  const url = String(sourceUrl ?? '').trim();
  const hash = String(contentHash ?? '').trim();
  const ext = String(externalId ?? '').trim();
  if (url && existing.urls.has(url)) return true;
  if (hash && existing.hashes.has(hash)) return true;
  if (ext && existing.externalIds.has(ext)) return true;
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
