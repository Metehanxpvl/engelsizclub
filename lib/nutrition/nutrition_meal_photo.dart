import 'dart:convert';

import 'nutrition_analyzer.dart';
import 'nutrition_types.dart';

/// Gemini öğün JSON → mevcut parser’ın beklediği metin.
String mealPhotoJsonToInput(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    s = s.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    s = s.replaceFirst(RegExp(r'\s*```$'), '');
  }
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw StateError('Fotoğraf analizi okunamadı.');
  }
  late final Object decoded;
  try {
    decoded = jsonDecode(s.substring(start, end + 1));
  } catch (_) {
    throw StateError('Fotoğraf analizi okunamadı.');
  }
  if (decoded is! Map) {
    throw StateError('Fotoğraf analizi okunamadı.');
  }
  final foods = decoded['foods'] ?? decoded['items'];
  if (foods is! List || foods.isEmpty) {
    throw StateError('Fotoğrafta analiz edilebilecek bir gıda bulunamadı.');
  }
  final parts = <String>[];
  for (final item in foods) {
    if (item is! Map) continue;
    final name =
        '${item['name'] ?? item['food'] ?? item['food_name'] ?? item['label'] ?? ''}'
            .trim();
    if (name.isEmpty) continue;
    final grams = _asDouble(
      item['grams'] ??
          item['gram'] ??
          item['g'] ??
          item['estimated_weight_g'] ??
          item['estimated_grams'],
    );
    final qty = _asDouble(item['quantity'] ?? item['adet']);
    if (grams != null && grams > 0) {
      parts.add('${grams.round()} g $name');
    } else if (qty != null && qty > 0) {
      parts.add('${qty == qty.roundToDouble() ? qty.round() : qty} $name');
    } else {
      parts.add(name);
    }
  }
  if (parts.isEmpty) {
    throw StateError('Fotoğrafta analiz edilebilecek bir gıda bulunamadı.');
  }
  return parts.join(', ');
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.').trim());
  return null;
}

NutritionAnalysis analyzeMealPhotoInput(
  String photoJson, {
  required DateTime date,
  NutritionUserProfile profile = const NutritionUserProfile(),
}) {
  return analyzeNutrition(
    mealPhotoJsonToInput(photoJson),
    date,
    profile: profile,
  );
}
