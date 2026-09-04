import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/centers_data.dart';
import '../data/turkish_cities_data.dart';
import '../meto_theme.dart';
import '../utils/async_timeout.dart';
import '../services/centers_google_geocode_service.dart';
import '../services/centers_google_places_service.dart';
import '../services/google_places_config.dart';
import '../widgets/web_google_map.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';

enum _LocStatus { idle, loading, ok, denied }

class _CenterWithDist {
  const _CenterWithDist({required this.center, required this.distKm});

  final MetoCenter center;
  final double distKm;
}

/// Merkezler — Google Maps + Places API (New).
class MerkezlerPage extends StatefulWidget {
  const MerkezlerPage({super.key});

  @override
  State<MerkezlerPage> createState() => _MerkezlerPageState();
}

class _MerkezlerPageState extends State<MerkezlerPage> {
  String _filter = 'Tümü';
  MetoCenter? _selectedCenter;
  final _searchController = TextEditingController();
  String _selectedCity = kDefaultCity;
  String _selectedIlce = kAllIlceler;
  double? _userLat;
  double? _userLng;
  _LocStatus _locStatus = _LocStatus.idle;
  GoogleMapController? _mapController;
  double? _cameraLat;
  double? _cameraLng;
  double _cameraZoom = 12;

  List<MetoCenter> _liveCenters = const [];
  bool _centersLoading = false;
  String? _centersError;
  String? _dataNote;
  double? _focusLat;
  double? _focusLng;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  TurkishCity get _cityInfo => kTurkishCities[_selectedCity]!;

  ({double lat, double lng}) get _mapCenter {
    if (_userLat != null && _userLng != null && _locStatus == _LocStatus.ok) {
      return (lat: _userLat!, lng: _userLng!);
    }
    if (_focusLat != null && _focusLng != null) {
      return (lat: _focusLat!, lng: _focusLng!);
    }
    return (lat: _cityInfo.lat, lng: _cityInfo.lng);
  }

  ({double lat, double lng}) get _mapCamera {
    if (_cameraLat != null && _cameraLng != null) {
      return (lat: _cameraLat!, lng: _cameraLng!);
    }
    return _mapCenter;
  }

