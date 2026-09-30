import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/async_timeout.dart';
import 'nutrition_types.dart';

String _schemaError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('daily_nutrition_logs') ||
      s.contains('nutrition_profile') ||
      s.contains('could not find the table') ||
      s.contains('schema cache') ||
      s.contains('does not exist')) {
    return 'Kayıt için Supabase’de daily_nutrition_logs.sql dosyasını çalıştırın.';
  }
  return e.toString().replaceFirst('Exception: ', '');
}

Future<void> saveDailyNutritionLog({
  required NutritionAnalysis analysis,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Kaydı kaydetmek için giriş yapın.');
  }
  final day =
      '${analysis.date.year.toString().padLeft(4, '0')}-${analysis.date.month.toString().padLeft(2, '0')}-${analysis.date.day.toString().padLeft(2, '0')}';
  try {
    await withNetworkTimeout(
      Supabase.instance.client.from('daily_nutrition_logs').upsert(
        {
          'user_id': user.id,
          'log_date': day,
          'raw_input': analysis.rawInput,
          'nutrients_result': analysis.toJson(),
          'analysis_version': analysis.version,
          'nutrition_profile': analysis.profile.id,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,log_date',
      ),
      message: 'Kayıt kaydedilemedi.',
    );
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError(_schemaError(e));
  }
}
