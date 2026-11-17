import 'package:supabase_flutter/supabase_flutter.dart';

import 'kredi_store.dart';
import 'services/catalog_adapters.dart';
import 'utils/async_timeout.dart';

class UzmanKosesProfil {
  const UzmanKosesProfil({
    this.id = 0,
    this.ownerId = '',
    this.ownerEmail = '',
    this.fullName = '',
    this.meslek = '',
    this.il = '',
    this.ilce = '',
    this.countryCode = 'TR',
    this.deneyimYili,
    this.dogrulandi = false,
    this.ustGrup = '',
    this.photoUrl = '',
    this.kartSpan = 1,
  });

  final int id;
  final String ownerId;
  final String ownerEmail;
  final String fullName;
  final String meslek;
  final String il;
  final String ilce;
  final String countryCode;
  final int? deneyimYili;
  final bool dogrulandi;
  final String ustGrup;
  final String photoUrl;
  final int kartSpan;

  bool get tamSatir => kartSpan >= 2;

  /// Kart altında: İl / İlçe
  String get yerLabel {
    final parts = <String>[
      if (il.trim().isNotEmpty) il.trim(),
      if (ilce.trim().isNotEmpty) ilce.trim(),
    ];
    return parts.join(' / ');
  }

  factory UzmanKosesProfil.fromJson(Map<String, dynamic> json) =>
      UzmanKosesProfil(
        id: (json['id'] as num?)?.toInt() ?? 0,
        ownerId: json['owner_id']?.toString() ?? '',
        ownerEmail: (json['owner_email']?.toString() ?? '').trim().toLowerCase(),
        fullName: json['full_name']?.toString().trim() ?? '',
        meslek: json['meslek']?.toString().trim() ?? '',
        il: json['il']?.toString().trim() ?? '',
        ilce: json['ilce']?.toString().trim() ?? '',
        countryCode:
            (json['country_code']?.toString() ?? 'TR').trim().toUpperCase(),
        deneyimYili: (json['deneyim_yili'] as num?)?.toInt(),
        dogrulandi: json['dogrulandi'] == true,
        ustGrup: json['ust_grup']?.toString() ?? '',
        photoUrl: json['photo_url']?.toString() ?? '',
        kartSpan: (json['kart_span'] as num?)?.toInt() == 2 ? 2 : 1,
      );
}

const kUzmanKosesBakiciMeslekleri = <String>[
  'Bakıcı',
  'Ev Yardımı',
  'Temizlik Görevlisi',
];

/// İlanlar > Uzman Ara meslekleri + bakıcı/ev desteği.
List<String> uzmanKosesMeslekSecenekleri({String extra = ''}) {
  final seen = <String>{};
  final out = <String>[];
  void add(String raw) {
    final t = raw.trim();
    if (t.isEmpty || !seen.add(t.toLowerCase())) return;
    out.add(t);
  }

  for (final u in CatalogAdapters.uzmanlikSecenekleri()) {
    add(u);
  }
  for (final b in kUzmanKosesBakiciMeslekleri) {
    add(b);
  }
  add(extra);
  return out;
}

/// Filtre: katalogdaki tüm meslekler + ilandaki ekstra etiketler.
List<String> uzmanKosesFiltreMeslekleri({
  Iterable<String> extra = const [],
  Iterable<String> grupEtiketleri = const [],
}) {
  final seen = <String>{};
  final out = <String>[];
  void add(String raw) {
    final t = raw.trim();
    if (t.isEmpty || !seen.add(uzmanKosesNormYer(t))) return;
    out.add(t);
  }

  for (final m in uzmanKosesMeslekSecenekleri()) {
    add(m);
  }
  for (final g in grupEtiketleri) {
    add(g);
  }
  for (final e in extra) {
    add(e);
  }
  out.sort((a, b) => uzmanKosesNormYer(a).compareTo(uzmanKosesNormYer(b)));
  return out;
}

bool canCreateUzmanKosesProfil({
  required bool isGuest,
  String? userEmail,
  String? userType,
}) {
  if (isGuest) return false;
  return isProfUserType(userType);
}

String uzmanKosesNormYer(String s) => s
    .toLowerCase()
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool uzmanKosesMatchesYer(
  UzmanKosesProfil p, {
  String il = '',
  String ilce = '',
}) {
  if (il.trim().isEmpty) return true;
  if (uzmanKosesNormYer(p.il) != uzmanKosesNormYer(il)) return false;
  if (ilce.trim().isEmpty) return true;
  return uzmanKosesNormYer(p.ilce) == uzmanKosesNormYer(ilce);
}

bool uzmanKosesMetinIcerir(String haystack, String needle) {
  final n = uzmanKosesNormYer(needle);
  if (n.isEmpty) return true;
  return uzmanKosesNormYer(haystack).contains(n);
}

bool uzmanKosesMatchesMeslek(UzmanKosesProfil p, String meslek) {
  if (meslek.trim().isEmpty) return true;
  return uzmanKosesNormYer(p.meslek) == uzmanKosesNormYer(meslek);
}

bool uzmanKosesMatchesQuery(UzmanKosesProfil p, String query) {
  final tokens = uzmanKosesNormYer(query)
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return true;
  final hay = uzmanKosesNormYer(
    [p.meslek, p.il, p.ilce, p.ustGrup].join(' '),
  );
  return tokens.every(hay.contains);
}

List<String> uzmanKosesListedMeslekler(
  Iterable<UzmanKosesProfil> profiles, {
  String ustGrup = '',
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final p in profiles) {
    if (ustGrup.isNotEmpty && p.ustGrup != ustGrup) continue;
    final t = p.meslek.trim();
    if (t.isEmpty || !seen.add(uzmanKosesNormYer(t))) continue;
    out.add(t);
  }
  out.sort((a, b) => uzmanKosesNormYer(a).compareTo(uzmanKosesNormYer(b)));
  return out;
}

