import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/centers_data.dart';
import '../data/turkish_cities_data.dart';
import '../meto_theme.dart';
import '../services/centers_google_places_service.dart';
import '../services/centers_osm_service.dart';
import '../services/google_places_config.dart';

enum _LocStatus { idle, loading, ok, denied }

class _CenterWithDist {
  const _CenterWithDist({required this.center, required this.distKm});

  final MetoCenter center;
  final double distKm;
}

/// Merkezler sekmesi — Google Places Nearby Search (ana) + OSM yedek.
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
  final MapController _mapController = MapController();

  List<MetoCenter> _liveCenters = const [];
  bool _centersLoading = false;
  String? _centersError;
  String? _dataNote;
  double? _focusLat;
  double? _focusLng;

  @override
  void initState() {
    super.initState();
    // Önce konum; ardından yakın merkezleri gerçek konumdan çek
    _detectLocation().then((_) {
      if (_locStatus != _LocStatus.ok) {
        _refreshCenters();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
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

  List<MetoCenter> get _sourceCenters {
    // Canlı OSM sonuçları varsa onları kullan; yoksa yerel yedek.
    if (_liveCenters.isNotEmpty) return _liveCenters;
    return kCenters.where((c) => c.city == _selectedCity).toList();
  }

  bool _matchesCategory(MetoCenter c) {
    if (_filter == 'Tümü') return true;
    final f = _filter.toLowerCase();
    final hay = [
      c.category,
      ...c.services,
      c.name,
    ].join(' ').toLowerCase();
    // Filtre kısa anahtar kelimesiyle eşle (İ/i sorununu azalt).
    final key = switch (_filter) {
      'Fizik Tedavi' => 'fizik',
      'Özel Eğitim' => 'özel eğitim',
      'Dil Terapisi' => 'dil',
      'Nöroloji' => 'nöro',
      _ => f,
    };
    final keyAlt = key
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c');
    final hayNorm = hay
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c');
    return hay.contains(key) || hayNorm.contains(keyAlt);
  }

  /// Seçilen il/ilçe için merkezleri döndürür.
  ({List<_CenterWithDist> items, String? note}) get _listing {
    final origin = _mapCenter;
    final q = _searchController.text.trim().toLowerCase();

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
          .toList();
      list.sort((a, b) => a.distKm.compareTo(b.distKm));
      return list;
    }

    final pool = _sourceCenters.where(_matchesCategory).where(matchesSearch);

    // 1) Seçilen ilçe (esnek eşleşme)
    if (_selectedIlce != kAllIlceler) {
      final exact = pool.where((c) => CentersOsmService.matchesIlce(c, _selectedIlce));
      if (exact.isNotEmpty) {
        return (items: build(exact), note: _dataNote);
      }
      final cityWide = pool.toList();
      if (cityWide.isNotEmpty) {
        return (
          items: build(cityWide),
          note:
              '$_selectedIlce için birebir kayıt bulunamadı — $_selectedCity genelindeki merkezler (mesafeye göre) gösteriliyor.',
        );
      }
    } else if (pool.isNotEmpty) {
      return (items: build(pool), note: _dataNote);
    }

    // 2) Yerel yedek + en yakınlar
    final fallback = kCenters.where(_matchesCategory).where(matchesSearch);
    final nearest = build(fallback).take(12).toList();
    if (nearest.isNotEmpty) {
      return (
        items: nearest,
        note:
            '$_selectedCity için canlı harita sonucu bulunamadı — kayıtlı yedek merkezler gösteriliyor.',
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

    final cityInfo = _cityInfo;
    var focusLat = cityInfo.lat;
    var focusLng = cityInfo.lng;

    // İlçe seçildiyse gerçek ilçe merkezini geocode et
    if (_selectedIlce != kAllIlceler) {
      final geo = await CentersOsmService.geocodePlace(
        city: _selectedCity,
        ilce: _selectedIlce,
      );
      if (geo != null) {
        focusLat = geo.lat;
        focusLng = geo.lng;
      }
    } else if (_userLat == null) {
      final geo = await CentersOsmService.geocodePlace(city: _selectedCity);
      if (geo != null) {
        focusLat = geo.lat;
        focusLng = geo.lng;
      }
    }

    // Konum açıksa kullanıcı konumundan ara
    final searchLat =
        (_locStatus == _LocStatus.ok && _userLat != null) ? _userLat! : focusLat;
    final searchLng =
        (_locStatus == _LocStatus.ok && _userLng != null) ? _userLng! : focusLng;

    var live = <MetoCenter>[];
    var sourceLabel = '';

    // 1) Google Places Nearby Search (API anahtarı varsa)
    if (GooglePlacesConfig.isConfigured) {
      try {
        live = await CentersGooglePlacesService.searchNearby(
          latitude: searchLat,
          longitude: searchLng,
          city: _selectedCity,
          radiusKm: 40,
        );
        if (live.isNotEmpty) {
          sourceLabel = 'Google Places';
        }
      } catch (e) {
        debugPrint('Google Places hata: $e');
      }
    }

    // 2) Anahtar yoksa veya sonuç boşsa OSM yedek
    if (live.isEmpty) {
      live = await CentersOsmService.fetchNear(
        lat: searchLat,
        lng: searchLng,
        city: _selectedCity,
        radiusKm: 50,
      );
      if (live.isNotEmpty) {
        sourceLabel = GooglePlacesConfig.isConfigured
            ? 'OpenStreetMap (Google sonuç vermedi)'
            : 'OpenStreetMap';
      }
    }

    if (!mounted) return;
    setState(() {
      // Konum açıksa harita kullanıcının olduğu yere odaklansın
      if (_locStatus == _LocStatus.ok && _userLat != null && _userLng != null) {
        _focusLat = _userLat;
        _focusLng = _userLng;
      } else {
        _focusLat = focusLat;
        _focusLng = focusLng;
      }
      _liveCenters = live;
      _centersLoading = false;
      if (live.isEmpty) {
        _centersError = GooglePlacesConfig.isConfigured
            ? 'Bu bölgede merkez bulunamadı. Konum izni verip “Konumumu bul”a basın veya ili değiştirin.'
            : 'Google Places API anahtarı yok ve OSM sonuç vermedi. '
                'lib/services/google_places_config.dart içine anahtar ekleyin.';
        _dataNote = null;
      } else {
        _centersError = null;
        _dataNote =
            '$sourceLabel · ${live.length} merkez · mesafeye göre sıralı';
      }
    });
    final mapLat = _focusLat ?? focusLat;
    final mapLng = _focusLng ?? focusLng;
    _moveMap(
      mapLat,
      mapLng,
      zoom: _locStatus == _LocStatus.ok
          ? 12.5
          : (_selectedIlce == kAllIlceler ? 11 : 13),
    );
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
    setState(() {
      _selectedCity = city;
      _selectedIlce = kAllIlceler;
      _locStatus = _LocStatus.idle;
      _userLat = null;
      _userLng = null;
      _liveCenters = const [];
    });
    final info = kTurkishCities[city]!;
    _moveMap(info.lat, info.lng, zoom: 11);
    _refreshCenters();
  }

  void _onIlceChanged(String ilce) {
    setState(() {
      _selectedIlce = ilce;
      // İlçe değişince kullanıcı konumunu koru ama odak ilçeye kayar.
    });
    _refreshCenters();
  }

  void _selectCenter(MetoCenter center) {
    setState(() => _selectedCenter = center);
    _moveMap(center.lat, center.lng, zoom: 14);
  }

  void _moveMap(double lat, double lng, {required double zoom}) {
    try {
      _mapController.move(LatLng(lat, lng), zoom);
    } catch (_) {
      // Harita henüz mount edilmediyse sessizce geç.
    }
  }

  Future<void> _openDirections(MetoCenter center) async {
    final from = _mapCenter;
    final uri = Uri.parse(
      'https://www.openstreetmap.org/directions'
      '?from=${from.lat},${from.lng}&to=${center.lat},${center.lng}',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const Text(
                            'Yakındaki Merkezler',
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
                                ? '📍 Konumunuza göre sıralandı'
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
                          decoration: const InputDecoration(
                            hintText: 'Merkez adı veya hizmet ara...',
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
                _OpenStreetMapView(
                  mapController: _mapController,
                  centers: _mapCenters,
                  focus: _mapCenter,
                  userLat: _userLat,
                  userLng: _userLng,
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
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MetoColors.primary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Yakındaki merkezler Google Places ile aranıyor…',
                            style: TextStyle(
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
          Expanded(
            child: Builder(
              builder: (context) {
                final listing = _listing;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                    if (listing.items.isEmpty) const _EmptySearch(),
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
                    label: const Text(
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
                    child: const Text('🏥', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 12),
                  Text(
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
                      const Text(
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
                            const Text(
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
                                Text(
                                  '${center.rating}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
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
                          const Text(
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
                        child: const Text('Yol Tarifi'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
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
                        child: const Text('Randevu Al'),
                      ),
                    ),
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
                    ? 'Alınıyor'
                    : ok
                        ? 'Konumum'
                        : 'Konumumu Bul',
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

class _OpenStreetMapView extends StatelessWidget {
  const _OpenStreetMapView({
    required this.mapController,
    required this.centers,
    required this.focus,
    required this.userLat,
    required this.userLng,
    required this.onSelectCenter,
  });

  final MapController mapController;
  final List<_CenterWithDist> centers;
  final ({double lat, double lng}) focus;
  final double? userLat;
  final double? userLng;
  final ValueChanged<MetoCenter> onSelectCenter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          border: Border.all(color: MetoColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: LatLng(focus.lat, focus.lng),
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.engelsizclub.metocare',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final item in centers)
                  Marker(
                    point: LatLng(item.center.lat, item.center.lng),
                    width: 30,
                    height: 30,
                    child: GestureDetector(
                      onTap: () => onSelectCenter(item.center),
                      child: Container(
                        decoration: BoxDecoration(
                          color: item.center.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('🏥', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                if (userLat != null && userLng != null)
                  Marker(
                    point: LatLng(userLat!, userLng!),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
          Text(
            'Merkez bulunamadı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          SizedBox(height: 4),
          Text(
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
                    child: const Text('🏥', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                              child: Text(
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
                            Text(
                              '${center.rating}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ] else
                            const Text(
                              'OSM',
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
            Text(
              'Medikal Cihaz Firmaları',
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
      ).showSnackBar(SnackBar(content: Text('Ara: ${vendor.phone}')));
    }
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
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
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
                            child: const Text(
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
                  child: Text('Ara: ${vendor.phone}'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
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
                child: const Text('Detay'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
