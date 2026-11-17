const kMeslekUstSaglik = 'Sağlık Uzmanları';
const kMeslekUstBakim = 'Bakım ve Ev Desteği';

int nextMeslekGrubuSira(Iterable<MeslekGrubu> all, String ustGrup) {
  var max = 0;
  var found = false;
  for (final g in all) {
    if (g.ustGrup != ustGrup) continue;
    found = true;
    if (g.sira > max) max = g.sira;
  }
  return (found ? max : 0) + 10;
}

class MeslekGrubu {
  const MeslekGrubu({
    required this.id,
    required this.key,
    required this.etiket,
    required this.ustGrup,
    this.sira = 0,
    this.aktif = true,
  });

  final int id;
  final String key;
  final String etiket;
  final String ustGrup;
  final int sira;
  final bool aktif;

  bool get isBakim => ustGrup == 'Bakım ve Ev Desteği';

  factory MeslekGrubu.fromJson(Map<String, dynamic> json) => MeslekGrubu(
        id: (json['id'] as num?)?.toInt() ?? 0,
        key: json['grup_key']?.toString() ?? '',
        etiket: json['etiket']?.toString() ?? '',
        ustGrup: json['ust_grup']?.toString() ?? '',
        sira: (json['sira'] as num?)?.toInt() ?? 0,
        aktif: json['aktif'] != false,
      );
}

class MeslekAlanSablon {
  const MeslekAlanSablon({
    required this.id,
    required this.meslekGrubuId,
    required this.alanKey,
    required this.etiket,
    required this.tip,
    this.secenekler = const [],
    this.zorunlu = false,
    this.sira = 0,
    this.aktif = true,
  });

  final int id;
  final int meslekGrubuId;
  final String alanKey;
  final String etiket;
  final String tip;
  final List<String> secenekler;
  final bool zorunlu;
  final int sira;
  final bool aktif;

  factory MeslekAlanSablon.fromJson(Map<String, dynamic> json) {
    final raw = json['secenekler'];
    final opts = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final t = e.toString().trim();
        if (t.isNotEmpty) opts.add(t);
      }
    }
    return MeslekAlanSablon(
      id: (json['id'] as num?)?.toInt() ?? 0,
      meslekGrubuId: (json['meslek_grubu_id'] as num?)?.toInt() ?? 0,
      alanKey: json['alan_key']?.toString() ?? '',
      etiket: json['etiket']?.toString() ?? '',
      tip: json['tip']?.toString() ?? 'text',
      secenekler: opts,
      zorunlu: json['zorunlu'] == true,
      sira: (json['sira'] as num?)?.toInt() ?? 0,
      aktif: json['aktif'] != false,
    );
  }

  MeslekAlanSablon copyWith({
    int? id,
    int? meslekGrubuId,
    String? alanKey,
    String? etiket,
    String? tip,
    List<String>? secenekler,
    bool? zorunlu,
    int? sira,
    bool? aktif,
  }) {
    return MeslekAlanSablon(
      id: id ?? this.id,
      meslekGrubuId: meslekGrubuId ?? this.meslekGrubuId,
      alanKey: alanKey ?? this.alanKey,
      etiket: etiket ?? this.etiket,
      tip: tip ?? this.tip,
      secenekler: secenekler ?? this.secenekler,
      zorunlu: zorunlu ?? this.zorunlu,
      sira: sira ?? this.sira,
      aktif: aktif ?? this.aktif,
    );
  }
}

class ExpertCvProfile {
  const ExpertCvProfile({
    this.id = 0,
    this.ownerId = '',
    this.ownerEmail = '',
    this.fullName = '',
    this.photoUrl = '',
    this.meslekGrubuId,
    this.meslekEtiket = '',
    this.ustGrup = '',
    this.il = '',
    this.ilce = '',
    this.countryCode = 'TR',
    this.deneyimYili,
    this.kisaTanitim = '',
    this.calismaSekli = const [],
    this.musaitlik = const [],
    this.diller = const [],
    this.isaretDili = false,
    this.engelliDeneyimi,
    this.engelliDeneyimAciklama = '',
    this.referanslar = '',
    this.iletisimTercihi = 'app_message',
    this.telefonIzin = false,
    this.epostaIzin = false,
    this.meslekDetaylari = const {},
    this.kvkkOnay = false,
    this.status = 'draft',
    this.rejectReason = '',
    this.dogrulandi = false,
    this.kartSpan = 1,
    this.ucretBitis,
    this.ilkAyKullanildi = false,
    this.odenenPuan = 0,
    this.publishedAt,
    this.createdAt,
  });

