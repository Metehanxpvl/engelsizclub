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
    this.pinned = false,
    this.expert = false,
    this.likedByMe = false,
    this.meslek = '',
    this.ownerEmail = '',
    this.photos = const [],
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
  final bool pinned;
  final bool expert;
  final bool likedByMe;
  final String meslek;
  final String ownerEmail;
  final List<String> photos;

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
  }) =>
      ForumPost(
        id: id,
        author: author,
        avatar: avatar,
        avatarColor: avatarColor,
        category: category ?? this.category,
        title: title ?? this.title,
        content: content ?? this.content,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        time: time,
        pinned: pinned,
        expert: expert ?? this.expert,
        likedByMe: likedByMe ?? this.likedByMe,
        meslek: meslek ?? this.meslek,
        ownerEmail: ownerEmail,
        photos: photos ?? this.photos,
      );
}

class ForumComment {
  const ForumComment({
    this.id = 0,
    required this.name,
    required this.text,
    required this.time,
    required this.color,
    this.ownerEmail = '',
  });

  final int id;
  final String name;
  final String text;
  final String time;
  final Color color;
  final String ownerEmail;
}

// Kullanıcının uygulama açıkken paylaştığı gönderiler burada tutulur.
final List<ForumPost> runtimeForumPosts = <ForumPost>[];

int _forumIdSeq = 1000;
int nextForumId() => ++_forumIdSeq;

const forumPosts = <ForumPost>[];

const forumCategories = [
  'Tümü',
  'Otizm',
  'Serebral Palsi',
  'DEHB',
  'Uzman',
  'Köşe Yazısı',
];

const newPostCategories = [
  'Otizm',
  'Serebral Palsi',
  'Down Sendromu',
  'DEHB',
  'Genel',
  'Uzman',
];

/// Uzman köşe yazısı meslekleri (Aile: aileler de köşe yazısı paylaşabilir)
const uzmanMeslekler = [
  'Doktor',
  'Fizyoterapist',
  'Ergoterapist',
  'Özel Eğitim Öğretmeni',
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
  'Dil Terapisti': Color(0xFFBE185D),
  'Aile': Color(0xFFF4A832),
};

Color forumCategoryColor(String category) =>
    forumCategoryColors[category] ?? const Color(0xFF1A6B4A);

bool isUzmanMeslek(String category) => uzmanMeslekler.contains(category);
