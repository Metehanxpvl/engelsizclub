import 'dart:convert';

import '../services/app_catalog_service.dart';

/// Kural operatörü: alan karşılaştırması.
class HakKural {
  const HakKural({
    required this.alan,
    required this.op,
    required this.deger,
  });

  final String alan;
  final String op; // >= | <= | > | < | == | != | in
  final dynamic deger;

  factory HakKural.fromJson(Map<String, dynamic> json) {
    return HakKural(
      alan: json['alan']?.toString() ?? '',
      op: json['op']?.toString() ?? '==',
      deger: json['deger'],
    );
  }

  Map<String, dynamic> toJson() => {
        'alan': alan,
        'op': op,
        'deger': deger,
      };
}

class HakKriter {
  const HakKriter({
    required this.metin,
    this.kural,
  });

  final String metin;
  final HakKural? kural;

  factory HakKriter.fromJson(Map<String, dynamic> json) {
    final k = json['kural'];
    HakKural? kural;
    if (k is Map) {
      kural = HakKural.fromJson(Map<String, dynamic>.from(k));
    }
    return HakKriter(
      metin: json['metin']?.toString() ?? '',
      kural: kural,
    );
  }

  Map<String, dynamic> toJson() => {
        'metin': metin,
        if (kural != null) 'kural': kural!.toJson(),
      };
}

class HakAdim {
  const HakAdim({
    required this.baslik,
    required this.aciklama,
    this.link,
  });

  final String baslik;
  final String aciklama;
  final String? link;

  factory HakAdim.fromJson(Map<String, dynamic> json) => HakAdim(
        baslik: json['baslik']?.toString() ?? '',
        aciklama: json['aciklama']?.toString() ?? '',
        link: _optStr(json['link']),
      );

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        'aciklama': aciklama,
        if (link != null && link!.isNotEmpty) 'link': link,
      };
}

class HakBelge {
  const HakBelge({
    required this.ad,
    required this.nereden,
    this.link,
  });

  final String ad;
  final String nereden;
  final String? link;

  factory HakBelge.fromJson(Map<String, dynamic> json) => HakBelge(
        ad: json['ad']?.toString() ?? '',
        nereden: json['nereden']?.toString() ?? '',
        link: _optStr(json['link']),
      );

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'nereden': nereden,
        if (link != null && link!.isNotEmpty) 'link': link,
      };
}

class HakItiraz {
  const HakItiraz({
    this.yol = '',
    this.sure = '',
    this.dilekce = '',
  });

  final String yol;
  final String sure;
  final String dilekce;

  bool get bos => yol.isEmpty && sure.isEmpty && dilekce.isEmpty;

  factory HakItiraz.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HakItiraz();
    return HakItiraz(
      yol: json['yol']?.toString() ?? '',
      sure: json['sure']?.toString() ?? '',
      dilekce: json['dilekce']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'yol': yol,
        'sure': sure,
        'dilekce': dilekce,
      };
}

class HakSss {
  const HakSss({
    required this.soru,
    required this.cevap,
  });

  final String soru;
  final String cevap;

  factory HakSss.fromJson(Map<String, dynamic> json) => HakSss(
        soru: json['soru']?.toString() ?? '',
        cevap: json['cevap']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'soru': soru,
        'cevap': cevap,
      };
}

class HakIletisim {
  const HakIletisim({
    required this.ad,
    this.telefon,
    this.link,
  });

  final String ad;
  final String? telefon;
  final String? link;

  factory HakIletisim.fromJson(Map<String, dynamic> json) => HakIletisim(
        ad: json['ad']?.toString() ?? '',
        telefon: _optStr(json['telefon']),
        link: _optStr(json['link']),
      );

  Map<String, dynamic> toJson() => {
        'ad': ad,
        if (telefon != null && telefon!.isNotEmpty) 'telefon': telefon,
        if (link != null && link!.isNotEmpty) 'link': link,
      };
}

class HakKaynak {
  const HakKaynak({
    required this.ad,
    required this.url,
  });

  final String ad;
  final String url;

  factory HakKaynak.fromJson(Map<String, dynamic> json) => HakKaynak(
        ad: json['ad']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'url': url,
      };
}