  final int id;
  final String ownerId;
  final String ownerEmail;
  final String fullName;
  final String photoUrl;
  final int? meslekGrubuId;
  final String meslekEtiket;
  final String ustGrup;
  final String il;
  final String ilce;
  final String countryCode;
  final int? deneyimYili;
  final String kisaTanitim;
  final List<String> calismaSekli;
  final List<String> musaitlik;
  final List<String> diller;
  final bool isaretDili;
  final bool? engelliDeneyimi;
  final String engelliDeneyimAciklama;
  final String referanslar;
  final String iletisimTercihi;
  final bool telefonIzin;
  final bool epostaIzin;
  final Map<String, dynamic> meslekDetaylari;
  final bool kvkkOnay;
  final String status;
  final String rejectReason;
  final bool dogrulandi;
  /// 1 = yarım satır (1 kutu), 2 = tam satır.
  final int kartSpan;
  final DateTime? ucretBitis;
  final bool ilkAyKullanildi;
  final int odenenPuan;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  bool get tamSatir => kartSpan >= 2;
  bool get puanOdedi => odenenPuan > 0;

  String get yerLabel {
    final parts = <String>[
      if (il.trim().isNotEmpty) il.trim(),
      if (ilce.trim().isNotEmpty) ilce.trim(),
    ];
    return parts.join(' / ');
  }

  bool get isPublished => status == 'published';
  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired';
  bool get isBakim => ustGrup == 'Bakım ve Ev Desteği';

  bool get isBakici {
    if (!isBakim) return false;
    final e = meslekEtiket.trim().toLowerCase();
    return e == 'bakıcı' || e == 'bakici';
  }

  String get mezunBolum {
    final a = meslekDetaylari[kUzmanMezunBolumKey]?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    return meslekDetaylari['mezun_oldugu_bolum']?.toString().trim() ?? '';
  }

  String get cepTelefonu {
    final fromDetay = meslekDetaylari['cep_telefonu']?.toString().trim() ?? '';
    if (fromDetay.isNotEmpty) return fromDetay;
    return meslekDetaylari['telefon']?.toString().trim() ?? '';
  }

  /// Klinik / ofis / iş yeri adresi. Ev adresi değil.
  String get isYeriAdresi {
    final a = meslekDetaylari[kUzmanIsYeriAdresKey]?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    return meslekDetaylari['isyeri_adresi']?.toString().trim() ?? '';
  }

  bool get iletisimMesaj =>
      iletisimTercihi == 'app_message' || iletisimTercihi == 'both';

  bool get iletisimTelefon =>
      telefonIzin || iletisimTercihi == 'phone' || iletisimTercihi == 'both';

  bool get iletisimEposta =>
      epostaIzin || iletisimTercihi == 'email';

  String get iletisimOzet {
    final parts = <String>[
      if (iletisimMesaj) 'Uygulama içi mesaj',
      if (iletisimTelefon) 'Telefon',
      if (iletisimEposta) 'E-posta',
    ];
    return parts.isEmpty ? 'Uygulama içi mesaj' : parts.join(', ');
  }

  ExpertCvProfile withMeslek({String? etiket, String? ustGrup}) {
    return ExpertCvProfile(
      id: id,
      ownerId: ownerId,
      ownerEmail: ownerEmail,
      fullName: fullName,
      photoUrl: photoUrl,
      meslekGrubuId: meslekGrubuId,
      meslekEtiket: (etiket != null && etiket.trim().isNotEmpty)
          ? etiket.trim()
          : meslekEtiket,
      ustGrup: (ustGrup != null && ustGrup.trim().isNotEmpty)
          ? ustGrup.trim()
          : this.ustGrup,
      il: il,
      ilce: ilce,
      countryCode: countryCode,
      deneyimYili: deneyimYili,
      kisaTanitim: kisaTanitim,
      calismaSekli: calismaSekli,
      musaitlik: musaitlik,
      diller: diller,
      isaretDili: isaretDili,
      engelliDeneyimi: engelliDeneyimi,
      engelliDeneyimAciklama: engelliDeneyimAciklama,
      referanslar: referanslar,
      iletisimTercihi: iletisimTercihi,
      telefonIzin: telefonIzin,
      epostaIzin: epostaIzin,
      meslekDetaylari: meslekDetaylari,
      kvkkOnay: kvkkOnay,
      status: status,
      rejectReason: rejectReason,
      dogrulandi: dogrulandi,
      kartSpan: kartSpan,
      ucretBitis: ucretBitis,
      ilkAyKullanildi: ilkAyKullanildi,
      odenenPuan: odenenPuan,
      publishedAt: publishedAt,
      createdAt: createdAt,
    );
  }

  /// Diploma / meslek belgesi paylaşılmışsa profil "Doğrulanmış" kabul edilir.
  bool get diplomaPaylasildi => belgeAlaniYuklendi(meslekDetaylari);
  bool get dogrulanmisProfil => dogrulandi || diplomaPaylasildi;

