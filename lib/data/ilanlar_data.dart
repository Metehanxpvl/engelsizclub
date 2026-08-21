import 'package:flutter/material.dart';

import '../kullanici_profil_store.dart';
import '../meto_theme.dart';

// ─── Supporting types ────────────────────────────────────────────────────────

class IlanReview {
  const IlanReview({
    required this.author,
    required this.avatar,
    required this.avatarColor,
    required this.rating,
    required this.date,
    required this.text,
  });

  final String author;
  final String avatar;
  final Color avatarColor;
  final int rating;
  final String date;
  final String text;
}

class PosterCv {
  const PosterCv({
    this.bolum = '',
    this.okul = '',
    this.mezunYil = '',
    this.deneyimYil = '',
    this.deneyimAlani = '',
    this.sertifikalar = const <String>[],
    this.hakkimda = '',
  });

  final String bolum;
  final String okul;
  final String mezunYil;
  final String deneyimYil;
  final String deneyimAlani;
  final List<String> sertifikalar;
  final String hakkimda;

  bool get hasContent =>
      bolum.trim().isNotEmpty ||
      okul.trim().isNotEmpty ||
      mezunYil.trim().isNotEmpty ||
      deneyimYil.trim().isNotEmpty ||
      deneyimAlani.trim().isNotEmpty ||
      hakkimda.trim().isNotEmpty ||
      sertifikalar.any((s) => s.trim().isNotEmpty);

  String get egitimText {
    final parts = <String>[
      if (bolum.trim().isNotEmpty) bolum.trim(),
      if (okul.trim().isNotEmpty) okul.trim(),
      if (mezunYil.trim().isNotEmpty) mezunYil.trim(),
    ];
    return parts.join('\n');
  }

  String get deneyimText {
    final parts = <String>[];
    final yil = deneyimYil.trim();
    if (yil.isNotEmpty) {
      parts.add(yil.toLowerCase().contains('yıl') ? yil : '$yil yıl deneyim');
    }
    if (deneyimAlani.trim().isNotEmpty) parts.add(deneyimAlani.trim());
    return parts.join('\n');
  }

  String get sertifikalarText => sertifikalar
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => '✓ $s')
      .join('\n');
}

class IlanPoster {
  const IlanPoster({
    required this.name,
    required this.avatar,
    required this.avatarColor,
    required this.rating,
    required this.reviewCount,
    required this.bio,
    required this.tags,
    required this.reviews,
    this.cv,
    this.fullName = '',
  });

  /// İlan kartında gösterilen ad (soyadı maskeli olabilir).
  final String name;
  /// Teklif sonrası sohbette gösterilecek tam ad soyad.
  final String fullName;
  final String avatar;
  final Color avatarColor;
  final double rating;
  final int reviewCount;
  final String bio;
  final List<String> tags;
  final List<IlanReview> reviews;
  final PosterCv? cv;

  /// Teklif / sohbet: tam ad yerine maskeli ad (M**** Ç****).
  String get revealedName {
    final full = fullName.trim();
    if (full.isNotEmpty && !full.contains('@')) {
      return maskPersonDisplayName(full);
    }
    final n = name.trim();
    return n.isEmpty ? 'Üye' : n;
  }
}

class SohbetKisi {
  const SohbetKisi({
    required this.ad,
    required this.avatar,
    required this.avatarColor,
    required this.isOnline,
    this.sonGorus,
    this.peerEmail = '',
    this.ilanId,
    this.ilanTitle,
  });

  final String ad;
  final String avatar;
  final Color avatarColor;
  final bool isOnline;
  final String? sonGorus;
  /// Gerçek kullanıcı e-postası (ilan sahibi). Boşsa örnek/demo ilandır.
  final String peerEmail;
  final int? ilanId;
  /// Teklif mesajında kullanılan ilan başlığı.
  final String? ilanTitle;
}

enum IlanKategori { uzmanlar, bakici, ikinciel }

/// Uzman sekmesinde ilan türü (`ilanlar.category`).
const kIlanCatUzmanAriyorum = 'Uzman Arıyorum';
const kIlanCatIsAriyorum = 'İş Arıyorum';

String normalizeUzmanListingCategory(dynamic raw) {
  final s = (raw ?? '').toString().trim();
  if (s.toLowerCase() == kIlanCatIsAriyorum.toLowerCase()) {
    return kIlanCatIsAriyorum;
  }
  return kIlanCatUzmanAriyorum;
}

bool isIlanIsAriyorum(String? category) =>
    normalizeUzmanListingCategory(category) == kIlanCatIsAriyorum;

/// 2. el ilan alt kategorisi (filtre + form).
const kIkincielAltMedikal = 'Medikal Malzemeler';
const kIkincielAltDiger = 'Diğer';
const kIkincielAltKategoriler = <String>[
  kIkincielAltMedikal,
  kIkincielAltDiger,
];

