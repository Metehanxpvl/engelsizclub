import 'package:flutter/material.dart';

class NeedCard {
  const NeedCard({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.bg,
    required this.category,
    this.desc,
    this.photo,
    this.isCustom = false,
  });

  final int id;
  final String label;
  final String emoji;
  final Color color;
  final Color bg;
  final String category;
  final String? desc;
  final String? photo;
  final bool isCustom;

  NeedCard copyWith({
    int? id,
    String? label,
    String? emoji,
    Color? color,
    Color? bg,
    String? category,
    String? desc,
    String? photo,
    bool? isCustom,
    bool clearDesc = false,
    bool clearPhoto = false,
  }) {
    return NeedCard(
      id: id ?? this.id,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      bg: bg ?? this.bg,
      category: category ?? this.category,
      desc: clearDesc ? null : (desc ?? this.desc),
      photo: clearPhoto ? null : (photo ?? this.photo),
      isCustom: isCustom ?? this.isCustom,
    );
  }

  NeedCard applyOverride(Map<String, dynamic> ovr) {
    return copyWith(
      label: ovr['label'] as String?,
      emoji: ovr['emoji'] as String?,
      color: ovr['color'] != null ? colorFromHex(ovr['color'] as String) : null,
      bg: ovr['bg'] != null ? colorFromHex(ovr['bg'] as String) : null,
      category: ovr['category'] as String?,
      desc: ovr['desc'] as String?,
      photo: ovr['photo'] as String?,
      clearDesc: ovr.containsKey('desc') && ovr['desc'] == null,
      clearPhoto: ovr.containsKey('photo') && ovr['photo'] == null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'color': colorToHex(color),
        'bg': colorToHex(bg),
        'category': category,
        if (desc != null) 'desc': desc,
        if (photo != null) 'photo': photo,
        'isCustom': isCustom,
      };

  /// Partial override payload (no id / isCustom).
  Map<String, dynamic> toOverrideJson() => {
        'label': label,
        'emoji': emoji,
        'color': colorToHex(color),
        'bg': colorToHex(bg),
        'category': category,
        if (desc != null && desc!.isNotEmpty) 'desc': desc,
        if (photo != null && photo!.isNotEmpty) 'photo': photo,
      };

  factory NeedCard.fromJson(Map<String, dynamic> json) {
    return NeedCard(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '⭐',
      color: colorFromHex(json['color'] as String? ?? '#1a6b4a'),
      bg: colorFromHex(json['bg'] as String? ?? '#e8f5ee'),
      category: json['category'] as String? ?? 'ozel',
      desc: json['desc'] as String?,
      photo: json['photo'] as String?,
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }
}

String colorToHex(Color c) {
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

Color colorFromHex(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class CardPaletteColor {
  const CardPaletteColor({required this.color, required this.bg});

  final Color color;
  final Color bg;
}

const kCardPalette = <CardPaletteColor>[
  CardPaletteColor(color: Color(0xFF1A6B4A), bg: Color(0xFFE8F5EE)),
  CardPaletteColor(color: Color(0xFF5B8DD9), bg: Color(0xFFE3F2FD)),
  CardPaletteColor(color: Color(0xFFE07A5F), bg: Color(0xFFFDF0EC)),
  CardPaletteColor(color: Color(0xFFF4A832), bg: Color(0xFFFFF8ED)),
  CardPaletteColor(color: Color(0xFF9C6DB3), bg: Color(0xFFF5EEFB)),
  CardPaletteColor(color: Color(0xFFE53935), bg: Color(0xFFFFEBEE)),
  CardPaletteColor(color: Color(0xFF00897B), bg: Color(0xFFE0F2F1)),
  CardPaletteColor(color: Color(0xFFF06292), bg: Color(0xFFFCE4EC)),
];

const kCardEmojis = <String>[
  '🍕',
  '🍎',
  '🍌',
  '🧃',
  '🍪',
  '🎈',
  '⚽',
  '🚗',
  '🐕',
  '🐱',
  '🦋',
  '🌸',
  '⭐',
  '🎯',
  '🎨',
  '📚',
  '🎵',
  '🚀',
  '🌈',
  '❤️',
  '😊',
  '🙌',
  '👏',
  '🏠',
  '🛁',
  '👕',
  '🎒',
  '✏️',
  '🎮',
  '📱',
];

const kNeedCards = <NeedCard>[
  NeedCard(
    id: 1,
    label: 'Su',
    emoji: '💧',
    color: Color(0xFF4FC3F7),
    bg: Color(0xFFE1F5FE),
    category: 'temel',
  ),
  NeedCard(
    id: 2,
    label: 'Yemek',
    emoji: '🍽️',
    color: Color(0xFF81C784),
    bg: Color(0xFFE8F5E9),
    category: 'temel',
  ),
  NeedCard(
    id: 3,
    label: 'Tuvalet',
    emoji: '🚽',
    color: Color(0xFFFFB74D),
    bg: Color(0xFFFFF3E0),
    category: 'temel',
  ),
  NeedCard(
    id: 4,
    label: 'Acıdı',
    emoji: '😢',
    color: Color(0xFFE57373),
    bg: Color(0xFFFFEBEE),
    category: 'duygu',
  ),
  NeedCard(
    id: 5,
    label: 'Yardım Et',
    emoji: '🤝',
    color: Color(0xFFBA68C8),
    bg: Color(0xFFF3E5F5),
    category: 'istek',
  ),
  NeedCard(
    id: 6,
    label: 'Anne',
    emoji: '👩',
    color: Color(0xFFF48FB1),
    bg: Color(0xFFFCE4EC),
    category: 'kisi',
  ),
  NeedCard(
    id: 7,
    label: 'Baba',
    emoji: '👨',
    color: Color(0xFF64B5F6),
    bg: Color(0xFFE3F2FD),
    category: 'kisi',
  ),
  NeedCard(
    id: 8,
    label: 'Oyun',
    emoji: '🎮',
    color: Color(0xFFAED581),
    bg: Color(0xFFF1F8E9),
    category: 'aktivite',
  ),
  NeedCard(
    id: 9,
    label: 'Uyku',
    emoji: '😴',
    color: Color(0xFF90CAF9),
    bg: Color(0xFFE3F2FD),
    category: 'temel',
  ),
  NeedCard(
    id: 10,
    label: 'Dışarı',
    emoji: '🌳',
    color: Color(0xFF66BB6A),
    bg: Color(0xFFE8F5E9),
    category: 'istek',
  ),
  NeedCard(
    id: 11,
    label: 'Hayır',
    emoji: '❌',
    color: Color(0xFFEF5350),
    bg: Color(0xFFFFEBEE),
    category: 'cevap',
  ),
  NeedCard(
    id: 12,
    label: 'Evet',
    emoji: '✅',
    color: Color(0xFF43A047),
    bg: Color(0xFFE8F5E9),
    category: 'cevap',
  ),
  NeedCard(
    id: 13,
    label: 'Dinlenmek',
    emoji: '🛋️',
    color: Color(0xFF7986CB),
    bg: Color(0xFFE8EAF6),
    category: 'istek',
  ),
  NeedCard(
    id: 14,
    label: 'Mutlu',
    emoji: '😄',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFFDE7),
    category: 'duygu',
    desc: 'Çok mutluyum! İçim gülüyor, kendimi harika hissediyorum.',
  ),
  NeedCard(
    id: 15,
    label: 'Üzgün',
    emoji: '😢',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFE3F2FD),
    category: 'duygu',
    desc: 'İçim sıkışmış, ağlamak istiyorum. Üzgün hissediyorum.',
  ),
  NeedCard(
    id: 16,
    label: 'Sıcak',
    emoji: '🌡️',
    color: Color(0xFFFF7043),
    bg: Color(0xFFFBE9E7),
    category: 'duygu',
    desc: 'Çok sıcak hissediyorum, serinlemek istiyorum.',
  ),
  NeedCard(
    id: 51,
    emoji: '🌅',
    label: 'Sabah Rutini',
    category: 'rutin',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
  ),
  NeedCard(
    id: 52,
    emoji: '🪥',
    label: 'Diş Fırçala',
    category: 'rutin',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
  ),
  NeedCard(
    id: 53,
    emoji: '🛁',
    label: 'Banyo',
    category: 'rutin',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFEEF3FC),
  ),
  NeedCard(
    id: 54,
    emoji: '👕',
    label: 'Giyinmek',
    category: 'rutin',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
  ),
  NeedCard(
    id: 55,
    emoji: '🍽️',
    label: 'Yemek Vakti',
    category: 'rutin',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
  ),
  NeedCard(
    id: 56,
    emoji: '😴',
    label: 'Uyku Vakti',
    category: 'rutin',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
  ),
  NeedCard(
    id: 57,
    emoji: '🎒',
    label: 'Okula Hazırlan',
    category: 'rutin',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
  ),
  NeedCard(
    id: 58,
    emoji: '🚿',
    label: 'Duş Al',
    category: 'rutin',
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
  ),
  NeedCard(
    id: 61,
    emoji: '👋',
    label: 'Merhaba',
    category: 'sosyal',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
  ),
  NeedCard(
    id: 62,
    emoji: '🤝',
    label: 'Anlaştık',
    category: 'sosyal',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
  ),
  NeedCard(
    id: 63,
    emoji: '🙏',
    label: 'Teşekkürler',
    category: 'sosyal',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
  ),
  NeedCard(
    id: 64,
    emoji: '😊',
    label: 'İyiyim',
    category: 'sosyal',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
  ),
  NeedCard(
    id: 65,
    emoji: '😔',
    label: 'Üzgünüm',
    category: 'sosyal',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
  ),
  NeedCard(
    id: 66,
    emoji: '🤒',
    label: 'Hastayım',
    category: 'sosyal',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
  ),
  NeedCard(
    id: 67,
    emoji: '🆘',
    label: 'Yardım Lazım',
    category: 'sosyal',
    color: Color(0xFFC0392B),
    bg: Color(0xFFFDE8E8),
  ),
  NeedCard(
    id: 68,
    emoji: '🔇',
    label: 'Çok Gürültü',
    category: 'sosyal',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
  ),
  NeedCard(
    id: 71,
    emoji: '😠',
    label: 'Kızgın',
    category: 'duygu',
    color: Color(0xFFE53935),
    bg: Color(0xFFFFEBEE),
    desc: 'Çok kızgınım! Bir şey beni çok rahatsız etti.',
  ),
  NeedCard(
    id: 72,
    emoji: '😰',
    label: 'Endişeli',
    category: 'duygu',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFE3F2FD),
    desc: 'İçimde sıkışmış bir his var. Bir şeyler beni endişelendiriyor.',
  ),
  NeedCard(
    id: 73,
    emoji: '🤩',
    label: 'Heyecanlı',
    category: 'duygu',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
    desc: 'Çok heyecanlandım! İçimde mutlu bir enerji var.',
  ),
  NeedCard(
    id: 74,
    emoji: '😌',
    label: 'Sakin',
    category: 'duygu',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
    desc: 'Şu an rahatım. Her şey yolunda hissediyorum.',
  ),
  NeedCard(
    id: 75,
    emoji: '😬',
    label: 'Gergin',
    category: 'duygu',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    desc: 'Kendimi gergin hissediyorum. Kaslarım sıkışmış gibi.',
  ),
  NeedCard(
    id: 76,
    emoji: '😤',
    label: 'Hüsrana Uğramış',
    category: 'duygu',
    color: Color(0xFFC0392B),
    bg: Color(0xFFFDE8E8),
    desc: 'Bir şeyi yapmaya çalıştım ama olmadı. Çok can sıkıcı!',
  ),
  NeedCard(
    id: 77,
    emoji: '😲',
    label: 'Şaşırmış',
    category: 'duygu',
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    desc: 'Beklemediğim bir şey oldu. Çok şaşırdım!',
  ),
  NeedCard(
    id: 78,
    emoji: '😨',
    label: 'Korkmuş',
    category: 'duygu',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F0FF),
    desc: 'Bir şeyden korkuyorum. Güvende hissetmiyorum.',
  ),
  NeedCard(
    id: 79,
    emoji: '🥱',
    label: 'Yorgun',
    category: 'duygu',
    color: Color(0xFF78909C),
    bg: Color(0xFFECEFF1),
    desc: 'Çok yoruldum. Dinlenmek istiyorum.',
  ),
  NeedCard(
    id: 80,
    emoji: '🤔',
    label: 'Kafası Karışık',
    category: 'duygu',
    color: Color(0xFFE8960A),
    bg: Color(0xFFFFF3DB),
    desc: 'Anlayamadım. Ne olduğunu çözemedim, kafam karışık.',
  ),
  NeedCard(
    id: 89,
    emoji: '😤',
    label: 'Gururlu',
    category: 'duygu',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    desc: 'Bir şeyi başardım ve kendimle gurur duyuyorum!',
  ),
  NeedCard(
    id: 90,
    emoji: '😒',
    label: 'Sıkılmış',
    category: 'duygu',
    color: Color(0xFF9E9E9E),
    bg: Color(0xFFF5F5F5),
    desc: 'Şu an sıkıldım. Yapmak istediğim bir şey yok.',
  ),
  NeedCard(
    id: 91,
    emoji: '😊',
    label: 'Utangaç',
    category: 'duygu',
    color: Color(0xFFE91E63),
    bg: Color(0xFFFCE4EC),
    desc: 'Kendimi utangaç hissediyorum. Çok fazla dikkat çekmek istemiyorum.',
  ),
  NeedCard(
    id: 92,
    emoji: '😜',
    label: 'Şakacı',
    category: 'duygu',
    color: Color(0xFFFF9800),
    bg: Color(0xFFFFF3E0),
    desc: 'Şu an şakacı hissediyorum. Eğlenmek ve güldürmek istiyorum!',
  ),
  NeedCard(
    id: 81,
    emoji: '✏️',
    label: 'Ödev',
    category: 'okul',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
  ),
  NeedCard(
    id: 82,
    emoji: '📖',
    label: 'Okuma',
    category: 'okul',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFEEF3FC),
  ),
  NeedCard(
    id: 83,
    emoji: '✂️',
    label: 'Kesme/Yapıştırma',
    category: 'okul',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
  ),
  NeedCard(
    id: 84,
    emoji: '🖍️',
    label: 'Boyama',
    category: 'okul',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
  ),
  NeedCard(
    id: 85,
    emoji: '🔢',
    label: 'Matematik',
    category: 'okul',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
  ),
  NeedCard(
    id: 86,
    emoji: '🎵',
    label: 'Müzik Dersi',
    category: 'okul',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
  ),
  NeedCard(
    id: 87,
    emoji: '🏃',
    label: 'Beden Eğitimi',
    category: 'okul',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
  ),
  NeedCard(
    id: 88,
    emoji: '🤫',
    label: 'Sessiz Olalım',
    category: 'okul',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
  ),
];