  factory ExpertCvProfile.fromJson(Map<String, dynamic> json) {
    final grup = json['meslek_gruplari'];
    String etiket = '';
    String ust = '';
    if (grup is Map) {
      etiket = grup['etiket']?.toString() ?? '';
      ust = grup['ust_grup']?.toString() ?? '';
    }
    return ExpertCvProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: json['owner_id']?.toString() ?? '',
      ownerEmail: (json['owner_email']?.toString() ?? '').trim().toLowerCase(),
      fullName: json['full_name']?.toString().trim() ?? '',
      photoUrl: json['photo_url']?.toString().trim() ?? '',
      meslekGrubuId: (json['meslek_grubu_id'] as num?)?.toInt(),
      meslekEtiket: etiket,
      ustGrup: ust,
      il: json['il']?.toString().trim() ?? '',
      ilce: json['ilce']?.toString().trim() ?? '',
      countryCode:
          (json['country_code']?.toString() ?? 'TR').trim().toUpperCase(),
      deneyimYili: (json['deneyim_yili'] as num?)?.toInt(),
      kisaTanitim: json['kisa_tanitim']?.toString() ?? '',
      calismaSekli: _strList(json['calisma_sekli']),
      musaitlik: _strList(json['musaitlik']),
      diller: _strList(json['diller']),
      isaretDili: json['isaret_dili'] == true,
      engelliDeneyimi: json['engelli_deneyimi'] is bool
          ? json['engelli_deneyimi'] as bool
          : null,
      engelliDeneyimAciklama:
          json['engelli_deneyim_aciklama']?.toString() ?? '',
      referanslar: json['referanslar']?.toString() ?? '',
      iletisimTercihi: json['iletisim_tercihi']?.toString() ?? 'app_message',
      telefonIzin: json['telefon_izin'] == true,
      epostaIzin: json['eposta_izin'] == true,
      meslekDetaylari: json['meslek_detaylari'] is Map
          ? Map<String, dynamic>.from(json['meslek_detaylari'] as Map)
          : const {},
      kvkkOnay: json['kvkk_onay'] == true,
      status: json['status']?.toString() ?? 'draft',
      rejectReason: json['reject_reason']?.toString() ?? '',
      dogrulandi: json['dogrulandi'] == true,
      kartSpan: uzmanKartSpanFrom(json),
      ucretBitis: DateTime.tryParse(json['ucret_bitis']?.toString() ?? ''),
      ilkAyKullanildi: json['ilk_ay_kullanildi'] == true,
      odenenPuan: uzmanOdenenPuanFrom(json),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class ExpertProfileFile {
  const ExpertProfileFile({
    required this.alanKey,
    required this.fileUrl,
  });

  final String alanKey;
  final String fileUrl;
}

bool belgeAlaniYuklendi(Map<String, dynamic> detay) {
  for (final k in const ['diploma', 'belge']) {
    final v = detay[k];
    if (v == true) return true;
    final t = v?.toString().trim() ?? '';
    if (t.isNotEmpty && t != 'null') return true;
  }
  return false;
}

bool isOpsiyonelBelgeAlani(String alanKey) =>
    alanKey == 'diploma' || alanKey == 'belge';

const kBelgeFotoAciklama =
    'Diplomanızın veya meslek belgenizin net bir fotoğrafı yeterlidir. '
    'Asıl belgeyi göndermeniz, taratmanız veya PDF yüklemeniz gerekmez; '
    'telefonunuzla çektiğiniz fotoğrafı yüklemeniz yeterli. '
    'Bu görsel yalnızca siz ve yöneticiler tarafından görülür.';

const kBelgeFotoOpsiyonelNot =
    'Zorunlu değil. Fotoğrafını paylaşırsanız profilinizde “Doğrulanmış profil” yazısı çıkar.';

String belgeYukleButonMetni(String alanKey, {required bool yuklendi}) {
  if (yuklendi) return 'Fotoğraf yüklendi';
  return alanKey == 'diploma' ? 'Diploma fotoğrafı yükle' : 'Belge fotoğrafı yükle';
}

const kUzmanDiplomaDosyaAlani = MeslekAlanSablon(
  id: 0,
  meslekGrubuId: 0,
  alanKey: 'diploma',
  etiket: 'Diploma / meslek belgesi',
  tip: 'file',
  sira: 130,
);

List<MeslekAlanSablon> uzmanCvDosyaAlanlari(
  Iterable<MeslekAlanSablon> sablonlar,
) {
  final files = [for (final e in sablonlar) if (e.tip == 'file') e];
  if (files.any((e) => e.alanKey == 'diploma')) return files;
  return [...files, kUzmanDiplomaDosyaAlani];
}

String uzmanBelgeAlaniEtiketi(String alanKey) {
  switch (alanKey) {
    case 'diploma':
      return 'Diploma / meslek belgesi';
    case 'belge':
      return 'Belge';
    case 'kimlik_dogrulama':
      return 'Kimlik';
    case 'adli_sicil':
      return 'Adli sicil';
    default:
      return 'Belge';
  }
}

List<String> _strList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}

const kCalismaSekliSecenekleri = <String>[
  'Ev ziyareti',
  'Klinik',
  'Online',
  'Tam zamanlı',
  'Saatlik',
];

const kBakimCalismaSekliSecenekleri = <String>[
  'Evde bakım',
  'Gündüz',
  'Gece',
  'Yatılı',
  'Saatlik',
  'Tam zamanlı',
];

const kMusaitlikSecenekleri = <String>[
  'Hafta içi',
  'Hafta sonu',
  'Gece',
  'Yatılı',
];

const kUzmanKartTekPuan = 3;
const kUzmanKartSatirPuan = 5;
const kUzmanKartAyGun = 30;
const kUzmanKartIlkUcretsizGun = 60;
/// Geriye dönük: ilk ücretsiz dönem (2 ay).
const kUzmanKartIlkAyGun = kUzmanKartIlkUcretsizGun;

const kUzmanKartBakiyeUyarisi =
    'Hesabınızda yeterli puan yoksa ilanınız yayından kalkacak.';
const kUzmanKartYetersizUyarisi =
    'Bakiyeniz yetersiz. Puan yüklemezseniz ilanınız yayından kalkacak.';
const kUzmanKartYayindanKalkti =
    'Bakiyeniz yetersiz olduğu için ilanınız yayından kaldırıldı. '
    'Puan yükleyip tekrar yayınlayabilirsiniz.';
const kUzmanKartUyeTarifeMetni =
    'İlanınızın yayında kalma süresi ilk 2 ay ücretsizdir. '
    'Sonraki aylarda tek kutucuk alan için $kUzmanKartTekPuan puan, '
    '2 kutucuk alan için $kUzmanKartSatirPuan puan hesabınızdan kesilir.';
const kUzmanKartUstBilgi = kUzmanKartUyeTarifeMetni;
const kUzmanIlanSil = 'İlanı sil';
const kUzmanIlanimiSil = 'İlanımı sil';
const kUzmanIlanSilOnay =
    'İlanınız yayından kalkacak ve profiliniz silinecek. Bu işlem geri alınamaz.';
const kUzmanYayinOnayBilgi =
    'Doğrulama yapıldıktan sonra profiliniz yayınlanacaktır.';

List<String> uzmanMetinListesi(dynamic raw) {
  if (raw == null) return const [];
  final out = <String>[];
  void add(String s) {
    final t = s.trim();
    if (t.isEmpty) return;
    final low = t.toLowerCase();
    if (low == 'diğer' || low == 'diger') return;
    out.add(t);
  }

  if (raw is Iterable) {
    for (final e in raw) {
      add(e.toString());
    }
    return out;
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return const [];
  if (s.contains(RegExp(r'[\n;,•]'))) {
    for (final part in s.split(RegExp(r'[\n;,•]+'))) {
      add(part);
    }
    return out;
  }
  add(s);
  return out;
}

List<String> uzmanBenzersizEtiketler(Iterable<dynamic> sources) {
  final seen = <String>{};
  final out = <String>[];
  for (final src in sources) {
    for (final item in uzmanMetinListesi(src)) {
      final key = item.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seen.add(key)) out.add(item);
    }
  }
  return out;
}

class UzmanSertifikaSatir {
  const UzmanSertifikaSatir({required this.baslik, this.kurum = ''});