  static String _normTr(String s) {
    return s
        .toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Seçilen ile ait mi? (yanlış şehirdeki sonuçları ele)
  bool _matchesSelectedCity(MetoCenter c, {double? focusLat, double? focusLng}) {
    final selected = _normTr(_selectedCity);
    final stamped = _normTr(c.city);
    final addr = _normTr('${c.address} ${c.ilce} ${c.name}');

    // Adreste başka büyük şehir açıkça geçiyorsa ve seçilen şehir yoksa ele
    for (final other in kCityNames) {
      final nOther = _normTr(other);
      if (nOther == selected || nOther.length < 5) continue;
      if (addr.contains(nOther) && !addr.contains(selected) && stamped != selected) {
        return false;
      }
    }

    if (stamped == selected || addr.contains(selected)) return true;

    // Şehir yazısı yoksa koordinatla doğrula (seçilen il merkezine yakın olmalı)
    final lat = focusLat ?? _cityInfo.lat;
    final lng = focusLng ?? _cityInfo.lng;
    final maxKm = _selectedIlce == kAllIlceler ? 70.0 : 28.0;
    return geoDistanceKm(lat, lng, c.lat, c.lng) <= maxKm;
  }

  List<MetoCenter> get _sourceCenters {
    final lat = _focusLat ?? _cityInfo.lat;
    final lng = _focusLng ?? _cityInfo.lng;
    if (_liveCenters.isNotEmpty) {
      final filtered = _liveCenters
          .where((c) => _matchesSelectedCity(c, focusLat: lat, focusLng: lng))
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    return kCenters
        .where((c) => _normTr(c.city) == _normTr(_selectedCity))
        .where((c) {
          final n = _normTr('${c.category} ${c.name}');
          final dilOrNoro = n.contains('dil') ||
              n.contains('konusma') ||
              n.contains('norolo') ||
              n.contains('neuro');
          if (!dilOrNoro) return true;
          return n.contains('fizik') ||
              n.contains('ozel egitim') ||
              n.contains('rehabilitasyon') ||
              n.contains('medikal');
        })
        .toList();
  }

  bool _matchesCategory(MetoCenter c) {
    if (_filter == 'Tümü') return true;
    final hayNorm = _normTr(
      [c.category, ...c.services, c.name].join(' '),
    );
    return switch (_filter) {
      'Fizik Tedavi' =>
        hayNorm.contains('fizik') || hayNorm.contains('fizyo'),
      'Özel Eğitim' =>
        hayNorm.contains('ozel egitim') ||
            hayNorm.contains('egitim') ||
            hayNorm.contains('rehabilitasyon') ||
            hayNorm.contains('oerm') ||
            hayNorm.contains('aba'),
      'Medikal' =>
        hayNorm.contains('medikal') ||
            hayNorm.contains('ortoped') ||
            hayNorm.contains('ortez') ||
            hayNorm.contains('protez') ||
            hayNorm.contains('malzeme') ||
            hayNorm.contains('cihaz'),
      _ => hayNorm.contains(_normTr(_filter)),
    };
  }

  /// Seçilen il/ilçe için merkezleri döndürür.
  ({List<_CenterWithDist> items, String? note}) get _listing {
    final origin = _mapCenter;
    final q = _searchController.text.trim().toLowerCase();
    final maxKm = _locStatus == _LocStatus.ok
        ? 45.0
        : (_selectedIlce == kAllIlceler ? 70.0 : 28.0);

    bool matchesSearch(MetoCenter c) =>
        q.isEmpty ||
        [c.name, c.category, c.address, c.ilce, ...c.services]
            .any((f) => f.toLowerCase().contains(q));

    List<_CenterWithDist> build(Iterable<MetoCenter> src) {
      final list = src
          .map(
            (c) => _CenterWithDist(
              center: c,
              distKm: geoDistanceKm(origin.lat, origin.lng, c.lat, c.lng),
            ),
          )
          .where((e) => e.distKm <= maxKm + 8)
          .toList();
      list.sort((a, b) => a.distKm.compareTo(b.distKm));
      return list;
    }

    // Her zaman seçilen ile kilitle
    final pool = _sourceCenters
        .where((c) => _matchesSelectedCity(c))
        .where(_matchesCategory)
        .where(matchesSearch);

    if (_selectedIlce != kAllIlceler) {
      final exact =
          pool.where((c) => _matchesIlce(c, _selectedIlce));
      if (exact.isNotEmpty) {
        return (items: build(exact), note: _dataNote);
      }
      final cityWide = pool.toList();
      if (cityWide.isNotEmpty) {
        return (
          items: build(cityWide),
          note:
              '$_selectedIlce için birebir kayıt bulunamadı — $_selectedCity genelindeki merkezler gösteriliyor.',
        );
      }
    } else if (pool.isNotEmpty) {
      return (items: build(pool), note: _dataNote);
    }

    // Yedek: yalnız seçilen ilin kayıtlı merkezleri (başka şehir ASLA)
    final fallback = kCenters
        .where((c) => _normTr(c.city) == _normTr(_selectedCity))
        .where(_matchesCategory)
        .where(matchesSearch);
    final nearest = build(fallback);
    if (nearest.isNotEmpty) {
      return (
        items: nearest,
        note:
            '$_selectedCity için canlı sonuç sınırlı — kayıtlı $_selectedCity merkezleri gösteriliyor.',
      );
    }

    return (items: <_CenterWithDist>[], note: _centersError);
  }

  List<_CenterWithDist> get _mapCenters => _listing.items;

  Future<void> _refreshCenters() async {
    setState(() {
      _centersLoading = true;
      _centersError = null;
    });

    try {
      final cityInfo = _cityInfo;
      var focusLat = cityInfo.lat;
      var focusLng = cityInfo.lng;

      // İlçe seçildiyse gerçek ilçe merkezini geocode et
      if (_selectedIlce != kAllIlceler) {
        final geo = await withNetworkTimeout(
          CentersGoogleGeocodeService.geocodePlace(
            city: _selectedCity,
            ilce: _selectedIlce,
          ),
          message: 'Konum bilgisi alınamadı.',
        );
        if (geo != null) {
          focusLat = geo.lat;
          focusLng = geo.lng;
        }
      } else if (_userLat == null) {
        final geo = await withNetworkTimeout(
          CentersGoogleGeocodeService.geocodePlace(city: _selectedCity),
          message: 'Konum bilgisi alınamadı.',
        );
        if (geo != null) {
          focusLat = geo.lat;
          focusLng = geo.lng;
        }
      }

      // GPS yalnız “Konumumu bul” sonrası kullanılır; yoksa seçilen il/ilçe.
      final useGps =
          _locStatus == _LocStatus.ok && _userLat != null && _userLng != null;
      final searchLat = useGps ? _userLat! : focusLat;
      final searchLng = useGps ? _userLng! : focusLng;

      var live = <MetoCenter>[];
      var sourceLabel = '';
      String? placesError;

      // Google Places API (New) — özel eğitim / fizik tedavi / medikal
      if (!GooglePlacesConfig.isConfigured) {
        placesError = 'Google Maps API anahtarı tanımlı değil.';
      } else {
        try {
          live = await withNetworkTimeout(
            CentersGooglePlacesService.searchNearby(
              latitude: searchLat,
              longitude: searchLng,
              city: _selectedCity,
              radiusKm: useGps
                  ? 40
                  : (_selectedIlce == kAllIlceler ? 45 : 18),
            ),
            timeout: const Duration(seconds: 15),
            message: 'Merkez araması zaman aşımına uğradı.',
          );
          if (live.isNotEmpty) {
            sourceLabel = 'Google Places';
          } else {
            final err = CentersGooglePlacesService.lastError;
            placesError = err;
            debugPrint('[Merkezler] Google boş: $err');
          }
        } catch (e) {
          debugPrint('Google Places hata: $e');
          placesError = e is NetworkTimeoutException
              ? e.message
              : '$e';
        }
      }

      // Yanlış şehir / uzak sonuçları at (Ankara seçip İstanbul gelmesin)
      final radiusLimit = useGps
          ? 50.0
          : (_selectedIlce == kAllIlceler ? 70.0 : 28.0);
      live = live
          .where((c) {
            final near = geoDistanceKm(searchLat, searchLng, c.lat, c.lng) <=
                radiusLimit + 5;
            return near &&
                _matchesSelectedCity(c, focusLat: searchLat, focusLng: searchLng);
          })
          .toList();

      // Yerel katalogdaki seçili il merkezlerini de ekle (özel eğitim eksik kalmasın)
      final localCity = kCenters
          .where((c) => _normTr(c.city) == _normTr(_selectedCity))
          .where((c) {
            if (_selectedIlce == kAllIlceler) return true;
            return _matchesIlce(c, _selectedIlce) ||
                geoDistanceKm(searchLat, searchLng, c.lat, c.lng) <= radiusLimit;
          });
      final merged = <String, MetoCenter>{};
      for (final c in [...live, ...localCity]) {
        final key =
            '${_normTr(c.name)}|${c.lat.toStringAsFixed(4)}|${c.lng.toStringAsFixed(4)}';
        merged.putIfAbsent(key, () => c);
      }
      live = merged.values.toList()
        ..sort((a, b) {
          final da = geoDistanceKm(searchLat, searchLng, a.lat, a.lng);
          final db = geoDistanceKm(searchLat, searchLng, b.lat, b.lng);
          return da.compareTo(db);
        });
      if (live.isNotEmpty && sourceLabel.isEmpty) {
        sourceLabel = 'Kayıtlı katalog';
      } else if (localCity.isNotEmpty && sourceLabel.isNotEmpty) {
        sourceLabel = '$sourceLabel + katalog';
      }

      if (!mounted) return;
      setState(() {
        if (useGps) {
          _focusLat = _userLat;
          _focusLng = _userLng;
        } else {
          _focusLat = focusLat;
          _focusLng = focusLng;
        }
        _liveCenters = live;
        if (live.isEmpty) {
          _centersError = placesError ??
              (useGps
                  ? 'Yakınınızda merkez bulunamadı. İl/ilçe seçerek tekrar deneyin.'
                  : '$_selectedCity${_selectedIlce == kAllIlceler ? '' : ' / $_selectedIlce'} için merkez bulunamadı. Başka ilçe deneyin.');
          _dataNote = null;
        } else {
          _centersError = null;
          final region = useGps
              ? 'Konumunuza göre'
              : (_selectedIlce == kAllIlceler
                  ? _selectedCity
                  : '$_selectedCity / $_selectedIlce');
          _dataNote =
              '$sourceLabel · $region · ${live.length} merkez · mesafeye göre sıralı';
        }
      });
      final mapLat = _focusLat ?? focusLat;
      final mapLng = _focusLng ?? focusLng;
      _moveMap(
        mapLat,
        mapLng,
        zoom: useGps
            ? 12.5
            : (_selectedIlce == kAllIlceler ? 11 : 13),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _centersError = e is NetworkTimeoutException
            ? e.message
            : 'Merkezler yüklenemedi. Tekrar deneyin.';
        _dataNote = null;
      });
    } finally {
      if (mounted) {
        setState(() => _centersLoading = false);
      }
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _locStatus = _LocStatus.loading);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locStatus = _LocStatus.denied);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locStatus = _LocStatus.denied);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final lat = pos.latitude;
      final lng = pos.longitude;

