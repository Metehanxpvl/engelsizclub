import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meto_theme.dart';
import 'utils/web_page_reload.dart';

const _prefsKey = 'uygulama_renk_temasi_v1';

/// Tema değişince MaterialApp'i yeniden kurmak için sürüm sayacı (mobil).
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

/// Seçimi kaydet ve uygula.
///
/// Web: prefs sonrası tam sayfa yenileme (MaterialApp ValueKey rebuild gri ekran
/// yapmasın diye). Mobil: [renkTemasiSurumu] ile mevcut rebuild.
///
/// Çağıran: önce sheet'i kapatıp kapanma animasyonunu (~350ms) beklemeli.
Future<void> saveAndApplyRenkTemasi(MetoPalette palette) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, palette.id);
  MetoColors.uygula(palette);
  if (kIsWeb) {
    reloadWebPage();
  } else {
    renkTemasiSurumu.value++;
  }
}
