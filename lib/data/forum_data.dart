import 'package:flutter/material.dart';

class ForumPost {
  const ForumPost({
    required this.id,
    required this.author,
    required this.avatar,
    required this.avatarColor,
    required this.category,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    required this.time,
    this.createdAt,
    this.tags = const [],
    this.pinned = false,
    this.expert = false,
    this.likedByMe = false,
    this.anon = false,
    this.meslek = '',
    this.ownerEmail = '',
    this.photos = const [],
    this.views = 0,
  });

  final int id;
  final String author;
  final String avatar;
  final Color avatarColor;
  final String category;
  final String title;
  final String content;
  final int likes;
  final int comments;
  final String time;
  final DateTime? createdAt;
  final List<String> tags;
  final bool pinned;
  final bool expert;
  final bool likedByMe;
  final bool anon;
  final String meslek;
  final String ownerEmail;
  final List<String> photos;
  final int views;

  bool get isAnonymous =>
      anon || author.trim().toLowerCase() == 'anonim';

  ForumPost copyWith({
    int? likes,
    int? comments,
    bool? likedByMe,
    String? category,
    String? title,
    String? content,
    bool? expert,
    String? meslek,
    List<String>? photos,
    String? avatar,
    bool? anon,
    DateTime? createdAt,
    List<String>? tags,
    int? views,
  }) =>
      ForumPost(
        id: id,
        author: author,
        avatar: avatar ?? this.avatar,
        avatarColor: avatarColor,
        category: category ?? this.category,
        title: title ?? this.title,
        content: content ?? this.content,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        time: time,
        createdAt: createdAt ?? this.createdAt,
        tags: tags ?? this.tags,
        pinned: pinned,
        expert: expert ?? this.expert,
        likedByMe: likedByMe ?? this.likedByMe,
        anon: anon ?? this.anon,
        meslek: meslek ?? this.meslek,
        ownerEmail: ownerEmail,
        photos: photos ?? this.photos,
        views: views ?? this.views,
      );
}

class ForumComment {
  const ForumComment({
    this.id = 0,
    required this.name,
    required this.text,
    required this.time,
    required this.color,
    this.avatar = '',
    this.ownerEmail = '',
    this.parentId,
    this.likes = 0,
    this.likedByMe = false,
  });

  final int id;
  final String name;
  final String text;
  final String time;
  final Color color;
  final String avatar;
  final String ownerEmail;
  final int? parentId;
  final int likes;
  final bool likedByMe;

  bool get isReply => parentId != null && parentId! > 0;

  ForumComment copyWith({
    int? likes,
    bool? likedByMe,
  }) =>
      ForumComment(
        id: id,
        name: name,
        text: text,
        time: time,
        color: color,
        avatar: avatar,
        ownerEmail: ownerEmail,
        parentId: parentId,
        likes: likes ?? this.likes,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

// Kullanıcının uygulama açıkken paylaştığı gönderiler burada tutulur.
final List<ForumPost> runtimeForumPosts = <ForumPost>[];

int _forumIdSeq = 1000;
int nextForumId() => ++_forumIdSeq;

const forumPosts = <ForumPost>[];

const newPostCategories = [
  'Serebral Palsi',
  'Otizm',
  'Down Sendromu',
  'DEHB',
  'Genel',
  'Uzman',
];

const forumCategories = [
  'Tümü',
  'Serebral Palsi',
  'Otizm',
  'DEHB',
  'Uzman',
  'Köşe Yazısı',
];

/// Uzman köşe yazısı meslekleri (Aile: aileler de köşe yazısı paylaşabilir)
const uzmanMeslekler = [
  'Doktor',
  'Fizyoterapist',
  'Ergoterapist',
  'Özel Eğitim Öğretmeni',
  'Gölge Öğretmen',
  'Dil Terapisti',
  'Aile',
];

const forumCategoryColors = <String, Color>{
  'Otizm': Color(0xFF5B8DD9),
  'Uzman': Color(0xFF1A6B4A),
  'Köşe Yazısı': Color(0xFF0F766E),
  'Serebral Palsi': Color(0xFF1A6B4A),
  'DEHB': Color(0xFF6B9AC4),
  'Doktor': Color(0xFF1D4ED8),
  'Fizyoterapist': Color(0xFF0F766E),
  'Ergoterapist': Color(0xFF7C3AED),
  'Özel Eğitim Öğretmeni': Color(0xFFB45309),
  'Gölge Öğretmen': Color(0xFF0D9488),
  'Dil Terapisti': Color(0xFFBE185D),
  'Aile': Color(0xFFF4A832),
};

Color forumCategoryColor(String category) =>
    forumCategoryColors[category] ?? const Color(0xFF1A6B4A);

bool isUzmanMeslek(String category) => uzmanMeslekler.contains(category);
