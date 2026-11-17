/// Turkish-aware fold for search / Places matching.
///
/// Replaces Turkish specials **before** [toLowerCase] so `İ` does not become
/// `i` + combining dot (`\u0307`), then strips any leftover combining dots.
String normTrForSearch(String s) {
  return s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c')
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Significant tokens from a free-text query (length ≥ [minLen]).
List<String> searchTokens(String query, {int minLen = 2}) {
  final n = normTrForSearch(query);
  if (n.isEmpty) return const [];
  return n
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length >= minLen)
      .toList(growable: false);
}

/// True when every significant query token appears somewhere in [haystack].
///
/// Multi-word queries like `kadıköy fizik tedavi` must not require the entire
/// phrase as a contiguous substring of a single field.
bool haystackMatchesQuery(String haystack, String query, {int minLen = 2}) {
  final tokens = searchTokens(query, minLen: minLen);
  if (tokens.isEmpty) return true;
  final h = normTrForSearch(haystack);
  return tokens.every(h.contains);
}
