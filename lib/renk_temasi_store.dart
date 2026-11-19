import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meto_theme.dart';

const _prefsKey = 'uygulama_renk_temasi_v1';

/// Tema değişince MaterialApp'i yeniden kurmak için sürüm sayacı.
final ValueNotifier<int> renkTemasiSurumu = ValueNotifier<int>(0);

MetoPalette metoPaletteById(String? id) {
  final raw = (id ?? '').trim();
  if (raw.isEmpty) return kMetoPalettes.first;
  for (final p in kMetoPalettes) {
    if (p.id == raw) return p;
  }
  return kMetoPalettes.first; // yesil
}

/// Prefs'ten yükle ve uygula; yoksa / hata ise yeşil.
Future<void> loadAndApplyRenkTemasi() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    MetoColors.uygula(metoPaletteById(id));
  } catch (_) {
    MetoColors.uygula(metoPaletteById('yesil'));
  }
}

/// Seçimi kaydet, uygula ve UI sürümünü artır.
Future<void> saveAndApplyRenkTemasi(MetoPalette palette) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, palette.id);
  MetoColors.uygula(palette);
  renkTemasiSurumu.value++;
}
