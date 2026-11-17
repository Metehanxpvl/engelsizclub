/** Turkish-aware fold for search matching. */
export function normTr(s: string): string {
  return s
    .replaceAll("İ", "i")
    .replaceAll("I", "i")
    .replaceAll("ı", "i")
    .replaceAll("Ö", "o")
    .replaceAll("ö", "o")
    .replaceAll("Ü", "u")
    .replaceAll("ü", "u")
    .replaceAll("Ş", "s")
    .replaceAll("ş", "s")
    .replaceAll("Ğ", "g")
    .replaceAll("ğ", "g")
    .replaceAll("Ç", "c")
    .replaceAll("ç", "c")
    .toLowerCase()
    .replaceAll("\u0307", "")
    .replace(/\s+/g, " ")
    .trim();
}

export function searchTokens(query: string, minLen = 2): string[] {
  const n = normTr(query);
  if (!n) return [];
  return n.split(/[^a-z0-9]+/).filter((t) => t.length >= minLen);
}

/** Every significant query token must appear somewhere in haystack. */
export function haystackMatchesQuery(haystack: string, query: string): boolean {
  const tokens = searchTokens(query);
  if (tokens.length === 0) return true;
  const h = normTr(haystack);
  return tokens.every((t) => h.includes(t));
}
