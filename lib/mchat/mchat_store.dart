import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Yerel depolama — cevaplar ve sorumluluk reddi kabulü.
/// Sunucuya veri göndermiyoruz.
class MchatStore {
  MchatStore._();

  static const _acceptedKey = 'mchat_disclaimer_accepted_v1';
  static const _answersKey = 'mchat_answers_v1';
  static const _indexKey = 'mchat_q_index_v1';

  static Future<bool> isDisclaimerAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_acceptedKey) ?? false;
  }

  static Future<void> acceptDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
  }

  /// { "1": "Evet", "2": "Hayır", ... }
  static Future<Map<int, String>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_answersKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          if (int.tryParse(e.key) != null && e.value is String)
            int.parse(e.key): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAnswers(Map<int, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = {
      for (final e in answers.entries) '${e.key}': e.value,
    };
    await prefs.setString(_answersKey, jsonEncode(encoded));
  }

  static Future<void> saveAnswer(int id, String value) async {
    final all = await loadAnswers();
    all[id] = value;
    await saveAnswers(all);
  }

  static Future<int> loadQuestionIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_indexKey) ?? 0).clamp(0, 19);
  }

  static Future<void> saveQuestionIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_indexKey, index.clamp(0, 19));
  }

  /// Yeni taramaya başlamak için cevapları temizle (kabul kalır).
  static Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_answersKey);
    await prefs.setInt(_indexKey, 0);
  }
}
