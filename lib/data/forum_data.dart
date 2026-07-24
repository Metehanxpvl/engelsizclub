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
}

class ForumComment {
  const ForumComment({
    required this.name,
    required this.text,
    required this.time,
    required this.color,
  });

  final String name;
  final String text;
  final String time;
  final Color color;
}

const forumPosts = <ForumPost>[
  ForumPost(
    id: 1,
    author: 'Ayşe K.',
    avatar: 'AK',
    avatarColor: Color(0xFF1A6B4A),
    category: 'Otizm',
    title: 'ABA terapisinde ilk 3 ayda neler değişti?',
    content:
        'Oğlumu 3 yaşında otizm tanısıyla aldık. ABA başladıktan 3 ay sonra göz teması kurmaya başladı. Deneyimlerimi paylaşmak istedim...',
    likes: 47,
    comments: 23,
    time: '2 saat önce',
  ),
  ForumPost(
    id: 2,
    author: 'Dr. Mehmet Y.',
    avatar: 'MY',
    avatarColor: Color(0xFF6B9AC4),
    category: 'Uzman',
    title: 'Erken müdahalede altın dönem: 0-3 yaş',
    content:
        'Beyin plastisitesi en yüksek olduğu bu dönemde yapılan müdahaleler çocuğun gelişimine en büyük katkıyı sağlar. Bilimsel araştırmalar...',
    likes: 134,
    comments: 41,
    time: '5 saat önce',
    pinned: true,
    expert: true,
  ),
  ForumPost(
    id: 3,
    author: 'Fatma S.',
    avatar: 'FS',
    avatarColor: Color(0xFFE07A5F),
    category: 'Serebral Palsi',
    title: "İstanbul'da iyi bir hidroterapi merkezi arıyorum",
    content:
        'Kızım için hidroterapi yapmayı düşünüyoruz. Deneyimi olan var mı? Özellikle Anadolu yakasında bir yer önerir misiniz?',
    likes: 12,
    comments: 18,
    time: '1 gün önce',
  ),
  ForumPost(
    id: 4,
    author: 'Hasan A.',
    avatar: 'HA',
    avatarColor: Color(0xFF9C6DB3),
    category: 'DEHB',
    title: 'Okul ile nasıl iletişim kuruyorsunuz?',
    content:
        'Oğlumun öğretmeni sürekli şikayet ediyor ama destek sunmaya çalışmıyor. Haklarımız konusunda ne yapabiliriz?',
    likes: 56,
    comments: 34,
    time: '2 gün önce',
  ),
];

const sampleComments = <ForumComment>[
  ForumComment(
    name: 'Zeynep A.',
    text: 'Bizim için de çok faydalı oldu, teşekkürler!',
    time: '1 saat önce',
    color: Color(0xFFF4A832),
  ),
  ForumComment(
    name: 'Ali R.',
    text: 'Hangi merkezde ABA terapisi aldınız?',
    time: '3 saat önce',
    color: Color(0xFF5BA882),
  ),
];

const forumCategories = [
  'Tümü',
  'Otizm',
  'Serebral Palsi',
  'DEHB',
  'Uzman',
  'İkinci El',
];

const newPostCategories = [
  'Otizm',
  'Serebral Palsi',
  'Down Sendromu',
  'DEHB',
  'Genel',
  'İkinci El Ürün',
];

const forumCategoryColors = <String, Color>{
  'Otizm': Color(0xFF5B8DD9),
  'Uzman': Color(0xFF1A6B4A),
  'Serebral Palsi': Color(0xFF1A6B4A),
  'DEHB': Color(0xFF6B9AC4),
};

Color forumCategoryColor(String category) =>
    forumCategoryColors[category] ?? const Color(0xFF1A6B4A);
