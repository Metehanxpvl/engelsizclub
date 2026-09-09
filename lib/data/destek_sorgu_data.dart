/// Destek Sorgu — 2026 SUT taban fiyatları ve hesap.
class DestekSorguUrun {
  const DestekSorguUrun({
    required this.id,
    required this.category,
    required this.categorySort,
    required this.name,
    required this.sutPrice,
    required this.renewMonths,
    required this.sortOrder,
  });

  final String id;
  final String category;
  final int categorySort;
  final String name;
  final double sutPrice;
  final int renewMonths;
  final int sortOrder;

  String get renewLabel {
    if (renewMonths <= 0) return 'SUT’ta miat belirtilmemiş';
    if (renewMonths % 12 == 0) {
      final y = renewMonths ~/ 12;
      return y == 1 ? '1 yıl' : '$y yıl';
    }
    return renewMonths == 1 ? '1 ay' : '$renewMonths ay';
  }

  factory DestekSorguUrun.fromJson(Map<String, dynamic> json) {
    return DestekSorguUrun(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      categorySort: (json['category_sort'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      sutPrice: (json['sut_price'] as num?)?.toDouble() ?? 0,
      renewMonths: (json['renew_months'] as num?)?.toInt() ?? 60,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class DestekSorguHesap {
  const DestekSorguHesap({
    required this.sut,
    required this.quote,
    required this.sgkPay,
    required this.pocket,
  });

  final double sut;
  final double quote;
  final double sgkPay;
  final double pocket;

  static DestekSorguHesap? fromQuote(double sut, double? quote) {
    if (quote == null || quote <= 0) return null;
    return DestekSorguHesap(
      sut: sut,
      quote: quote,
      sgkPay: quote < sut ? quote : sut,
      pocket: quote > sut ? quote - sut : 0,
    );
  }
}

DateTime addRenewMonths(DateTime start, int months) {
  return DateTime(start.year, start.month + months, start.day);
}

/// SGK SUT EK-3/C (Yür. 24.01.2026) yedek listesi — resmi XLS satırının aynısı.
const kDestekSorguFallback = <DestekSorguUrun>[
  DestekSorguUrun(
    id: 'std-manuel',
    category: 'Tekerlekli sandalye (EK-3/C-2)',
    categorySort: 1,
    name: 'OP1342 — STANDART MANUEL TEKERLEKLİ SANDALYE',
    sutPrice: 1848.00,
    renewMonths: 60,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'hafif-ped',
    category: 'Tekerlekli sandalye (EK-3/C-2)',
    categorySort: 1,
    name: 'OP1343 — HAFİF MANUEL TEKERLEKLİ SANDALYE',
    sutPrice: 4435.20,
    renewMonths: 60,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'pediatrik',
    category: 'Tekerlekli sandalye (EK-3/C-2)',
    categorySort: 1,
    name: 'OP1344 — PEDİATRİK TEKERLEKLİ SANDALYE',
    sutPrice: 4435.20,
    renewMonths: 60,
    sortOrder: 3,
  ),
  DestekSorguUrun(
    id: 'std-akulu',
    category: 'Tekerlekli sandalye (EK-3/C-2)',
    categorySort: 1,
    name: 'OP1345 — STANDART AKÜLÜ TEKERLEKLİ SANDALYE',
    sutPrice: 12600.00,
    renewMonths: 60,
    sortOrder: 4,
  ),
  DestekSorguUrun(
    id: 'aktif',
    category: 'Özel hallerde karşılanan (EK-3/C-5)',
    categorySort: 2,
    name: '100072 — AKTİF TEKERLEKLİ SANDALYE',
    sutPrice: 16934.40,
    renewMonths: 60,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'ozellikli-akulu',
    category: 'Özel hallerde karşılanan (EK-3/C-5)',
    categorySort: 2,
    name: '100005 — ÖZELLİKLİ AKÜLÜ TEKERLEKLİ SANDALYE',
    sutPrice: 47040.00,
    renewMonths: 60,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'havali-yatak',
    category: 'Bakım malzemeleri (EK-3/C-2)',
    categorySort: 3,
    name: 'OP1300 — HAVALI YATAK',
    sutPrice: 840.00,
    renewMonths: 60,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'havali-minder',
    category: 'Bakım malzemeleri (EK-3/C-2)',
    categorySort: 3,
    name: 'OP1301 — HAVALI MİNDER',
    sutPrice: 295.68,
    renewMonths: 60,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'ayakta',
    category: 'Bakım malzemeleri (EK-3/C-2)',
    categorySort: 3,
    name:
        'OP1297 — AYAKTA DİK POZİSYONLAMA CİHAZI (STAND UP WHEELCHAİR) (MANUEL KALKIŞ MANUEL SÜRÜŞ)',
    sutPrice: 13104.00,
    renewMonths: 60,
    sortOrder: 3,
  ),
  DestekSorguUrun(
    id: 'bez-yetiskin',
    category: 'Sarf malzemeler (EK-3/C-4)',
    categorySort: 4,
    name: 'A10049 — HASTA ALT BEZİ/KÜLOTLU HASTA ALT BEZİ',
    sutPrice: 6.31,
    renewMonths: 0,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'bez-cocuk',
    category: 'Sarf malzemeler (EK-3/C-4)',
    categorySort: 4,
    name: 'A10118 — ÇOCUK HASTA ALT BEZİ/ÇOCUK KÜLOTLU HASTA ALT BEZİ',
    sutPrice: 4.93,
    renewMonths: 0,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'kafo',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name: 'OP1545 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ (YETİŞKİN)',
    sutPrice: 5312.16,
    renewMonths: 24,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'kafo-cocuk',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name:
        'OP1548 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ (2-18 YAŞ ARASI HASTALAR İÇİN)',
    sutPrice: 3719.52,
    renewMonths: 12,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'afo',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name:
        'OP1066 — YÜKSEK YOĞUNLUKLU PLASTİK YÜRÜYÜŞ MOLDU (HARİCİ EKLEMLİ) (PAFO)',
    sutPrice: 934.08,
    renewMonths: 12,
    sortOrder: 3,
  ),
  DestekSorguUrun(
    id: 'dafo',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name:
        'OP1062 — YÜKSEK YOĞUNLUKLU PLASTİK YÜRÜYÜŞ MOLDU (SUPRA MALLEOLAR) (AFO/DAFO/SMAFO)',
    sutPrice: 554.40,
    renewMonths: 12,
    sortOrder: 4,
  ),
  DestekSorguUrun(
    id: 'hkafo',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name: 'OP1546 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ BEL KEMERLİ (YETİŞKİN)',
    sutPrice: 6021.12,
    renewMonths: 24,
    sortOrder: 5,
  ),
  DestekSorguUrun(
    id: 'hkafo-cocuk',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name:
        'OP1549 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ BEL KEMERLİ (2-18 YAŞ ARASI HASTALAR İÇİN)',
    sutPrice: 4213.44,
    renewMonths: 12,
    sortOrder: 6,
  ),
  DestekSorguUrun(
    id: 'korse',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name: 'OP1274 — SKOLYOZ ORTEZLERİ (BOSTON, MİAMİ VB TİP PLASTİK TLSO)',
    sutPrice: 1313.76,
    renewMonths: 6,
    sortOrder: 7,
  ),
  DestekSorguUrun(
    id: 'el-atel',
    category: 'Ortez (EK-3/C-2)',
    categorySort: 5,
    name: 'OP1122 — DİNAMİK EL-BİLEK-PARMAK SPLİNTİ',
    sutPrice: 628.32,
    renewMonths: 6,
    sortOrder: 8,
  ),
  DestekSorguUrun(
    id: 'trans-tibial',
    category: 'Protez (EK-3/C-2)',
    categorySort: 6,
    name: 'OP1166 — DİZ ALTI PROTEZİ (MODÜLER)',
    sutPrice: 10735.20,
    renewMonths: 60,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'transfemoral',
    category: 'Protez (EK-3/C-2)',
    categorySort: 6,
    name: 'OP1189 — DİZ ÜSTÜ PROTEZİ (MEKANİK-MODÜLER)',
    sutPrice: 17307.36,
    renewMonths: 60,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'transradial',
    category: 'Protez (EK-3/C-2)',
    categorySort: 6,
    name: 'OP1225 — DİRSEK ALTI PROTEZİ (MEKANİK FONKSİYONEL-MODULER)',
    sutPrice: 11880.96,
    renewMonths: 60,
    sortOrder: 3,
  ),
  DestekSorguUrun(
    id: 'transhumeral',
    category: 'Protez (EK-3/C-2)',
    categorySort: 6,
    name: 'OP1233 — DİRSEK ÜSTÜ PROTEZİ (MEKANİK FONKSİYONEL-MODULER)',
    sutPrice: 17895.36,
    renewMonths: 60,
    sortOrder: 4,
  ),
  DestekSorguUrun(
    id: 'cpap',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name: 'DO1011 — CPAP CİHAZI',
    sutPrice: 3265.92,
    renewMonths: 120,
    sortOrder: 1,
  ),
  DestekSorguUrun(
    id: 'auto-cpap',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name: 'DO1012 — AUTO CPAP',
    sutPrice: 6531.84,
    renewMonths: 120,
    sortOrder: 2,
  ),
  DestekSorguUrun(
    id: 'bpap-s',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name: 'DO1013 — BPAP S CİHAZI',
    sutPrice: 7920.00,
    renewMonths: 120,
    sortOrder: 3,
  ),
  DestekSorguUrun(
    id: 'bpap',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name: 'DO1014 — BPAP S/T',
    sutPrice: 9389.52,
    renewMonths: 120,
    sortOrder: 4,
  ),
  DestekSorguUrun(
    id: 'oksijen',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name: 'DO1009 — OKSİJEN KONSANTRATÖRÜ',
    sutPrice: 9391.20,
    renewMonths: 120,
    sortOrder: 5,
  ),
  DestekSorguUrun(
    id: 'tasinabilir-oksijen',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name:
        'DO1071 — TAŞINABİLİR (PORTABLE) OKSİJEN KONSANTRATÖRÜ (5 KG ALTINDA, ŞARJLI VE YEDEK BATARYA İLE BİRLİKTE)',
    sutPrice: 30159.36,
    renewMonths: 120,
    sortOrder: 6,
  ),
  DestekSorguUrun(
    id: 'ventilator',
    category: 'Solunum cihazları (EK-3/C-3)',
    categorySort: 7,
    name:
        'DO1017 — EV TİPİ MEKANİK VENTİLATÖR (EN AZ BASINÇ DESTEKLİ VENTİLASYON (PSV) İLE BİRLİKTE VOLÜM VE/VEYA BASINÇ KONTROLLÜ VENTİLASYON (VCV, PCV) SAĞLAYAN VENTİLATÖRLER)',
    sutPrice: 63360.00,
    renewMonths: 60,
    sortOrder: 7,
  ),
];
