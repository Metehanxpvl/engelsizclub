import '../../info_library/models/info_content.dart' show extractYoutubeVideoId;

export '../../info_library/models/info_content.dart' show extractYoutubeVideoId;

/// Keşfet kategori (Sana Özel = tüm onaylı; Phase 1 kişiselleştirme yok).
class KesfetCategory {
  const KesfetCategory({
    required this.slug,
    required this.title,
  });

  final String slug;
  final String title;

  static const sanaOzel = KesfetCategory(slug: 'sana-ozel', title: 'Sana Özel');

  static const feed = <KesfetCategory>[
    sanaOzel,
    KesfetCategory(slug: 'engellilik', title: 'Engellilik'),
    KesfetCategory(slug: 'hastaliklar', title: 'Hastalıklar'),
    KesfetCategory(slug: 'haklar', title: 'Haklar & Yardımlar'),
    KesfetCategory(slug: 'saglik', title: 'Sağlık'),
    KesfetCategory(slug: 'egitim', title: 'Eğitim'),
    KesfetCategory(slug: 'aile', title: 'Aile'),
    KesfetCategory(slug: 'erisilebilirlik', title: 'Erişilebilirlik'),
  ];

  static String titleFor(String slug) {
    for (final c in feed) {
      if (c.slug == slug) return c.title;
    }
    return slug;
  }
}

class KesfetKeyword {
  const KesfetKeyword({
    this.id = 0,
    required this.phrase,
    required this.polarity,
    this.weight = 10,
    this.categoryHint = '',
    this.isWeak = false,
    this.isActive = true,
  });

  final int id;
  final String phrase;
  /// `positive` | `negative` | `safety`
  final String polarity;
  final int weight;
  final String categoryHint;
  final bool isWeak;
  final bool isActive;