String _normTrIkinciel(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('İ', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

/// Kayıtlı `category` değerini Medikal / Diğer veya özel alt kategoriye çözer.
String ikincielAltKategoriOf(String category, {List<String>? extras}) {
  final c = _normTrIkinciel(category);
  if (c.isEmpty) return kIkincielAltDiger;
  final known = <String>[
    ...kIkincielAltKategoriler,
    ...?extras,
  ];
  for (final a in known) {
    if (_normTrIkinciel(a) == c) return a;
  }
  if (c == 'diger' || c == 'other' || c == 'autres' || c == 'sonstiges') {
    return kIkincielAltDiger;
  }
  if (c.contains('medikal') ||
      c.contains('medical') ||
      c.contains('medizin')) {
    return kIkincielAltMedikal;
  }
  // Eski demo / serbest kategori etiketleri
  const medicalHints = <String>[
    'tekerlekli',
    'sandalye',
    'yurutec',
    'yürütec',
    'ortez',
    'protez',
    'terapi',
    'adaptif',
    'iletisim',
    'cihaz',
    'medikal',
    'walker',
    'wheelchair',
    'isi',
    'oksijen',
    'dinleme',
    'isime',
  ];
  for (final h in medicalHints) {
    if (c.contains(_normTrIkinciel(h))) return kIkincielAltMedikal;
  }
  return kIkincielAltDiger;
}


class UzmanRenk {
  const UzmanRenk({
    required this.color,
    required this.bg,
    required this.emoji,
  });

  final Color color;
  final Color bg;
  final String emoji;
}

class UzmanCvData {
  const UzmanCvData({
    required this.bolum,
    required this.okul,
    required this.mezunYil,
    required this.deneyimYil,
    required this.deneyimAlani,
    required this.sertifikalar,
  });

  final String bolum;
  final String okul;
  final String mezunYil;
  final String deneyimYil;
  final String deneyimAlani;
  final List<String> sertifikalar;
}

class UzmanIlani {
  const UzmanIlani({
    required this.id,
    required this.title,
    required this.uzmanlik,
    required this.tani,
    required this.city,
    required this.district,
    required this.age,
    required this.frequency,
    required this.note,
    required this.budget,
    required this.posted,
    required this.views,
    required this.offers,
    required this.urgent,
    required this.poster,
    this.photos = const [],
    this.countryCode = 'TR',
    this.category = kIlanCatUzmanAriyorum,
  });

  final int id;
  final String title;
  final String uzmanlik;
  final String tani;
  final String city;
  final String district;
  final String age;
  final String frequency;
  final String note;
  final String budget;
  final String posted;
  final int views;
  final int offers;
  final bool urgent;
  final IlanPoster poster;
  /// Uzman / bakıcı ilanlarında en fazla 2 fotoğraf.
  final List<IlanPhoto> photos;
  final String countryCode;
  /// `Uzman Arıyorum` (aile) veya `İş Arıyorum` (uzman/bakıcı).
  final String category;

  UzmanIlani copyWith({int? views}) => UzmanIlani(
        id: id,
        title: title,
        uzmanlik: uzmanlik,
        tani: tani,
        city: city,
        district: district,
        age: age,
        frequency: frequency,
        note: note,
        budget: budget,
        posted: posted,
        views: views ?? this.views,
        offers: offers,
        urgent: urgent,
        poster: poster,
        photos: photos,
        countryCode: countryCode,
        category: category,
      );
}

class BakiciIlani {
  const BakiciIlani({
    required this.id,
    required this.title,
    required this.city,
    required this.district,
    required this.tani,
    required this.age,
    required this.hours,
    required this.note,
    required this.budget,
    required this.posted,
    required this.views,
    required this.urgent,
    required this.poster,
    this.photos = const [],
    this.countryCode = 'TR',
  });

  final int id;
  final String title;
  final String city;
  final String district;
  final String tani;
  final String age;
  final String hours;
  final String note;
  final String budget;
  final String posted;
  final int views;
  final bool urgent;
  final IlanPoster poster;
  /// Uzman / bakıcı ilanlarında en fazla 2 fotoğraf.
  final List<IlanPhoto> photos;
  final String countryCode;

  BakiciIlani copyWith({int? views}) => BakiciIlani(
        id: id,
        title: title,
        city: city,
        district: district,
        tani: tani,
        age: age,
        hours: hours,
        note: note,
        budget: budget,
        posted: posted,
        views: views ?? this.views,
        urgent: urgent,
        poster: poster,
        photos: photos,
        countryCode: countryCode,
      );
}

/// 2. el ürün durumu seçenekleri (ilan formu + badge).
const kIkincielDurumSecenekleri = <String>[
  'Sıfır ürün',
  'Az kullanılmış',
  'İyi',
  'Kötü',
];

({Color bg, Color fg}) ikincielDurumRenk(String condition) {
  switch (condition.trim().toLowerCase()) {
    case 'sıfır ürün':
    case 'sifir urun':
      return (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1D4ED8));
    case 'az kullanılmış':
    case 'az kullanilmis':
      return (bg: const Color(0xFFECFDF5), fg: const Color(0xFF0F766E));
    case 'kötü':
    case 'kotu':
      return (bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C));
    case 'iyi':
    default:
      return (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF15803D));
  }
}

/// Uzman ve bakıcı ilanları için izin verilen maksimum fotoğraf sayısı.
const kUzmanBakiciMaxPhotos = 2;

class IkincielIlani {
  const IkincielIlani({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.district,
    required this.condition,
    required this.brand,
    required this.note,
    required this.price,
    required this.originalPrice,
    required this.posted,
    required this.views,
    required this.emoji,
    required this.photos,
    required this.poster,
    this.countryCode = 'TR',
  });

  final int id;
  final String title;
  final String category;
  final String city;
  final String district;
  final String condition;
  final String brand;
  final String note;
  final String price;
  final String originalPrice;
  final String posted;
  final int views;
  final String emoji;
  final List<IlanPhoto> photos;
  final IlanPoster poster;
  final String countryCode;

  IkincielIlani copyWith({int? views}) => IkincielIlani(
        id: id,
        title: title,
        category: category,
        city: city,
        district: district,
        condition: condition,
        brand: brand,
        note: note,
        price: price,
        originalPrice: originalPrice,
        posted: posted,
        views: views ?? this.views,
        emoji: emoji,
        photos: photos,
        poster: poster,
        countryCode: countryCode,
      );
}

/// 2. el ilan görseli — gerçek foto (data URL) veya örnek renk kutusu.
class IlanPhoto {
  const IlanPhoto.swatch(this.color) : dataUrl = null;
  const IlanPhoto.data(this.dataUrl) : color = null;

