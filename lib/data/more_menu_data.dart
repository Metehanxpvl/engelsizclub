/// Daha Fazlası menü öğesi (Supabase `daha_fazlasi_menu`).
class MoreMenuItem {
  const MoreMenuItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.linkType,
    required this.link,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.isBuiltin,
  });

  /// Uygulama içi route kimlikleri (`link_type: route`).
  static const builtinRoutes = <String>{
    'aile_kocu',
    'haklar',
    'kartlar',
    'mchat',
    'cvi',
    'cvi2',
    'gelisim',
  };

  final int id;
  final String title;
  final String subtitle;
  /// `route` | `url`
  final String linkType;
  final String link;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final bool isBuiltin;

  /// Normalize edilmiş route kimliği (url değilse).
  String? get routeKey => normalizeMoreMenuRoute(link);

  bool get isKnownRoute => routeKey != null;

  bool get isUrl => !isKnownRoute && linkType == 'url';
  bool get isRoute => isKnownRoute || linkType == 'route';

  MoreMenuItem copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? linkType,
    String? link,
    String? icon,
    int? sortOrder,
    bool? isActive,
    bool? isBuiltin,
  }) {
    return MoreMenuItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      linkType: linkType ?? this.linkType,
      link: link ?? this.link,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  factory MoreMenuItem.fromJson(Map<String, dynamic> json) {
    final rawLink = json['link']?.toString() ?? '';
    final route = normalizeMoreMenuRoute(rawLink);
    var linkType =
        (json['link_type']?.toString() ?? 'url').trim().toLowerCase();
    if (route != null) linkType = 'route';

    return MoreMenuItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      linkType: linkType,
      link: route ?? rawLink.trim(),
      icon: json['icon']?.toString() ?? 'link',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      isBuiltin: json['is_builtin'] == true,
    );
  }

  /// DB yazımı için map. `id` asla gönderilmez (identity otomatik üretir).
  Map<String, dynamic> toWriteJson() {
    return {
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'link_type': linkType,
      'link': link.trim(),
      'icon': icon.trim().isEmpty ? 'link' : icon.trim(),
      'sort_order': sortOrder,
      'is_active': isActive,
      'is_builtin': isBuiltin,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// `cvi2`, `/cvi2`, `route:cvi2` → `cvi2` (bilinmeyen route ise null).
String? normalizeMoreMenuRoute(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.startsWith('route:')) s = s.substring(6).trim();
  if (s.startsWith('/')) s = s.substring(1);
  if (s.contains('://') || s.contains('.')) return null;
  return MoreMenuItem.builtinRoutes.contains(s) ? s : null;
}

/// DB yoksa / hata olursa kullanılan varsayılan menü.
List<MoreMenuItem> defaultMoreMenuItems() => const [
      MoreMenuItem(
        id: -1,
        title: 'Aile Koçum',
        subtitle: 'Ders, ilaç ve not takibi (çevrimdışı)',
        linkType: 'route',
        link: 'aile_kocu',
        icon: 'family',
        sortOrder: 10,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -2,
        title: 'Haklar',
        subtitle: 'Devlet hakları ve rehber',
        linkType: 'route',
        link: 'haklar',
        icon: 'balance',
        sortOrder: 20,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -3,
        title: 'Kartlar',
        subtitle: 'Görsel destek kartları',
        linkType: 'route',
        link: 'kartlar',
        icon: 'grid',
        sortOrder: 30,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -4,
        title: 'Otizm Tarama',
        subtitle: 'M-CHAT tarama akışı',
        linkType: 'route',
        link: 'mchat',
        icon: 'search',
        sortOrder: 40,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -5,
        title: 'CVI Görsel Egzersizleri',
        subtitle: '20 adımlık yüksek kontrastlı görsel egzersiz',
        linkType: 'route',
        link: 'cvi',
        icon: 'eye',
        sortOrder: 50,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -7,
        title: 'CVI Egzersizleri-2',
        subtitle: 'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
        linkType: 'url',
        link: '/bilgi-kutuphanesi/cvi-egzersizleri-2',
        icon: 'eye',
        sortOrder: 55,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -6,
        title: 'Gelişim Etkinlikleri',
        subtitle: '120 etkinlik · 7 grup · filtre ve video',
        linkType: 'route',
        link: 'gelisim',
        icon: 'extension',
        sortOrder: 60,
        isActive: true,
        isBuiltin: true,
      ),
    ];
