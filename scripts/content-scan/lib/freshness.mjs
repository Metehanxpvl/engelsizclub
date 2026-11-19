// Güncellik filtresi (news modu): eski ve tarihsiz içerik LLM'e ve kuyruğa girmesin.
// Haberler: en fazla 3 gün. Fırsat/destek ve diğerleri: en fazla 7 gün.

export const NEWS_MAX_AGE_DAYS = 3;
export const GENERAL_MAX_AGE_DAYS = 7;

const DAY_MS = 24 * 3600 * 1000;

export function ageDays(date, nowMs = Date.now()) {
  if (!date) return null;
  const t = Date.parse(date);
  if (!Number.isFinite(t)) return null;
  return (nowMs - t) / DAY_MS;
}

/** LLM öncesi: tarihsiz veya 7 günden eski kayıtları ele. */
export function isFreshForScan(item, nowMs = Date.now()) {
  const age = ageDays(item?.date, nowMs);
  if (age == null) return false;
  return age <= GENERAL_MAX_AGE_DAYS;
}

/** Yönlendirme sonrası: haber tablosuna gidecekse 3 gün sınırı. */
export function isFreshForTable(table, item, nowMs = Date.now()) {
  if (table !== 'news_candidates') return true;
  const age = ageDays(item?.date, nowMs);
  return age != null && age <= NEWS_MAX_AGE_DAYS;
}
