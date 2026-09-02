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
    'harita',
    'merkezler',
    'aile_kocu',
    'haklar',
    'kartlar',
    'mchat',
    'cvi',
    'cvi2',
    'gelisim',
    'barkod',
    'taramalar',
    'puzzle',
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
  bool get isFolder => routeKey == 'taramalar';

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
  if (s == 'taramalar_egzersizler_oyun') s = 'taramalar';
  return MoreMenuItem.builtinRoutes.contains(s) ? s : null;
}

const defaultHaritaMenuItem = MoreMenuItem(
  id: -9,
  title: 'Harita',
  subtitle: 'Destek merkezleri ve yakındaki hizmet noktaları',
  linkType: 'route',
  link: 'harita',
  icon: 'place',
  sortOrder: 0,
  isActive: true,
  isBuiltin: true,
);

bool isHaritaMenuItem(MoreMenuItem e) {
  final k = (e.routeKey ?? e.link.trim().toLowerCase());
  return k == 'harita' || k == 'merkezler';
}

/// Harita artık alt menüde değil; Daha Fazlası’nda üstte dursun.
/// [pinTop] kullanıcı menüsünde her zaman en üste alır; admin listesinde sıra korunur.
List<MoreMenuItem> withProminentHarita(
  List<MoreMenuItem> items, {
  bool pinTop = true,
}) {
  final existing = items.where(isHaritaMenuItem).toList();
  if (existing.isEmpty) {
    return [defaultHaritaMenuItem, ...items];
  }
  if (!pinTop) return items;
  return [existing.first, ...items.where((e) => !isHaritaMenuItem(e))];
}

/// Eski çağrılar: haritayı gizleme — artık menüde öne çıkar.
List<MoreMenuItem> withoutMainNavMapItems(List<MoreMenuItem> items) {
  return withProminentHarita(items);
}

const puzzleGameUrl = '/fotografli-puzzle.html';

const defaultTaramalarGroupItem = MoreMenuItem(
  id: -10,
  title: 'Taramalar & Egzersizler & Oyun',
  subtitle: 'Puzzle, CVI egzersizleri ve otizm tarama',
  linkType: 'route',
  link: 'taramalar',
  icon: 'apps',
  sortOrder: 5,
  isActive: true,
  isBuiltin: true,
);

bool isTaramalarGroupItem(MoreMenuItem e) {
  final k = (e.routeKey ?? e.link.trim().toLowerCase());
  return k == 'taramalar' || k == 'taramalar_egzersizler_oyun';
}

/// Üst menüde durmamalı; grup içine taşınan öğeler.
bool isTaramalarChildItem(MoreMenuItem e) {
  if (isTaramalarGroupItem(e)) return false;
  final key = e.routeKey;
  if (key == 'cvi' || key == 'cvi2' || key == 'mchat' || key == 'puzzle') {
    return true;
  }
  final raw = e.link.trim().toLowerCase();
  if (raw.contains('fotografli-puzzle')) return true;
  if (raw.contains('cvi-egzersizleri-2')) return true;
  if (raw.contains('cvi-gorsel-egzersiz')) return true;
  return false;
}

/// Grup altındaki 4 özellik (mevcut ekranlar — yeniden yazılmaz).
List<MoreMenuItem> taramalarGroupChildren() => const [
      MoreMenuItem(
        id: -11,
        title: 'Puzzled oyun',
        subtitle: 'Fotoğraflı puzzle',
        linkType: 'route',
        link: 'puzzle',
        icon: 'games',
        sortOrder: 1,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -12,
        title: 'CVI görsel egzersizleri',
        subtitle: '20 adımlık yüksek kontrastlı görsel egzersiz',
        linkType: 'route',
        link: 'cvi',
        icon: 'eye',
        sortOrder: 2,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -13,
        title: 'CVI görsel egzersizleri-2',
        subtitle: 'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
        linkType: 'route',
        link: 'cvi2',
        icon: 'eye',
        sortOrder: 3,
        isActive: true,
        isBuiltin: true,
      ),
      MoreMenuItem(
        id: -14,
        title: 'Otizm tarama modülleri',
        subtitle: 'M-CHAT tarama akışı',
        linkType: 'route',
        link: 'mchat',
        icon: 'search',
        sortOrder: 4,
        isActive: true,
        isBuiltin: true,
      ),
    ];

/// Bilgi Kütüphanesi’ne taşınan öğeler (üst menü ve grupta tekrar görünmesin).
bool isMovedToLibraryMenuItem(MoreMenuItem e) {
  final raw = e.link.trim().toLowerCase().replaceAll('–', '-');
  final title = e.title.trim().toLowerCase().replaceAll('–', '-');
  if (raw.contains('0-2-yas-gelisim-rehberi')) return true;
  if (raw.contains('daha-fazlasi/ozel')) return true;
  if (title.contains('0-2') && title.contains('gelişim rehberi')) return true;
  if (title.contains('0-2') && title.contains('gelisim rehberi')) return true;
  return false;
}

List<MoreMenuItem> withoutMovedLibraryItems(List<MoreMenuItem> items) {
  return items.where((e) => !isMovedToLibraryMenuItem(e)).toList();
}

/// Grubu Harita’dan hemen sonra gösterir; çocukları üst listeden çeker.
/// [pinTop] kullanıcı menüsü; admin listesinde sıra korunur, eksik grup eklenir.
List<MoreMenuItem> withTaramalarGroup(
  List<MoreMenuItem> items, {
  bool pinTop = true,
}) {
  final existing = items.where(isTaramalarGroupItem).toList();
  final rest = items.where((e) => !isTaramalarGroupItem(e)).toList();
  final group = existing.isEmpty ? defaultTaramalarGroupItem : existing.first;

  if (!pinTop) {
    if (existing.isNotEmpty) return items;
    final haritaIdx = rest.indexWhere(isHaritaMenuItem);
    if (haritaIdx >= 0) {
      return [
        ...rest.take(haritaIdx + 1),
        group,
        ...rest.skip(haritaIdx + 1),
      ];
    }
    return [group, ...rest];
  }

  final visible = rest.where((e) => !isTaramalarChildItem(e)).toList();
  if (visible.isNotEmpty && isHaritaMenuItem(visible.first)) {
    return [visible.first, group, ...visible.skip(1)];
  }
  return [group, ...visible];
}

List<MoreMenuItem> prepareUserMoreMenu(List<MoreMenuItem> items) {
  return withTaramalarGroup(
    withProminentHarita(withoutMovedLibraryItems(items), pinTop: true),
    pinTop: true,
  );
}

List<MoreMenuItem> prepareAdminMoreMenu(List<MoreMenuItem> items) {
  return withTaramalarGroup(
    withProminentHarita(withoutMovedLibraryItems(items), pinTop: false),
    pinTop: false,
  );
}

/// DB yoksa / hata olursa kullanılan varsayılan menü.
List<MoreMenuItem> defaultMoreMenuItems() => const [
      defaultHaritaMenuItem,
      defaultTaramalarGroupItem,
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
      MoreMenuItem(
        id: -8,
        title: 'Barkod / Ürün Analizi',
        subtitle: 'İçerik, olası alerjenler ve katkı bilgisi (teşhis değildir)',
        linkType: 'route',
        link: 'barkod',
        icon: 'barcode',
        sortOrder: 70,
        isActive: true,
        isBuiltin: true,
      ),
    ];
