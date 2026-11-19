import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// hak_takip.durum değerleri.
const kHakTakipDurumlari = <String>{
  'basvurmadim',
  'basvurdum',
  'bekliyor',
  'onaylandi',
  'reddedildi',
};

class HakProfil {
  const HakProfil({
    this.cevaplar = const {},
    this.raporBitis,
    this.updatedAt,
  });

  final Map<String, dynamic> cevaplar;
  final DateTime? raporBitis;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'cevaplar': cevaplar,
        'rapor_bitis': raporBitis?.toIso8601String().split('T').first,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory HakProfil.fromJson(Map<String, dynamic> json) {
    final c = json['cevaplar'];
    Map<String, dynamic> cevaplar = const {};
    if (c is Map<String, dynamic>) {
      cevaplar = Map<String, dynamic>.from(c);
    } else if (c is Map) {
      cevaplar = Map<String, dynamic>.from(c);
    } else if (c is String && c.trim().isNotEmpty) {
      try {
        final d = jsonDecode(c);
        if (d is Map) cevaplar = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return HakProfil(
      cevaplar: cevaplar,
      raporBitis: _parseDate(json['rapor_bitis'] ?? json['raporBitis']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

class HakTakip {
  const HakTakip({
    required this.hakId,
    this.durum = 'basvurmadim',
    this.belgeler = const [],
    this.basvuruTarihi,
    this.sonucTarihi,
    this.itirazSonTarih,
    this.notlar = '',
    this.updatedAt,
  });

  final String hakId;
  final String durum;
  final List<Map<String, dynamic>> belgeler;
  final DateTime? basvuruTarihi;
  final DateTime? sonucTarihi;
  final DateTime? itirazSonTarih;
  final String notlar;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'hak_id': hakId,
        'durum': durum,
        'belgeler': belgeler,
        'basvuru_tarihi': basvuruTarihi?.toIso8601String().split('T').first,
        'sonuc_tarihi': sonucTarihi?.toIso8601String().split('T').first,
        'itiraz_son_tarih':
            itirazSonTarih?.toIso8601String().split('T').first,
        'notlar': notlar,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory HakTakip.fromJson(Map<String, dynamic> json) {
    final belgelerRaw = json['belgeler'];
    var belgeler = <Map<String, dynamic>>[];
    if (belgelerRaw is List) {
      for (final e in belgelerRaw) {
        if (e is Map<String, dynamic>) {
          belgeler.add(Map<String, dynamic>.from(e));
        } else if (e is Map) {
          belgeler.add(Map<String, dynamic>.from(e));
        }
      }
    }
    final durum = (json['durum']?.toString() ?? 'basvurmadim').trim();
    return HakTakip(
      hakId: (json['hak_id'] ?? json['hakId'] ?? '').toString(),
      durum: kHakTakipDurumlari.contains(durum) ? durum : 'basvurmadim',
      belgeler: belgeler,
      basvuruTarihi: _parseDate(json['basvuru_tarihi'] ?? json['basvuruTarihi']),
      sonucTarihi: _parseDate(json['sonuc_tarihi'] ?? json['sonucTarihi']),
      itirazSonTarih:
          _parseDate(json['itiraz_son_tarih'] ?? json['itirazSonTarih']),
      notlar: json['notlar']?.toString() ?? '',
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

const _prefsProfilKey = 'hak_profil_guest_v1';
const _prefsTakipKey = 'hak_takip_guest_v1';

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

String? _dateOnly(DateTime? d) => d?.toIso8601String().split('T').first;

Future<HakProfil> hakProfilYukle() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return _guestProfilYukle();

  try {
    final row = await Supabase.instance.client
        .from('hak_profil')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return const HakProfil();
    return HakProfil.fromJson(Map<String, dynamic>.from(row));
  } catch (_) {
    return _guestProfilYukle();
  }
}

Future<void> hakProfilKaydet(
  Map<String, dynamic> cevaplar, {
  DateTime? raporBitis,
}) async {
  final now = DateTime.now().toUtc();
  final profil = HakProfil(
    cevaplar: Map<String, dynamic>.from(cevaplar),
    raporBitis: raporBitis,
    updatedAt: now,
  );

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    await _guestProfilKaydet(profil);
    return;
  }

  await Supabase.instance.client.from('hak_profil').upsert({
    'user_id': user.id,
    'cevaplar': profil.cevaplar,
    'rapor_bitis': _dateOnly(raporBitis),
    'updated_at': now.toIso8601String(),
  });
}

Future<Map<String, HakTakip>> hakTakipYukle() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return _guestTakipYukle();

  try {
    final rows = await Supabase.instance.client
        .from('hak_takip')
        .select()
        .eq('user_id', user.id);
    final out = <String, HakTakip>{};
    for (final raw in (rows as List)) {
      final t = HakTakip.fromJson(Map<String, dynamic>.from(raw as Map));
      if (t.hakId.isNotEmpty) out[t.hakId] = t;
    }
    return out;
  } catch (_) {
    return _guestTakipYukle();
  }
}

Future<void> hakTakipKaydet(HakTakip takip) async {
  final now = DateTime.now().toUtc();
  final durum = kHakTakipDurumlari.contains(takip.durum)
      ? takip.durum
      : 'basvurmadim';
  final next = HakTakip(
    hakId: takip.hakId,
    durum: durum,
    belgeler: takip.belgeler,
    basvuruTarihi: takip.basvuruTarihi,
    sonucTarihi: takip.sonucTarihi,
    itirazSonTarih: takip.itirazSonTarih,
    notlar: takip.notlar,
    updatedAt: now,
  );

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    final all = await _guestTakipYukle();
    all[next.hakId] = next;
    await _guestTakipKaydetAll(all);
    return;
  }

  await Supabase.instance.client.from('hak_takip').upsert({
    'user_id': user.id,
    'hak_id': next.hakId,
    'durum': next.durum,
    'belgeler': next.belgeler,
    'basvuru_tarihi': _dateOnly(next.basvuruTarihi),
    'sonuc_tarihi': _dateOnly(next.sonucTarihi),
    'itiraz_son_tarih': _dateOnly(next.itirazSonTarih),
    'notlar': next.notlar,
    'updated_at': now.toIso8601String(),
  });
}

Future<HakProfil> _guestProfilYukle() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsProfilKey);
  if (raw == null || raw.isEmpty) return const HakProfil();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return HakProfil.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {}
  return const HakProfil();
}

Future<void> _guestProfilKaydet(HakProfil profil) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsProfilKey, jsonEncode(profil.toJson()));
}

Future<Map<String, HakTakip>> _guestTakipYukle() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsTakipKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, HakTakip>{};
    decoded.forEach((k, v) {
      if (v is Map) {
        final t = HakTakip.fromJson(Map<String, dynamic>.from(v));
        final id = t.hakId.isNotEmpty ? t.hakId : k.toString();
        out[id] = HakTakip(
          hakId: id,
          durum: t.durum,
          belgeler: t.belgeler,
          basvuruTarihi: t.basvuruTarihi,
          sonucTarihi: t.sonucTarihi,
          itirazSonTarih: t.itirazSonTarih,
          notlar: t.notlar,
          updatedAt: t.updatedAt,
        );
      }
    });
    return out;
  } catch (_) {
    return {};
  }
}

Future<void> _guestTakipKaydetAll(Map<String, HakTakip> all) async {
  final prefs = await SharedPreferences.getInstance();
  final payload = <String, dynamic>{
    for (final e in all.entries) e.key: e.value.toJson(),
  };
  await prefs.setString(_prefsTakipKey, jsonEncode(payload));
}
