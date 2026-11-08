import '../uzman_kosesi_profiles_store.dart';

const kKurumIsCalismaSekliSecenekleri = <String>[
  'Tam zamanlı',
  'Yarı zamanlı',
  'Vardiyalı',
  'Sözleşmeli',
];

const kKurumIsKvkkOnayMetni =
    'Kurum adı, aranan meslek, il/ilçe, kurum adresi, ilan metni, '
    'opsiyonel kurum görseli ve opsiyonel telefon bilgimin Engelsiz Club '
    'Uzman Profilleri Köşesi’nde görüntülenmesi için KVKK kapsamında açık rıza veriyorum.';

class KurumIsIlani {
  const KurumIsIlani({
    this.id = 0,
    this.ownerId = '',
    this.ownerEmail = '',
    this.kurumAdi = '',
    this.arananMeslek = '',
    this.il = '',
    this.ilce = '',
    this.adres = '',
    this.photoUrl = '',
    this.aciklama = '',
    this.calismaSekli = const [],
    this.telefon = '',
    this.status = 'published',
    this.createdAt,
  });

  final int id;
  final String ownerId;
  final String ownerEmail;
  final String kurumAdi;
  final String arananMeslek;
  final String il;
  final String ilce;
  final String adres;
  final String photoUrl;
  final String aciklama;
  final List<String> calismaSekli;
  final String telefon;
  final String status;
  final DateTime? createdAt;

  bool get isPublished => status == 'published';

  String get yerLabel {
    final parts = <String>[
      if (il.trim().isNotEmpty) il.trim(),
      if (ilce.trim().isNotEmpty) ilce.trim(),
    ];
    return parts.join(' / ');
  }

  factory KurumIsIlani.fromJson(Map<String, dynamic> json) {
    final raw = json['calisma_sekli'];
    final sekil = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final t = e.toString().trim();
        if (t.isNotEmpty) sekil.add(t);
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      sekil.add(raw.trim());
    }
    return KurumIsIlani(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: json['owner_id']?.toString() ?? '',
      ownerEmail: (json['owner_email']?.toString() ?? '').trim().toLowerCase(),
      kurumAdi: json['kurum_adi']?.toString().trim() ?? '',
      arananMeslek: json['aranan_meslek']?.toString().trim() ?? '',
      il: json['il']?.toString().trim() ?? '',
      ilce: json['ilce']?.toString().trim() ?? '',
      adres: json['adres']?.toString().trim() ?? '',
      photoUrl: json['photo_url']?.toString().trim() ?? '',
      aciklama: json['aciklama']?.toString().trim() ?? '',
      calismaSekli: sekil,
      telefon: json['telefon']?.toString().trim() ?? '',
      status: json['status']?.toString() ?? 'published',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

bool canCreateKurumIsIlani({
  required bool isGuest,
  String? userEmail,
}) {
  if (isGuest) return false;
  return (userEmail ?? '').trim().isNotEmpty;
}

String? validateKurumIsIlani({
  required String kurumAdi,
  required String arananMeslek,
  required String il,
  required String aciklama,
  required bool kvkk,
  String adres = '',
}) {
  if (kurumAdi.trim().length < 2) return 'Kurum adı yazın.';
  if (arananMeslek.trim().isEmpty) return 'Aranan mesleği seçin.';
  if (il.trim().isEmpty) return 'İl seçin.';
  if (adres.trim().length < 5) return 'Kurum adresini yazın.';
  if (aciklama.trim().length < 10) {
    return 'İlan açıklaması en az 10 karakter olmalı.';
  }
  if (!kvkk) return 'KVKK onayını işaretleyin.';
  return null;
}

bool kurumIsIlaniMatches(
  KurumIsIlani ilan, {
  String meslek = '',
  String il = '',
  String ilce = '',
}) {
  if (meslek.trim().isNotEmpty &&
      uzmanKosesNormYer(ilan.arananMeslek) != uzmanKosesNormYer(meslek)) {
    return false;
  }
  if (il.trim().isEmpty) return true;
  if (uzmanKosesNormYer(ilan.il) != uzmanKosesNormYer(il)) return false;
  if (ilce.trim().isEmpty) return true;
  return uzmanKosesNormYer(ilan.ilce) == uzmanKosesNormYer(ilce);
}

List<KurumIsIlani> kurumIsIlanlariFiltrele(
  Iterable<KurumIsIlani> ilanlar, {
  String meslek = '',
  String il = '',
  String ilce = '',
}) {
  return [
    for (final e in ilanlar)
      if (kurumIsIlaniMatches(e, meslek: meslek, il: il, ilce: ilce)) e,
  ];
}