class CardCategory {
  const CardCategory({required this.id, required this.label});

  final String id;
  final String label;
}

const kCardCategories = <CardCategory>[
  CardCategory(id: 'tümü', label: 'Tümü'),
  CardCategory(id: 'temel', label: 'Temel İhtiyaç'),
  CardCategory(id: 'duygu', label: 'Duygular'),
  CardCategory(id: 'istek', label: 'İstekler'),
  CardCategory(id: 'kisi', label: 'Kişiler'),
  CardCategory(id: 'cevap', label: 'Cevaplar'),
  CardCategory(id: 'rutin', label: 'Günlük Rutin'),
  CardCategory(id: 'sosyal', label: 'Sosyal'),
  CardCategory(id: 'okul', label: 'Okul'),
  CardCategory(id: 'ozel', label: '⭐ Özel'),
];

/// Categories available when editing / creating a card (Figma select options).
const kCardEditCategories = <CardCategory>[
  CardCategory(id: 'temel', label: 'Temel İhtiyaç'),
  CardCategory(id: 'duygu', label: 'Duygular'),
  CardCategory(id: 'istek', label: 'İstekler'),
  CardCategory(id: 'kisi', label: 'Kişiler'),
  CardCategory(id: 'rutin', label: 'Günlük Rutin'),
  CardCategory(id: 'sosyal', label: 'Sosyal'),
  CardCategory(id: 'okul', label: 'Okul'),
  CardCategory(id: 'ozel', label: '⭐ Özel'),
];

const kCustomCardsPrefsKey = 'engelsiz_custom_cards';
const kCardOverridesPrefsKey = 'engelsiz_card_overrides';
