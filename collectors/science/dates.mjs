/** Papers and trials: last 5 calendar years. 1825 = 5 * 365 (PubMed reldate). */

export const LOOKBACK_YEARS = 5;
export const RELDATE_DAYS = 5 * 365;

export function utcYmd(now = new Date()) {
  const d = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(d.getTime())) return '';
  return d.toISOString().slice(0, 10);
}

export function lookbackStartYmd(now = new Date(), years = LOOKBACK_YEARS) {
  const d = now instanceof Date ? new Date(now) : new Date(now);
  if (Number.isNaN(d.getTime())) return '';
  d.setUTCFullYear(d.getUTCFullYear() - Number(years || LOOKBACK_YEARS));
  return utcYmd(d);
}

export function pubmedMindate(now = new Date(), years = LOOKBACK_YEARS) {
  return lookbackStartYmd(now, years).replace(/-/g, '/');
}

export function pubmedMaxdate(now = new Date()) {
  return utcYmd(now).replace(/-/g, '/');
}

/**
 * @returns {{ ymd: string, yearOnly: boolean } | null}
 */
export function parseFlexibleDate(raw) {
  const s = String(raw || '').trim();
  if (!s) return null;
  const iso = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return { ymd: `${iso[1]}-${iso[2]}-${iso[3]}`, yearOnly: false };
  const slash = s.match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})/);
  if (slash) {
    return {
      ymd: `${slash[1]}-${String(slash[2]).padStart(2, '0')}-${String(slash[3]).padStart(2, '0')}`,
      yearOnly: false,
    };
  }
  const compact = s.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (compact) {
    return { ymd: `${compact[1]}-${compact[2]}-${compact[3]}`, yearOnly: false };
  }
  const year = s.match(/^(\d{4})$/);
  if (year) return { ymd: `${year[1]}-01-01`, yearOnly: true };
  return null;
}

/**
 * true = within window, false = older, null = unknown date.
 * Year-only values keep the whole calendar year of the cutoff.
 */
export function isWithinLookback(
  raw,
  now = new Date(),
  years = LOOKBACK_YEARS,
) {
  const parsed = parseFlexibleDate(raw);
  if (!parsed) return null;
  const start = lookbackStartYmd(now, years);
  if (!start) return null;
  if (parsed.yearOnly || parsed.ymd.endsWith('-01-01')) {
    return parsed.ymd.slice(0, 4) >= start.slice(0, 4);
  }
  return parsed.ymd >= start;
}

export function itemDateForLookback(item) {
  return (
    item?.publicationDate ||
    item?.startDate ||
    item?.lastUpdatePostDate ||
    item?.resultsFirstPostDate ||
    null
  );
}

/** Drop dated papers/trials older than the lookback. Unknown dates are kept (API already filtered). */
export function shouldDropOlder(item, now = new Date(), years = LOOKBACK_YEARS) {
  const primary = item?.publicationDate || item?.startDate;
  if (primary) return isWithinLookback(primary, now, years) === false;
  if (item?.lastUpdatePostDate) {
    return isWithinLookback(item.lastUpdatePostDate, now, years) === false;
  }
  return false;
}

export function filterRecentItems(items, now = new Date(), years = LOOKBACK_YEARS) {
  return (items || []).filter((item) => !shouldDropOlder(item, now, years));
}

export function scienceDateWindow(now = new Date(), years = LOOKBACK_YEARS) {
  const today = utcYmd(now);
  const start = lookbackStartYmd(now, years);
  return {
    years,
    reldateDays: RELDATE_DAYS,
    start,
    end: today,
    pubmedMindate: start.replace(/-/g, '/'),
    pubmedMaxdate: today.replace(/-/g, '/'),
  };
}
