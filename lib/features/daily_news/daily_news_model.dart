String dailyNewsDateTimeLabel(DateTime dt) {
  final d = dt.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year} $hh:$min';
}

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
    this.createdAt,
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
  final DateTime? createdAt;
  final String imageUrl;
  final List<String> affectedUsers;

  /// GitHub Action’ın haberi kuyruğa yazdığı an (yerel saat).
  String get collectedAtLabel =>
      createdAt == null ? '' : dailyNewsDateTimeLabel(createdAt!);

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
      createdAt: createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      categories: categories,
      affectedUsers: affectedUsers,
    );
  }

  factory DailyNewsCandidate.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
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
      publishedAt: parseTs(json['published_at']),
      createdAt: parseTs(json['created_at']),
      imageUrl: '${json['image_url'] ?? ''}',
      affectedUsers: [
        for (final e in (json['affected_users'] as List? ?? const []))
          if ('$e'.trim().isNotEmpty) '$e'.trim(),
      ],
    );
  }
}
