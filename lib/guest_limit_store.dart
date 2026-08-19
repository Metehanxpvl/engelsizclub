import 'package:shared_preferences/shared_preferences.dart';

/// Misafir (guest) freemium limitleri.
class GuestLimitStore {
  GuestLimitStore._();

  static const maxSearches = 2;
  static const timedAccess = Duration(minutes: 2);
  /// Otizm tarama (M-CHAT) misafir süresi.
  static const mchatTimedAccess = Duration(minutes: 1);

  static const _searchCountKey = 'guest_search_count_v1';
  // v2: eski (süresi dolmuş) deneme kayıtlarını sıfırlamak için
  static const _haklarStartKey = 'guest_tab_start_haklar_v2';
  static const _kartlarStartKey = 'guest_tab_start_kartlar_v2';
  static const _mchatStartKey = 'guest_tab_start_mchat_v1';
  static const _dahaStartKey = 'guest_tab_start_daha_fazlasi_v2';
  static const _cviStartKey = 'guest_tab_start_cvi_v2';
  static const _legacyKeys = <String>[
    'guest_tab_start_haklar_v1',
    'guest_tab_start_kartlar_v1',
  ];

  static String _tabKey(String tab) => switch (tab) {
        'haklar' => _haklarStartKey,
        'kartlar' => _kartlarStartKey,
        'mchat' => _mchatStartKey,
        'daha_fazlasi' => _dahaStartKey,
        'cvi' => _cviStartKey,
        _ => 'guest_tab_start_${tab}_v2',
      };

  static Duration limitFor(String tab) =>
      tab == 'mchat' ? mchatTimedAccess : timedAccess;

  /// Yapılan misafir arama sayısı.
  static Future<int> searchCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_searchCountKey) ?? 0;
  }

  /// Yeni arama yapılabilir mi? (0 veya 1 → evet; ≥2 → hayır)
  static Future<bool> canSearch() async {
    return (await searchCount()) < maxSearches;
  }

  /// Aramayı kaydeder; yeni sayacı döner.
  static Future<int> recordSearch() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_searchCountKey) ?? 0) + 1;
    await prefs.setInt(_searchCountKey, next);
    return next;
  }

  /// Haklar / Kartlar / M-CHAT: ilk girişte timestamp yazar.
  /// Süre dolmuşsa false.
  static Future<bool> allowTimedTab(String tab) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _tabKey(tab);
    final max = limitFor(tab);
    final raw = prefs.getInt(key);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw == null || raw <= 0) {
      await prefs.setInt(key, now);
      return true;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now().difference(start) < max;
  }

  /// Kalan süre (saniye). Timestamp yoksa henüz başlamamış → tam limit.
  static Future<int> remainingTimedSeconds(String tab) async {
    final prefs = await SharedPreferences.getInstance();
    final max = limitFor(tab);
    final raw = prefs.getInt(_tabKey(tab));
    if (raw == null || raw <= 0) return max.inSeconds;
    final elapsed =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(raw));
    final left = max - elapsed;
    return left.isNegative ? 0 : left.inSeconds;
  }

  /// Yeni misafir oturumu: Haklar/Kartlar/M-CHAT süresini sıfırla.
  static Future<void> resetTimedTabsForGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_haklarStartKey);
    await prefs.remove(_kartlarStartKey);
    await prefs.remove(_mchatStartKey);
    await prefs.remove(_dahaStartKey);
    await prefs.remove(_cviStartKey);
    for (final k in _legacyKeys) {
      await prefs.remove(k);
    }
  }

  /// Üye girişi sonrası misafir sayaçlarını temizle.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchCountKey);
    await prefs.remove(_haklarStartKey);
    await prefs.remove(_kartlarStartKey);
    await prefs.remove(_mchatStartKey);
    await prefs.remove(_dahaStartKey);
    await prefs.remove(_cviStartKey);
    for (final k in _legacyKeys) {
      await prefs.remove(k);
    }
  }
}
