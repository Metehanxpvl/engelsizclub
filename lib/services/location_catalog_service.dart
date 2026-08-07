import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/centers_data.dart' show kAllIlceler;
import '../data/intl_locations_seed.dart';
import '../data/location_models.dart';
import '../data/turkish_cities_data.dart';
import '../l10n/locale_controller.dart';

/// Ülke → eyalet/il → şehir/ilçe kataloğu.
/// Önce Supabase (`country_code` filtresi), yoksa yerel seed.
class LocationCatalogService {
  LocationCatalogService._();
  static final LocationCatalogService instance = LocationCatalogService._();

  static const anywhereCode = '__ANYWHERE__';
  static const allCountryCode = '__ALL_COUNTRY__';
  static const allStateLabel = 'Tümü';
  static const allCityLabel = kAllIlceler;

  List<LocCountry>? _countries;
  final Map<String, List<LocState>> _statesByCountry = {};
  final Map<String, Map<int, List<LocCity>>> _citiesByState = {};
  bool _countriesLoaded = false;

  List<LocCountry> get countries =>
      List.unmodifiable(_countries ?? _localCountries());

  LocCountry? countryByCode(String code) {
    final c = code.trim().toUpperCase();
    for (final e in countries) {
      if (e.code == c) return e;
    }
    return null;
  }

  String defaultCountryCode([AppLang? lang]) =>
      countryCodeForLang(lang ?? LocaleController.instance.lang);

  Future<void> ensureCountries() async {
    if (_countriesLoaded && _countries != null) return;
    try {
      final rows = await Supabase.instance.client
          .from('locations_countries')
          .select()
          .eq('active', true)
          .inFilter('code', kSupportedCountryCodes)
          .order('sort_order');
      final list = (rows as List)
          .map((e) => LocCountry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => kSupportedCountryCodes.contains(e.code))
          .toList();
      if (list.isNotEmpty) {
        _countries = list;
        _countriesLoaded = true;
        return;
      }
    } catch (e) {
      debugPrint('locations_countries: $e');
    }
    _countries = _localCountries();
    _countriesLoaded = true;
  }

  Future<List<LocState>> statesFor(String countryCode) async {
    final code = countryCode.trim().toUpperCase();
    if (!kSupportedCountryCodes.contains(code)) return const [];
    final cached = _statesByCountry[code];
    if (cached != null) return cached;

    try {
      final rows = await Supabase.instance.client
          .from('locations_states')
          .select()
          .eq('country_code', code)
          .order('name');
      final list = (rows as List)
          .map((e) => LocState.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isNotEmpty) {
        _statesByCountry[code] = list;
        return list;
      }
    } catch (e) {
      debugPrint('locations_states($code): $e');
    }

    final local = _localStates(code);
    _statesByCountry[code] = local;
    return local;
  }

  Future<List<LocCity>> citiesFor({
    required String countryCode,
    required int stateId,
    String? stateName,
  }) async {
    final code = countryCode.trim().toUpperCase();
    if (!kSupportedCountryCodes.contains(code)) return const [];

    final byState = _citiesByState.putIfAbsent(code, () => {});
    final cached = byState[stateId];
    if (cached != null) return cached;

    if (stateId > 0) {
      try {
        final rows = await Supabase.instance.client
            .from('locations_cities')
            .select()
            .eq('country_code', code)
            .eq('state_id', stateId)
            .order('name');
        final list = (rows as List)
            .map((e) => LocCity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) {
          byState[stateId] = list;
          return list;
        }
      } catch (e) {
        debugPrint('locations_cities($code,$stateId): $e');
      }
    }

    final name = stateName?.trim() ?? '';
    final local = _localCities(code, stateId: stateId, stateName: name);
    byState[stateId] = local;
    return local;
  }

  Future<List<String>> stateNames(String countryCode) async {
    final states = await statesFor(countryCode);
    return states.map((s) => s.name).toList();
  }

  Future<List<String>> cityNames({
    required String countryCode,
    required String stateName,
  }) async {
    final states = await statesFor(countryCode);
    LocState? match;
    for (final s in states) {
      if (s.name == stateName) {
        match = s;
        break;
      }
    }
    if (match == null) return const [];
    final cities = await citiesFor(
      countryCode: countryCode,
      stateId: match.id,
      stateName: match.name,
    );
    return cities.map((c) => c.name).toList();
  }

  List<LocCountry> _localCountries() => kSeedCountries
      .map(LocCountry.fromJson)
      .where((e) => kSupportedCountryCodes.contains(e.code))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<LocState> _localStates(String code) {
    if (code == 'TR') {
      var i = 1;
      return [
        for (final name in kCityNames)
          LocState(id: i++, countryCode: 'TR', name: name, code: name),
      ];
    }
    final map = kSeedStatesCities[code];
    if (map == null) return const [];
    var i = 1;
    return [
      for (final name in map.keys)
        LocState(id: i++, countryCode: code, name: name, code: name),
    ];
  }

  List<LocCity> _localCities(
    String code, {
    required int stateId,
    required String stateName,
  }) {
    if (code == 'TR') {
      final info = kTurkishCities[stateName];
      if (info == null) return const [];
      var i = 1;
      return [
        for (final n in info.ilceler)
          if (n != kAllIlceler)
            LocCity(
              id: i++,
              countryCode: 'TR',
              stateId: stateId,
              name: n,
            ),
      ];
    }
    final cities = kSeedStatesCities[code]?[stateName] ?? const <String>[];
    var i = 1;
    return [
      for (final n in cities)
        LocCity(id: i++, countryCode: code, stateId: stateId, name: n),
    ];
  }

  void clearCache() {
    _countries = null;
    _countriesLoaded = false;
    _statesByCountry.clear();
    _citiesByState.clear();
  }
}