  final Color? color;
  final String? dataUrl;

  bool get hasImage {
    final d = dataUrl;
    return d != null &&
        d.isNotEmpty &&
        (d.startsWith('data:') || d.startsWith('http'));
  }

  Color get swatchColor => color ?? const Color(0xFFDCE8F5);

  dynamic toJson() {
    if (hasImage) return dataUrl;
    return swatchColor.toARGB32();
  }

  factory IlanPhoto.fromJson(dynamic e) {
    if (e is String) {
      final s = e.trim();
      if (s.startsWith('data:') || s.startsWith('http')) {
        return IlanPhoto.data(s);
      }
      final n = int.tryParse(s);
      if (n != null) return IlanPhoto.swatch(Color(n));
    }
    if (e is num) return IlanPhoto.swatch(Color(e.toInt()));
    return const IlanPhoto.swatch(Color(0xFFDCE8F5));
  }
}

// ─── Theme helpers ─────────────────────────────────────────────────────────

const _c = MetoColors.primary;
const _e07 = Color(0xFFE07A5F);
const _9c6 = Color(0xFF9C6DB3);
const _6b9 = Color(0xFF6B9AC4);
const _f4a = Color(0xFFF4A832);
const _5b8 = Color(0xFF5B8DD9);

const uzmanRenk = <String, UzmanRenk>{
  'Fizyoterapist': UzmanRenk(
    color: _c,
    bg: MetoColors.selectedBg,
    emoji: '🏃',
  ),
  'Ergoterapist': UzmanRenk(
    color: _9c6,
    bg: Color(0xFFF5EEFB),
    emoji: '✋',
  ),
  'Özel Eğitim Öğretmeni': UzmanRenk(
    color: _6b9,
    bg: Color(0xFFEEF5FB),
    emoji: '📚',
  ),
  'Gölge Öğretmen': UzmanRenk(
    color: Color(0xFF0D9488),
    bg: Color(0xFFECFDF5),
    emoji: '🧑‍🏫',
  ),
  'Dil Terapisti': UzmanRenk(
    color: _e07,
    bg: Color(0xFFFDF0EC),
    emoji: '💬',
  ),
  'Dil Konuşma Terapisti': UzmanRenk(
    color: _e07,
    bg: Color(0xFFFDF0EC),
    emoji: '💬',
  ),
  'Psikolog': UzmanRenk(
    color: _9c6,
    bg: Color(0xFFF3E8FF),
    emoji: '🧠',
  ),
};

/// İlan verirken uzman alt kategorileri.
const kUzmanlikSecenekleri = <String>[
  'Fizyoterapist',
  'Ergoterapist',
  'Dil Konuşma Terapisti',
  'Özel Eğitim Öğretmeni',
  'Gölge Öğretmen',
  'Psikolog',
];

const uzmanKm = <int, int>{1: 3, 2: 12, 3: 28, 4: 45, 5: 180};
const bakiciKm = <int, int>{10: 5, 11: 95, 12: 220, 13: 8};

const uzmanCvMap = <String, UzmanCvData>{
  'Fizyoterapist': UzmanCvData(
    bolum: 'Fizyoterapi ve Rehabilitasyon',
    okul: 'Hacettepe Üniversitesi',
    mezunYil: '2015',
    deneyimYil: '8',
    deneyimAlani:
        'Serebral Palsi, nörolojik rehabilitasyon, yürüme analizi',
    sertifikalar: [
      'Bobath Sertifikası',
      'NDT Eğitimi',
      'Pediatrik Fizyoterapi',
    ],
  ),
  'Ergoterapist': UzmanCvData(
    bolum: 'Ergoterapi',
    okul: 'İstanbul Üniversitesi',
    mezunYil: '2017',
    deneyimYil: '6',
    deneyimAlani:
        'Duyu bütünleme, günlük yaşam aktiviteleri, adaptif cihaz kullanımı',
    sertifikalar: [
      'Ayres Duyu Bütünleme Sertifikası',
      'El Rehabilitasyonu',
    ],
  ),
  'Özel Eğitim Öğretmeni': UzmanCvData(
    bolum: 'Özel Eğitim Öğretmenliği',
    okul: 'Ankara Üniversitesi',
    mezunYil: '2016',
    deneyimYil: '7',
    deneyimAlani:
        'Otizm, zihinsel yetersizlik, DEHB, bireyselleştirilmiş eğitim planı',
    sertifikalar: [
      'ABA Sertifikası',
      'PECS Eğitimi',
      'Sosyal Beceri Terapisi',
    ],
  ),
  'Dil Terapisti': UzmanCvData(
    bolum: 'Dil ve Konuşma Terapisi',
    okul: 'Anadolu Üniversitesi',
    mezunYil: '2018',
    deneyimYil: '5',
    deneyimAlani:
        'Gecikmiş dil gelişimi, otizm, kekemelik, yutma terapisi',
    sertifikalar: [
      'PROMPT Sertifikası',
      'AAC Uzmanı',
      'Erken Müdahale',
    ],
  ),
};

const formPhotoColors = [
  Color(0xFFDCE8F5),
  Color(0xFFE8F0DC),
  Color(0xFFF5E8DC),
  Color(0xFFF0DCE8),
  Color(0xFFDCE5F0),
  Color(0xFFE8F5EE),
  Color(0xFFF5F0DC),
];

// ─── Listing data ────────────────────────────────────────────────────────────