/// app_rights.dosya (+ kaynaklar / son_guncelleme / uzman_onayi) modeli.
class HakDosyasi {
  const HakDosyasi({
    this.ozet = '',
    this.kimler = const [],
    this.kimlerAlamaz = const [],
    this.adimlar = const [],
    this.belgeler = const [],
    this.sure = '',
    this.sonrasi = '',
    this.retSebepleri = const [],
    this.itiraz = const HakItiraz(),
    this.hakKaybi = const [],
    this.birlikte = const [],
    this.sss = const [],
    this.iletisim = const [],
    this.kaynaklar = const [],
    this.sonGuncelleme,
    this.uzmanOnayi,
  });

  final String ozet;
  final List<HakKriter> kimler;
  final List<String> kimlerAlamaz;
  final List<HakAdim> adimlar;
  final List<HakBelge> belgeler;
  final String sure;
  final String sonrasi;
  final List<String> retSebepleri;
  final HakItiraz itiraz;
  final List<String> hakKaybi;
  final List<String> birlikte;
  final List<HakSss> sss;
  final List<HakIletisim> iletisim;
  final List<HakKaynak> kaynaklar;
  final DateTime? sonGuncelleme;
  final String? uzmanOnayi;

  bool get bos =>
      ozet.trim().isEmpty && kimler.isEmpty && adimlar.isEmpty;

  /// [row] = app_rights satırı (katalog Map). Eksik anahtarlar boş.
  factory HakDosyasi.fromRow(Map<String, dynamic> row) {
    final dosya = _asMap(row['dosya']) ?? const <String, dynamic>{};
    final kaynaklarRaw = row['kaynaklar'] ?? dosya['kaynaklar'];
    return HakDosyasi(
      ozet: dosya['ozet']?.toString() ?? '',
      kimler: _mapList(dosya['kimler'], HakKriter.fromJson),
      kimlerAlamaz: _strList(dosya['kimlerAlamaz']),
      adimlar: _mapList(dosya['adimlar'], HakAdim.fromJson),
      belgeler: _mapList(dosya['belgeler'], HakBelge.fromJson),
      sure: dosya['sure']?.toString() ?? '',
      sonrasi: dosya['sonrasi']?.toString() ?? '',
      retSebepleri: _strList(dosya['retSebepleri']),
      itiraz: HakItiraz.fromJson(_asMap(dosya['itiraz'])),
      hakKaybi: _strList(dosya['hakKaybi']),
      birlikte: _strList(dosya['birlikte']),
      sss: _mapList(dosya['sss'], HakSss.fromJson),
      iletisim: _mapList(dosya['iletisim'], HakIletisim.fromJson),
      kaynaklar: _mapList(kaynaklarRaw, HakKaynak.fromJson),
      sonGuncelleme: _parseDate(row['son_guncelleme']),
      uzmanOnayi: _optStr(row['uzman_onayi']),
    );
  }

  Map<String, dynamic> toDosyaJson() => {
        'ozet': ozet,
        'kimler': [for (final k in kimler) k.toJson()],
        'kimlerAlamaz': kimlerAlamaz,
        'adimlar': [for (final a in adimlar) a.toJson()],
        'belgeler': [for (final b in belgeler) b.toJson()],
        'sure': sure,
        'sonrasi': sonrasi,
        'retSebepleri': retSebepleri,
        'itiraz': itiraz.toJson(),
        'hakKaybi': hakKaybi,
        'birlikte': birlikte,
        'sss': [for (final s in sss) s.toJson()],
        'iletisim': [for (final i in iletisim) i.toJson()],
      };
}

/// Katalogdaki hak satırından dosya; yoksa null.
HakDosyasi? hakDosyasiOf(String hakId) {
  final id = hakId.trim();
  if (id.isEmpty) return null;
  final rows = AppCatalogService.instance.list(CatalogPack.rights);
  for (final r in rows) {
    if (r['id']?.toString() == id) {
      return HakDosyasi.fromRow(r);
    }
  }
  return null;
}

String? _optStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

