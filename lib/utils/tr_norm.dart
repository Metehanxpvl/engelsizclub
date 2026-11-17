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
