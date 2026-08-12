import '../info_library/models/info_content.dart' show extractYoutubeVideoId;

class GelisimEtkinlik {
  const GelisimEtkinlik({
    required this.id,
    required this.title,
    required this.description,
    required this.tip,
    required this.grup,
    required this.grupAd,
    required this.yas,
    required this.yasAd,
    required this.zorluk,
    required this.zorlukAd,
    required this.youtubeUrl,
    required this.kaynak,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String title;
  final String description;
  final String tip;
  final String grup;
  final String grupAd;
  final String yas;
  final String yasAd;
  final String zorluk;
  final String zorlukAd;
  final String youtubeUrl;
  final String kaynak;
  final int sortOrder;
  final bool isActive;

  String? get youtubeId => extractYoutubeVideoId(youtubeUrl);

  GelisimEtkinlik copyWith({
    String? title,
    String? description,
    String? tip,
    String? youtubeUrl,
    String? kaynak,
    bool? isActive,
  }) {
    return GelisimEtkinlik(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      tip: tip ?? this.tip,
      grup: grup,
      grupAd: grupAd,
      yas: yas,
      yasAd: yasAd,
      zorluk: zorluk,
      zorlukAd: zorlukAd,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      kaynak: kaynak ?? this.kaynak,
      sortOrder: sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  factory GelisimEtkinlik.fromJson(Map<String, dynamic> json) {
    return GelisimEtkinlik(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      tip: json['tip']?.toString() ?? '',
      grup: json['grup']?.toString() ?? '',
      grupAd: json['grup_ad']?.toString() ?? '',
      yas: json['yas']?.toString() ?? '',
      yasAd: json['yas_ad']?.toString() ?? '',
      zorluk: json['zorluk']?.toString() ?? '',
      zorlukAd: json['zorluk_ad']?.toString() ?? '',
      youtubeUrl: json['youtube_url']?.toString() ?? '',
      kaynak: json['kaynak']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}
