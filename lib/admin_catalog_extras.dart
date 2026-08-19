import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Admin'in eklediği / gizlediği katalog seçenekleri.
/// Bulut senkronu seçenekleri geri getirse bile `removed` listesi UI'da gizler.
class AdminCatalogExtras {
  AdminCatalogExtras._();
  static final AdminCatalogExtras instance = AdminCatalogExtras._();

  static const _addedKey = 'admin_catalog_extras_v1';
  static const _removedKey = 'admin_catalog_removed_v1';
  Map<String, List<String>> _byScope = {};
  Map<String, List<String>> _removedByScope = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _byScope = _decodeScopeMap(prefs.getString(_addedKey));
    _removedByScope = _decodeScopeMap(prefs.getString(_removedKey));
    _loaded = true;
  }

  Map<String, List<String>> _decodeScopeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(
          k.toString(),
          v is List
              ? [
                  for (final e in v)
                    if (e.toString().trim().isNotEmpty) e.toString().trim(),
                ]
              : <String>[],
        ),
      );
    } catch (_) {
      return {};
    }
  }

  List<String> labelsFor(String scope) {
    return List<String>.from(_byScope[scope] ?? const []);
  }

  bool isRemoved(String scope, String label) {
    final name = label.trim().toLowerCase();
    if (name.isEmpty) return false;
    final list = _removedByScope[scope] ?? const [];
    return list.any((e) => e.trim().toLowerCase() == name);
  }

  Future<void> addLabel(String scope, String label) async {
    await ensureLoaded();
    final s = scope.trim();
    final name = label.trim();
    if (s.isEmpty || name.isEmpty) return;
    await unmarkRemoved(scope, name);
    final list = List<String>.from(_byScope[s] ?? const []);
    final exists = list.any((e) => e.toLowerCase() == name.toLowerCase());
    if (!exists) list.add(name);
    _byScope[s] = list;
    await _persistAdded();
  }

  Future<void> removeLabel(String scope, String label) async {
    await ensureLoaded();
    final s = scope.trim();
    final name = label.trim().toLowerCase();
    if (s.isEmpty || name.isEmpty) return;
    final list = List<String>.from(_byScope[s] ?? const [])
      ..removeWhere((e) => e.trim().toLowerCase() == name);
    if (list.isEmpty) {
      _byScope.remove(s);
    } else {
      _byScope[s] = list;
    }
    await _persistAdded();
  }

  Future<void> markRemoved(String scope, String label) async {
    await ensureLoaded();
    final s = scope.trim();
    final name = label.trim();
    if (s.isEmpty || name.isEmpty) return;
    final list = List<String>.from(_removedByScope[s] ?? const []);
    final exists = list.any((e) => e.toLowerCase() == name.toLowerCase());
    if (!exists) list.add(name);
    _removedByScope[s] = list;
    await removeLabel(s, name);
    await _persistRemoved();
  }

  Future<void> unmarkRemoved(String scope, String label) async {
    await ensureLoaded();
    final s = scope.trim();
    final name = label.trim().toLowerCase();
    if (s.isEmpty || name.isEmpty) return;
    final list = List<String>.from(_removedByScope[s] ?? const [])
      ..removeWhere((e) => e.trim().toLowerCase() == name);
    if (list.isEmpty) {
      _removedByScope.remove(s);
    } else {
      _removedByScope[s] = list;
    }
    await _persistRemoved();
  }

  Future<void> _persistAdded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addedKey, jsonEncode(_byScope));
  }

  Future<void> _persistRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_removedKey, jsonEncode(_removedByScope));
  }
}
