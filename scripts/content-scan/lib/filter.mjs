import { foldTr } from './normalize.mjs';

const CORE = [
  'engelli',
  'engelsiz',
  'ozel gereksinim',
  'ozel egitim',
  'destek',
  'bakim',
  'burs',
  'hibe',
  'maas',
  'aylik',
  'erisilebilir',
  'tedavi',
  'rehabilitasyon',
  'ekpss',
  'otv',
  'protez',
  'ortez',
  'tekerlekli',
  'koklear',
  'kaynastirma',
  'cozger',
];

const HARD_DROP = [
  'magazin',
  'unlu',
  'dizi final',
  'mac sonucu',
  'spor toto',
  'hava durumu',
  'burc yorum',
  'ilan: satilik',
  'kumar',
  'bahis',
];

export function haystack(item) {
  return foldTr(
    `${item.title || ''} ${item.raw_snippet || item.summary || ''} ${item.source || ''}`,
  );
}

export function extraConditionNeedles(conditions) {
  const out = [];
  for (const c of conditions || []) {
    for (const w of [...(c.tr || []), ...(c.en || []), c.ad]) {
      const f = foldTr(w);
      if (f) out.push(f);
    }
  }
  return out;
}

export function passesKeywordFilter(item, conditions = []) {
  const hay = haystack(item);
  if (!hay) return false;
  if (HARD_DROP.some((k) => hay.includes(k))) return false;
  if (CORE.some((k) => hay.includes(k))) return true;
  const extra = extraConditionNeedles(conditions);
  if (extra.some((k) => k.length > 2 && hay.includes(k))) return true;
  if (item.group === 'science' || item.kind === 'science') return extra.some((k) => hay.includes(k));
  return false;
}