const uzmanIlanlar = <UzmanIlani>[
  UzmanIlani(
    id: 1,
    title: 'Evde Fizyoterapist Arıyoruz',
    uzmanlik: 'Fizyoterapist',
    tani: 'Serebral Palsi',
    city: 'Ankara',
    district: 'Çankaya',
    age: '6 yaş',
    frequency: 'Haftada 3 seans',
    note:
        'Alt ekstremite odaklı çalışma yapılacak. Evde seans verebilecek deneyimli fizyoterapist.',
    budget: '₺400–600/seans',
    posted: '2 saat önce',
    views: 34,
    offers: 5,
    urgent: true,
    poster: IlanPoster(
      name: 'Ayşe Y.',
      avatar: 'AY',
      avatarColor: _e07,
      rating: 4.9,
      reviewCount: 12,
      bio:
          'SP tanılı 6 yaşında oğlum için evde fizyoterapist arıyoruz. Zamanında ödeme, güler yüzlü aile.',
      tags: ['Evde Seans', 'SP Deneyimi', 'Zamanında Ödeme'],
      reviews: [
        IlanReview(
          author: 'Emre F.',
          avatar: 'EF',
          avatarColor: _c,
          rating: 5,
          date: '2 ay önce',
          text:
              'Çok anlayışlı ve organize bir aile. Seans zamanına tam uyuyorlar, teşekkürler.',
        ),
        IlanReview(
          author: 'Selin K.',
          avatar: 'SK',
          avatarColor: _9c6,
          rating: 5,
          date: '4 ay önce',
          text:
              'Her şeyi önceden hazırlıyorlar, çocukla iletişimleri mükemmel.',
        ),
        IlanReview(
          author: 'Murat D.',
          avatar: 'MD',
          avatarColor: _6b9,
          rating: 4,
          date: '6 ay önce',
          text:
              'Güzel bir aile, sadece zaman zaman programa değişiklik olabiliyor.',
        ),
      ],
    ),
  ),
  UzmanIlani(
    id: 2,
    title: 'Dil ve Konuşma Terapisti Aranıyor',
    uzmanlik: 'Dil Terapisti',
    tani: 'Otizm',
    city: 'İstanbul',
    district: 'Kadıköy',
    age: '4 yaş',
    frequency: 'Haftada 4 seans',
    note:
        'Verbal olmayan çocuğumuz için AAC desteği verebilecek deneyimli terapist.',
    budget: '₺350–500/seans',
    posted: '5 saat önce',
    views: 61,
    offers: 9,
    urgent: false,
    poster: IlanPoster(
      name: 'Mehmet S.',
      avatar: 'MS',
      avatarColor: _c,
      rating: 4.7,
      reviewCount: 8,
      bio:
          '4 yaşında otizm spektrum tanılı oğlum için AAC konusunda uzman terapist arıyoruz. Ev ortamı müsait.',
      tags: ['AAC Deneyimi', 'Esnek Saat', 'Otizm'],
      reviews: [
        IlanReview(
          author: 'Pınar T.',
          avatar: 'PT',
          avatarColor: _e07,
          rating: 5,
          date: '1 ay önce',
          text:
              'Harika bir aile, çocuğa karşı çok sabırlılar. Kesinlikle tavsiye ederim.',
        ),
        IlanReview(
          author: 'Burak A.',
          avatar: 'BA',
          avatarColor: _f4a,
          rating: 4,
          date: '3 ay önce',
          text:
              'İyi niyetli, bazen iletişim gecikmesi olabiliyor ama genel olarak memnunum.',
        ),
      ],
    ),
  ),
  UzmanIlani(
    id: 3,
    title: 'Ergoterapist — Evde veya Merkezde',
    uzmanlik: 'Ergoterapist',
    tani: 'Down Sendromu',
    city: 'İzmir',
    district: 'Bornova',
    age: '8 yaş',
    frequency: 'Haftada 2 seans',
    note:
        'İnce motor beceri ve günlük yaşam aktiviteleri üzerine çalışma istiyoruz.',
    budget: '₺300–450/seans',
    posted: '1 gün önce',
    views: 28,
    offers: 3,
    urgent: false,
    poster: IlanPoster(
      name: 'Fatma D.',
      avatar: 'FD',
      avatarColor: _9c6,
      rating: 5.0,
      reviewCount: 15,
      bio:
          'Down sendromlu kızımız için ergoterapist arıyoruz. Çok neşeli bir çocuk, terapistleri çok seviyor.',
      tags: ['Merkez veya Ev', 'Down Sendromu', '5+ Yıl'],
      reviews: [
        IlanReview(
          author: 'Zeynep O.',
          avatar: 'ZO',
          avatarColor: _c,
          rating: 5,
          date: '3 hafta önce',
          text:
              'Bu aileyle çalışmak tam anlamıyla keyifli. Çocukları çok tatlı, aile çok ilgili.',
        ),
        IlanReview(
          author: 'Can M.',
          avatar: 'CM',
          avatarColor: _6b9,
          rating: 5,
          date: '2 ay önce',
          text: '3 yıldır çalışıyorum, hiç sorun yaşamadım. Önerilen en iyi aile.',
        ),
        IlanReview(
          author: 'Hande K.',
          avatar: 'HK',
          avatarColor: _e07,
          rating: 5,
          date: '4 ay önce',
          text: 'Her zaman zamanında ödeme, teşekkür mesajları. Harika aile.',
        ),
      ],
    ),
  ),
  UzmanIlani(
    id: 4,
    title: 'Özel Eğitim Öğretmeni Arıyoruz',
    uzmanlik: 'Özel Eğitim Öğretmeni',
    tani: 'DEHB',
    city: 'İstanbul',
    district: 'Beşiktaş',
    age: '9 yaş',
    frequency: 'Haftada 3 gün',
    note:
        'Okul uyumu ve akademik destek için bireysel çalışacak özel eğitim öğretmeni.',
    budget: '₺350–500/seans',
    posted: '3 gün önce',
    views: 47,
    offers: 7,
    urgent: false,
    poster: IlanPoster(
      name: 'Hasan K.',
      avatar: 'HK',
      avatarColor: _6b9,
      rating: 4.5,
      reviewCount: 6,
      bio:
          'DEHB tanılı oğlumuz için sabırlı ve deneyimli özel eğitim öğretmeni arıyoruz.',
      tags: ['DEHB', 'Akademik Destek', 'Beşiktaş'],
      reviews: [
        IlanReview(
          author: 'Nilüfer B.',
          avatar: 'NB',
          avatarColor: _9c6,
          rating: 5,
          date: '1 ay önce',
          text:
              'Çok anlayışlı bir baba, çocuğun gelişimi için her şeyi yapıyor.',
        ),
        IlanReview(
          author: 'Tarık S.',
          avatar: 'TS',
          avatarColor: _c,
          rating: 4,
          date: '5 ay önce',
          text: 'Genel olarak iyi, bazen program esnekliği istiyor.',
        ),
      ],
    ),
  ),
  UzmanIlani(
    id: 5,
    title: 'SP Deneyimli Fizyoterapist',
    uzmanlik: 'Fizyoterapist',
    tani: 'Serebral Palsi',
    city: 'Bursa',
    district: 'Nilüfer',
    age: '5 yaş',
    frequency: 'Haftada 4 seans',
    note:
        'NDT sertifikalı fizyoterapist tercih edilir. Üst ekstremite çalışması.',
    budget: '₺450–650/seans',
    posted: '4 saat önce',
    views: 19,
    offers: 2,
    urgent: true,
    poster: IlanPoster(
      name: 'Leyla M.',
      avatar: 'LM',
      avatarColor: _f4a,
      rating: 4.8,
      reviewCount: 9,
      bio:
          'SP tanılı kızımız için NDT eğitimli fizyoterapist arıyoruz. Evimiz geniş ve uygun.',
      tags: ['NDT Sertifika', 'Üst Ekstremite', 'Acil'],
      reviews: [
        IlanReview(
          author: 'Ozan F.',
          avatar: 'OF',
          avatarColor: _c,
          rating: 5,
          date: '2 hafta önce',
          text:
              'Çok sıcak kanlı bir aile. Çocuklarının iyileşmesi için her şeyi yapıyorlar.',
        ),
        IlanReview(
          author: 'Dila K.',
          avatar: 'DK',
          avatarColor: _e07,
          rating: 5,
          date: '3 ay önce',
          text:
              'Zamanında ödeme, seansa hazırlıklı geliyorlar. Takdire şayan.',
        ),
      ],
    ),
  ),
];

