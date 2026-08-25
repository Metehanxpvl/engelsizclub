import 'kesfet_models.dart';

/// SQL `kesfet_score_text` ile aynı kurallar (Phase 1 admin önizleme).
/// Tek zayıf negatif (ör. gündem) otomatik red değildir.
/// Sağlık iddiası → safety_flag; asla otomatik onay yok.
KesfetScore scoreKesfetText({
  required String title,
  required String description,
  List<String> tags = const [],
  String channel = '',
  List<KesfetKeyword> keywords = const [],
}) {
  final list = keywords.where((k) => k.isActive && k.phrase.trim().isNotEmpty);
  final haystack = [
    title,
    description,
    tags.join(' '),
    channel,
  ].join(' ').toLowerCase();

  var score = 0;
  var safety = false;
  final notes = <String>[];
  final pos = <String>[];
  final neg = <String>[];
  final catVotes = <String, int>{};

  for (final k in list) {
    final p = k.phrase.trim().toLowerCase();
    if (p.isEmpty || !haystack.contains(p)) continue;
    switch (k.polarity) {
      case 'positive':
        score += k.weight;
        pos.add(k.phrase);
        final hint = k.categoryHint.trim();
        if (hint.isNotEmpty && hint != 'sana-ozel') {
          catVotes[hint] = (catVotes[hint] ?? 0) + k.weight;
        }
      case 'negative':
        neg.add(k.phrase);
        score -= k.isWeak ? (k.weight / 2).ceil().clamp(1, k.weight) : k.weight;
      case 'safety':
        safety = true;
        score -= 5;
        notes.add(k.phrase);
      default:
        break;
    }
  }

  var cat = 'engellilik';
  var best = 0;
  catVotes.forEach((slug, w) {
    if (w > best) {
      best = w;
      cat = slug;
    }
  });

  return KesfetScore(
    score: score,
    safetyFlag: safety,
    suggestedCategory: cat,
    safetyNote: safety
        ? 'Sağlık iddiası tespit edildi: ${notes.join(', ')}'
        : '',
    matchedPositives: pos,
    matchedNegatives: neg,
  );
}

/// Tablo boşsa / ağ yoksa kullanılan yedek liste (seed ile uyumlu).
const kKesfetFallbackKeywords = <KesfetKeyword>[
  KesfetKeyword(phrase: 'engelli', polarity: 'positive', weight: 12, categoryHint: 'engellilik'),
  KesfetKeyword(phrase: 'engellilik', polarity: 'positive', weight: 14, categoryHint: 'engellilik'),
  KesfetKeyword(phrase: 'özel gereksinim', polarity: 'positive', weight: 14, categoryHint: 'engellilik'),
  KesfetKeyword(phrase: 'otizm', polarity: 'positive', weight: 16, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'down sendrom', polarity: 'positive', weight: 16, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'serebral palsi', polarity: 'positive', weight: 16, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'tekerlekli sandalye', polarity: 'positive', weight: 14, categoryHint: 'erisilebilirlik'),
  KesfetKeyword(phrase: 'erişilebilirlik', polarity: 'positive', weight: 16, categoryHint: 'erisilebilirlik'),
  KesfetKeyword(phrase: 'işaret dili', polarity: 'positive', weight: 14, categoryHint: 'erisilebilirlik'),
  KesfetKeyword(phrase: 'engelli maaşı', polarity: 'positive', weight: 16, categoryHint: 'haklar'),
  KesfetKeyword(phrase: 'evde bakım', polarity: 'positive', weight: 14, categoryHint: 'haklar'),
  KesfetKeyword(phrase: 'özel eğitim', polarity: 'positive', weight: 16, categoryHint: 'egitim'),
  KesfetKeyword(phrase: 'nadir hastalık', polarity: 'positive', weight: 16, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'sma', polarity: 'positive', weight: 14, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'prematüre', polarity: 'positive', weight: 12, categoryHint: 'hastaliklar'),
  KesfetKeyword(phrase: 'fizyoterapi', polarity: 'positive', weight: 12, categoryHint: 'saglik'),
  KesfetKeyword(phrase: 'aile', polarity: 'positive', weight: 6, categoryHint: 'aile', isWeak: true),
  KesfetKeyword(phrase: 'gündem', polarity: 'negative', weight: 6, isWeak: true),
  KesfetKeyword(phrase: 'magazin', polarity: 'negative', weight: 14),
  KesfetKeyword(phrase: 'unboxing', polarity: 'negative', weight: 16),
  KesfetKeyword(phrase: 'komedi', polarity: 'negative', weight: 14),
  KesfetKeyword(phrase: 'gameplay', polarity: 'negative', weight: 16),
  KesfetKeyword(phrase: 'makyaj', polarity: 'negative', weight: 14),
  KesfetKeyword(phrase: 'prank', polarity: 'negative', weight: 16),
  KesfetKeyword(phrase: 'kesin iyileştirir', polarity: 'safety', weight: 20),
  KesfetKeyword(phrase: 'mucize tedavi', polarity: 'safety', weight: 20),
  KesfetKeyword(phrase: 'doktora gerek yok', polarity: 'safety', weight: 20),
  KesfetKeyword(phrase: '%100 tedavi', polarity: 'safety', weight: 20),
  KesfetKeyword(phrase: 'garantili şifa', polarity: 'safety', weight: 20),
];
