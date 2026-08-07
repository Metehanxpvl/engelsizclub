import 'package:flutter/material.dart';

import '../../../data/forum_data.dart';

/// Ölçeklenebilir forum konusu (Supabase `forum_posts` satırı).
class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.avatar,
    required this.avatarColor,
    required this.category,
    required this.createdAt,
    this.diseaseId,
    this.diseaseLabel,
    this.subCategoryId,
    this.subCategoryLabel,
    this.ageGroup = '',
    this.tags = const [],
    this.views = 0,
    this.replyCount = 0,
    this.likes = 0,
    this.isResolved = false,
    this.pinned = false,
    this.expert = false,
    this.likedByMe = false,
    this.anon = false,
    this.meslek = '',
    this.ownerEmail = '',
    this.photos = const [],
  });

  final int id;
  final String title;
  final String content;
  final String author;
  final String avatar;
  final Color avatarColor;
  final String category;
  final DateTime createdAt;
  final String? diseaseId;
  final String? diseaseLabel;
  final String? subCategoryId;
  final String? subCategoryLabel;
  final String ageGroup;
  final List<String> tags;
  final int views;
  final int replyCount;
  final int likes;
  final bool isResolved;
  final bool pinned;
  final bool expert;
  final bool likedByMe;
  final bool anon;
  final String meslek;
  final String ownerEmail;
  final List<String> photos;

  String get displayDisease {
    final d = (diseaseLabel ?? '').trim();
    if (d.isNotEmpty) return d;
    return category.trim().isEmpty ? 'Genel' : category.trim();
  }

  /// Mevcut detay / yorum UI ile uyumluluk.
  ForumPost toForumPost() => ForumPost(
        id: id,
        author: author,
        avatar: avatar,
        avatarColor: avatarColor,
        category: displayDisease,
        title: title,
        content: content,
        likes: likes,
        comments: replyCount,
        time: _relative(createdAt),
        createdAt: createdAt,
        tags: tags,
        pinned: pinned,
        expert: expert,
        likedByMe: likedByMe,
        anon: anon,
        meslek: meslek,
        ownerEmail: ownerEmail,
        photos: photos,
      );

  static String _relative(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    final d = createdAt.toLocal();
    return '${d.day}.${d.month}.${d.year}';
  }
}

enum ForumSortMode {
  newest,
  popular,
  mostReplied,
  unanswered,
}

extension ForumSortModeX on ForumSortMode {
  String get label => switch (this) {
        ForumSortMode.newest => 'En yeni',
        ForumSortMode.popular => 'Popüler',
        ForumSortMode.mostReplied => 'En çok cevap',
        ForumSortMode.unanswered => 'Cevapsız',
      };
}

/// Çoklu filtre parametreleri.
@immutable
class ForumFilterParams {
  const ForumFilterParams({
    this.diseaseId,
    this.subCategoryId,
    this.ageGroup,
    this.tag,
    this.resolvedOnly,
    this.query = '',
    this.sort = ForumSortMode.newest,
  });

  final String? diseaseId;
  final String? subCategoryId;
  final String? ageGroup;
  final String? tag;
  final bool? resolvedOnly;
  final String query;
  final ForumSortMode sort;

  static const empty = ForumFilterParams();

  bool get hasActiveFilters =>
      (diseaseId != null && diseaseId!.isNotEmpty) ||
      (subCategoryId != null && subCategoryId!.isNotEmpty) ||
      (ageGroup != null && ageGroup!.isNotEmpty) ||
      (tag != null && tag!.isNotEmpty) ||
      resolvedOnly != null ||
      query.trim().isNotEmpty ||
      sort != ForumSortMode.newest;

  ForumFilterParams copyWith({
    String? diseaseId,
    String? subCategoryId,
    String? ageGroup,
    String? tag,
    bool? resolvedOnly,
    String? query,
    ForumSortMode? sort,
    bool clearDisease = false,
    bool clearSubCategory = false,
    bool clearAgeGroup = false,
    bool clearTag = false,
    bool clearResolved = false,
  }) =>
      ForumFilterParams(
        diseaseId: clearDisease ? null : (diseaseId ?? this.diseaseId),
        subCategoryId:
            clearSubCategory ? null : (subCategoryId ?? this.subCategoryId),
        ageGroup: clearAgeGroup ? null : (ageGroup ?? this.ageGroup),
        tag: clearTag ? null : (tag ?? this.tag),
        resolvedOnly: clearResolved ? null : (resolvedOnly ?? this.resolvedOnly),
        query: query ?? this.query,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumFilterParams &&
          diseaseId == other.diseaseId &&
          subCategoryId == other.subCategoryId &&
          ageGroup == other.ageGroup &&
          tag == other.tag &&
          resolvedOnly == other.resolvedOnly &&
          query == other.query &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(
        diseaseId,
        subCategoryId,
        ageGroup,
        tag,
        resolvedOnly,
        query,
        sort,
      );
}

class ForumTopicsPage {
  const ForumTopicsPage({
    required this.items,
    required this.hasMore,
    required this.page,
  });

  final List<ForumTopic> items;
  final bool hasMore;
  final int page;
}

/// UI yaş grubu etiketleri.
const kForumAgeGroups = <String>[
  '0-3',
  '3-6',
  '6-12',
  '12-18',
  '18+',
];