const bakiciIlanlar = <BakiciIlani>[
  BakiciIlani(
    id: 10,
    title: 'Gündüz Bakıcı Arıyoruz',
    city: 'İstanbul',
    district: 'Ataşehir',
    tani: 'Otizm',
    age: '7 yaş',
    hours: 'Hafta içi 08:00–17:00',
    note:
        'Otizm konusunda deneyimli, sabırlı bakıcı arıyoruz. Temel ABA bilgisi artı.',
    budget: '₺15.000–20.000/ay',
    posted: '3 saat önce',
    views: 52,
    urgent: true,
    poster: IlanPoster(
      name: 'Canan B.',
      avatar: 'CB',
      avatarColor: _5b8,
      rating: 4.8,
      reviewCount: 7,
      bio:
          'İki çocuklu bir aileyiz. Otizm konusunda bilinçliyiz, bakıcımızla sürekli iletişim halinde oluruz.',
      tags: ['Güvenli Ev', 'Düzenli Ödeme', 'Esnek'],
      reviews: [
        IlanReview(
          author: 'Sema T.',
          avatar: 'ST',
          avatarColor: _c,
          rating: 5,
          date: '1 ay önce',
          text:
              'Çok anlayışlı bir aile. Bakıcının refahını önemsiyorlar, yemek ve ulaşım sağlıyorlar.',
        ),
        IlanReview(
          author: 'Reyhan K.',
          avatar: 'RK',
          avatarColor: _9c6,
          rating: 5,
          date: '3 ay önce',
          text: 'Otizm konusunda bilgili aile, bakıcıya yol gösteriyorlar.',
        ),
        IlanReview(
          author: 'Alev D.',
          avatar: 'AD',
          avatarColor: _e07,
          rating: 4,
          date: '6 ay önce',
          text:
              'İyi bir aile, bazen mesai uzayabiliyor ama ödemesini eksiksiz yapıyorlar.',
        ),
      ],
    ),
  ),
  BakiciIlani(
    id: 11,
    title: 'Yarı Zamanlı Bakıcı — Öğleden Sonra',
    city: 'Ankara',
    district: 'Yenimahalle',
    tani: 'Serebral Palsi',
    age: '10 yaş',
    hours: 'Hafta içi 13:00–18:00',
    note:
        'Tekerlekli sandalye kullanan kızımız için fiziksel engelli deneyimi olan bakıcı.',
    budget: '₺8.000–10.000/ay',
    posted: '1 gün önce',
    views: 38,
    urgent: false,
    poster: IlanPoster(
      name: 'Kemal Y.',
      avatar: 'KY',
      avatarColor: _c,
      rating: 4.6,
      reviewCount: 4,
      bio:
          'SP tanılı kızımız için öğle sonrası bakıcı arıyoruz. Sakin bir ev ortamımız var.',
      tags: ['Sakin Ortam', 'SP Deneyimi', 'Yenimahalle'],
      reviews: [
        IlanReview(
          author: 'Filiz A.',
          avatar: 'FA',
          avatarColor: _f4a,
          rating: 5,
          date: '2 ay önce',
          text: 'Düzenli ve güvenilir bir aile, çok memnun kaldım.',
        ),
        IlanReview(
          author: 'Meral T.',
          avatar: 'MT',
          avatarColor: _6b9,
          rating: 4,
          date: '5 ay önce',
          text: 'İyi niyetli, bazen program değişikliği olabiliyor.',
        ),
      ],
    ),
  ),
  BakiciIlani(
    id: 12,
    title: 'Hafta Sonu Bakıcı',
    city: 'İzmir',
    district: 'Karşıyaka',
    tani: 'Down Sendromu',
    age: '5 yaş',
    hours: 'Cumartesi–Pazar 09:00–18:00',
    note:
        'Hafta sonları ailece çalıştığımız için güvenilir bir bakıcıya ihtiyacımız var.',
    budget: '₺3.000–4.000/hafta sonu',
    posted: '2 gün önce',
    views: 21,
    urgent: false,
    poster: IlanPoster(
      name: 'Yıldız G.',
      avatar: 'YG',
      avatarColor: _9c6,
      rating: 5.0,
      reviewCount: 11,
      bio:
          'Down sendromlu oğlumuz çok neşeli bir çocuk. Hafta sonları güvenebileceğimiz bakıcı arıyoruz.',
      tags: ['Neşeli Çocuk', 'Down Sendromu', 'Karşıyaka'],
      reviews: [
        IlanReview(
          author: 'Oya K.',
          avatar: 'OK',
          avatarColor: _c,
          rating: 5,
          date: '3 hafta önce',
          text:
              'Harika aile! Çocukları gerçekten çok tatlı, bakıcıya karşı çok nazikler.',
        ),
        IlanReview(
          author: 'Hüseyin B.',
          avatar: 'HB',
          avatarColor: _e07,
          rating: 5,
          date: '2 ay önce',
          text: 'Yıllardır bu aileyle çalışıyorum, hiç sorun yaşamadım.',
        ),
      ],
    ),
  ),
  BakiciIlani(
    id: 13,
    title: 'Tam Zamanlı Bakıcı / Refakatçi',
    city: 'İstanbul',
    district: 'Sarıyer',
    tani: 'DEHB + Gelişim Geriliği',
    age: '12 yaş',
    hours: 'Pzt–Cum 07:30–18:30',
    note:
        'İki tanısı olan oğlumuz için deneyimli, sabırlı ve taşıt kullanabilen bakıcı.',
    budget: '₺18.000–25.000/ay',
    posted: '5 saat önce',
    views: 67,
    urgent: true,
    poster: IlanPoster(
      name: 'Oğuz T.',
      avatar: 'OT',
      avatarColor: _e07,
      rating: 4.4,
      reviewCount: 5,
      bio:
          'DEHB ve gelişim geriliği tanılı oğlumuz için güvenilir refakatçi/bakıcı arıyoruz. Araç sağlanır.',
      tags: ['Araç Sağlanır', 'Yüksek Bütçe', 'Sarıyer'],
      reviews: [
        IlanReview(
          author: 'Nalan S.',
          avatar: 'NS',
          avatarColor: _c,
          rating: 5,
          date: '6 hafta önce',
          text:
              'Ciddi ve güvenilir bir aile. Çocuğun ihtiyaçlarını çok iyi biliyorlar.',
        ),
        IlanReview(
          author: 'Coşkun Y.',
          avatar: 'CY',
          avatarColor: _6b9,
          rating: 4,
          date: '4 ay önce',
          text:
              'Yoğun bir tempolu bir iş ama aile çok anlayışlı, iyi ödeme yapıyorlar.',
        ),
      ],
    ),
  ),
];

