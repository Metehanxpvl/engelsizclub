import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dinamik katalog paket adları (Supabase app_catalog_versions.name).
abstract final class CatalogPack {
  static const settings = 'settings';
  static const categories = 'categories';
  static const content = 'content';
  static const rights = 'rights';
  static const centers = 'centers';
  static const diseases = 'diseases';

  static const all = <String>[
    settings,
    categories,
    content,
    rights,
    centers,
    diseases,
  ];
}

/// Supabase'den dinamik veri çeker; yerelde TTL + sürüm cache tutar.
///
/// Kota dostu akış:
/// 1) Diskten anında yükle (offline / hızlı açılış)
/// 2) `app_catalog_versions` ile ucuz sürüm kontrolü
/// 3) Sadece değişen / süresi dolmuş paketleri indir
class AppCatalogService extends ChangeNotifier {
  AppCatalogService._();
  static final AppCatalogService instance = AppCatalogService._();

  static const _prefsPrefix = 'catalog_v1_';
  static const _defaultTtl = Duration(hours: 6);

  final Map<String, List<Map<String, dynamic>>> _lists = {};
  final Map<String, Map<String, dynamic>> _settings = {};
  final Map<String, int> _localVersions = {};
  final Map<String, DateTime> _fetchedAt = {};

  bool _booted = false;
  bool _syncing = false;
  String? _lastError;

  bool get isReady => _booted;
  bool get isSyncing => _syncing;
  String? get lastError => _lastError;

  /// Ayar (JSON). Yoksa [fallback].
  dynamic setting(String key, [dynamic fallback]) {
    final row = _settings[key];
    if (row == null) return fallback;
    return row['value'] ?? fallback;
  }