      var closest = kDefaultCity;
      var minD = double.infinity;
      for (final entry in kTurkishCities.entries) {
        final d = geoDistanceKm(lat, lng, entry.value.lat, entry.value.lng);
        if (d < minD) {
          minD = d;
          closest = entry.key;
        }
      }

      if (!mounted) return;
      setState(() {
        _userLat = lat;
        _userLng = lng;
        _locStatus = _LocStatus.ok;
        _selectedCity = closest;
        _selectedIlce = kAllIlceler;
      });
      _moveMap(lat, lng, zoom: 12);
      await _refreshCenters();
    } catch (_) {
      if (!mounted) return;
      setState(() => _locStatus = _LocStatus.denied);
    }
  }

  void _onCityChanged(String city) {
    final info = kTurkishCities[city]!;
    setState(() {
      _selectedCity = city;
      _selectedIlce = kAllIlceler;
      _locStatus = _LocStatus.idle;
      _userLat = null;
      _userLng = null;
      _liveCenters = const [];
      _focusLat = info.lat;
      _focusLng = info.lng;
      _centersError = null;
      _dataNote = null;
    });
    _moveMap(info.lat, info.lng, zoom: 11);
    _refreshCenters();
  }

  void _onIlceChanged(String ilce) {
    setState(() {
      _selectedIlce = ilce;
      // İlçe seçimi GPS’i kapatır — arama bu ilçeye göre yapılır.
      _locStatus = _LocStatus.idle;
      _userLat = null;
      _userLng = null;
      _liveCenters = const [];
    });
    _refreshCenters();
  }

  void _selectCenter(MetoCenter center) {
    setState(() => _selectedCenter = center);
    _moveMap(center.lat, center.lng, zoom: 14);
  }

  bool _matchesIlce(MetoCenter c, String selectedIlce) {
    if (selectedIlce == kAllIlceler) return true;
    final a = _normTr(selectedIlce);
    final b = _normTr(c.ilce);
    if (a.isEmpty || b.isEmpty) return true;
    return b.contains(a) || a.contains(b);
  }

  void _moveMap(double lat, double lng, {required double zoom}) {
    setState(() {
      _cameraLat = lat;
      _cameraLng = lng;
      _cameraZoom = zoom;
    });
    if (kIsWeb) return;
    final c = _mapController;
    if (c == null) return;
    try {
      c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
    } catch (e) {
      debugPrint('[Map] move hata: $e');
    }
  }

  static bool _hasPhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    return digits.length >= 7;
  }

  Future<void> _callPhoneNumber(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length < 7) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Telefon numarası yok.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Ara: $phone')),
      );
    }
  }

  Future<void> _openDirections(MetoCenter center) async {
    final from = _mapCenter;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${from.lat},${from.lng}'
      '&destination=${center.lat},${center.lng}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCenter != null) {
      return _buildDetail(_selectedCenter!);
    }
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const L10nText(
                            'Merkezler',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _locStatus == _LocStatus.ok
                                ? 'Konumunuza göre sıralandı'
                                : _liveCenters.isEmpty && !_centersLoading
                                    ? 'İl/ilçe seçin veya Yakınımdaki merkezleri bul’a basın'
                                    : '$_selectedCity · $_selectedIlce',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LocationButton(
                      status: _locStatus,
                      onTap: _detectLocation,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CityDropdown(
                        value: _selectedCity,
                        items: kCityNames,
                        onChanged: _onCityChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CityDropdown(
                        value: _selectedIlce,
                        items: _cityInfo.ilceler,
                        onChanged: _onIlceChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetoColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 15,
                        color: MetoColors.mutedFg,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 14,
                            color: MetoColors.foreground,
                          ),
                          decoration: InputDecoration(
                            hintText: S.auto('Merkez adı veya hizmet ara...'),
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: MetoColors.mutedFg,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(
                            Icons.close,
                            size: 14,
                            color: MetoColors.mutedFg,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Stack(
              children: [
                _GoogleMapView(
                  centers: _mapCenters,
                  focus: _mapCamera,
                  zoom: _cameraZoom,
                  userLat: _userLat,
                  userLng: _userLng,
                  onMapCreated: (c) => _mapController = c,
                  onSelectCenter: _selectCenter,
                ),
                if (_centersLoading)
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MetoColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locStatus == _LocStatus.ok
                                ? 'Konumunuza göre merkezler aranıyor…'
                                : (_selectedIlce == kAllIlceler
                                    ? '$_selectedCity merkezleri aranıyor…'
                                    : '$_selectedIlce / $_selectedCity aranıyor…'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kCenterCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = kCenterCategories[i];
                return _FilterChip(
                  label: cat,
                  active: _filter == cat,
                  onTap: () => setState(() => _filter = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Builder(
              builder: (context) {
                final listing = _listing;
                return Column(
                  children: [
                    if (listing.note != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Color(0xFFB45309)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                listing.note!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB45309),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (listing.items.isEmpty && _centersError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Text(
                              _centersError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _refreshCenters,
                              icon: const Icon(Icons.refresh),
                              label: const L10nText('Tekrar dene'),
                            ),
                          ],
                        ),
                      )
                    else if (listing.items.isEmpty)
                      const _EmptySearch(),
                    ...listing.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CenterListTile(
                          center: item.center,
                          distKm: item.distKm,
                          onTap: () => _selectCenter(item.center),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _MedicalVendorsSection(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(MetoCenter center) {
    final distKm = geoDistanceKm(
      _mapCenter.lat,
      _mapCenter.lng,
      center.lat,
      center.lng,
    );
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  center.color.withValues(alpha: 0.13),
                  MetoColors.background,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedCenter = null),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: MetoColors.primary,
                    ),
                    label: const L10nText(
                      'Geri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MetoColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: center.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: center.color.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const L10nText('🏥', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 12),
                  L10nText(
                    center.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: center.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      center.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Adres',
                  value: center.address,
                  color: center.color,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefon',
                  value: center.phone,
                  color: center.color,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Çalışma Saatleri',
                  value: center.hours,
                  color: center.color,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetoColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const L10nText(
                        'Sunulan Hizmetler',
                        style: TextStyle(
                          fontSize: 12,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in center.services)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: center.color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: center.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetoColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const L10nText(
                              'Değerlendirme',
                              style: TextStyle(
                                fontSize: 12,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: MetoColors.accentGold,
                                ),
                                const SizedBox(width: 4),
                                L10nText(
                                  '${center.rating}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                L10nText(
                                  '(${center.reviews} yorum)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MetoColors.mutedFg,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const L10nText(
                            'Uzaklık',
                            style: TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDistanceKm(distKm),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _openDirections(center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetoColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          elevation: 1,
                        ),
                        child: const L10nText('Yol Tarifi'),
                      ),
                    ),
                    if (_hasPhone(center.phone)) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _callPhoneNumber(context, center.phone),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MetoColors.primary,
                            side: const BorderSide(
                              color: MetoColors.primary,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const L10nText('Randevu Al'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.status, required this.onTap});

  final _LocStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = status == _LocStatus.ok;
    return Material(
      color: ok ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: status == _LocStatus.loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == _LocStatus.loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ok ? Colors.white : MetoColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.location_on,
                  size: 13,
                  color: ok ? Colors.white : MetoColors.primary,
                ),
              const SizedBox(width: 6),
              Text(
                status == _LocStatus.loading
                    ? 'Aranıyor…'
                    : ok
                        ? 'Yakınımdaki merkezler'
                        : 'Yakınımdaki merkezleri bul',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ok ? Colors.white : MetoColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetoColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more,
              size: 18, color: MetoColors.mutedFg),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MetoColors.foreground,
          ),
          dropdownColor: MetoColors.card,
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _GoogleMapView extends StatefulWidget {
  const _GoogleMapView({
    required this.centers,
    required this.focus,
    required this.zoom,
    required this.userLat,
    required this.userLng,
    required this.onMapCreated,
    required this.onSelectCenter,
  });

  final List<_CenterWithDist> centers;
  final ({double lat, double lng}) focus;
  final double zoom;
  final double? userLat;
  final double? userLng;
  final void Function(GoogleMapController controller) onMapCreated;
  final ValueChanged<MetoCenter> onSelectCenter;

  @override
  State<_GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<_GoogleMapView> {
  GoogleMapController? _controller;

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (var i = 0; i < widget.centers.length; i++) {
      final item = widget.centers[i];
      markers.add(
        Marker(
          markerId: MarkerId('center_$i-${item.center.name}'),
          position: LatLng(item.center.lat, item.center.lng),
          infoWindow: InfoWindow(
            title: item.center.name,
            snippet: item.center.category,
          ),
          onTap: () => widget.onSelectCenter(item.center),
        ),
      );
    }
    if (widget.userLat != null && widget.userLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(widget.userLat!, widget.userLng!),
          infoWindow: const InfoWindow(title: 'Konumun'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  List<WebMapMarker> get _webMarkers {
    final out = <WebMapMarker>[
      for (var i = 0; i < widget.centers.length; i++)
        WebMapMarker(
          id: 'c_$i',
          lat: widget.centers[i].center.lat,
          lng: widget.centers[i].center.lng,
          title: widget.centers[i].center.name,
          snippet: widget.centers[i].center.category,
        ),
    ];
    if (widget.userLat != null && widget.userLng != null) {
      out.add(
        WebMapMarker(
          id: 'user',
          lat: widget.userLat!,
          lng: widget.userLng!,
          title: 'Konumun',
        ),
      );
    }
    return out;
  }

  @override
  void didUpdateWidget(covariant _GoogleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) return;
    final changed = oldWidget.focus.lat != widget.focus.lat ||
        oldWidget.focus.lng != widget.focus.lng ||
        oldWidget.zoom != widget.zoom;
    if (!changed) return;
    try {
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.focus.lat, widget.focus.lng),
            zoom: widget.zoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Map] camera update hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebGoogleMapHost(
        lat: widget.focus.lat,
        lng: widget.focus.lng,
        zoom: widget.zoom,
        markers: _webMarkers,
        height: 220,
        onMarkerTap: (id) {
          if (!id.startsWith('c_')) return;
          final i = int.tryParse(id.substring(2));
          if (i == null || i < 0 || i >= widget.centers.length) return;
          widget.onSelectCenter(widget.centers[i].center);
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: MetoColors.border),
        ),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.focus.lat, widget.focus.lng),
            zoom: widget.zoom,
          ),
          markers: _markers,
          onMapCreated: (c) {
            _controller = c;
            widget.onMapCreated(c);
          },
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MetoColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, size: 22, color: MetoColors.mutedFg),
            ),
          ),
          SizedBox(height: 16),
          L10nText(
            'Merkez bulunamadı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          SizedBox(height: 4),
          L10nText(
            'Bu bölgede kayıtlı merkez yok.',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      ),
    );
  }
}

class _CenterListTile extends StatelessWidget {
  const _CenterListTile({
    required this.center,
    required this.distKm,
    required this.onTap,
  });

  final MetoCenter center;
  final double distKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: center.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const L10nText('🏥', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          center.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          center.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 10,
                              color: MetoColors.mutedFg,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: L10nText(
                                '${center.ilce} · ${center.city}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (center.rating > 0) ...[
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: MetoColors.accentGold,
                            ),
                            const SizedBox(width: 2),
                            L10nText(
                              '${center.rating}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ] else
                            const L10nText(
                              'Maps',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDistanceKm(distKm),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MetoColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in center.services)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: center.color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: center.color,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalVendorsSection extends StatelessWidget {
  const _MedicalVendorsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 16,
              color: MetoColors.accentGold,
            ),
            SizedBox(width: 8),
            L10nText(
              'Yardımcı Ekipman Firmaları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kVendorFilterLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MetoColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kVendorFilterLabels[i],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        for (final v in kMedicalVendors) ...[
          _VendorCard(vendor: v),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});

  final MedicalVendor vendor;

  Future<void> _callPhone(BuildContext context) async {
    final digits = vendor.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: L10nText('Ara: ${vendor.phone}')));
    }
  }

  Future<void> _showVendorDetail(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText(
                  vendor.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                L10nText(
                  '${vendor.city} / ${vendor.district}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 10),
                L10nText(
                  vendor.products.join(', '),
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
                if (vendor.sgk || vendor.cargo) ...[
                  const SizedBox(height: 10),
                  L10nText(
                    [
                      if (vendor.sgk) 'SGK',
                      if (vendor.cargo) 'Kargo',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _callPhone(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: L10nText('Ara: ${vendor.phone}'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: vendor.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(vendor.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    L10nText(
                      vendor.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    L10nText(
                      '${vendor.city} / ${vendor.district}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (vendor.sgk)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'SGK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        if (vendor.cargo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const L10nText(
                              'Kargo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        for (final p in vendor.products.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: vendor.color.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: vendor.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _callPhone(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    elevation: 0,
                  ),
                  child: L10nText('Ara: ${vendor.phone}'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showVendorDetail(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MetoColors.foreground,
                  side: const BorderSide(color: MetoColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const L10nText('Detay'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
