import 'dart:convert';

const kGlobalNewsStatuses = <String>{
  'pending_review',
  'published',
  'rejected',
};

const kGlobalNewsCategories = <String, String>{
  'tumu': 'Tümü',
  'erisilebilirlik': 'Erişilebilirlik',
  'haklar': 'Haklar',
  'tedavi': 'Tedavi',
  'genetik': 'Genetik',
  'noroteknoloji': 'Nöro-teknoloji',
  'klinik': 'Klinik araştırma',
  'diger': 'Diğer',
};

String normalizeGlobalNewsStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s == 'approved' || s == 'approve' || s == 'onaylandi') return 'published';
  if (s == 'pending' || s == 'review' || s == 'draft') return 'pending_review';
  if (s == 'hidden' || s == 'gizle' || s == 'withdrawn') return 'rejected';
  if (kGlobalNewsStatuses.contains(s)) return s;
  return 'pending_review';
}

bool isPublishedGlobalNews(String status) =>
    normalizeGlobalNewsStatus(status) == 'published';

bool isPendingGlobalNews(String status) =>
    normalizeGlobalNewsStatus(status) == 'pending_review';

class GlobalNewsItem {
  const GlobalNewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.sourceName,
    required this.sourceUrl,
    this.titleOriginal = '',
    this.imageUrl = '',
    required this.status,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String sourceName;
  final String sourceUrl;
  final String titleOriginal;
  final String imageUrl;
  final String status;
  final DateTime? publishedAt;

  String get categoryLabel =>
      kGlobalNewsCategories[category] ?? kGlobalNewsCategories['diger']!;

  GlobalNewsItem applyOverride(GlobalNewsOverride? o) {
    if (o == null) return this;
    return copyWith(
      title: o.title,
      summary: o.summary,
      imageUrl: o.imageUrl,
      status: o.status,
    );
  }

  GlobalNewsItem copyWith({
    String? title,
    String? summary,
    String? imageUrl,
    String? status,
  }) {
    final nextTitle = (title ?? this.title).trim();
    final nextImage = (imageUrl ?? this.imageUrl).trim();
    return GlobalNewsItem(
      id: id,
      title: nextTitle.isEmpty ? this.title : nextTitle,
      summary: summary ?? this.summary,
      category: category,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      titleOriginal: titleOriginal,
      imageUrl: nextImage.isEmpty ? this.imageUrl : nextImage,
      status: normalizeGlobalNewsStatus(status ?? this.status),
      publishedAt: publishedAt,
    );
  }

  factory GlobalNewsItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
    }

    final url = json['source_url']?.toString().trim() ??
        json['url']?.toString().trim() ??
        '';
    final idRaw = json['id']?.toString().trim() ?? '';
    return GlobalNewsItem(
      id: idRaw.isNotEmpty ? idRaw : url,
      title: json['title']?.toString().trim() ?? '',
      summary: json['summary']?.toString().trim() ?? '',
      category: (json['category']?.toString().trim().toLowerCase().isEmpty ??
              true)
          ? 'diger'
          : json['category'].toString().trim().toLowerCase(),
      sourceName: json['source_name']?.toString().trim() ?? '',
      sourceUrl: url,
      titleOriginal: json['title_original']?.toString().trim() ?? '',
      imageUrl: json['image_url']?.toString().trim() ?? '',
      status: normalizeGlobalNewsStatus(
        json['status']?.toString() ?? 'pending_review',
      ),
      publishedAt: parseTs(json['published_at'] ?? json['fetchedAt']),
    );
  }
}

class GlobalNewsOverride {
  const GlobalNewsOverride({
    required this.newsId,
    required this.status,
    this.title,
    this.summary,
    this.imageUrl,
  });

  final String newsId;
  final String status;
  final String? title;
  final String? summary;
  final String? imageUrl;

  factory GlobalNewsOverride.fromJson(Map<String, dynamic> json) {
    return GlobalNewsOverride(
      newsId: json['news_id']?.toString().trim() ?? '',
      status: normalizeGlobalNewsStatus(
        json['status']?.toString() ?? 'pending_review',
      ),
      title: json['title']?.toString().trim(),
      summary: json['summary']?.toString().trim(),
      imageUrl: json['image_url']?.toString().trim(),
    );
  }
}

List<GlobalNewsItem> parseGlobalNewsJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const [];
  }
  List<dynamic> list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map) {
    final nested = decoded['items'] ?? decoded['news'] ?? decoded['data'];
    list = nested is List ? nested : const [];
  } else {
    list = const [];
  }
  return list
      .whereType<Map>()
      .map((e) => GlobalNewsItem.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.id.isNotEmpty && e.sourceUrl.isNotEmpty)
      .toList();
}
