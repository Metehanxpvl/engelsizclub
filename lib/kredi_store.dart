import 'package:shared_preferences/shared_preferences.dart';

const pendingGoogleRoleKey = 'pending_google_user_type';

String krediPrefsKeyFor(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_kredi_${e.isEmpty ? fallback : e}';
}

/// Yeni üye başlangıç kredisi: uzman/bakıcı → 10 hediye, aile → 3.
/// Mevcut kredi kaydı varsa üzerine yazmaz.
Future<void> seedWelcomeCredits({
  required String email,
  required String? userType,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  if (prefs.containsKey(key)) return;

  final bonusKey = '${key}_welcome_gift';
  final isProf = userType == 'uzman' || userType == 'bakici';
  final start = isProf ? 10 : 3;
  await prefs.setInt(key, start);
  if (isProf) {
    await prefs.setBool(bonusKey, true);
  }
}

Future<void> savePendingGoogleRole(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(pendingGoogleRoleKey, role);
}

Future<void> clearPendingGoogleRole() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(pendingGoogleRoleKey);
}

Future<String?> readPendingGoogleRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(pendingGoogleRoleKey);
}
