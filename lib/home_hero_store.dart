import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';

class HomeHeroSlide {
  const HomeHeroSlide({
    required this.id,
    required this.imageUrl,
    this.altText = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String imageUrl;
  final String altText;
  final int sortOrder;
  final bool isActive;

  bool get isAsset => imageUrl.trim().startsWith('asset:');
  String get assetPath => imageUrl.trim().replaceFirst('asset:', '');

  bool get isNetwork {
    final u = imageUrl.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  HomeHeroSlide copyWith({
    String? imageUrl,
    String? altText,
    int? sortOrder,
    bool? isActive,
  }) =>
      HomeHeroSlide(
        id: id,
        imageUrl: imageUrl ?? this.imageUrl,
        altText: altText ?? this.altText,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );

  factory HomeHeroSlide.fromJson(Map<String, dynamic> json) => HomeHeroSlide(
        id: (json['id'] as num?)?.toInt() ?? 0,
        imageUrl: json['image_url']?.toString() ?? '',
        altText: json['alt_text']?.toString() ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] != false,
      );
}

/// Varsayılan paket görselleri (tablo boş / erişilemezse).
const kDefaultHomeHeroSlides = <HomeHeroSlide>[
  HomeHeroSlide(
    id: -1,
    imageUrl: 'asset:assets/images/118547.png',
    altText: 'Terapist ve özel gereksinimli çocuk yürüyüş terapisinde',
    sortOrder: 1,
  ),
  HomeHeroSlide(
    id: -2,
    imageUrl: 'asset:assets/images/118587-1.png',
    altText: 'Gökkuşağı altında mutlu iki çocuk',
    sortOrder: 2,
  ),
  HomeHeroSlide(
    id: -3,
    imageUrl: 'asset:assets/images/118600.png',
    altText: 'Anne ve yeni doğan bebeği hastanede',
    sortOrder: 3,
  ),
];

List<HomeHeroSlide>? _cache;
DateTime? _cacheAt;
const _ttl = Duration(minutes: 10);

List<HomeHeroSlide>? get cachedHomeHeroSlides => _cache;

bool get hasFreshHomeHeroCache {
  final at = _cacheAt;
  final list = _cache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

void invalidateHomeHeroCache() {
  _cache = null;
  _cacheAt = null;
}

Future<List<HomeHeroSlide>> loadHomeHeroSlides({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  if (!forceRefresh && hasFreshHomeHeroCache) {
    return List<HomeHeroSlide>.from(_cache!);
  }
  try {
    final admin = isAppAdmin(viewerEmail);
    var q = Supabase.instance.client.from('home_hero_slides').select();
    if (!admin) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('sort_order').order('id');
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => HomeHeroSlide.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.imageUrl.trim().isNotEmpty)
        .toList();
    if (list.isEmpty) {
      _cache = List.unmodifiable(kDefaultHomeHeroSlides);
    } else {
      _cache = List.unmodifiable(list);
    }
    _cacheAt = DateTime.now();
    return List<HomeHeroSlide>.from(_cache!);
  } catch (_) {
    if (_cache != null) return List<HomeHeroSlide>.from(_cache!);
    return List<HomeHeroSlide>.from(kDefaultHomeHeroSlides);
  }
}

Future<HomeHeroSlide> addHomeHeroSlide({
  required String imageUrl,
  String altText = '',
  int? sortOrder,
  required String adminEmail,
}) async {
  if (!isAppAdmin(adminEmail)) {
    throw StateError('Yalnızca admin geçiş görseli ekleyebilir.');
  }
  final nextOrder = sortOrder ??
      ((_cache?.isNotEmpty == true
              ? _cache!.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b)
              : 0) +
          1);
  final row = await Supabase.instance.client
      .from('home_hero_slides')
      .insert({
        'image_url': imageUrl.trim(),
        'alt_text': altText.trim(),
        'sort_order': nextOrder,
        'is_active': true,
        'created_by': adminEmail.trim().toLowerCase(),
      })
      .select()
      .single();
  invalidateHomeHeroCache();
  return HomeHeroSlide.fromJson(Map<String, dynamic>.from(row));
}

Future<HomeHeroSlide> updateHomeHeroSlide({
  required int id,
  String? imageUrl,
  String? altText,
  int? sortOrder,
  bool? isActive,
}) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  if (!isAppAdmin(email)) {
    throw StateError('Yalnızca admin güncelleyebilir.');
  }
  final payload = <String, dynamic>{
    if (imageUrl != null) 'image_url': imageUrl.trim(),
    if (altText != null) 'alt_text': altText.trim(),
    if (sortOrder != null) 'sort_order': sortOrder,
    if (isActive != null) 'is_active': isActive,
  };
  if (payload.isEmpty) {
    throw StateError('Güncellenecek alan yok.');
  }
  final row = await Supabase.instance.client
      .from('home_hero_slides')
      .update(payload)
      .eq('id', id)
      .select()
      .single();
  invalidateHomeHeroCache();
  return HomeHeroSlide.fromJson(Map<String, dynamic>.from(row));
}

Future<void> deleteHomeHeroSlide(int id) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  if (!isAppAdmin(email)) {
    throw StateError('Yalnızca admin silebilir.');
  }
  await Supabase.instance.client.from('home_hero_slides').delete().eq('id', id);
  invalidateHomeHeroCache();
}
