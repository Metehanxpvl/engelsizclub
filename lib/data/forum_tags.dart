// Forum etiketleri — hazır tıbbi alt tipler + serbest # etiket yardımcıları.

/// Kategori etiketine göre önerilen hazır etiketler (# ile).
const Map<String, List<String>> kForumSuggestedTagsByCategory = {
  'Serebral Palsi': [
    '#SpastikDipleji',
    '#SpastikHemipleji',
    '#SpastikKuadripleji',
    '#DiskinetikSP',
    '#AtaksikSP',
    '#KarisikTipSP',
    '#Fizyoterapi',
    '#Ortez',
  ],
  'Otizm': [
    '#AspergerSendromu',
    '#AtipikOtizm',
    '#OSB',
    '#YuksekFonksiyonluOtizm',
    '#KonusmaGecikmesi',
    '#ErkenMudahale',
    '#OzelEgitim',
    '#DuyuButunleme',
  ],
  'Down Sendromu': [
    '#Trizomi21',
    '#MozaikDown',
    '#TranslokasyonDown',
    '#ErkenMudahale',
    '#KonusmaTerapisi',
    '#Egitim',
  ],
  'SMA': [
    '#Tip1SMA',
    '#Tip2SMA',
    '#Tip3SMA',
    '#Tip4SMA',
    '#Spinraza',
    '#Zolgensma',
    '#Evrysdi',
    '#Fizyoterapi',
  ],
  'DEHB': [
    '#DikkatEksikligi',
    '#Hiperaktivite',
    '#KombineTip',
    '#OkulDestegi',
    '#DavranisTerapisi',
  ],
  'Gelişim Geriliği': [
    '#MotorGelisim',
    '#DilGelisim',
    '#KognitifGelisim',
    '#ErkenMudahale',
    '#OzelEgitim',
  ],
  'Duyu Bütünleme': [
    '#DokunmaHassasiyeti',
    '#IsitmeHassasiyeti',
    '#Denge',
    '#Propriosepsiyon',
    '#Ergoterapi',
  ],
  'İletişim Bozuklukları': [
    '#KonusmaGecikmesi',
    '#Artikulasyon',
    '#Kekemelik',
    '#Afazi',
    '#DilKonusmaTerapisi',
  ],
  'Nadir Hastalıklar': [
    '#GenetikTani',
    '#TedaviErisim',
    '#Bakim',
    '#DestekGrubu',
  ],
  'Genel Konular': [
    '#SoruCevap',
    '#Deneyim',
    '#Tavsiye',
    '#Haklar',
    '#Destek',
    '#Duyuru',
  ],
  'Köşe Yazısı': [
    '#KoseYazisi',
    '#UzmanGorusu',
    '#AileyeNot',
    '#Rehber',
  ],
  'Uzman': [
    '#KoseYazisi',
    '#UzmanGorusu',
    '#MeslekPaylasimi',
  ],
};

/// Etiketi normalize eder: `#TagName` formatı, boşluk yok, PascalCase'e yakın.
String normalizeForumTag(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return '';
  // Virgül / boşlukla ayrılmışsa ilk parçayı al
  t = t.split(RegExp(r'[\s,;]+')).first.trim();
  if (t.isEmpty) return '';
  if (!t.startsWith('#')) t = '#$t';
  // Sadece harf/rakam/_ bırak
  final body = t.substring(1).replaceAll(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]', unicode: true), '');
  if (body.isEmpty) return '';
  return '#$body';
}

List<String> normalizeForumTags(Iterable<String> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final r in raw) {
    final t = normalizeForumTag(r);
    if (t.isEmpty) continue;
    final key = t.toLowerCase();
    if (seen.add(key)) out.add(t);
  }
  return out;
}

/// Metin içinden `#Etiket` yakalar.
List<String> extractHashTagsFromText(String text) {
  final re = RegExp(r'#([\wğüşıöçĞÜŞİÖÇ]+)', unicode: true);
  return normalizeForumTags(re.allMatches(text).map((m) => '#${m.group(1)!}'));
}

List<String> suggestedTagsForCategory(String category) {
  final c = category.trim();
  if (c.isEmpty) return kForumSuggestedTagsByCategory['Genel Konular'] ?? const [];
  // Doğrudan eşleşme
  final direct = kForumSuggestedTagsByCategory[c];
  if (direct != null) return List<String>.from(direct);
  // Esnek eşleşme
  final lower = c.toLowerCase();
  for (final e in kForumSuggestedTagsByCategory.entries) {
    if (lower.contains(e.key.toLowerCase()) ||
        e.key.toLowerCase().contains(lower)) {
      return List<String>.from(e.value);
    }
  }
  if (lower.contains('serebral') || lower.contains('palsi')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Serebral Palsi']!);
  }
  if (lower.contains('otizm')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Otizm']!);
  }
  if (lower.contains('down')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Down Sendromu']!);
  }
  if (lower.contains('sma')) {
    return List<String>.from(kForumSuggestedTagsByCategory['SMA']!);
  }
  if (lower.contains('dehb')) {
    return List<String>.from(kForumSuggestedTagsByCategory['DEHB']!);
  }
  if (lower.contains('gelişim') || lower.contains('gelisim')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Gelişim Geriliği']!);
  }
  if (lower.contains('duyu')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Duyu Bütünleme']!);
  }
  if (lower.contains('iletişim') || lower.contains('iletisim')) {
    return List<String>.from(
        kForumSuggestedTagsByCategory['İletişim Bozuklukları']!);
  }
  if (lower.contains('nadir')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Nadir Hastalıklar']!);
  }
  if (lower.contains('köşe') || lower.contains('kose') || lower.contains('uzman')) {
    return List<String>.from(kForumSuggestedTagsByCategory['Köşe Yazısı']!);
  }
  return List<String>.from(kForumSuggestedTagsByCategory['Genel Konular']!);
}