const ikincielIlanlar = <IkincielIlani>[
  IkincielIlani(
    id: 20,
    title: 'Çocuk Tekerlekli Sandalye',
    category: 'Tekerlekli Sandalye',
    city: 'İstanbul',
    district: 'Pendik',
    condition: 'İyi',
    brand: 'Ottobock',
    note:
        '2 yıl kullanıldı, temiz ve bakımlı. Oğlum büyüdüğü için satıyoruz.',
    price: '₺4.500',
    originalPrice: '₺12.000',
    posted: '1 saat önce',
    views: 43,
    emoji: '🦽',
    photos: [
      IlanPhoto.swatch(Color(0xFFDCE8F5)),
      IlanPhoto.swatch(Color(0xFFC8DDF0)),
      IlanPhoto.swatch(Color(0xFFB8D3ED)),
    ],
    poster: IlanPoster(
      name: 'Tuba A.',
      avatar: 'TA',
      avatarColor: _e07,
      rating: 5.0,
      reviewCount: 8,
      bio:
          '3 yıldır özel eğitim malzemesi alıp satıyorum. Her ürünü temiz ve bakımlı teslim ederim.',
      tags: ['Hızlı Teslimat', 'Fatura Var', 'Güvenilir'],
      reviews: [
        IlanReview(
          author: 'Sercan B.',
          avatar: 'SB',
          avatarColor: _c,
          rating: 5,
          date: '1 ay önce',
          text: 'Tam tanımlandığı gibi, sıfır sorun. Tekrar alırım.',
        ),
        IlanReview(
          author: 'Gülşen M.',
          avatar: 'GM',
          avatarColor: _9c6,
          rating: 5,
          date: '3 ay önce',
          text: 'Çok dürüst bir satıcı, ürün gerçekten temizdi.',
        ),
      ],
    ),
  ),
  IkincielIlani(
    id: 21,
    title: 'Duyu Bütünleme Salıncağı',
    category: 'Terapi Ekipmanı',
    city: 'Ankara',
    district: 'Çankaya',
    condition: 'Çok İyi',
    brand: 'Southpaw',
    note:
        'Ergoterapi için kullandık, taşınmamız nedeniyle satılıktır. Tavan kancası dahil.',
    price: '₺2.800',
    originalPrice: '₺7.500',
    posted: '3 saat önce',
    views: 29,
    emoji: '🎡',
    photos: [
      IlanPhoto.swatch(Color(0xFFE8F0DC)),
      IlanPhoto.swatch(Color(0xFFD8E8C8)),
    ],
    poster: IlanPoster(
      name: 'Berk D.',
      avatar: 'BD',
      avatarColor: _6b9,
      rating: 4.7,
      reviewCount: 5,
      bio:
          'Ailemizin kullandığı terapi ekipmanlarını temiz tutarak satıyoruz. Birebir görüşmeye açığız.',
      tags: ['Ankara', 'Kurulum Yardımı', 'Pazarlık Yok'],
      reviews: [
        IlanReview(
          author: 'Aslı T.',
          avatar: 'AT',
          avatarColor: _c,
          rating: 5,
          date: '2 ay önce',
          text: 'Çok temiz ürün, fotoğraflarla birebir aynıydı.',
        ),
        IlanReview(
          author: 'Volkan E.',
          avatar: 'VE',
          avatarColor: _e07,
          rating: 4,
          date: '5 ay önce',
          text:
              'İyi satıcı, teslimat biraz gecikmeli oldu ama ürün mükemmeldi.',
        ),
      ],
    ),
  ),
  IkincielIlani(
    id: 22,
    title: 'Adaptif Bisiklet',
    category: 'Adaptif Araç',
    city: 'İzmir',
    district: 'Bornova',
    condition: 'İyi',
    brand: 'Rifton',
    note:
        'SP tanılı çocuklar için üretilmiş denge bisikleti. Az kullanıldı.',
    price: '₺6.200',
    originalPrice: '₺18.000',
    posted: '2 gün önce',
    views: 55,
    emoji: '🚲',
    photos: [
      IlanPhoto.swatch(Color(0xFFF5E8DC)),
      IlanPhoto.swatch(Color(0xFFF0D8C8)),
      IlanPhoto.swatch(Color(0xFFEDD0BA)),
      IlanPhoto.swatch(Color(0xFFE8C8AA)),
    ],
    poster: IlanPoster(
      name: 'Nesrin K.',
      avatar: 'NK',
      avatarColor: _9c6,
      rating: 4.9,
      reviewCount: 13,
      bio:
          'Özel gereksinimli çocuklara yönelik adaptif araçlar satıyorum. Her şey çalışır durumda.',
      tags: ['Adaptif Araç', 'Az Kullanılmış', 'Rifton Uzmanı'],
      reviews: [
        IlanReview(
          author: 'Taner M.',
          avatar: 'TM',
          avatarColor: _c,
          rating: 5,
          date: '3 hafta önce',
          text:
              'Mükemmel satıcı! Ürün hakkında çok bilgili, montajda yardımcı oldu.',
        ),
        IlanReview(
          author: 'Ece S.',
          avatar: 'ES',
          avatarColor: _f4a,
          rating: 5,
          date: '1 ay önce',
          text: 'Çocuğumuz çok sevdi. Her şey %100 doğru tanımlanmıştı.',
        ),
        IlanReview(
          author: 'Kaan B.',
          avatar: 'KB',
          avatarColor: _6b9,
          rating: 5,
          date: '3 ay önce',
          text: 'Güvenilir ve hızlı. Tekrar bu satıcıdan alırım.',
        ),
      ],
    ),
  ),
  IkincielIlani(
    id: 23,
    title: 'AAC İletişim Tableti + Yazılım',
    category: 'İletişim Cihazı',
    city: 'İstanbul',
    district: 'Beşiktaş',
    condition: 'Çok İyi',
    brand: 'Tobii Dynavox',
    note:
        'Proloquo2Go lisanslı iPad. Çocuğumuz artık konuşabildiği için satıyoruz.',
    price: '₺9.500',
    originalPrice: '₺22.000',
    posted: '1 gün önce',
    views: 88,
    emoji: '📱',
    photos: [
      IlanPhoto.swatch(Color(0xFFDCE5F5)),
      IlanPhoto.swatch(Color(0xFFCCD8F0)),
    ],
    poster: IlanPoster(
      name: 'İpek Y.',
      avatar: 'İY',
      avatarColor: _c,
      rating: 5.0,
      reviewCount: 4,
      bio:
          'Çocuğumuz Proloquo2Go ile konuşmaya başladı, artık ihtiyacımız yok. Cihaz sıfır gibi.',
      tags: ['Lisanslı Yazılım', 'iPad', 'AAC'],
      reviews: [
        IlanReview(
          author: 'Sibel A.',
          avatar: 'SA',
          avatarColor: _9c6,
          rating: 5,
          date: '6 ay önce',
          text:
              'Çocuğumuzun hayatını değiştiren ürünü aldık. Satıcı çok bilgiliydi.',
        ),
      ],
    ),
  ),
  IkincielIlani(
    id: 24,
    title: 'Önden Destekli Yürüteç',
    category: 'Yürüteç',
    city: 'Bursa',
    district: 'Nilüfer',
    condition: 'İyi',
    brand: 'Kaye Products',
    note: 'Ayarlanabilir boy. Temiz tutulmuştur.',
    price: '₺1.800',
    originalPrice: '₺5.500',
    posted: '4 saat önce',
    views: 31,
    emoji: '🦯',
    photos: [
      IlanPhoto.swatch(Color(0xFFE8F5EE)),
      IlanPhoto.swatch(Color(0xFFD8EDE4)),
    ],
    poster: IlanPoster(
      name: 'Orhan S.',
      avatar: 'OS',
      avatarColor: _f4a,
      rating: 4.6,
      reviewCount: 6,
      bio:
          'Özel gereksinimli çocuklar için çeşitli yardımcı araçlarım var. Kargo veya elden teslim.',
      tags: ['Kargo Var', 'Bursa', 'Uygun Fiyat'],
      reviews: [
        IlanReview(
          author: 'Pelin K.',
          avatar: 'PK',
          avatarColor: _c,
          rating: 5,
          date: '1 ay önce',
          text: 'Tam beklediğim gibi. Çok hızlı kargo, teşekkürler.',
        ),
        IlanReview(
          author: 'Barış T.',
          avatar: 'BT',
          avatarColor: _e07,
          rating: 4,
          date: '3 ay önce',
          text: 'Ürün iyi durumda, fiyat uygun. Tavsiye ederim.',
        ),
      ],
    ),
  ),
];

