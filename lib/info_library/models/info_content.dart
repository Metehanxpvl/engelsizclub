/// Bilgi Kütüphanesi dinamik içerik modeli (`info_library_contents`).
class InfoContent {
  const InfoContent({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeUrl,
    required this.category,
    required this.createdAt,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String description;
  final String youtubeUrl;
  final String category;
  final DateTime createdAt;
  final bool isActive;
  final int sortOrder;

  factory InfoContent.fromRow(Map<String, dynamic> json) {
    return InfoContent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      youtubeUrl: json['youtube_url']?.toString() ?? '',
      category: json['category']?.toString() ?? 'genel',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// YouTube URL veya ham video ID → 11 karakterlik id.
  String? get youtubeVideoId => extractYoutubeVideoId(youtubeUrl);

  InfoContent copyWith({
    String? title,
    String? description,
    String? youtubeUrl,
    String? category,
    bool? isActive,
    int? sortOrder,
  }) =>
      InfoContent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        youtubeUrl: youtubeUrl ?? this.youtubeUrl,
        category: category ?? this.category,
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// `https://youtu.be/ID`, `watch?v=ID`, `embed/ID` veya ham ID.
String? extractYoutubeVideoId(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^[\w-]{11}$').hasMatch(s)) return s;

  final uri = Uri.tryParse(s);
  if (uri == null) return null;

  final v = uri.queryParameters['v'];
  if (v != null && v.length == 11) return v;

  final segs = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  for (var i = 0; i < segs.length; i++) {
    if ((segs[i] == 'embed' || segs[i] == 'shorts' || segs[i] == 'v') &&
        i + 1 < segs.length &&
        segs[i + 1].length >= 11) {
      return segs[i + 1].substring(0, 11);
    }
  }
  if (uri.host.contains('youtu.be') && segs.isNotEmpty) {
    final id = segs.first;
    if (id.length >= 11) return id.substring(0, 11);
  }
  return null;
}

/// Yaygın kategori anahtarları.
abstract final class InfoLibraryCategories {
  static const premature = 'premature';
  static const genel = 'genel';
}
