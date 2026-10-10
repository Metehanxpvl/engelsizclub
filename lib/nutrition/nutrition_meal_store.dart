import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'nutrition_types.dart';

const kNutritionMealPrefsKey = 'nutrition_local_meals_v1';

String nutritionDayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

class NutritionSavedMeal {
  const NutritionSavedMeal({required this.rawInput, this.fingerprint = ''});

  final String rawInput;
  final String fingerprint;
}

class NutritionMealStore {
  NutritionMealStore._();
  static final NutritionMealStore instance = NutritionMealStore._();

  Map<String, dynamic> _root = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kNutritionMealPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _root = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {
      _root = {};
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kNutritionMealPrefsKey, jsonEncode(_root));
  }

  Future<Map<NutritionMealSlot, NutritionSavedMeal>> mealsFor(DateTime date) async {
    await load();
    final day = _root[nutritionDayKey(date)];
    if (day is! Map) return {};
    final out = <NutritionMealSlot, NutritionSavedMeal>{};
    for (final slot in NutritionMealSlot.values) {
      final row = day[slot.id];
      if (row is Map) {
        final raw = (row['raw'] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        out[slot] = NutritionSavedMeal(
          rawInput: raw,
          fingerprint: (row['fp'] ?? '').toString(),
        );
      } else if (row is String && row.trim().isNotEmpty) {
        out[slot] = NutritionSavedMeal(rawInput: row.trim());
      }
    }
    return out;
  }

  Future<void> saveMeal({
    required DateTime date,
    required NutritionMealSlot slot,
    required String rawInput,
    String fingerprint = '',
  }) async {
    await load();
    final key = nutritionDayKey(date);
    final day = Map<String, dynamic>.from(
      _root[key] is Map ? Map<String, dynamic>.from(_root[key] as Map) : {},
    );
    day[slot.id] = {
      'raw': rawInput.trim(),
      'fp': fingerprint,
    };
    _root[key] = day;
    await _persist();
  }
}

String nutritionPhotoFingerprint(List<int> bytes) {
  if (bytes.isEmpty) return '';
  var h = bytes.length;
  final n = bytes.length < 64 ? bytes.length : 64;
  for (var i = 0; i < n; i++) {
    h = 0x1fffffff & (h * 31 + bytes[i]);
    h = 0x1fffffff & (h * 31 + bytes[bytes.length - 1 - i]);
  }
  return '$h:${bytes.length}';
}