// ─── Runtime (kullanıcı tarafından eklenen) ilanlar ──────────────────────────
// Uygulama açıkken paylaşılan ilanlar burada tutulur ve listelerin başına eklenir.
final List<UzmanIlani> runtimeUzmanIlanlar = <UzmanIlani>[];
final List<BakiciIlani> runtimeBakiciIlanlar = <BakiciIlani>[];
final List<IkincielIlani> runtimeIkincielIlanlar = <IkincielIlani>[];

int _ilanIdSeq = 1000;
int nextIlanId() => ++_ilanIdSeq;

/// İlan / iletişim görünen adı: M**** Ç**** (her kelimenin ilk harfi + ****).
String maskPersonDisplayName(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Üye';
  String maskWord(String word) {
    final w = word.trim();
    if (w.isEmpty) return '****';
    return '${w[0].toUpperCase()}****';
  }
  if (parts.length == 1) return maskWord(parts.first);
  return '${maskWord(parts.first)} ${maskWord(parts.last)}';
}

final _emailInTextRe = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);

/// TR cep / sabit ve uluslararası telefon kalıpları.
final _phoneInTextRe = RegExp(
  r'(?<!\d)(?:\+90[\s\-.]?|0)?(?:5\d{2}[\s\-.]?\d{3}[\s\-.]?\d{2}[\s\-.]?\d{2}|'
  r'(?:2|3|4)\d{2}[\s\-.]?\d{3}[\s\-.]?\d{2}[\s\-.]?\d{2})(?!\d)|'
  r'(?<!\d)\+?\d[\d\s\-().]{7,}\d(?!\d)',
  multiLine: true,
);

