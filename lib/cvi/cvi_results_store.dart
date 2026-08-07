import 'package:supabase_flutter/supabase_flutter.dart';

import 'cvi_models.dart';

/// Oturum bitince tek ağ isteği — aktif egzersizde DB yok.
class CviResultsStore {
  CviResultsStore._();

  /// Özet + adım metriklerini tek insert ile kaydeder.
  /// Giriş yoksa veya tablo yoksa sessizce false döner.
  static Future<bool> saveSession(CviSessionSummary summary) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      final email = (user.email ?? '').trim().toLowerCase();
      final steps = summary.stepResults.map((e) => e.toJson()).toList();

      // Tek satır özet (içinde adım dizisi) — 1 round-trip.
      await client.from('cvi_sessions').insert({
        'owner_id': user.id,
        'owner_email': email,
        'config_version': summary.configVersion,
        'total_steps': summary.totalSteps,
        'correct_count': summary.correctCount,
        'percentage': summary.percentage,
        'avg_reaction_ms': summary.avgReactionMs,
        'step_results': steps,
        'clutter_tolerance': {
          for (final e in summary.clutterTolerance.entries)
            '${e.key}': e.value,
        },
        'color_preference': summary.colorPreference,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
