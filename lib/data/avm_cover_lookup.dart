import 'dart:convert';

import 'package:flutter/services.dart';

import '../gezi_kampanya_store.dart';

/// `scripts/avm_sources.json` içindeki resmi AVM kapak URL'leri.
const kAvmSourcesAsset = 'scripts/avm_sources.json';

/// Etkinlik görseli yoksa AVM sayfasının kendi fotoğrafı (og/hero).
class AvmCoverIndex {
  AvmCoverIndex._(this._byCityAvm, this._byAvm);

  final Map<String, String> _byCityAvm;
  final Map<String, String> _byAvm;

  static final AvmCoverIndex empty = AvmCoverIndex._(
    const {},
    const {},
  );

  static AvmCoverIndex? _cached;

  static Future<AvmCoverIndex> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await rootBundle.loadString(kAvmSourcesAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cached = empty;
        return empty;
      }
      final byCityAvm = <String, String>{};
      final byAvm = <String, String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final city = foldTurkish(map['city']?.toString() ?? '');
        final avm = foldTurkish(map['avm_name']?.toString() ?? '');
        final image = (map['image']?.toString() ?? '').trim();
        if (avm.isEmpty || image.isEmpty) continue;
        if (!_usableCover(image)) continue;
        byAvm.putIfAbsent(avm, () => image);
        if (city.isNotEmpty) {
          byCityAvm['$city|$avm'] = image;
        }
      }
      _cached = AvmCoverIndex._(byCityAvm, byAvm);
      return _cached!;
    } catch (_) {
      _cached = empty;
      return empty;
    }
  }

  static bool _usableCover(String image) {
    final u = image.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    final lower = u.toLowerCase();
    if (RegExp(
      r'dummy\.png|transparent\.png|facebook\.png|event-offer-m\.png|'
      r'hugedomains|holder\.js|_logo\.png|/logo\.png|\.mp4(?:\?|$)',
    ).hasMatch(lower)) {
      return false;
    }
    final path = lower.split('?').first;
    return RegExp(r'\.(jpe?g|png|webp|avif)$').hasMatch(path);
  }

  String urlFor({required String avmName, String city = ''}) {
    final avm = foldTurkish(avmName);
    if (avm.isEmpty) return '';
    final cityKey = foldTurkish(city);
    if (cityKey.isNotEmpty) {
      final hit = _byCityAvm['$cityKey|$avm'];
      if (hit != null && hit.isNotEmpty) return hit;
    }
    return _byAvm[avm] ?? '';
  }
}
