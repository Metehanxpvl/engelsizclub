/// Basit kullanıcı içeriği filtresi (forum, ilan, yorum).
library;

/// Yaygın küfür / hakaret kalıpları (kısmi eşleşme, küçük harf).
const _blockedPatterns = [
  'amk',
  'aq ',
  'orospu',
  'piç',
  'sik',
  'yarrak',
  'mal ',
  'salak',
  'aptal',
  'gerizekalı',
  'kahpe',
  'pezevenk',
  'fuck',
  'shit',
  'bitch',
];

/// Metinde uygunsuz ifade var mı?
bool containsBlockedContent(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.trim().isEmpty) return false;
  for (final p in _blockedPatterns) {
    if (normalized.contains(p)) return true;
  }
  return false;
}

/// Uygunsuz içerik varsa kullanıcıya gösterilecek mesaj.
String blockedContentMessage() =>
    'Paylaşımınız uygunsuz veya saldırgan ifadeler içeriyor. '
    'Lütfen metni düzenleyin. Engelsiz Club’da uygunsuz içeriğe sıfır tolerans uygulanır.';
