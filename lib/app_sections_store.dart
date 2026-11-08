import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'utils/async_timeout.dart';

const kUzmanKosesSectionKey = 'uzman_kosesi';
const kDefaultUzmanKosesTitle = 'Uzman Profilleri Köşesi';

class AppSection {
  const AppSection({
    required this.sectionKey,
    required this.title,
    this.coverImageUrl = '',
  });

  final String sectionKey;
  final String title;
  final String coverImageUrl;

  bool get hasCover => coverImageUrl.trim().isNotEmpty;

  factory AppSection.fromJson(Map<String, dynamic> json) => AppSection(
        sectionKey: (json['section_key']?.toString() ?? '').trim().toLowerCase(),
        title: (json['title']?.toString() ?? '').trim(),
        coverImageUrl: (json['cover_image_url']?.toString() ?? '').trim(),
      );
}

const kDefaultUzmanKosesSection = AppSection(
  sectionKey: kUzmanKosesSectionKey,
  title: kDefaultUzmanKosesTitle,
);

AppSection? _uzmanCache;
DateTime? _uzmanCacheAt;
const _ttl = Duration(minutes: 10);

void invalidateAppSectionsCache() {
  _uzmanCache = null;
  _uzmanCacheAt = null;
}

bool get hasFreshUzmanKosesCache {
  final at = _uzmanCacheAt;
  final row = _uzmanCache;
  if (at == null || row == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

AppSection? get cachedUzmanKoses => _uzmanCache;

AppSection _withFallback(AppSection? row) {
  var title = (row?.title.trim().isNotEmpty == true)
      ? row!.title.trim()
      : kDefaultUzmanKosesTitle;
  if (title == 'Uzman Köşesi') title = kDefaultUzmanKosesTitle;
  return AppSection(
    sectionKey: kUzmanKosesSectionKey,
    title: title,
    coverImageUrl: row?.coverImageUrl.trim() ?? '',
  );
}

Future<AppSection> loadUzmanKosesSection({bool forceRefresh = false}) async {
  if (!forceRefresh && hasFreshUzmanKosesCache) {
    return _withFallback(_uzmanCache);
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('app_sections')
          .select()
          .eq('section_key', kUzmanKosesSectionKey)
          .limit(1),
    );
    AppSection? found;
    for (final e in (rows as List).whereType<Map>()) {
      found = AppSection.fromJson(Map<String, dynamic>.from(e));
      break;
    }
    final resolved = _withFallback(found);
    _uzmanCache = resolved;
    _uzmanCacheAt = DateTime.now();
    return resolved;
  } catch (_) {
    if (_uzmanCache != null) return _withFallback(_uzmanCache);
    return kDefaultUzmanKosesSection;
  }
}

Future<void> upsertUzmanKosesSection({
  required String title,
  required String coverImageUrl,
  required String adminEmail,
}) async {
  if (!isAppAdmin(adminEmail)) {
    throw StateError('Yalnızca admin bu kartı düzenleyebilir.');
  }
  final name = title.trim();
  if (name.isEmpty) {
    throw StateError('Kart adı boş olamaz.');
  }
  await Supabase.instance.client.from('app_sections').upsert({
    'section_key': kUzmanKosesSectionKey,
    'title': name,
    'cover_image_url': coverImageUrl.trim(),
    'updated_by': adminEmail.trim().toLowerCase(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
  _uzmanCache = AppSection(
    sectionKey: kUzmanKosesSectionKey,
    title: name,
    coverImageUrl: coverImageUrl.trim(),
  );
  _uzmanCacheAt = DateTime.now();
}
