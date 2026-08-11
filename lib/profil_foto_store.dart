import 'package:shared_preferences/shared_preferences.dart';

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
