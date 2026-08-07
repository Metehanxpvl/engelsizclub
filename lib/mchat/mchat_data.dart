// M-CHAT-R tarzı otizm tarama soruları.
// Not: Bu uygulama tanı koymaz; yalnızca bilgilendirici tarama amaçlıdır.

class MchatSoru {
  const MchatSoru({
    required this.id,
    required this.soru,
    required this.kritik,
    required this.riskli,
  });

  final int id;
  final String soru;
  /// Kritik madde — sonuç algoritmasında ayrı sayılır.
  final bool kritik;
  /// Risk puanı veren cevap: "Evet" veya "Hayır"
  final String riskli;
}

/// 20 soruluk tarama listesi.
const mchatSorular = <MchatSoru>[
  MchatSoru(
    id: 1,
    soru: 'Çocuğunuz sizinle göz teması kurmaktan hoşlanır mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 2,
    soru: 'Çocuğunuz ismiyle seslenince bakar mı?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 3,
    soru: 'Çocuğunuz bir şey gösterip sizinle paylaşır mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 4,
    soru: 'Çocuğunuz taklit oyunları oynar mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 5,
    soru: 'Çocuğunuz parmağıyla istediği bir şeyi gösterir mi?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 6,
    soru: 'Çocuğunuz parmağınızla gösterdiğiniz şeye bakar mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 7,
    soru: 'Çocuğunuz sizin yaptığınız şeylere ilgi duyar mı?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 8,
    soru: 'Çocuğunuz sizinle iletişim kurmak için ses çıkarır mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 9,
    soru: 'Çocuğunuz yüz ifadelerinize tepki verir mi?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 10,
    soru: 'Çocuğunuz garip seslere tepki verir mi?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 11,
    soru: 'Çocuğunuz yüzünüze gülümser mi?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 12,
    soru: 'Çocuğunuz sizinle karşılıklı oyun oynar mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 13,
    soru: 'Çocuğunuz sizinle konuşmak için kelime kullanır mı?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 14,
    soru: 'Çocuğunuz bir şey istediğinde elinizi tutup gösterir mi?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 15,
    soru: 'Çocuğunuz bir şeye bakarken parmağınızla gösterince bakar mı?',
    kritik: true,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 16,
    soru: 'Çocuğunuz etraftaki nesnelerle aşırı ilgilenir mi?',
    kritik: false,
    riskli: 'Evet',
  ),
  MchatSoru(
    id: 17,
    soru: 'Çocuğunuz sizi anlamak için yüzünüze bakar mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 18,
    soru: 'Çocuğunuz tekrarlayan hareketler yapar mı?',
    kritik: false,
    riskli: 'Evet',
  ),
  MchatSoru(
    id: 19,
    soru: 'Çocuğunuz gözünüze bakarak iletişim kurar mı?',
    kritik: false,
    riskli: 'Hayır',
  ),
  MchatSoru(
    id: 20,
    soru: 'Çocuğunuz seslere karşı aşırı duyarlı mı?',
    kritik: true,
    riskli: 'Evet',
  ),
];

enum MchatRiskSeviye { dusuk, orta, yuksek }

class MchatSonuc {
  const MchatSonuc({
    required this.toplamRisk,
    required this.kritikRisk,
    required this.seviye,
  });

  final int toplamRisk;
  final int kritikRisk;
  final MchatRiskSeviye seviye;

  String get baslik => switch (seviye) {
        MchatRiskSeviye.yuksek => 'YÜKSEK RİSK',
        MchatRiskSeviye.orta => 'ORTA RİSK',
        MchatRiskSeviye.dusuk => 'DÜŞÜK RİSK',
      };

  String get aciklama => switch (seviye) {
        MchatRiskSeviye.yuksek =>
          'Tarama sonucunda yüksek risk işaretleri görülüyor. '
              'Bu sonuç tanı değildir.',
        MchatRiskSeviye.orta =>
          'Tarama sonucu orta risk aralığında. '
              'Bu sonuç tanı değildir.',
        MchatRiskSeviye.dusuk =>
          'Tarama sonucu düşük risk aralığında. '
              'Bu sonuç tanı değildir.',
      };

  /// Risk faktörüne göre danışmanlık yönlendirmesi.
  String get oneri => switch (seviye) {
        MchatRiskSeviye.yuksek =>
          'En yakın sağlık kuruluşunda çocuk gelişimi veya gelişimsel pediatri '
              'uzmanına danışmanızı önemle öneririz.',
        MchatRiskSeviye.orta =>
          'Endişeniz sürüyorsa en yakın sağlık kuruluşunda bir uzmana '
              'danışmanız faydalı olur; gelişim takibine devam edin.',
        MchatRiskSeviye.dusuk =>
          'Gelişimi izlemeye devam edin. Endişeniz olursa en yakın sağlık '
              'kuruluşunda bir uzmana danışabilirsiniz.',
      };
}

/// Algoritma:
/// kritikRisk >= 2 VEYA toplamRisk >= 3 → YÜKSEK
/// toplamRisk == 2 → ORTA
/// diğer → DÜŞÜK
MchatSonuc hesaplaMchatSonuc(Map<int, String> cevaplar) {
  var toplam = 0;
  var kritik = 0;
  for (final s in mchatSorular) {
    final c = cevaplar[s.id];
    if (c == null) continue;
    if (c == s.riskli) {
      toplam++;
      if (s.kritik) kritik++;
    }
  }
  final seviye = (kritik >= 2 || toplam >= 3)
      ? MchatRiskSeviye.yuksek
      : (toplam == 2)
          ? MchatRiskSeviye.orta
          : MchatRiskSeviye.dusuk;
  return MchatSonuc(
    toplamRisk: toplam,
    kritikRisk: kritik,
    seviye: seviye,
  );
}
