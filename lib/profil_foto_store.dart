import 'package:shared_preferences/shared_preferences.dart';

/// DB’de yalnız kısa http(s) URL tutulsun — base64 şişirmesin.
bool isProfilFotoUrl(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  return s.startsWith('https://') || s.startsWith('http://');
}

String? sanitizeProfilFotoUrl(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty || !isProfilFotoUrl(s)) return null;
  return s;
}

String profilFotoPrefsKey(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_profil_foto_${e.isEmpty ? fallback : e}';
}

Future<String?> loadProfilFoto(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(profilFotoPrefsKey(email));
  if (v == null || v.isEmpty) return null;
  // Eski base64 blob’ları cihaz önbelleğinden temizle (DB şişmesi + storage).
  if (v.startsWith('data:')) {
    await prefs.remove(profilFotoPrefsKey(email));
    return null;
  }
  return v;
}

Future<void> saveProfilFoto(String email, String photoUrl) async {
  final prefs = await SharedPreferences.getInstance();
  final v = photoUrl.trim();
  // Telefon/web önbelleğinde yalnızca kısa URL tut.
  if (v.isEmpty || v.startsWith('data:')) {
    await prefs.remove(profilFotoPrefsKey(email));
    return;
  }
  await prefs.setString(profilFotoPrefsKey(email), v);
}

Future<void> clearProfilFoto(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(profilFotoPrefsKey(email));
}
