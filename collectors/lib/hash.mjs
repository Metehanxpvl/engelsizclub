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

export const RELEVANCE_KEYWORDS = [
  'engelli',
  'engelsiz',
  'özel gereksinim',
  'ozel gereksinim',
  'otizm',
  'down sendrom',
  'serebral palsi',
  'sma',
  'dehb',
  'erişilebilir',
  'erisilebilir',
  'evde eğitim',
  'evde egitim',
  'özel eğitim',
  'ozel egitim',
  'ram ',
  'bakım aylığı',
  'bakim ayligi',
  'engelli maaşı',
  'engelli maasi',
  'işkur',
  'iskur',
  'burs',
  'istihdam',
  'kota',
  'erişilebilirlik',
];

export function hasRelevanceKeyword(text) {
  const hay = String(text ?? '').toLowerCase();
  if (!hay.trim()) return false;
  return RELEVANCE_KEYWORDS.some((k) => hay.includes(k));
}
