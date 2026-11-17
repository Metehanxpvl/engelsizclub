import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../utils/async_timeout.dart';
import 'kurum_is_ilan_models.dart';

const _table = 'expert_kurum_is_ilanlari';

List<KurumIsIlani>? _cache;
DateTime? _cacheAt;
bool _tableUnavailable = false;
const _ttl = Duration(minutes: 5);

bool _ready() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

void invalidateKurumIsIlanlariCache() {
  _cache = null;
  _cacheAt = null;
}

bool get hasFreshKurumIsIlanlariCache {
  final at = _cacheAt;
  final list = _cache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<KurumIsIlani>? get cachedKurumIsIlanlari => _cache;

List<KurumIsIlani> _parse(dynamic rows) {
  final raw = rows is List ? rows : const [];
  return [
    for (final e in raw.whereType<Map>())
      KurumIsIlani.fromJson(Map<String, dynamic>.from(e)),
  ];
}

bool _missingTable(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('pgrst') ||
      msg.contains('schema cache') ||
      msg.contains('does not exist') ||
      (msg.contains('relation') && msg.contains('kurum'));
}

Future<List<KurumIsIlani>> loadKurumIsIlanlari({
  bool forceRefresh = false,
}) async {
  if (!forceRefresh && hasFreshKurumIsIlanlariCache) {
    return List<KurumIsIlani>.from(_cache!);
  }
  if (_tableUnavailable || !_ready()) {
    return List<KurumIsIlani>.from(_cache ?? const []);
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from(_table)
          .select()
          .eq('status', 'published')
          .order('created_at', ascending: false),
    );
    final list = _parse(rows);
    _cache = List<KurumIsIlani>.unmodifiable(list);
    _cacheAt = DateTime.now();
    return List<KurumIsIlani>.from(list);
  } catch (e) {
    if (_missingTable(e)) _tableUnavailable = true;
    return List<KurumIsIlani>.from(_cache ?? const []);
  }
}

Future<KurumIsIlani?> loadKurumIsIlani(int id) async {
  if (id <= 0 || !_ready()) return null;
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from(_table).select().eq('id', id).limit(1),
    );
    final list = _parse(rows);
    return list.isEmpty ? null : list.first;
  } catch (e) {
    if (_missingTable(e)) _tableUnavailable = true;
    return null;
  }
}

Future<KurumIsIlani> saveKurumIsIlani({
  int? id,
  required String kurumAdi,
  required String arananMeslek,
  required String il,
  required String ilce,
  required String aciklama,
  String adres = '',
  String photoUrl = '',
  List<String> calismaSekli = const [],
  String telefon = '',
  required bool kvkk,
}) async {
  if (!_ready()) {
    throw StateError('Bağlantı yok. Lütfen tekrar deneyin.');
  }
  final err = validateKurumIsIlani(
    kurumAdi: kurumAdi,
    arananMeslek: arananMeslek,
    il: il,
    aciklama: aciklama,
    kvkk: kvkk,
    adres: adres,
  );
  if (err != null) throw StateError(err);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('İlan yayınlamak için giriş yapın.');
  }
  final email = (user.email ?? '').trim().toLowerCase();
  if (email.isEmpty) {
    throw StateError('E-posta bulunamadı. Tekrar giriş yapın.');
  }
  final payload = <String, dynamic>{
    if (id != null && id > 0) 'id': id,
    'owner_id': user.id,
    'owner_email': email,
    'kurum_adi': kurumAdi.trim(),
    'aranan_meslek': arananMeslek.trim(),
    'il': il.trim(),
    'ilce': ilce.trim(),
    'adres': adres.trim(),
    'photo_url': photoUrl.trim(),
    'aciklama': aciklama.trim(),
    'calisma_sekli': calismaSekli,
    'telefon': telefon.trim(),
    'status': 'published',
  };
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from(_table).upsert(payload).select(),
    );
    final list = _parse(rows);
    if (list.isEmpty) throw StateError('İlan kaydedilemedi.');
    invalidateKurumIsIlanlariCache();
    return list.first;
  } catch (e) {
    if (e is StateError) rethrow;
    if (_missingTable(e)) {
      _tableUnavailable = true;
      throw StateError(
        'Kurum iş ilanı tablosu henüz kurulmadı. '
        'supabase/expert_kurum_is_ilanlari.sql ve '
        'supabase/expert_kurum_is_ilanlari_photo.sql dosyalarını çalıştırın.',
      );
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('photo_url') || msg.contains('adres')) {
      throw StateError(
        'Kurum görseli / adres kolonları henüz yok. '
        'supabase/expert_kurum_is_ilanlari_photo.sql dosyasını çalıştırın.',
      );
    }
    if (msg.contains('row-level security') || msg.contains('42501')) {
      throw StateError('İlan kaydetme yetkisi yok.');
    }
    throw StateError('İlan kaydedilemedi. Lütfen tekrar deneyin.');
  }
}

Future<void> deleteKurumIsIlani(int id) async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  if (id <= 0) throw StateError('İlan silinemedi.');
  final user = Supabase.instance.client.auth.currentUser;
  final email = (user?.email ?? '').trim().toLowerCase();
  if (user == null || email.isEmpty) {
    throw StateError('İlan silmek için giriş yapın.');
  }
  try {
    if (isAppAdmin(email)) {
      await withNetworkTimeout(
        Supabase.instance.client.from(_table).delete().eq('id', id),
      );
    } else {
      await withNetworkTimeout(
        Supabase.instance.client
            .from(_table)
            .delete()
            .eq('id', id)
            .eq('owner_id', user.id),
      );
    }
    invalidateKurumIsIlanlariCache();
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError('İlan silinemedi.');
  }
}
