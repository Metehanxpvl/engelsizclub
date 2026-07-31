class DuyuruItem {
  const DuyuruItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    this.sourceUrl,
    required this.createdAt,
    this.isActive = true,
  });

  final int id;
  final String title;
  final String body;
  /// http(s) URL veya data:image/...;base64,...
  final String imageUrl;
  /// Hedef / kaynak link (target_link)
  final String? sourceUrl;
  final DateTime createdAt;
  final bool isActive;

  bool get hasSource {
    final u = (sourceUrl ?? '').trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  DuyuruItem copyWith({
    String? title,
    String? body,
    String? imageUrl,
    String? sourceUrl,
    bool clearSource = false,
    bool? isActive,
  }) =>
      DuyuruItem(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        imageUrl: imageUrl ?? this.imageUrl,
        sourceUrl: clearSource ? null : (sourceUrl ?? this.sourceUrl),
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
      );
}
