import 'package:shared_preferences/shared_preferences.dart';

String profilFotoPrefsKey(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_profil_foto_${e.isEmpty ? fallback : e}';
}

Future<String?> loadProfilFoto(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(profilFotoPrefsKey(email));
  if (v == null || v.isEmpty) return null;
  return v;
}

Future<void> saveProfilFoto(String email, String dataUrl) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(profilFotoPrefsKey(email), dataUrl);
}

Future<void> clearProfilFoto(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(profilFotoPrefsKey(email));
}
