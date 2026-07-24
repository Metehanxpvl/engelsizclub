// Figma Make `src/data/centers.ts` -> Dart veri dosyası üreticisi.
//
// Kullanım (paket kökünden):
//   dart run tool/gen_centers_data.dart
//
// Kaynak `.figma_sync/centers.ts` güncellendiğinde bu script yeniden koşulmalı;
// `lib/data/centers_data.dart` ve `lib/data/turkish_cities_data.dart` elle
// düzenlenmemelidir.

import 'dart:convert';
import 'dart:io';

void main() {
  final source = File('.figma_sync/centers.ts').readAsStringSync(
    encoding: utf8,
  );

  final cities = _JsParser(source).parseNamed('turkishCities') as Map;
  final centers = _JsParser(source).parseNamed('centers') as List;
  final vendors = _JsParser(source).parseNamed('medicalVendors') as List;

  File('lib/data/centers_data.dart').writeAsStringSync(
    _centersFile(centers, vendors),
    encoding: utf8,
  );
  File('lib/data/turkish_cities_data.dart').writeAsStringSync(
    _citiesFile(cities),
    encoding: utf8,
  );

  stdout.writeln(
    'Üretildi: ${centers.length} merkez, ${vendors.length} firma, '
    '${cities.length} il.',
  );
}

const _header = '''
// GENERATED FILE — elle düzenlemeyin.
// Kaynak: .figma_sync/centers.ts
// Üretici: tool/gen_centers_data.dart
''';

