import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ana sayfa altı: mağaza + Instagram / Facebook linkleri.
class SocialLinksConfig {
  const SocialLinksConfig({
    this.instagramUrl = kDefaultInstagramUrl,
    this.facebookUrl = kDefaultFacebookUrl,
    this.appStoreUrl = '',
    this.playStoreUrl = '',
  });

  final String instagramUrl;
  final String facebookUrl;
  final String appStoreUrl;
  final String playStoreUrl;

  static const kDefaultInstagramUrl = 'https://www.instagram.com/engelsizclub';
  static const kDefaultFacebookUrl =
      'https://www.facebook.com/share/1QAzdknz5M/';

  SocialLinksConfig copyWith({
    String? instagramUrl,
    String? facebookUrl,
    String? appStoreUrl,
    String? playStoreUrl,
  }) =>
      SocialLinksConfig(
        instagramUrl: instagramUrl ?? this.instagramUrl,
        facebookUrl: facebookUrl ?? this.facebookUrl,
        appStoreUrl: appStoreUrl ?? this.appStoreUrl,
        playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      );

  Map<String, dynamic> toJson() => {
        'instagram': instagramUrl.trim(),
        'facebook': facebookUrl.trim(),
        'app_store': appStoreUrl.trim(),
        'play_store': playStoreUrl.trim(),
      };

  factory SocialLinksConfig.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const SocialLinksConfig();
    String pick(String k, [String fallback = '']) {
      final v = raw[k]?.toString().trim() ?? '';
      return v.isEmpty ? fallback : v;
    }

    return SocialLinksConfig(
      instagramUrl: pick('instagram', kDefaultInstagramUrl),
      facebookUrl: pick('facebook', kDefaultFacebookUrl),
      appStoreUrl: pick('app_store'),
      playStoreUrl: pick('play_store'),
    );
  }
}

const _prefsKey = 'social_links_cache_v1';
const _settingsKey = 'social_links';

/// `app_settings.social_links` + cihaz önbelleği (URL metni; blob yok).
class SocialLinksStore {
  SocialLinksStore._();
  static final SocialLinksStore instance = SocialLinksStore._();

  SocialLinksConfig _config = const SocialLinksConfig();
  SocialLinksConfig get config => _config;

  Future<SocialLinksConfig> load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            _config = SocialLinksConfig.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        }
      } catch (_) {}
    }

    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', _settingsKey)
          .maybeSingle();
      if (row != null) {
        final value = row['value'];
        Map<String, dynamic>? map;
        if (value is Map) {
          map = Map<String, dynamic>.from(value);
        } else if (value is String && value.trim().isNotEmpty) {
          final decoded = jsonDecode(value);
          if (decoded is Map) map = Map<String, dynamic>.from(decoded);
        }
        if (map != null) {
          _config = SocialLinksConfig.fromJson(map);
          await _cacheLocal(_config);
        }
      }
    } catch (_) {
      // offline → prefs
    }
    return _config;
  }

  Future<void> save(SocialLinksConfig next) async {
    await Supabase.instance.client.from('app_settings').upsert({
      'key': _settingsKey,
      'value': next.toJson(),
      'description': 'Ana sayfa sosyal medya ve mağaza linkleri',
    });
    _config = next;
    await _cacheLocal(next);
  }

  Future<void> _cacheLocal(SocialLinksConfig c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(c.toJson()));
    } catch (_) {}
  }
}
