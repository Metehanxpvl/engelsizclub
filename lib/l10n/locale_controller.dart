import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desteklenen arayüz dilleri.
enum AppLang {
  tr,
  en,
  de,
  ar,
  fr;

  String get code => name;

  Locale get locale => switch (this) {
        AppLang.tr => const Locale('tr'),
        AppLang.en => const Locale('en'),
        AppLang.de => const Locale('de'),
        AppLang.ar => const Locale('ar'),
        AppLang.fr => const Locale('fr'),
      };

  bool get isRtl => this == AppLang.ar;

  /// Profil seçicide görünen ad (her zaman yerel ad).
  String get nativeLabel => switch (this) {
        AppLang.tr => 'Türkçe',
        AppLang.en => 'English',
        AppLang.de => 'Deutsch',
        AppLang.ar => 'العربية',
        AppLang.fr => 'Français',
      };

  String get flagEmoji => switch (this) {
        AppLang.tr => '🇹🇷',
        AppLang.en => '🇬🇧',
        AppLang.de => '🇩🇪',
        AppLang.ar => '🇸🇦',
        AppLang.fr => '🇫🇷',
      };

  static AppLang fromCode(String? raw) {
    final c = (raw ?? '').trim().toLowerCase();
    if (c.isEmpty) return detectDevice();
    // en_US / tr_TR vb.
    final primary = c.split(RegExp(r'[_-]')).first;
    return AppLang.values.firstWhere(
      (e) => e.code == primary,
      orElse: detectDevice,
    );
  }

  /// Cihaz / sistem dil tercihine göre (desteklenmeyen → Türkçe).
  static AppLang detectDevice() {
    final locales = PlatformDispatcher.instance.locales;
    for (final locale in locales) {
      switch (locale.languageCode.toLowerCase()) {
        case 'tr':
          return AppLang.tr;
        case 'en':
          return AppLang.en;
        case 'de':
          return AppLang.de;
        case 'ar':
          return AppLang.ar;
        case 'fr':
          return AppLang.fr;
      }
    }
    return AppLang.tr;
  }
}

/// Kalıcı dil tercihi — SharedPreferences.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'app_ui_lang_v1';

  AppLang _lang = AppLang.tr;
  bool _loaded = false;
  bool _userPicked = false;

  AppLang get lang => _lang;
  bool get loaded => _loaded;
  bool get userPicked => _userPicked;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _lang = AppLang.fromCode(saved);
      _userPicked = true;
    } else {
      _lang = AppLang.detectDevice();
      _userPicked = false;
      // İlk açılışta cihaz dilini kaydet — sonraki açılışlarda sabit kalsın
      await prefs.setString(_prefsKey, _lang.code);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLang(AppLang lang) async {
    if (_lang == lang && _loaded && _userPicked) return;
    _lang = lang;
    _loaded = true;
    _userPicked = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.code);
  }
}
