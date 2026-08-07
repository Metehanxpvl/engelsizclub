import '../l10n/locale_controller.dart';

/// Uygulama dil seçenekleriyle birebir aynı ülkeler.
const kSupportedCountryCodes = <String>['TR', 'GB', 'DE', 'SA', 'FR'];

/// Paylaşım / profil konum objesi.
class LocationData {
  const LocationData({
    this.countryCode = '',
    this.country = '',
    this.state = '',
    this.city = '',
  });

  final String countryCode;
  final String country;
  /// İl / eyalet / bölge
  final String state;
  /// İlçe / şehir
  final String city;

  bool get isEmpty =>
      countryCode.isEmpty && state.isEmpty && city.isEmpty;

  /// Eski alanlarla uyum: city→state, district→city (ilçe).
  String get legacyCity => state;
  String get legacyDistrict => city;

  Map<String, dynamic> toJson() => {
        'country_code': countryCode,
        'country': country,
        'state': state,
        'city': city,
      };

  factory LocationData.fromJson(dynamic raw) {
    if (raw is! Map) return const LocationData();
    final m = Map<String, dynamic>.from(raw);
    return LocationData(
      countryCode: (m['country_code'] ?? m['countryCode'] ?? '')
          .toString()
          .toUpperCase(),
      country: (m['country'] ?? '').toString(),
      state: (m['state'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
    );
  }

  /// Eski ilan kayıtlarından (sadece city/district) konum çıkarır.
  factory LocationData.fromLegacy({
    required String city,
    required String district,
    String countryCode = 'TR',
    String country = 'Türkiye',
  }) {
    return LocationData(
      countryCode: countryCode.toUpperCase(),
      country: country,
      state: city.trim(),
      city: district.trim(),
    );
  }

  LocationData copyWith({
    String? countryCode,
    String? country,
    String? state,
    String? city,
  }) =>
      LocationData(
        countryCode: countryCode ?? this.countryCode,
        country: country ?? this.country,
        state: state ?? this.state,
        city: city ?? this.city,
      );

  String get displayLine {
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationData &&
          other.countryCode == countryCode &&
          other.country == country &&
          other.state == state &&
          other.city == city;

  @override
  int get hashCode => Object.hash(countryCode, country, state, city);
}

class LocCountry {
  const LocCountry({
    required this.code,
    required this.nameTr,
    required this.nameEn,
    required this.nameNative,
    required this.flagEmoji,
    this.sortOrder = 0,
  });

  final String code;
  final String nameTr;
  final String nameEn;
  final String nameNative;
  final String flagEmoji;
  final int sortOrder;

  String labelFor(AppLang lang) => switch (lang) {
        AppLang.tr => nameTr,
        AppLang.en => nameEn,
        AppLang.de => nameNative.isNotEmpty ? nameNative : nameEn,
        AppLang.ar => nameNative.isNotEmpty ? nameNative : nameEn,
        AppLang.fr => nameNative.isNotEmpty ? nameNative : nameEn,
      };

  /// State alanı için UI etiketi (ülkeye göre).
  String stateLabelTr() => switch (code) {
        'TR' => 'İl',
        'DE' => 'Eyalet',
        'GB' => 'Bölge',
        'SA' => 'Bölge',
        'FR' => 'Bölge',
        _ => 'Bölge',
      };

  /// City alanı için UI etiketi.
  String cityLabelTr() => switch (code) {
        'TR' => 'İlçe',
        _ => 'Şehir',
      };

  factory LocCountry.fromJson(Map<String, dynamic> j) => LocCountry(
        code: (j['code'] ?? '').toString().toUpperCase(),
        nameTr: (j['name_tr'] ?? j['nameTr'] ?? '').toString(),
        nameEn: (j['name_en'] ?? j['nameEn'] ?? '').toString(),
        nameNative: (j['name_native'] ?? j['nameNative'] ?? '').toString(),
        flagEmoji: (j['flag_emoji'] ?? j['flagEmoji'] ?? '').toString(),
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class LocState {
  const LocState({
    required this.id,
    required this.countryCode,
    required this.name,
    this.code = '',
  });

  final int id;
  final String countryCode;
  final String name;
  final String code;

  factory LocState.fromJson(Map<String, dynamic> j) => LocState(
        id: (j['id'] as num?)?.toInt() ?? 0,
        countryCode: (j['country_code'] ?? '').toString().toUpperCase(),
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
      );
}

class LocCity {
  const LocCity({
    required this.id,
    required this.countryCode,
    required this.stateId,
    required this.name,
  });

  final int id;
  final String countryCode;
  final int stateId;
  final String name;

  factory LocCity.fromJson(Map<String, dynamic> j) => LocCity(
        id: (j['id'] as num?)?.toInt() ?? 0,
        countryCode: (j['country_code'] ?? '').toString().toUpperCase(),
        stateId: (j['state_id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
      );
}

/// Dil seçeneğinden varsayılan ülke.
String countryCodeForLang(AppLang lang) => switch (lang) {
      AppLang.tr => 'TR',
      AppLang.en => 'GB',
      AppLang.de => 'DE',
      AppLang.ar => 'SA',
      AppLang.fr => 'FR',
    };
