import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_controller.dart';

/// Uygulama / kullanıcı metinlerini seçilen dile çevirir.
/// Google gtx + MyMemory yedek; sonuç bellek + SharedPreferences önbelleğinde.
class ContentTranslator extends ChangeNotifier {
  ContentTranslator._() {
    LocaleController.instance.addListener(_onLangChanged);
  }

  static final ContentTranslator instance = ContentTranslator._();

  static const _prefsKey = 'content_tr_cache_v1';

  final Map<String, String> _mem = {};
  bool _diskLoaded = false;
  int _inflight = 0;
  final Set<String> _queued = {};

  String get targetCode => LocaleController.instance.lang.code;

  bool get isBusy => _inflight > 0;

  void _onLangChanged() => notifyListeners();

  Future<void> ensureLoaded() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is Map) {
        map.forEach((k, v) {
          if (k is String && v is String && v.isNotEmpty) {
            _mem[k] = v;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Boyut sınırı: en son ~2500 kayıt
      final entries = _mem.entries.toList();
      final slice = entries.length > 2500
          ? Map.fromEntries(entries.sublist(entries.length - 2500))
          : _mem;
      await prefs.setString(_prefsKey, jsonEncode(slice));
    } catch (_) {}
  }

  String _cacheKey(String text, String from, String to) => '$from|$to|$text';

  /// Senkron: önbellekte varsa çeviri, yoksa kaynak.
  /// Kaynak genelde TR; hedef TR iken İngilizce görünen metinleri TR'ye çevirir.
  String sync(String text, {String from = 'tr'}) {
    final t = _normalize(text);
    if (t.isEmpty) return text;
    final to = targetCode;

    // Hedef TR: Türkçe kaynak aynen; İngilizce görünen UGC → tr
    if (LocaleController.instance.lang == AppLang.tr) {
      if (from == 'tr' && _looksEnglish(t) && !_looksTurkish(t)) {
        final hit = _mem[_cacheKey(t, 'en', 'tr')];
        if (hit != null) return hit;
        prefetch(t, from: 'en');
        return text;
      }
      return text;
    }

    if (to == from) return text;

    // Metin zaten hedef dilde görünüyorsa çevirme
    if (to == 'en' && _looksEnglish(t) && !_looksTurkish(t)) return text;

    final hit = _mem[_cacheKey(t, from, to)];
    if (hit != null) return hit;
    prefetch(t, from: from);
    return text;
  }

  static bool _looksTurkish(String s) {
    if (RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(s)) return true;
    return RegExp(
      r'\b(ve|bir|icin|için|ile|bu|olan|var|yok|ilan|uzman|bakici|bakıcı|araniyor|aranıyor|temizlik|alet|medikal|diger|diğer|tumu|tümü)\b',
      caseSensitive: false,
    ).hasMatch(s);
  }

  static bool _looksEnglish(String s) {
    return RegExp(
      r'\b(the|and|for|with|from|looking|needed|caregiver|specialist|expert|second[\s-]?hand|listings?|sale|buy|sell|cleaning|equipment|medical|other|all)\b',
      caseSensitive: false,
    ).hasMatch(s);
  }

  /// Async çeviri; başarısızsa kaynak metin.
  Future<String> translate(String text, {String from = 'tr', String? to}) async {
    await ensureLoaded();
    final t = _normalize(text);
    if (t.isEmpty) return text;
    final target = to ?? targetCode;
    if (target == from) return text;
    final key = _cacheKey(t, from, target);
    final cached = _mem[key];
    if (cached != null) return cached;

    _inflight++;
    try {
      final out = await _fetch(t, from: from, to: target);
      _mem[key] = out;
      unawaited(_persist());
      notifyListeners();
      return out;
    } finally {
      _inflight--;
    }
  }

  /// Arka planda çevir; UI [sync] ile sonra güncellenir.
  void prefetch(String text, {String from = 'tr'}) {
    final t = _normalize(text);
    if (t.isEmpty) return;
    final to = targetCode;
    if (to == from) return;
    final key = _cacheKey(t, from, to);
    if (_mem.containsKey(key) || _queued.contains(key)) return;
    _queued.add(key);
    unawaited(() async {
      try {
        await translate(t, from: from, to: to);
      } finally {
        _queued.remove(key);
      }
    }());
  }

  Future<void> prefetchMany(Iterable<String> texts, {String from = 'tr'}) async {
    await ensureLoaded();
    final to = targetCode;
    if (to == from) return;
    final pending = <String>[];
    for (final raw in texts) {
      final t = _normalize(raw);
      if (t.isEmpty) continue;
      final key = _cacheKey(t, from, to);
      if (!_mem.containsKey(key)) pending.add(t);
    }
    if (pending.isEmpty) return;

    // ~900 karakterlik gruplar
    var i = 0;
    while (i < pending.length) {
      final batch = <String>[];
      var len = 0;
      while (i < pending.length && batch.length < 40) {
        final s = pending[i];
        if (batch.isNotEmpty && len + s.length > 900) break;
        batch.add(s);
        len += s.length + 1;
        i++;
      }
      final joined = batch.join('\n');
      try {
        final translated = await _fetch(joined, from: from, to: to);
        final parts = translated.split('\n');
        if (parts.length == batch.length) {
          for (var j = 0; j < batch.length; j++) {
            _mem[_cacheKey(batch[j], from, to)] = parts[j].trim();
          }
        } else {
          for (final s in batch) {
            await translate(s, from: from, to: to);
          }
        }
      } catch (_) {
        for (final s in batch) {
          await translate(s, from: from, to: to);
        }
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    unawaited(_persist());
  }

  static String _normalize(String text) => text
      .replaceAll(RegExp(r'[^\S\n]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .trim();

  Future<String> _fetch(String t, {required String from, required String to}) async {
    // 1) Google (anahtarsız gtx)
    try {
      final r = await http.get(Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(t)}',
      ));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as List;
        final segs = (data.isNotEmpty ? data[0] as List? : null) ?? const [];
        final buf = StringBuffer();
        for (final s in segs) {
          if (s is List && s.isNotEmpty) buf.write(s[0]?.toString() ?? '');
        }
        final out = buf.toString().trim();
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}

    // 2) MyMemory
    try {
      final q = t.length > 480 ? '${t.substring(0, 480)}…' : t;
      final r = await http.get(Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(q)}&langpair=$from|$to',
      ));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map;
        final translated =
            (data['responseData'] as Map?)?['translatedText']?.toString() ?? '';
        if (translated.isNotEmpty &&
            !translated.toUpperCase().contains('MYMEMORY')) {
          return translated;
        }
      }
    } catch (_) {}

    return t;
  }
}
