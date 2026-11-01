class DailyNewsCandidate {
  const DailyNewsCandidate({
    required this.id,
    required this.sourceName,
    required this.sourceUrl,
    required this.articleUrl,
    required this.title,
    required this.summary,
    required this.category,
    required this.relevanceScore,
    required this.importanceLevel,
    required this.aiReason,
    required this.status,
    this.publishedAt,
    this.imageUrl = '',
    this.categories = const [],
    this.affectedUsers = const [],
  });

  final String id;
  final String sourceName;
  final String sourceUrl;
  final String articleUrl;
  final String title;
  final String summary;
  final String category;
  final List<String> categories;
  final int relevanceScore;
  final String importanceLevel;
  final String aiReason;
  final String status;
  final DateTime? publishedAt;
  final String imageUrl;
  final List<String> affectedUsers;

  String get importanceLabelTr => switch (importanceLevel) {
        'very_high' => 'Çok önemli',
        'high' => 'Önemli',
        _ => 'Bilgilendirici',
      };

  DailyNewsCandidate copyWith({
    String? title,
    String? summary,
    String? imageUrl,
  }) {
    return DailyNewsCandidate(
      id: id,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      articleUrl: articleUrl,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category,
      relevanceScore: relevanceScore,
      importanceLevel: importanceLevel,
      aiReason: aiReason,
      status: status,
      publishedAt: publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      categories: categories,
      affectedUsers: affectedUsers,
    );
  }

  factory DailyNewsCandidate.fromJson(Map<String, dynamic> json) {
    DateTime? published;
    final raw = json['published_at'];
    if (raw is String && raw.trim().isNotEmpty) {
      published = DateTime.tryParse(raw);
    }
    return DailyNewsCandidate(
      id: '${json['id'] ?? ''}',
      sourceName: '${json['source_name'] ?? ''}',
      sourceUrl: '${json['source_url'] ?? ''}',
      articleUrl: '${json['article_url'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      summary: '${json['summary'] ?? ''}'.trim(),
      category: '${json['category'] ?? 'Diğer'}',
      categories: [
        for (final e in (json['categories'] as List? ?? const []))
          if ('$e'.trim().isNotEmpty) '$e'.trim(),
      ],
      relevanceScore: (json['relevance_score'] as num?)?.round() ?? 0,
      importanceLevel: '${json['importance_level'] ?? 'informational'}',
      aiReason: '${json['ai_reason'] ?? ''}'.trim(),
      status: '${json['status'] ?? 'pending'}',
      publishedAt: published,
      imageUrl: '${json['image_url'] ?? ''}',
      affectedUsers: [
        for (final e in (json['affected_users'] as List? ?? const []))
          if ('$e'.trim().isNotEmpty) '$e'.trim(),
      ],
    );
  }
}