List<String> _strList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    if (t.startsWith('[')) {
      try {
        final decoded = jsonDecode(t);
        return _strList(decoded);
      } catch (_) {
        return [t];
      }
    }
    return [t];
  }
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  List? list;
  if (raw is List) {
    list = raw;
  } else if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) list = decoded;
    } catch (_) {
      return const [];
    }
  }
  if (list == null) return const [];
  final out = <T>[];
  for (final e in list) {
    if (e is Map<String, dynamic>) {
      out.add(fromJson(e));
    } else if (e is Map) {
      out.add(fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}

/// Admin kaydı öncesi dosya JSON şema doğrulaması. Hata mesajları döner.
List<String> validateHakDosyaJson(dynamic decoded) {
  final errors = <String>[];
  if (decoded is! Map) {
    errors.add('Dosya JSON bir nesne (object) olmalı.');
    return errors;
  }
  final m = Map<String, dynamic>.from(decoded);

  void expectString(String key) {
    if (!m.containsKey(key) || m[key] == null) return;
    if (m[key] is! String) errors.add('"$key" metin (string) olmalı.');
  }

  void expectStringList(String key) {
    if (!m.containsKey(key) || m[key] == null) return;
    final v = m[key];
    if (v is! List) {
      errors.add('"$key" dizi olmalı.');
      return;
    }
    for (var i = 0; i < v.length; i++) {
      if (v[i] != null && v[i] is! String) {
        errors.add('"$key[$i]" metin olmalı.');
      }
    }
  }

  expectString('ozet');
  expectString('sure');
  expectString('sonrasi');
  expectStringList('kimlerAlamaz');
  expectStringList('retSebepleri');
  expectStringList('hakKaybi');
  expectStringList('birlikte');

  if (m['kimler'] != null) {
    if (m['kimler'] is! List) {
      errors.add('"kimler" dizi olmalı.');
    } else {
      final list = m['kimler'] as List;
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e is! Map) {
          errors.add('"kimler[$i]" nesne olmalı.');
          continue;
        }
        final item = Map<String, dynamic>.from(e);
        if (item['metin'] != null && item['metin'] is! String) {
          errors.add('"kimler[$i].metin" metin olmalı.');
        }
        if (item['kural'] != null) {
          if (item['kural'] is! Map) {
            errors.add('"kimler[$i].kural" nesne olmalı.');
          } else {
            final k = Map<String, dynamic>.from(item['kural'] as Map);
            const ops = {'>=', '<=', '>', '<', '==', '!=', 'in'};
            if (k['alan'] != null && k['alan'] is! String) {
              errors.add('"kimler[$i].kural.alan" metin olmalı.');
            }
            final op = k['op']?.toString();
            if (op != null && !ops.contains(op)) {
              errors.add(
                '"kimler[$i].kural.op" geçersiz ($op).',
              );
            }
          }
        }
      }
    }
  }

  void expectObjList(
    String key,
    Set<String> requiredKeys,
  ) {
    if (m[key] == null) return;
    if (m[key] is! List) {
      errors.add('"$key" dizi olmalı.');
      return;
    }
    final list = m[key] as List;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is! Map) {
        errors.add('"$key[$i]" nesne olmalı.');
        continue;
      }
      final item = Map<String, dynamic>.from(e);
      for (final rk in requiredKeys) {
        if (item[rk] != null && item[rk] is! String) {
          errors.add('"$key[$i].$rk" metin olmalı.');
        }
      }
    }
  }

  expectObjList('adimlar', {'baslik', 'aciklama'});
  expectObjList('belgeler', {'ad', 'nereden'});
  expectObjList('sss', {'soru', 'cevap'});
  expectObjList('iletisim', {'ad'});

  if (m['itiraz'] != null) {
    if (m['itiraz'] is! Map) {
      errors.add('"itiraz" nesne olmalı.');
    } else {
      final it = Map<String, dynamic>.from(m['itiraz'] as Map);
      for (final k in ['yol', 'sure', 'dilekce']) {
        if (it[k] != null && it[k] is! String) {
          errors.add('"itiraz.$k" metin olmalı.');
        }
      }
    }
  }

  return errors;
}

List<String> validateHakKaynaklarJson(dynamic decoded) {
  final errors = <String>[];
  if (decoded is! List) {
    errors.add('Kaynaklar JSON bir dizi olmalı.');
    return errors;
  }
  for (var i = 0; i < decoded.length; i++) {
    final e = decoded[i];
    if (e is! Map) {
      errors.add('Kaynaklar[$i] nesne olmalı.');
      continue;
    }
    final item = Map<String, dynamic>.from(e);
    if (item['ad'] != null && item['ad'] is! String) {
      errors.add('Kaynaklar[$i].ad metin olmalı.');
    }
    if (item['url'] != null && item['url'] is! String) {
      errors.add('Kaynaklar[$i].url metin olmalı.');
    }
  }
  return errors;
}