  factory KesfetKeyword.fromRow(Map<String, dynamic> json) {
    return KesfetKeyword(
      id: (json['id'] as num?)?.toInt() ?? 0,
      phrase: json['phrase']?.toString() ?? '',
      polarity: json['polarity']?.toString() ?? 'positive',
      weight: (json['weight'] as num?)?.toInt() ?? 10,
      categoryHint: json['category_hint']?.toString() ?? '',
      isWeak: json['is_weak'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class KesfetScore {
  const KesfetScore({
    required this.score,
    required this.safetyFlag,
    required this.suggestedCategory,
    this.safetyNote = '',
    this.matchedPositives = const [],
    this.matchedNegatives = const [],
  });

  final int score;
  final bool safetyFlag;
  final String suggestedCategory;
  final String safetyNote;
  final List<String> matchedPositives;
  final List<String> matchedNegatives;

  /// Phase 1: asla otomatik onay.
  bool get autoApprove => false;
}

class KesfetVideo {
  const KesfetVideo({
    required this.id,
    required this.youtubeVideoId,
    required this.youtubeUrl,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelName,
    required this.channelUrl,
    required this.category,
    required this.tags,
    required this.sourceUrl,
    required this.status,
    required this.relevanceScore,
    required this.safetyFlag,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.viewCount,
    required this.createdAt,
    this.relatedArticleId = '',
    this.relatedArticleSlug = '',
    this.safetyNote = '',
    this.publishedAt,
    this.likedByMe = false,
    this.savedByMe = false,
  });

  final String id;
  final String youtubeVideoId;
  final String youtubeUrl;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelName;
  final String channelUrl;
  final String category;
  final List<String> tags;
  final String sourceUrl;
  final String relatedArticleId;
  final String relatedArticleSlug;
  final String status;
  final int relevanceScore;
  final bool safetyFlag;
  final String safetyNote;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final bool likedByMe;
  final bool savedByMe;

  bool get hasRelatedArticle =>
      relatedArticleId.trim().isNotEmpty ||
      relatedArticleSlug.trim().isNotEmpty;

  String get categoryTitle => KesfetCategory.titleFor(category);

  String get watchUrl {
    final id = youtubeVideoId.trim();
    if (id.isEmpty) return youtubeUrl;
    return 'https://www.youtube.com/shorts/$id';
  }

  /// Orijinal YouTube bağlantısı (watch / shorts). Kaynak satırından açılır.
  String get externalYoutubeUrl {
    final orig = youtubeUrl.trim();
    if (orig.startsWith('http://') || orig.startsWith('https://')) return orig;
    final src = sourceUrl.trim();
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    return watchUrl;
  }

  String get resolvedThumb {
    if (thumbnailUrl.trim().isNotEmpty) return thumbnailUrl.trim();
    final id = youtubeVideoId.trim();
    if (id.isEmpty) return '';
    return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  }

  String get shareAppUrl {
    final id = youtubeVideoId.trim();
    if (id.isEmpty) return 'https://www.engelsizclub.com/kesfet';
    return 'https://www.engelsizclub.com/kesfet?v=$id';
  }

  KesfetVideo copyWith({
    bool? likedByMe,
    bool? savedByMe,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    String? status,
  }) {
    return KesfetVideo(
      id: id,
      youtubeVideoId: youtubeVideoId,
      youtubeUrl: youtubeUrl,
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      channelName: channelName,
      channelUrl: channelUrl,
      category: category,
      tags: tags,
      sourceUrl: sourceUrl,
      relatedArticleId: relatedArticleId,
      relatedArticleSlug: relatedArticleSlug,
      status: status ?? this.status,
      relevanceScore: relevanceScore,
      safetyFlag: safetyFlag,
      safetyNote: safetyNote,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      viewCount: viewCount,
      createdAt: createdAt,
      publishedAt: publishedAt,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
    );
  }

  factory KesfetVideo.fromRow(
    Map<String, dynamic> json, {
    bool likedByMe = false,
    bool savedByMe = false,
  }) {
    final tagsRaw = json['tags'];
    final tags = <String>[];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        final s = t?.toString().trim() ?? '';
        if (s.isNotEmpty) tags.add(s);
      }
    }
    final yid = json['youtube_video_id']?.toString() ?? '';
    final url = json['youtube_url']?.toString() ?? '';
    return KesfetVideo(
      id: json['id']?.toString() ?? '',
      youtubeVideoId: yid.isNotEmpty
          ? yid
          : (extractYoutubeVideoId(url) ?? ''),
      youtubeUrl: url,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? '',
      channelUrl: json['channel_url']?.toString() ?? '',
      category: json['category']?.toString() ?? 'engellilik',
      tags: tags,
      sourceUrl: json['source_url']?.toString() ?? '',
      relatedArticleId: json['related_article_id']?.toString() ?? '',
      relatedArticleSlug: json['related_article_slug']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      relevanceScore: (json['relevance_score'] as num?)?.toInt() ?? 0,
      safetyFlag: json['safety_flag'] == true,
      safetyNote: json['safety_note']?.toString() ?? '',
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      saveCount: (json['save_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );
  }
}

class KesfetComment {
  const KesfetComment({
    required this.id,
    required this.videoId,
    required this.body,
    required this.author,
    required this.ownerEmail,
    required this.createdAt,
  });

  final int id;
  final String videoId;
  final String body;
  final String author;
  final String ownerEmail;
  final DateTime createdAt;

  factory KesfetComment.fromRow(Map<String, dynamic> json) {
    return KesfetComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      videoId: json['video_id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Üye',
      ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class KesfetReportRow {
  const KesfetReportRow({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.youtubeUrl,
    required this.reason,
    required this.ownerEmail,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String videoId;
  final String videoTitle;
  final String youtubeUrl;
  final String reason;
  final String ownerEmail;
  final String status;
  final DateTime createdAt;

  factory KesfetReportRow.fromRow(Map<String, dynamic> json) {
    return KesfetReportRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      videoId: json['video_id']?.toString() ?? '',
      videoTitle: json['video_title']?.toString() ?? '',
      youtubeUrl: json['youtube_url']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      ownerEmail: json['owner_email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class KesfetOEmbed {
  const KesfetOEmbed({
    required this.title,
    required this.authorName,
    required this.authorUrl,
    required this.thumbnailUrl,
  });

  final String title;
  final String authorName;
  final String authorUrl;
  final String thumbnailUrl;
}