  int settingInt(String key, int fallback) {
    final v = setting(key, fallback);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  List<Map<String, dynamic>> list(String pack) =>
      List<Map<String, dynamic>>.from(_lists[pack] ?? const []);

  List<Map<String, dynamic>> categoriesOf(String scope) {
    return list(CatalogPack.categories)
        .where((e) => (e['scope']?.toString() ?? '') == scope)
        .toList()
      ..sort((a, b) =>
          ((a['sort_order'] as num?)?.toInt() ?? 0)
              .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
  }

  /// Uygulama açılışında bir kez çağır.
  Future<void> bootstrap({bool forceRefresh = false}) async {
    await _loadAllFromDisk();
    _booted = true;
    notifyListeners();
    // Arka planda senkronize et (UI'yi bekletme)
    // ignore: unawaited_futures
    sync(force: forceRefresh);
  }

  /// Akıllı senkron. [force]=true ise TTL/sürüm yok sayılır.
  Future<void> sync({bool force = false}) async {
    if (_syncing) return;
    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final ttlHours = settingInt('catalog_ttl_hours', 6);
      final ttl = Duration(hours: ttlHours.clamp(1, 168));

      // 1) Ucuz sürüm tablosu
      Map<String, int> remoteVersions = {};
      try {
        final rows = await client.from('app_catalog_versions').select();
        for (final raw in (rows as List)) {
          if (raw is! Map) continue;
          final name = raw['name']?.toString() ?? '';
          final ver = (raw['version'] as num?)?.toInt() ?? 0;
          if (name.isNotEmpty) remoteVersions[name] = ver;
        }
      } catch (e) {
        // Tablo yoksa / offline: sadece TTL'ye bak, hata yut.
        debugPrint('catalog versions: $e');
        remoteVersions = {};
      }

      for (final pack in CatalogPack.all) {
        final localVer = _localVersions[pack] ?? 0;
        final remoteVer = remoteVersions[pack] ?? 0;
        final fetched = _fetchedAt[pack];
        final stale = fetched == null ||
            DateTime.now().difference(fetched) > (force ? Duration.zero : ttl);
        final versionBump = remoteVer > localVer;

        if (!force && !stale && !versionBump && _hasData(pack)) {
          continue; // kota dostu: indirme
        }

        final ok = await _fetchPack(client, pack);
        if (ok) {
          _localVersions[pack] = remoteVer > 0 ? remoteVer : localVer + 1;
          _fetchedAt[pack] = DateTime.now();
          await _persistPack(pack);
        }
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('AppCatalogService.sync: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  bool _hasData(String pack) {
    if (pack == CatalogPack.settings) return _settings.isNotEmpty;
    return (_lists[pack] ?? const []).isNotEmpty;
  }

  Future<bool> _fetchPack(SupabaseClient client, String pack) async {
    try {
      switch (pack) {
        case CatalogPack.settings:
          final rows = await client.from('app_settings').select();
          final entries = <MapEntry<String, Map<String, dynamic>>>[];
          for (final raw in (rows as List).whereType<Map>()) {
            final key = raw['key']?.toString() ?? '';
            if (key.isEmpty) continue;
            entries.add(MapEntry(key, Map<String, dynamic>.from(raw)));
          }
          _settings
            ..clear()
            ..addEntries(entries);
          return true;

        case CatalogPack.categories:
          final rows = await client
              .from('app_categories')
              .select()
              .eq('active', true)
              .order('sort_order');
          _lists[pack] = _asMaps(rows);
          return true;

        case CatalogPack.content:
          final rows = await client
              .from('app_content')
              .select()
              .eq('active', true)
              .order('sort_order');
          _lists[pack] = _asMaps(rows);
          return true;

        case CatalogPack.rights:
          final rows = await client
              .from('app_rights')
              .select()
              .eq('active', true)
              .order('sort_order');
          _lists[pack] = _asMaps(rows);
          return true;

        case CatalogPack.centers:
          final rows = await client
              .from('app_centers')
              .select()
              .eq('active', true)
              .limit(2000);
          _lists[pack] = _asMaps(rows);
          return true;

        case CatalogPack.diseases:
          final rows = await client
              .from('app_diseases')
              .select()
              .eq('active', true)
              .order('sort_order');
          _lists[pack] = _asMaps(rows);
          return true;
      }
    } catch (e) {
      debugPrint('fetch $pack: $e');
    }
    return false;
  }

  List<Map<String, dynamic>> _asMaps(dynamic rows) {
    return (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _loadAllFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pack in CatalogPack.all) {
      final raw = prefs.getString('$_prefsPrefix$pack');
      final ver = prefs.getInt('${_prefsPrefix}ver_$pack') ?? 0;
      final ts = prefs.getInt('${_prefsPrefix}ts_$pack');
      _localVersions[pack] = ver;
      if (ts != null) {
        _fetchedAt[pack] =
            DateTime.fromMillisecondsSinceEpoch(ts, isUtc: false);
      }
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (pack == CatalogPack.settings && decoded is Map) {
          _settings
            ..clear()
            ..addAll(decoded.map(
              (k, v) => MapEntry(
                k.toString(),
                v is Map
                    ? Map<String, dynamic>.from(v)
                    : <String, dynamic>{'key': k, 'value': v},
              ),
            ));
        } else if (decoded is List) {
          _lists[pack] = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }
  }

  Future<void> _persistPack(String pack) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = pack == CatalogPack.settings
        ? jsonEncode(_settings)
        : jsonEncode(_lists[pack] ?? const []);
    await prefs.setString('$_prefsPrefix$pack', payload);
    await prefs.setInt(
        '${_prefsPrefix}ver_$pack', _localVersions[pack] ?? 0);
    await prefs.setInt(
      '${_prefsPrefix}ts_$pack',
      (_fetchedAt[pack] ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Yerel hastalık sırasını günceller (oturum + disk cache).
  Future<void> applyLocalDiseaseOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final current = List<Map<String, dynamic>>.from(
      _lists[CatalogPack.diseases] ?? const [],
    );
    if (current.isEmpty) return;

    final byId = <String, Map<String, dynamic>>{
      for (final r in current)
        if ((r['id']?.toString() ?? '').isNotEmpty) r['id'].toString(): r,
    };
    final reordered = <Map<String, dynamic>>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final row = byId.remove(id);
      if (row == null) continue;
      reordered.add({...row, 'sort_order': i});
    }
    for (final leftover in byId.values) {
      reordered.add({...leftover, 'sort_order': reordered.length});
    }
    _lists[CatalogPack.diseases] = reordered;
    _fetchedAt[CatalogPack.diseases] = DateTime.now();
    await _persistPack(CatalogPack.diseases);
    notifyListeners();
  }

  /// Hastalık kartlarının sırasını günceller (`app_diseases.sort_order`).
  /// Yerel cache'i hemen günceller, ardından Supabase'e yazar (RLS: admin).
  Future<void> persistDiseaseOrder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await applyLocalDiseaseOrder(orderedIds);

    final client = Supabase.instance.client;
    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < orderedIds.length; i++) {
      await client.from('app_diseases').update({
        'sort_order': i,
        'updated_at': now,
      }).eq('id', orderedIds[i]);
    }
  }

  /// Cache'i temizle (debug / zorla yenile).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pack in CatalogPack.all) {
      await prefs.remove('$_prefsPrefix$pack');
      await prefs.remove('${_prefsPrefix}ver_$pack');
      await prefs.remove('${_prefsPrefix}ts_$pack');
    }
    _lists.clear();
    _settings.clear();
    _localVersions.clear();
    _fetchedAt.clear();
    notifyListeners();
  }

  Duration get ttl {
    final h = settingInt('catalog_ttl_hours', _defaultTtl.inHours);
    return Duration(hours: h.clamp(1, 168));
  }
}
