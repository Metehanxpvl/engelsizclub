import 'package:shared_preferences/shared_preferences.dart';

String _teklifKey(String email) =>
    'teklif_verilen_ilanlar_${email.trim().toLowerCase()}';

Future<Set<int>> loadTeklifVerilenIlanlar(String email) async {
  if (email.trim().isEmpty) return {};
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_teklifKey(email)) ?? const [];
  return {
    for (final s in raw)
      if (int.tryParse(s) != null) int.parse(s),
  };
}

Future<void> markTeklifVerildi({
  required String email,
  required int ilanId,
}) async {
  if (email.trim().isEmpty || ilanId <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  final key = _teklifKey(email);
  final current = prefs.getStringList(key) ?? <String>[];
  final id = '$ilanId';
  if (current.contains(id)) return;
  await prefs.setStringList(key, [...current, id]);
}