final _socialContactRe = RegExp(
  r'(?:https?://)?(?:wa\.me|api\.whatsapp\.com|t\.me|telegram\.me)/\S+',
  caseSensitive: false,
);

/// İlan başlık/açıklama: telefon, e-posta ve dış iletişim linklerini temizler.
String scrubIlanListingText(String text) {
  if (text.trim().isEmpty) return text;
  return text
      .replaceAllMapped(_emailInTextRe, (_) => '***')
      .replaceAllMapped(_phoneInTextRe, (_) => '***')
      .replaceAllMapped(_socialContactRe, (_) => '***');
}

/// Mesaj / önizleme metnindeki e-posta ve telefonları gizler.
String scrubEmailsInText(String text) {
  return text
      .replaceAllMapped(_emailInTextRe, (_) => 'üye')
      .replaceAllMapped(_phoneInTextRe, (_) => 'üye')
      .replaceAllMapped(_socialContactRe, (_) => 'üye');
}

/// Sohbet / bildirimde gösterilecek ad — e-posta gizler, adı maskeler.
String publicContactLabel(
  String raw, {
  String preferredName = '',
  String fallback = 'Üye',
}) {
  final preferred = preferredName.trim();
  if (preferred.isNotEmpty && !preferred.contains('@')) {
    return maskPersonDisplayName(preferred);
  }
  var s = raw.trim();
  if (s.isEmpty) return fallback;
  if (s.contains('↔')) return fallback;
  if (s.contains('@')) return fallback;
  return maskPersonDisplayName(s);
}

String contactAvatarLetter(String label) {
  final s = publicContactLabel(label).trim();
  if (s.isEmpty || s == 'Üye') return 'Ü';
  return s[0].toUpperCase();
}

/// Avatar baş harfleri (maskeli isimden: M**** Ç**** → MÇ).
String posterAvatarInitials(String displayName) {
  final first = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p[0])
      .join()
      .toUpperCase();
  if (first.isEmpty) return 'Ü';
  return first.substring(0, first.length.clamp(0, 2));
}

void syncIlanIdSeq(int maxId) {
  if (maxId > _ilanIdSeq) _ilanIdSeq = maxId;
}

/// İlanı paylaşan kullanıcıyı temsil eden basit profil.
const selfIlanPoster = IlanPoster(
  name: 'Siz',
  avatar: 'SZ',
  avatarColor: MetoColors.primary,
  rating: 0,
  reviewCount: 0,
  bio: 'İlan sahibi',
  tags: <String>[],
  reviews: <IlanReview>[],
);

double avgRating(List<IlanReview> reviews) {
  if (reviews.isEmpty) return 0;
  return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
}

UzmanRenk uzmanRenkFor(String uzmanlik) {
  return uzmanRenk[uzmanlik] ??
      const UzmanRenk(
        color: MetoColors.primary,
        bg: MetoColors.selectedBg,
        emoji: '👤',
      );
}

PosterCv posterCvFromProfil(KullaniciProfil profil) {
  final certs = profil.sertifikalar
      .split(RegExp(r'[\n,;]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return PosterCv(
    okul: profil.egitim.trim(),
    deneyimYil: profil.deneyimYili.trim(),
    deneyimAlani: profil.uzmanliklar.trim(),
    sertifikalar: certs,
    hakkimda: profil.hakkimda.trim(),
  );
}

PosterCv posterCvFor(IlanPoster poster) => poster.cv ?? const PosterCv();
