/// Basit kullanıcı içeriği filtresi (forum, ilan, yorum).
library;

String _trLower(String raw) {
  return raw
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');
}

/// Tam kelime: küfür, hakaret, tehdit / şiddet, kaba hijyen argosu.
///
/// `sik` gibi kısa kökleri **alt dizgi** olarak arama: `psikolog`,
/// `psikiyatrist`, `klasik`, `eksik` yanlışlıkla engellenir.
const _blockedWords = <String>{
  // Küfür / hakaret
  'amk',
  'amq',
  'amına',
  'amina',
  'aminakoyayim',
  'aminakoyim',
  'orospu',
  'orospucocugu',
  'orospuevladı',
  'orospuevladi',
  'piç',
  'pic',
  'siktir',
  'sikik',
  'sikerim',
  'sikiş',
  'sikis',
  'yarrak',
  'yarak',
  'kahpe',
  'pezevenk',
  'gavat',
  'ibne',
  'gerizekalı',
  'gerizekali',
  'salak',
  'aptal',
  'fuck',
  'shit',
  'bitch',
  'asshole',
  // Şiddet / tehdit
  'öldür',
  'oldur',
  'öldürecem',
  'oldurecem',
  'öldüreceğim',
  'oldurecegim',
  'öldürürüm',
  'oldururum',
  'gebert',
  'geberteceğim',
  'gebertecegim',
  'tecavüz',
  'tecavuz',
  // Kaba hijyen / argo (bakım cümlesi değil, tek kelime sövme)
  'bez',
  'klozet',
};

/// Kök + ek: siktiririm, orospunun, öldürecez…
/// `sik` prefix olarak da kullanılmaz (psikolog / psikiyatrist).
const _blockedPrefixes = <String>[
  'siktir',
  'sikik',
  'siker',
  'orospu',
  'öldür',
  'oldur',
  'tecavüz',
  'tecavuz',
  'gebert',
];

/// Meslek / bakım terimleri: küfür kökü içeriyor gibi görünseler de serbest.
const _benignStems = <String>[
  'psikolog',
  'psikoloj',
  'psikiyatr',
  'klasik',
  'eksik',
  'bezelye',
  'obez',
];

final _tokenSplit = RegExp(r'[^a-z0-9çğıöşü]+');

Iterable<String> _tokens(String normalized) {
  return normalized.split(_tokenSplit).where((t) => t.isNotEmpty);
}

bool _isBenignToken(String token) {
  for (final stem in _benignStems) {
    if (token.contains(stem)) return true;
  }
  return false;
}

/// Metinde uygunsuz ifade var mı?
bool containsBlockedContent(String text) {
  final normalized = _trLower(text).replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.trim().isEmpty) return false;

  for (final token in _tokens(normalized)) {
    if (_isBenignToken(token)) continue;
    if (_blockedWords.contains(token)) return true;
    for (final prefix in _blockedPrefixes) {
      if (token.startsWith(prefix) && token.length >= prefix.length) {
        return true;
      }
    }
  }

  final compact = normalized.replaceAll(RegExp(r'[\s\-_./]+'), '');
  if (compact.contains('bezklozet') || compact.contains('klozetbez')) {
    return true;
  }
  return false;
}

/// Uygunsuz içerik varsa kullanıcıya gösterilecek mesaj (yumuşak uyarı).
String blockedContentMessage() =>
    'Bu metinde kaba, küfürlü veya sert bir ifade var. '
    'Lütfen daha nazik bir dille yazın. Engelsiz Club sakin bir aile alanı.';
