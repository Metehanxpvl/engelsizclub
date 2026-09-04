import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/async_timeout.dart';

/// Kısa tut: ilk kareyi bekletme; menü açılana kadar çoğu zaman hazır olur.
const kScreenConfigTimeout = Duration(milliseconds: 2500);

const _prefsKey = 'app_screen_config_v1';

/// `app_screen_config` satırı — native derleme veya sitedeki canlı sayfa.
class AppScreenRow {
  const AppScreenRow({
    required this.id,
    required this.title,
    required this.openMode,
    required this.url,
    required this.enabled,
    required this.sort,
  });

  final String id;
  final String title;
  /// `native` | `web`
  final String openMode;
  final String url;
  final bool enabled;
  final int sort;

  bool get isWeb => openMode == 'web';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'open_mode': openMode,
        'url': url,
        'enabled': enabled,
        'sort': sort,
      };

  factory AppScreenRow.fromJson(Map<String, dynamic> json) {
    final mode = (json['open_mode']?.toString() ?? 'native')
        .trim()
        .toLowerCase();
    return AppScreenRow(
      id: (json['id']?.toString() ?? '').trim(),
      title: json['title']?.toString() ?? '',
      openMode: mode == 'web' ? 'web' : 'native',
      url: (json['url']?.toString() ?? '').trim(),
      enabled: json['enabled'] != false,
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ağ / tablo yoksa: her şey native (güvenli yedek). URL’ler yine dolu.
const kDefaultScreenRows = <AppScreenRow>[
  AppScreenRow(
    id: 'boyama',
    title: 'Boyama',
    openMode: 'native',
    url: 'https://www.engelsizclub.com/boyama',
    enabled: true,
    sort: 10,
  ),
  AppScreenRow(
    id: 'puzzle',
    title: 'Fotoğraflı Puzzle',
    openMode: 'native',
    url: 'https://www.engelsizclub.com/fotografli-puzzle.html',
    enabled: true,
    sort: 20,
  ),
  AppScreenRow(
    id: 'bilgi_kutuphanesi',
    title: 'Bilgi Kütüphanesi',
    openMode: 'native',
    url: 'https://www.engelsizclub.com',
    enabled: true,
    sort: 30,
  ),
  AppScreenRow(
    id: 'ilanlar',
    title: 'İlanlar',
    openMode: 'native',
    url: 'https://www.engelsizclub.com',
    enabled: true,
    sort: 40,
  ),
  AppScreenRow(
    id: 'etkinlikler',
    title: 'Etkinlikler',
    openMode: 'native',
    url: 'https://www.engelsizclub.com',
    enabled: true,
    sort: 50,
  ),
  AppScreenRow(
    id: 'forum',
    title: 'Forum',
    openMode: 'native',
    url: 'https://www.engelsizclub.com',
    enabled: true,
    sort: 60,
  ),
];

/// Açılışta + uygulamaya dönüşte çekilir. İlk kareyi bekletmez.
class AppScreenConfigStore {
  AppScreenConfigStore._();
  static final AppScreenConfigStore instance = AppScreenConfigStore._();

  Map<String, AppScreenRow> _rows = {
    for (final r in kDefaultScreenRows) r.id: r,
  };
  bool _loading = false;

  AppScreenRow? row(String id) => _rows[id];

  /// Telefonda `web` + dolu https URL. Flutter web zaten canlı site — iç içe açma.
  bool opensInWeb(String id) {
    if (kIsWeb) return false;
    final r = _rows[id];
    if (r == null || !r.enabled || !r.isWeb) return false;
    return _usableUrl(r.url) != null;
  }

  /// WebView’e verilecek adres; native / boş / geçersizse null.
  String? webUrl(String id) {
    if (!opensInWeb(id)) return null;
    return _usableUrl(_rows[id]!.url);
  }

  /// Puzzle gibi her zaman siteden açılanlar: uzak URL, yoksa yedek.
  String urlOrFallback(String id, String fallback) {
    final raw = _rows[id]?.url.trim() ?? '';
    return _usableUrl(raw) ?? fallback;
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      await _hydrateCache();
      await _fetchRemote();
    } catch (e) {
      debugPrint('AppScreenConfigStore: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _hydrateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final parsed = <String, AppScreenRow>{
        for (final r in kDefaultScreenRows) r.id: r,
      };
      for (final item in decoded) {
        if (item is! Map) continue;
        final row = AppScreenRow.fromJson(Map<String, dynamic>.from(item));
        if (row.id.isEmpty) continue;
        parsed[row.id] = row;
      }
      _rows = parsed;
    } catch (_) {}
  }

  Future<void> _fetchRemote() async {
    try {
      final rows = await withNetworkTimeout(
        Supabase.instance.client
            .from('app_screen_config')
            .select('id, title, open_mode, url, enabled, sort')
            .eq('enabled', true)
            .order('sort')
            .order('id'),
        timeout: kScreenConfigTimeout,
      );
      if (rows is! List || rows.isEmpty) return;
      final parsed = <String, AppScreenRow>{
        for (final r in kDefaultScreenRows) r.id: r,
      };
      for (final item in rows) {
        if (item is! Map) continue;
        final row = AppScreenRow.fromJson(Map<String, dynamic>.from(item));
        if (row.id.isEmpty) continue;
        parsed[row.id] = row;
      }
      _rows = parsed;
      await _cacheLocal();
    } catch (e) {
      debugPrint('AppScreenConfigStore fetch: $e');
    }
  }

  Future<void> _cacheLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_rows.values.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }
}

String? _usableUrl(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('/')) return t;
  final u = Uri.tryParse(t);
  if (u == null ||
      !(u.hasScheme && (u.scheme == 'http' || u.scheme == 'https'))) {
    return null;
  }
  return t;
}