  final String baslik;
  final String kurum;
}

List<UzmanSertifikaSatir> uzmanSertifikaSatirlari(Iterable<dynamic> sources) {
  final seen = <String>{};
  final rows = <UzmanSertifikaSatir>[];
  for (final src in sources) {
    for (final line in uzmanMetinListesi(src)) {
      var title = line;
      var sub = '';
      for (final sep in ['→', '->', '—', '–']) {
        final i = line.indexOf(sep);
        if (i > 0) {
          title = line.substring(0, i).trim();
          sub = line.substring(i + sep.length).trim();
          break;
        }
      }
      if (sub.isEmpty) {
        final dash = RegExp(r'\s*[-–—]\s+').firstMatch(line);
        if (dash != null && dash.start > 0) {
          title = line.substring(0, dash.start).trim();
          sub = line.substring(dash.end).trim();
        }
      }
      final key = '${title.toLowerCase()}|${sub.toLowerCase()}';
      if (title.isNotEmpty && seen.add(key)) {
        rows.add(UzmanSertifikaSatir(baslik: title, kurum: sub));
      }
    }
  }
  return rows;
}

String uzmanBoolGoster(
  dynamic v, {
  String evet = 'Var',
  String hayir = 'Yok',
}) {
  if (v == true) return evet;
  if (v == false) return hayir;
  final s = v?.toString().trim().toLowerCase() ?? '';
  if (s.isEmpty) return '';
  if (s == 'true' || s == 'evet' || s == 'var' || s == '1') return evet;
  if (s == 'false' || s == 'hayır' || s == 'hayir' || s == 'yok' || s == '0') {
    return hayir;
  }
  return v.toString().trim();
}

String uzmanSeansGoster(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return '';
  if (RegExp(r'dk|dakika', caseSensitive: false).hasMatch(s)) return s;
  return s;
}

String uzmanEtiketOzeti(Iterable<String> tags, {String fallback = ''}) {
  final t = tags.toList();
  if (t.isEmpty) return fallback;
  if (t.length == 1) return t.first;
  if (t.length == 2) return '${t[0]} ve ${t[1]}';
  return t.join(', ');
}

String uzmanProfilEkranBasligi(ExpertCvProfile p) {
  if (!p.isBakim) return 'Terapist profili';
  final e = p.meslekEtiket.trim();
  return e.isEmpty ? 'Bakım profili' : '$e profili';
}

String uzmanIkinciAksiyonMetni(ExpertCvProfile p) =>
    p.isBakim ? 'Hizmet talep et' : 'Randevu talep et';

String uzmanAdresKartBasligi(ExpertCvProfile p) =>
    p.isBakim ? 'Hizmet adresi' : 'İş yeri adresi';

String uzmanGrupKartBasligi(ExpertCvProfile p) =>
    p.isBakim ? 'Bakım / hizmet' : 'Çalıştığı gruplar';

List<String> uzmanGrupKartEtiketleri(ExpertCvProfile p) {
  if (p.isBakim) {
    return uzmanBenzersizEtiketler([
      p.meslekDetaylari['bakim_turu'],
      p.meslekDetaylari['hizmet_turu'],
    ]);
  }
  return uzmanBenzersizEtiketler([
    p.meslekDetaylari['engel_gruplari'],
    p.meslekDetaylari['calistigi_gruplar'],
  ]);
}

String uzmanUzmanlikKartBasligi(ExpertCvProfile p) =>
    p.isBakim ? 'Yapabildikleri' : 'Uzmanlık alanları';

List<String> uzmanUzmanlikKartEtiketleri(ExpertCvProfile p) {
  if (p.isBakim) {
    return uzmanBenzersizEtiketler([
      p.meslekDetaylari['yapabildikleri'],
      p.meslekDetaylari['ek_hizmetler'],
    ]);
  }
  return uzmanBenzersizEtiketler([
    p.meslekDetaylari['uzmanlik_alanlari'],
    p.meslekDetaylari['uzmanlik_ilgi'],
  ]);
}

class UzmanHizliSatir {
  const UzmanHizliSatir({
    required this.label,
    required this.value,
    this.iconHint = 'info',
  });

