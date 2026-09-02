import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/async_timeout.dart';
import 'gemini_service.dart';

/// TİTCK KÜB/KT (hasta kullanma talimatı) — resmi PDF.
/// İstemci TITCK'ye gitmez (CORS / WAF). Edge Function `titck-kubkt` kamu
/// DataTables aramasını vekiller; anahtar yok. Fonksiyon yoksa resmi liste.
class TitckLeafletHit {
  const TitckLeafletHit({
    this.name = '',
    this.activeIngredient = '',
    this.ktUrl,
    this.kubUrl,
  });

  final String name;
  final String activeIngredient;
  final String? ktUrl;
  final String? kubUrl;

  String? get prospectusUrl {
    final kt = (ktUrl ?? '').trim();
    if (kt.isNotEmpty) return kt;
    final kub = (kubUrl ?? '').trim();
    return kub.isEmpty ? null : kub;
  }
}

class TitckKubktService {
  TitckKubktService._();

  static const officialListUrl = 'https://www.titck.gov.tr/kubkt';

  static const functionName = 'titck-kubkt';

  /// DataTables araması uzun isimde zayıf; ilk 2–3 token.
  static String searchQuery(String medicineName) {
    final parts = medicineName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length <= 3) return parts.join(' ');
    return parts.take(3).join(' ');
  }

  static Future<TitckLeafletHit?> findLeaflet(String medicineName) async {
    final q = searchQuery(medicineName);
    if (q.length < 3) return null;
    try {
      final client = Supabase.instance.client;
      final anon = GeminiService.supabaseAnonKeyForProxy;
      if (anon.isEmpty) return null;
      final res = await withNetworkTimeout(
        client.functions.invoke(
          functionName,
          body: {'query': q},
          headers: {
            'Authorization': 'Bearer $anon',
            'apikey': anon,
          },
        ),
        timeout: const Duration(seconds: 12),
        message: 'TİTCK KÜB/KT yanıt vermedi.',
      );
      final data = res.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      if (map['ok'] != true) return null;
      final kt = _https(map['kt_url'] ?? map['ktUrl']);
      final kub = _https(map['kub_url'] ?? map['kubUrl']);
      if (kt == null && kub == null) return null;
      return TitckLeafletHit(
        name: (map['name'] ?? '').toString().trim(),
        activeIngredient: (map['active'] ?? map['active_ingredient'] ?? '')
            .toString()
            .trim(),
        ktUrl: kt,
        kubUrl: kub,
      );
    } on FunctionException catch (e) {
      debugPrint('titck-kubkt ${e.status}: ${e.reasonPhrase}');
      return null;
    } catch (e, st) {
      debugPrint('titck-kubkt atlandı: $e\n$st');
      return null;
    }
  }

  static String? _https(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (!host.contains('titck.gov.tr')) return null;
    return uri.toString();
  }
}