List<UzmanKosesProfil> uzmanKosesFiltrele(
  Iterable<UzmanKosesProfil> profiles, {
  String ustGrup = '',
  String meslek = '',
  String il = '',
  String ilce = '',
  String query = '',
  bool onlyVerified = false,
}) {
  final list = [
    for (final p in profiles)
      if ((ustGrup.isEmpty || p.ustGrup == ustGrup) &&
          uzmanKosesMatchesMeslek(p, meslek) &&
          uzmanKosesMatchesYer(p, il: il, ilce: ilce) &&
          uzmanKosesMatchesQuery(p, query) &&
          (!onlyVerified || p.dogrulandi))
        p,
  ];
  list.sort((a, b) => (b.tamSatir ? 1 : 0).compareTo(a.tamSatir ? 1 : 0));
  return list;
}

List<UzmanKosesProfil>? _cache;
DateTime? _cacheAt;
bool _tableUnavailable = false;
const _ttl = Duration(minutes: 5);

bool _supabaseReady() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

void invalidateUzmanKosesProfilesCache() {
  _cache = null;
  _cacheAt = null;
}

bool get hasFreshUzmanKosesProfilesCache {
  final at = _cacheAt;
  final list = _cache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<UzmanKosesProfil>? get cachedUzmanKosesProfiles => _cache;

Future<List<UzmanKosesProfil>> loadUzmanKosesProfiles({
  bool forceRefresh = false,
}) async {
  if (!forceRefresh && hasFreshUzmanKosesProfilesCache) {
    return List<UzmanKosesProfil>.from(_cache!);
  }
  if (_tableUnavailable || !_supabaseReady()) {
    return List<UzmanKosesProfil>.from(_cache ?? const []);
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('uzman_kosesi_profiles')
          .select()
          .order('created_at', ascending: false),
    );
    final raw = rows is List ? rows : const [];
    final list = [
      for (final e in raw.whereType<Map>())
        UzmanKosesProfil.fromJson(Map<String, dynamic>.from(e)),
    ];
    _cache = List<UzmanKosesProfil>.unmodifiable(list);
    _cacheAt = DateTime.now();
    return List<UzmanKosesProfil>.from(list);
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('pgrst') ||
        msg.contains('schema cache') ||
        msg.contains('does not exist') ||
        (msg.contains('relation') && msg.contains('uzman_kosesi'))) {
      _tableUnavailable = true;
    }
    return List<UzmanKosesProfil>.from(_cache ?? const []);
  }
}

UzmanKosesProfil? myUzmanKosesProfil(
  List<UzmanKosesProfil> all, {
  required String email,
}) {
  final e = email.trim().toLowerCase();
  if (e.isEmpty) return null;
  for (final p in all) {
    if (p.ownerEmail == e) return p;
  }
  return null;
}

Future<UzmanKosesProfil> upsertUzmanKosesProfil({
  required String fullName,
  required String meslek,
  required String il,
  required String ilce,
  String countryCode = 'TR',
}) async {
  if (!_supabaseReady()) {
    throw StateError('Bağlantı yok. Lütfen tekrar deneyin.');
  }
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Profil oluşturmak için giriş yapın.');
  }
  final email = (user.email ?? '').trim().toLowerCase();
  if (email.isEmpty) {
    throw StateError('E-posta bulunamadı. Tekrar giriş yapın.');
  }
  final type = currentAuthUserType();
  if (!canCreateUzmanKosesProfil(
    isGuest: false,
    userEmail: email,
    userType: type,
  )) {
    throw StateError(
      'Uzman Profilleri Köşesi profili yalnızca Destek Veren rolünde oluşturulabilir. '
      'Menü → Hesap rolü bölümünden Destek Veren’e geçin.',
    );
  }
  final name = fullName.trim();
  final job = meslek.trim();
  if (name.isEmpty) throw StateError('Ad soyad gerekli.');
  if (job.isEmpty) throw StateError('Meslek seçin.');
  if (il.trim().isEmpty) throw StateError('İl seçin.');

  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from('uzman_kosesi_profiles').upsert(
        {
          'owner_id': user.id,
          'owner_email': email,
          'full_name': name,
          'meslek': job,
          'il': il.trim(),
          'ilce': ilce.trim(),
          'country_code': countryCode.trim().isEmpty ? 'TR' : countryCode.trim(),
        },
        onConflict: 'owner_id',
      ).select(),
    );
    final raw = rows is List ? rows : const [];
    UzmanKosesProfil? saved;
    for (final e in raw.whereType<Map>()) {
      saved = UzmanKosesProfil.fromJson(Map<String, dynamic>.from(e));
      break;
    }
    if (saved == null) {
      throw StateError('Profil kaydedilemedi.');
    }
    invalidateUzmanKosesProfilesCache();
    return saved;
  } catch (e) {
    if (e is StateError) rethrow;
    final msg = e.toString().toLowerCase();
    if (msg.contains('row-level security') || msg.contains('42501')) {
      throw StateError(
        'Profil kaydedilemedi: Destek Veren rolünde olmalısınız.',
      );
    }
    if (msg.contains('does not exist') || msg.contains('schema cache')) {
      throw StateError(
        'Uzman Köşesi tablosu henüz kurulmadı. supabase/uzman_kosesi_profiles.sql dosyasını çalıştırın.',
      );
    }
    throw StateError('Profil kaydedilemedi. Lütfen tekrar deneyin.');
  }
}