  final String label;
  final String value;
  final String iconHint;
}

List<UzmanHizliSatir> uzmanHizliBilgiler(ExpertCvProfile p) {
  String join(dynamic raw) => uzmanBenzersizEtiketler([raw]).join(', ');
  final out = <UzmanHizliSatir>[];
  void add(String label, String value, String icon) {
    final t = value.trim();
    if (t.isEmpty) return;
    out.add(UzmanHizliSatir(label: label, value: t, iconHint: icon));
  }

  if (p.isBakim) {
    if (p.isBakici) {
      add('Mezun olunan bölüm', p.mezunBolum, 'school');
    }
    final duzen = join(p.meslekDetaylari['calisma_duzeni']);
    add(
      'Çalışma düzeni',
      duzen.isNotEmpty ? duzen : p.calismaSekli.join(', '),
      'work',
    );
    add(
      'Kendi malzemesi',
      uzmanBoolGoster(p.meslekDetaylari['kendi_malzeme']),
      'clean',
    );
    add(
      'Sigara tercihi',
      p.meslekDetaylari['tercih_sigara']?.toString() ?? '',
      'smoke',
    );
    add(
      'Evcil hayvan',
      p.meslekDetaylari['tercih_evcil']?.toString() ?? '',
      'pets',
    );
    add(
      'Engelli bireylerle deneyim',
      uzmanBoolGoster(p.engelliDeneyimi),
      'access',
    );
    return out;
  }

  final evFromDetay = uzmanBoolGoster(
    p.meslekDetaylari['ev_ziyareti'],
    evet: 'Yapıyor',
    hayir: 'Yapmıyor',
  );
  final evFromCalisma = p.calismaSekli.any(
    (s) => s.toLowerCase().contains('ev ziyareti'),
  );
  add('Seans süresi', uzmanSeansGoster(p.meslekDetaylari['seans_suresi']), 'schedule');
  add(
    'Kendi ekipmanı',
    uzmanBoolGoster(
      p.meslekDetaylari['ekipman'] ?? p.meslekDetaylari['kendi_ekipman'],
    ),
    'medical',
  );
  add(
    'Ev ziyareti',
    evFromDetay.isNotEmpty ? evFromDetay : (evFromCalisma ? 'Yapıyor' : ''),
    'home',
  );
  add(
    'Engelli bireylerle deneyim',
    uzmanBoolGoster(p.engelliDeneyimi),
    'access',
  );
  return out;
}

String uzmanHeroUzmanlik(ExpertCvProfile p) {
  if (p.isBakim) {
    return uzmanEtiketOzeti(
      uzmanBenzersizEtiketler([
        p.meslekDetaylari['bakim_turu'],
        p.meslekDetaylari['hizmet_turu'],
      ]),
      fallback: p.meslekEtiket.trim(),
    );
  }
  var tags = uzmanBenzersizEtiketler([p.meslekDetaylari['uzmanlik_alanlari']]);
  if (tags.isEmpty) {
    tags = uzmanBenzersizEtiketler([p.meslekDetaylari['uzmanlik_ilgi']]);
  }
  return uzmanEtiketOzeti(tags, fallback: p.meslekEtiket.trim());
}

String uzmanBasHarfler(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String uzmanProfilBakanOzeti(int n) {
  if (n <= 0) return 'Henüz kimse bakmadı';
  if (n == 1) return '1 kişi baktı';
  return '$n kişi baktı';
}

const kUzmanYorumYok = 'Yorum yok';

String uzmanYildizOzeti(double avg, int count) {
  if (count <= 0) return kUzmanYorumYok;
  return '${avg.toStringAsFixed(1)} / 5';
}

String uzmanTelDigits(String raw) => raw.replaceAll(RegExp(r'[^\d+]'), '');

bool uzmanTelAranabilir(String raw) {
  final d = uzmanTelDigits(raw).replaceAll('+', '');
  return d.length >= 10;
}

double uzmanYildizOrtalama(Iterable<int> ratings) {
  final list = ratings.toList();
  if (list.isEmpty) return 0;
  return list.fold<int>(0, (a, b) => a + b) / list.length;
}

String uzmanYorumTarih(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days <= 0) return 'Bugün';
  if (days == 1) return 'Dün';
  if (days < 7) return '$days gün önce';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

int uzmanKartPuan(int span) => span >= 2 ? kUzmanKartSatirPuan : kUzmanKartTekPuan;

int uzmanKartSpanFrom(Map json) {
  final col = (json['kart_span'] as num?)?.toInt();
  if (col == 2 || col == 1) return col!;
  final detay = json['meslek_detaylari'];
  if (detay is Map) {
    final n = int.tryParse(detay['kart_span']?.toString() ?? '');
    if (n == 2) return 2;
  }
  return 1;
}

int uzmanOdenenPuanFrom(Map json) {
  final col = (json['odenen_puan'] as num?)?.toInt();
  if (col != null && col > 0) return col;
  final detay = json['meslek_detaylari'];
  if (detay is Map) {
    return int.tryParse(detay['odenen_puan']?.toString() ?? '') ?? 0;
  }
  return 0;
}

int uzmanProfilYayindaGun(ExpertCvProfile p, {DateTime? now}) {
  final start = p.publishedAt ?? p.createdAt;
  if (start == null) return 0;
  final d = (now ?? DateTime.now()).toUtc().difference(start.toUtc()).inDays;
  return d < 0 ? 0 : d;
}

String uzmanProfilYayindaOzet(ExpertCvProfile p, {DateTime? now}) {
  final gun = uzmanProfilYayindaGun(p, now: now);
  if (gun <= 0) return 'Bugün yayınlandı';
  return '$gun gündür yayında';
}

String uzmanProfilOdemeOzeti(ExpertCvProfile p, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (p.odenenPuan > 0) {
    return '${p.odenenPuan} puan ödendi';
  }
  if (!p.ilkAyKullanildi) return 'Henüz puan ödemedi';
  final bitis = p.ucretBitis;
  if (bitis != null && bitis.isAfter(n) && p.odenenPuan <= 0) {
    return 'İlk 2 ay ücretsiz · henüz puan ödemedi';
  }
  if (bitis != null && bitis.isAfter(n)) {
    return 'Dönem ${bitis.day.toString().padLeft(2, '0')}.${bitis.month.toString().padLeft(2, '0')}.${bitis.year} tarihine kadar';
  }
  return 'Puan ödemedi';
}

/// İlk 2 ay veya süresi dolmamış dönem ücretsiz; aksi halde her ay 3 veya 5 puan.
int uzmanKartYayinUcreti({
  required ExpertCvProfile? existing,
  required int span,
}) {
  final now = DateTime.now();
  if (existing == null || !existing.ilkAyKullanildi) return 0;
  if (existing.isExpired) return uzmanKartPuan(span);
  final bitis = existing.ucretBitis;
  if (bitis != null && bitis.isAfter(now)) return 0;
  return uzmanKartPuan(span);
}

int uzmanKartDonemGun({required bool ilkDonem}) =>
    ilkDonem ? kUzmanKartIlkUcretsizGun : kUzmanKartAyGun;

String uzmanKartBoyutOzeti(int span) => span >= 2
    ? '2 kutucuk · sonraki aylarda $kUzmanKartSatirPuan puan'
    : 'Tek kutucuk · sonraki aylarda $kUzmanKartTekPuan puan';

String uzmanKartUcretAciklamasi({required int span, required bool ucretsiz}) {
  final puan = uzmanKartPuan(span);
  final boyut = span >= 2 ? '2 kutucuk alan' : 'tek kutucuk alan';
  if (ucretsiz) {
    return 'İlanınızın yayında kalma süresi ilk 2 ay ücretsizdir. '
        'Sonraki aylarda $boyut için $puan puan hesabınızdan kesilir. '
        '$kUzmanKartBakiyeUyarisi';
  }
  return 'Sonraki aylarda $boyut için $puan puan hesabınızdan kesilir. '
      '$kUzmanKartBakiyeUyarisi';
}

const kUzmanIsYeriAdresKey = 'is_yeri_adresi';
const kUzmanMezunBolumKey = 'mezun_bolum';
const kUzmanIsYeriAdresUyeNotu =
    'Yalnızca uygulamaya üye olanlar görür. Ev adresinizi yazmayın.';
const kUzmanIsYeriAdresGirisNotu = 'Adresi görmek için giriş yapın.';

bool uzmanIsYeriAdresiGorunur({
  required bool isGuest,
  required String userEmail,
  bool isOwner = false,
}) {
  if (isOwner) return true;
  return !isGuest && userEmail.trim().isNotEmpty;
}

const kOrtakCvDetayKeys = <String>{
  'cep_telefonu',
  kUzmanIsYeriAdresKey,
  kUzmanMezunBolumKey,
  'universite',
  'mezuniyet_yili',
  'belgeler',
  'makale_var',
  'makale_aciklama',
  'uzmanlik_ilgi',
  'kart_span',
  'odenen_puan',
};

const kTerapistSadeceDetayKeys = <String>{
  'universite',
  'mezuniyet_yili',
  'makale_var',
  'makale_aciklama',
  'uzmanlik_ilgi',
  'uzmanlik_alanlari',
  'seans_suresi',
  'ekipman',
  'kendi_ekipman',
  'ev_ziyareti',
  'engel_gruplari',
  'calistigi_gruplar',
  'derece',
};

const kBakimSadeceDetayKeys = <String>{
  kUzmanMezunBolumKey,
  'bakim_turu',
  'deneyim_aciklama',
  'egitim_sertifika',
  'yapabildikleri',
  'calisma_duzeni',
  'tercih_sigara',
  'tercih_evcil',
  'referanslar_onemli',
  'hizmet_turu',
  'musaitlik_gun',
  'calisma_sikligi',
  'kendi_malzeme',
  'calistigi_yer_turleri',
  'ek_hizmetler',
  'referanslar_ev',
};

List<String> uzmanCalismaSekliSecenekleri({required bool bakim}) =>
    bakim ? kBakimCalismaSekliSecenekleri : kCalismaSekliSecenekleri;

List<String> uzmanCvFormAdimBasliklari({required bool bakim}) => bakim
    ? const [
        'Meslek',
        'Ortak bilgiler',
        'Bakım bilgileri',
        'Fotoğraf / belge',
        'Onay ve özet',
      ]
    : const [
        'Meslek',
        'Ortak bilgiler',
        'Mesleğe özel',
        'Fotoğraf / diploma',
        'Onay ve özet',
      ];

Map<String, dynamic> uzmanDetayMeslekTemizle(
  Map<String, dynamic> detay, {
  required bool bakim,
}) {
  final out = Map<String, dynamic>.from(detay);
  final drop = bakim ? kTerapistSadeceDetayKeys : kBakimSadeceDetayKeys;
  for (final k in drop) {
    out.remove(k);
  }
  return out;
}

List<MeslekAlanSablon> uzmanBakimVarsayilanSablonlari({
  required String grupKey,
  int meslekGrubuId = 0,
}) {
  MeslekAlanSablon f(
    String key,
    String etiket,
    String tip, {
    List<String> secenekler = const [],
    int sira = 0,
  }) =>
      MeslekAlanSablon(
        id: 0,
        meslekGrubuId: meslekGrubuId,
        alanKey: key,
        etiket: etiket,
        tip: tip,
        secenekler: secenekler,
        sira: sira,
      );

  if (grupKey == 'ev_yardimi') {
    return [
      f(
        'hizmet_turu',
        'Hizmet türü',
        'multi_select',
        secenekler: const ['Ev', 'Ofis', 'Derin temizlik', 'Taşınma sonrası'],
        sira: 10,
      ),
      f('musaitlik_gun', 'Gün / saat müsaitliği', 'textarea', sira: 20),
      f(
        'calisma_sikligi',
        'Çalışma sıklığı',
        'select',
        secenekler: const ['Haftalık', 'Aylık', 'Tek seferlik'],
        sira: 30,
      ),
      f('kendi_malzeme', 'Kendi malzemesini getiriyor mu', 'boolean', sira: 40),
      f('calistigi_yer_turleri', 'Çalıştığı yer türleri', 'textarea', sira: 50),
      f(
        'ek_hizmetler',
        'Ek hizmetler',
        'multi_select',
        secenekler: const ['Ütü', 'Cam silme', 'Yemek hazırlığı'],
        sira: 60,
      ),
      f('referanslar_ev', 'Referanslar', 'textarea', sira: 70),
      f('belge', 'Belge (opsiyonel)', 'file', sira: 80),
    ];
  }
  return [
    f(
      'bakim_turu',
      'Bakım türü',
      'multi_select',
      secenekler: const ['Yaşlı', 'Çocuk', 'Engelli', 'Yatalak hasta'],
      sira: 10,
    ),
    f(
      kUzmanMezunBolumKey,
      'Mezun olunan bölüm',
      'text',
      sira: 15,
    ),
    f(
      'deneyim_aciklama',
      'Hangi bireylere baktığı ve deneyim açıklaması',
      'textarea',
      sira: 20,
    ),
    f(
      'egitim_sertifika',
      'Eğitim / sertifika',
      'multi_select',
      secenekler: const [
        'Hasta ve yaşlı hizmetleri kursu',
        'İlk yardım',
        'Bakım eğitimi',
      ],
      sira: 30,
    ),
    f(
      'yapabildikleri',
      'Yapabildikleri',
      'multi_select',
      secenekler: const [
        'Kaldırma/transfer',
        'İlaç hatırlatma',
        'Hijyen bakımı',
        'Yemek hazırlama',
        'Tekerlekli sandalye/yatak desteği',
        'Diğer',
      ],
      sira: 40,
    ),
    f(
      'calisma_duzeni',
      'Çalışma düzeni',
      'multi_select',
      secenekler: const ['Gündüz', 'Gece', 'Yatılı', 'Saatlik'],
      sira: 50,
    ),
    f(
      'tercih_sigara',
      'Sigara (tercih)',
      'select',
      secenekler: const [
        'Fark etmez',
        'Sigara içilmeyen ev',
        'Sigara içilebilir',
      ],
      sira: 60,
    ),
    f(
      'tercih_evcil',
      'Evcil hayvan (tercih)',
      'select',
      secenekler: const [
        'Fark etmez',
        'Evcil hayvan olmasın',
        'Evcil hayvan olabilir',
      ],
      sira: 70,
    ),
    f(
      'referanslar_onemli',
      'Referanslar (önceki aile/işverenler)',
      'textarea',
      sira: 80,
    ),
    f('belge', 'Belge (opsiyonel)', 'file', sira: 90),
  ];
}

List<MeslekAlanSablon> uzmanMeslekSablonlariVeyaBakimVarsayilan({
  required List<MeslekAlanSablon> sablonlar,
  required bool bakim,
  required String grupKey,
  int meslekGrubuId = 0,
}) {
  if (!bakim) return sablonlar;
  final filtered = [
    for (final e in sablonlar)
      if (!kTerapistSadeceDetayKeys.contains(e.alanKey)) e,
  ];
  if (filtered.any((e) => kBakimSadeceDetayKeys.contains(e.alanKey))) {
    return filtered;
  }
  return uzmanBakimVarsayilanSablonlari(
    grupKey: grupKey,
    meslekGrubuId: meslekGrubuId,
  );
}

const kKvkkOnayMetni =
    'Kişisel verilerimin (ad soyad, meslek, il/ilçe, deneyim, '
    'tanıtım, opsiyonel cep telefonu, opsiyonel iş yeri adresi ve yüklediğim belgeler) Engelsiz Club Uzman Profilleri Köşesi’nde '
    'görüntülenmesi ve değerlendirilmesi için KVKK kapsamında açık rıza veriyorum. '
    'TC kimlik no, ev adresi ve doğum tarihi paylaşılmayacaktır.';

const kUzmanSorumlulukReddi =
    'Uzmanlar bağımsızdır. Engelsiz Club bilgilendirme amaçlı bir topluluk '
    'platformudur; uzmanların hizmetlerinden sorumlu değildir.';

const kBakimKimlikNotu =
    'Görüşme sırasında kimlik ve referans kontrolü yapmanızı öneririz.';

List<String> validateExpertCv({
  required ExpertCvProfile draft,
  required List<MeslekAlanSablon> sablonlar,
  required Map<String, String> fileUrls,
  bool forPublish = false,
}) {
  final errs = <String>[];
  if (draft.fullName.trim().length < 2) errs.add('Ad soyad');
  if (draft.meslekGrubuId == null) errs.add('Meslek grubu');
  if (!forPublish) return errs;
  if (draft.il.trim().isEmpty) errs.add('İl');
  final tan = draft.kisaTanitim.trim();
  if (tan.length < 10) {
    errs.add('Kısa tanıtım (en az 10 karakter)');
  }
  if (forPublish && !draft.kvkkOnay) errs.add('KVKK açık rıza onayı');

  for (final s in sablonlar.where((e) => e.aktif)) {
    final v = draft.meslekDetaylari[s.alanKey];
    if (s.tip == 'file' || s.tip == 'boolean' || s.tip == 'multi_select') {
      continue;
    }
    final text = v?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    if (s.tip == 'textarea' && text.length > 2000) {
      errs.add('${s.etiket} (en fazla 2000 karakter)');
    } else if (s.tip == 'text' && text.length > 200) {
      errs.add('${s.etiket} (en fazla 200 karakter)');
    }
  }
  return errs;
}
