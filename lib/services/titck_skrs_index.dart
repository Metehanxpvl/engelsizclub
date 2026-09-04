import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/gs1_barcode.dart';

/// Public TİTCK / SGK barkod snapshot (barkod → ad + etken madde / ATC).
/// Kaynak: dinamikmodul/43 (aktif+pasif), dinamikmodul/85 ruhsat, SGK EK-4/A
/// yedekleri. ITS / Oyak API yok.
class TitckSkrsHit {
  const TitckSkrsHit({
    required this.barcode,
    required this.name,
    this.activeIngredient = '',
  });

  final String barcode;
  final String name;
  final String activeIngredient;
}

/// Parsed GTIN file for [compute] (primitives only).
Map<String, dynamic> _parseTitckGtinJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return const {'rows': <List<String>>[], 'keyToRow': <String, int>{}};
  }
  final by = decoded['by'];
  if (by is! Map) {
    return const {'rows': <List<String>>[], 'keyToRow': <String, int>{}};
  }
  final rows = <List<String>>[];
  final keyToRow = <String, int>{};
  by.forEach((dynamic key, dynamic value) {
    final barcode = key.toString().trim();
    if (barcode.length < 8) return;
    String name = '';
    String atc = '';
    if (value is List && value.isNotEmpty) {
      name = value[0].toString().trim();
      if (value.length > 1) atc = value[1].toString().trim();
    } else if (value is String) {
      name = value.trim();
    }
    if (name.isEmpty) return;
    final idx = rows.length;
    rows.add(<String>[barcode, name, atc]);
    for (final k in Gs1Barcode.cacheKeys(barcode)) {
      keyToRow.putIfAbsent(k, () => idx);
    }
  });
  return {'rows': rows, 'keyToRow': keyToRow};
}

/// Yerel açık indeks (on binlerce GTIN). İlk ilaç taramasında bir kez yüklenir.
class TitckSkrsIndex {
  TitckSkrsIndex._();

  static const assetPath = 'assets/medicines/titck_skrs_gtin.json';

  static Map<String, TitckSkrsHit>? _byBarcode;
  static List<TitckSkrsHit>? _all;
  static Future<void>? _loading;
  static String? lastMatchForm;

  /// Test: tam JSON yüklemeden indeks ver.
  @visibleForTesting
  static void debugSetHits(Iterable<TitckSkrsHit> hits) {
    final map = <String, TitckSkrsHit>{};
    final list = <TitckSkrsHit>[];
    for (final hit in hits) {
      list.add(hit);
      for (final key in Gs1Barcode.cacheKeys(hit.barcode)) {
        map[key] = hit;
      }
    }
    _byBarcode = map;
    _all = list;
    _loading = Future<void>.value();
    lastMatchForm = null;
  }

  @visibleForTesting
  static void debugReset() {
    _byBarcode = null;
    _all = null;
    _loading = null;
    lastMatchForm = null;
  }

  static Future<void> ensureLoaded() {
    if (_byBarcode != null) return Future<void>.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      // Let the scanner paint before a ~2MB jsonDecode on web.
      await Future<void>.delayed(Duration.zero);
      if (!kIsWeb) {
        _applyParsed(await compute(_parseTitckGtinJson, raw));
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _byBarcode = {};
        _all = const [];
        return;
      }
      final by = decoded['by'];
      if (by is! Map) {
        _byBarcode = {};
        _all = const [];
        return;
      }
      await _ingestByMap(by);
    } catch (e, st) {
      debugPrint('TİTCK SKRS indeks yüklenemedi: $e\n$st');
      _byBarcode = {};
      _all = const [];
    }
  }

  static void _applyParsed(Map<String, dynamic> parsed) {
    final rowsRaw = parsed['rows'];
    final keysRaw = parsed['keyToRow'];
    if (rowsRaw is! List || keysRaw is! Map) {
      _byBarcode = {};
      _all = const [];
      return;
    }
    final list = <TitckSkrsHit>[];
    for (final row in rowsRaw) {
      if (row is! List || row.isEmpty) continue;
      final barcode = row[0].toString();
      final name = row.length > 1 ? row[1].toString() : '';
      final atc = row.length > 2 ? row[2].toString() : '';
      list.add(
        TitckSkrsHit(
          barcode: barcode,
          name: name,
          activeIngredient: atc,
        ),
      );
    }
    final map = <String, TitckSkrsHit>{};
    keysRaw.forEach((dynamic key, dynamic value) {
      final idx = value is int ? value : int.tryParse(value.toString());
      if (idx == null || idx < 0 || idx >= list.length) return;
      map[key.toString()] = list[idx];
    });
    _byBarcode = map;
    _all = list;
    debugPrint(
      'TİTCK GTIN indeks: ${list.length} ürün, ${map.length} barkod anahtarı',
    );
  }

  static Future<void> _ingestByMap(Map<dynamic, dynamic> by) async {
    final map = <String, TitckSkrsHit>{};
    final list = <TitckSkrsHit>[];
    final keys = by.keys.toList(growable: false);
    for (var i = 0; i < keys.length; i++) {
      final barcode = keys[i].toString().trim();
      if (barcode.length < 8) continue;
      final value = by[keys[i]];
      String name = '';
      String atc = '';
      if (value is List && value.isNotEmpty) {
        name = value[0].toString().trim();
        if (value.length > 1) atc = value[1].toString().trim();
      } else if (value is String) {
        name = value.trim();
      }
      if (name.isEmpty) continue;
      final hit = TitckSkrsHit(
        barcode: barcode,
        name: name,
        activeIngredient: atc,
      );
      list.add(hit);
      for (final k in Gs1Barcode.cacheKeys(barcode)) {
        map.putIfAbsent(k, () => hit);
      }
      if (i > 0 && i % 2500 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    _byBarcode = map;
    _all = list;
    debugPrint(
      'TİTCK GTIN indeks: ${list.length} ürün, ${map.length} barkod anahtarı',
    );
  }

  /// O(1) map lookup after [ensureLoaded]. Never re-parses the JSON asset.
  static Future<TitckSkrsHit?> findByBarcode(String barcode) async {
    await ensureLoaded();
    final map = _byBarcode;
    if (map == null || map.isEmpty) return null;
    lastMatchForm = null;
    for (final cand in Gs1Barcode.lookupCandidates(barcode)) {
      for (final key in Gs1Barcode.cacheKeys(cand.value)) {
        final hit = map[key];
        if (hit != null) {
          lastMatchForm = cand.form;
          debugPrint(
            'GTIN index hit form=${cand.form} key=$key '
            'stored=${hit.barcode}',
          );
          return hit;
        }
      }
    }
    debugPrint('GTIN index miss raw=${barcode.trim()}');
    return null;
  }

  static Future<List<TitckSkrsHit>> searchByName(
    String query, {
    int limit = 8,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    await ensureLoaded();
    final all = _all;
    if (all == null || all.isEmpty) return const [];
    final scored = <(int, int, TitckSkrsHit)>[];
    for (final hit in all) {
      final raw = hit.name.trim();
      if (raw.length < 2 || RegExp(r'^\d{3,}$').hasMatch(raw)) continue;
      final name = raw.toLowerCase();
      if (!name.contains(q)) continue;
      scored.add((name.startsWith(q) ? 0 : 1, name.length, hit));
    }
    scored.sort((a, b) {
      final byStart = a.$1.compareTo(b.$1);
      if (byStart != 0) return byStart;
      return a.$2.compareTo(b.$2);
    });
    return [for (final row in scored.take(limit)) row.$3];
  }
}