String _centersFile(List centers, List vendors) {
  final b = StringBuffer()
    ..write(_header)
    ..writeln()
    ..writeln("import 'dart:math' as math;")
    ..writeln()
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..write(_models)
    ..writeln()
    ..writeln('const kCenters = <MetoCenter>[');
  for (final raw in centers) {
    final c = raw as Map;
    b
      ..writeln('  MetoCenter(')
      ..writeln('    id: ${c['id']},')
      ..writeln("    city: ${_str(c['city'])},")
      ..writeln("    ilce: ${_str(c['ilce'])},")
      ..writeln('    name: ${_str(c['name'])},')
      ..writeln('    category: ${_str(c['category'])},')
      ..writeln('    address: ${_str(c['address'])},')
      ..writeln('    phone: ${_str(c['phone'])},')
      ..writeln('    hours: ${_str(c['hours'])},')
      ..writeln('    services: ${_strList(c['services'] as List)},')
      ..writeln('    rating: ${_dbl(c['rating'])},')
      ..writeln('    reviews: ${c['reviews']},')
      ..writeln('    color: ${_color(c['color'] as String)},')
      ..writeln('    lat: ${_dbl(c['lat'])},')
      ..writeln('    lng: ${_dbl(c['lng'])},')
      ..writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('const kMedicalVendors = <MedicalVendor>[');
  for (final raw in vendors) {
    final v = raw as Map;
    b
      ..writeln('  MedicalVendor(')
      ..writeln('    id: ${v['id']},')
      ..writeln('    name: ${_str(v['name'])},')
      ..writeln('    products: ${_strList(v['products'] as List)},')
      ..writeln('    city: ${_str(v['city'])},')
      ..writeln('    district: ${_str(v['district'])},')
      ..writeln('    phone: ${_str(v['phone'])},')
      ..writeln('    sgk: ${v['sgk']},')
      ..writeln('    cargo: ${v['cargo']},')
      ..writeln('    icon: ${_str(v['icon'])},')
      ..writeln('    color: ${_color(v['color'] as String)},')
      ..writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..write(_helpers);
  return b.toString();
}

String _citiesFile(Map cities) {
  final b = StringBuffer()
    ..write(_header)
    ..writeln()
    ..writeln("import 'centers_data.dart';")
    ..writeln()
    ..writeln('/// Kaynaktaki sırayı koruyan il listesi (seçici sıralaması).')
    ..writeln('const kCityNames = <String>[');
  for (final name in cities.keys) {
    b.writeln('  ${_str(name)},');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('const kTurkishCities = <String, TurkishCity>{');
  for (final entry in cities.entries) {
    final info = entry.value as Map;
    final ilceler =
        (info['ilceler'] as List).map((e) => '      ${_str(e)},').join('\n');
    b
      ..writeln('  ${_str(entry.key)}: TurkishCity(')
      ..writeln('    lat: ${_dbl(info['lat'])},')
      ..writeln('    lng: ${_dbl(info['lng'])},')
      ..writeln('    ilceler: [')
      ..writeln(ilceler)
      ..writeln('    ],')
      ..writeln('  ),');
  }
  b.writeln('};');
  return b.toString();
}

const _models = r'''
/// Bir il ve ilçeleri (`turkishCities`).
class TurkishCity {
  const TurkishCity({
    required this.lat,
    required this.lng,
    required this.ilceler,
  });

  final double lat;
  final double lng;
  final List<String> ilceler;
}

/// Rehabilitasyon / özel eğitim merkezi (`centers`).
class MetoCenter {
  const MetoCenter({
    required this.id,
    required this.city,
    required this.ilce,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    required this.hours,
    required this.services,
    required this.rating,
    required this.reviews,
    required this.color,
    required this.lat,
    required this.lng,
  });

  final int id;
  final String city;
  final String ilce;
  final String name;
  final String category;
  final String address;
  final String phone;
  final String hours;
  final List<String> services;
  final double rating;
  final int reviews;
  final Color color;
  final double lat;
  final double lng;
}

/// Medikal cihaz firması (`medicalVendors`).
class MedicalVendor {
  const MedicalVendor({
    required this.id,
    required this.name,
    required this.products,
    required this.city,
    required this.district,
    required this.phone,
    required this.sgk,
    required this.cargo,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final List<String> products;
  final String city;
  final String district;
  final String phone;
  final bool sgk;
  final bool cargo;
  final String icon;
  final Color color;
}
''';

const _helpers = r'''
const kCenterCategories = <String>[
  'Tümü',
  'Fizik Tedavi',
  'Özel Eğitim',
  'Dil Terapisi',
  'Nöroloji',
];

const kVendorFilterLabels = <String>['Tümü', "SGK'lı", 'Kargo Var', 'İstanbul'];

const kAllIlceler = 'Tümü İlçeler';
const kDefaultCity = 'İstanbul';

/// İki koordinat arasındaki kuş uçuşu mesafe (km) — Haversine.
double geoDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  const toRad = math.pi / 180;
  final sinDLat = math.sin((lat2 - lat1) * toRad / 2);
  final sinDLng = math.sin((lng2 - lng1) * toRad / 2);
  final a = sinDLat * sinDLat +
      math.cos(lat1 * toRad) * math.cos(lat2 * toRad) * sinDLng * sinDLng;
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// 1 km altını metre olarak gösterir: `850 m`, `4.1 km`.
String formatDistanceKm(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
''';

String _str(Object? value) {
  final escaped = (value as String)
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'");
  return "'$escaped'";
}

String _strList(List values) => '[${values.map((e) => _str(e)).join(', ')}]';

String _dbl(Object? raw) {
  final text = '$raw';
  return text.contains('.') || text.contains('e') || text.contains('E')
      ? text
      : '$text.0';
}

String _color(String hex) =>
    'Color(0xFF${hex.replaceFirst('#', '').toUpperCase()})';

/// `centers.ts` içindeki JS/TS object literal'lerini okuyan minimal ayrıştırıcı.
/// Sayıları kaynaktaki gösterimiyle (`_Num`) saklar, böylece hassasiyet korunur.
class _JsParser {
  _JsParser(this.src);

  final String src;
  int _i = 0;

  /// `export const <name> ... = <value>;` ifadesindeki değeri döndürür.
  Object? parseNamed(String name) {
    final decl = RegExp('const\\s+$name\\b').firstMatch(src);
    if (decl == null) throw StateError('$name bulunamadı');
    _i = src.indexOf('=', decl.end) + 1;
    return _value();
  }

  void _skipTrivia() {
    while (_i < src.length) {
      final c = src[_i];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        _i++;
      } else if (c == '/' && _i + 1 < src.length && src[_i + 1] == '/') {
        while (_i < src.length && src[_i] != '\n') {
          _i++;
        }
      } else {
        return;
      }
    }
  }

  Object? _value() {
    _skipTrivia();
    final c = src[_i];
    if (c == '{') return _object();
    if (c == '[') return _array();
    if (c == '"' || c == "'" || c == '`') return _string();
    if (src.startsWith('true', _i)) {
      _i += 4;
      return true;
    }
    if (src.startsWith('false', _i)) {
      _i += 5;
      return false;
    }
    if (src.startsWith('null', _i)) {
      _i += 4;
      return null;
    }
    return _number();
  }

  Map<String, Object?> _object() {
    _i++; // {
    final map = <String, Object?>{};
    while (true) {
      _skipTrivia();
      if (src[_i] == '}') {
        _i++;
        return map;
      }
      final key = src[_i] == '"' || src[_i] == "'" ? _string() : _identifier();
      _skipTrivia();
      _i++; // :
      map[key] = _value();
      _skipTrivia();
      if (src[_i] == ',') _i++;
    }
  }

  List<Object?> _array() {
    _i++; // [
    final list = <Object?>[];
    while (true) {
      _skipTrivia();
      if (src[_i] == ']') {
        _i++;
        return list;
      }
      list.add(_value());
      _skipTrivia();
      if (src[_i] == ',') _i++;
    }
  }

  String _identifier() {
    final start = _i;
    while (_i < src.length && RegExp(r'[A-Za-z0-9_$]').hasMatch(src[_i])) {
      _i++;
    }
    return src.substring(start, _i);
  }

  String _string() {
    final quote = src[_i++];
    final b = StringBuffer();
    while (src[_i] != quote) {
      if (src[_i] == r'\') {
        _i++;
        b.write(switch (src[_i]) {
          'n' => '\n',
          't' => '\t',
          'r' => '\r',
          final other => other,
        });
      } else {
        b.write(src[_i]);
      }
      _i++;
    }
    _i++;
    return b.toString();
  }

  _Num _number() {
    final start = _i;
    while (_i < src.length && RegExp(r'[-+0-9.eE]').hasMatch(src[_i])) {
      _i++;
    }
    return _Num(src.substring(start, _i));
  }
}

/// Kaynaktaki sayı gösterimini birebir taşıyan sarmalayıcı.
class _Num {
  const _Num(this.literal);

  final String literal;

  @override
  String toString() => literal;
}
