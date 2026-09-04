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
    this.parentId,
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
    'boyama',
    'folder',
  };

  final int id;
  final String title;
  final String subtitle;
  /// `route` | `url` | `folder`
  final String linkType;
  final String link;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final bool isBuiltin;
  /// Aynı tabloda üst grup. `null` = üst seviye.
  final int? parentId;

  /// Normalize edilmiş route kimliği (url değilse).
  String? get routeKey =>
      linkType == 'folder' ? 'folder' : normalizeMoreMenuRoute(link);

  bool get isKnownRoute => routeKey != null;

  bool get isUrl => !isKnownRoute && linkType == 'url';
  bool get isRoute => isKnownRoute || linkType == 'route';

  /// Admin grubu veya yerleşik Taramalar klasörü.
  bool get isFolder {
    if (linkType == 'folder') return true;
    final key = routeKey ?? link.trim().toLowerCase();
    return key == 'taramalar' ||
        key == 'taramalar_egzersizler_oyun' ||
        key == 'folder';
  }

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
    Object? parentId = _parentIdSentinel,
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
      parentId: identical(parentId, _parentIdSentinel)
          ? this.parentId
          : parentId as int?,
    );
  }

  factory MoreMenuItem.fromJson(Map<String, dynamic> json) {
    final rawLink = json['link']?.toString() ?? '';
    var linkType =
        (json['link_type']?.toString() ?? 'url').trim().toLowerCase();
    final parentRaw = json['parent_id'];
    final parentId = parentRaw is num
        ? parentRaw.toInt()
        : int.tryParse(parentRaw?.toString() ?? '');
    final safeParent =
        (parentId != null && parentId > 0) ? parentId : null;

    if (linkType == 'folder') {
      return MoreMenuItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        linkType: 'folder',
        link: rawLink.trim().isEmpty ? 'folder' : rawLink.trim(),
        icon: json['icon']?.toString() ?? 'folder',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] != false,
        isBuiltin: json['is_builtin'] == true,
        parentId: safeParent,
      );
    }

    final route = normalizeMoreMenuRoute(rawLink);
    if (route != null) linkType = route == 'folder' ? 'folder' : 'route';

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
      parentId: safeParent,
    );
  }

  /// DB yazımı için map. `id` asla gönderilmez (identity otomatik üretir).
  Map<String, dynamic> toWriteJson() {
    return {
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'link_type': linkType == 'folder' ? 'folder' : linkType,
      'link': linkType == 'folder'
          ? (link.trim().isEmpty ? 'folder' : link.trim())
          : link.trim(),
      'icon': icon.trim().isEmpty
          ? (linkType == 'folder' ? 'folder' : 'link')
          : icon.trim(),
      'sort_order': sortOrder,
      'is_active': isActive,
      'is_builtin': isBuiltin,
      'parent_id': parentId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

const Object _parentIdSentinel = Object();

/// `cvi2`, `/cvi2`, `route:cvi2` → `cvi2` (bilinmeyen route ise null).
/// `boyama.html` / `/boyama` URL’leri in-app `boyama` route’una çevrilir.
String? normalizeMoreMenuRoute(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.startsWith('route:')) s = s.substring(6).trim();

  final isUrlish = s.contains('://') || s.contains('.');
  if (isUrlish) {
    if (s.contains('boyama.html') ||
        RegExp(r'(^|/)boyama(/|$|\?)').hasMatch(s)) {
      return 'boyama';
    }
    return null;
  }

  if (s.startsWith('/')) s = s.substring(1);
  if (s == 'taramalar_egzersizler_oyun') s = 'taramalar';
  return MoreMenuItem.builtinRoutes.contains(s) ? s : null;
}

int compareMoreMenuOrder(MoreMenuItem a, MoreMenuItem b) {
  final bySort = a.sortOrder.compareTo(b.sortOrder);
  return bySort != 0 ? bySort : a.id.compareTo(b.id);
}

bool hasMoreMenuNesting(List<MoreMenuItem> items) {
  return items.any((e) => e.parentId != null && e.parentId! > 0);
}

/// Üst seviye: parent yok veya parent listede değil (pasif/silinmiş).
List<MoreMenuItem> moreMenuRoots(List<MoreMenuItem> items) {
  final ids = items.map((e) => e.id).toSet();
  final roots = items
      .where((e) => e.parentId == null || !ids.contains(e.parentId))
      .toList();
  roots.sort(compareMoreMenuOrder);
  return roots;
}

List<MoreMenuItem> moreMenuChildren(
  List<MoreMenuItem> items,
  int parentId,
) {
  final children =
      items.where((e) => e.parentId == parentId).toList();
  children.sort(compareMoreMenuOrder);
  return children;
}

class MoreMenuTreeNode {
  const MoreMenuTreeNode({required this.item, required this.depth});
  final MoreMenuItem item;
  final int depth;
}

/// Admin listesi: parent_id + sort_order ağacı.
List<MoreMenuTreeNode> flattenMoreMenuTree(List<MoreMenuItem> items) {
  final byParent = <int?, List<MoreMenuItem>>{};
  final ids = items.map((e) => e.id).toSet();
  for (final e in items) {
    final key = (e.parentId != null && ids.contains(e.parentId))
        ? e.parentId
        : null;
    byParent.putIfAbsent(key, () => []).add(e);
  }
  for (final list in byParent.values) {
    list.sort(compareMoreMenuOrder);
  }

  final out = <MoreMenuTreeNode>[];
  final walking = <int>{};

  void walk(int? parentId, int depth) {
    for (final e in byParent[parentId] ?? const <MoreMenuItem>[]) {
      if (!walking.add(e.id)) continue;
      out.add(MoreMenuTreeNode(item: e, depth: depth));
      walk(e.id, depth + 1);
      walking.remove(e.id);
    }
  }

  walk(null, 0);
  return out;
}

bool wouldCreateMoreMenuCycle(
  List<MoreMenuItem> items,
  int id,
  int? newParentId,
) {
  if (newParentId == null) return false;
  if (newParentId == id) return true;
  final byId = {for (final e in items) e.id: e};
  int? current = newParentId;
  final seen = <int>{};
  while (current != null) {
    if (current == id) return true;
    if (!seen.add(current)) return true;
    current = byId[current]?.parentId;
  }
  return false;
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

const defaultBoyamaMenuItem = MoreMenuItem(
  id: -15,
  title: 'engelsiz Boyama',
  subtitle: 'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  linkType: 'route',
  link: 'boyama',
  icon: '🎨',
  sortOrder: 6,
  isActive: true,
  isBuiltin: true,
);

bool isTaramalarGroupItem(MoreMenuItem e) {
  final k = (e.routeKey ?? e.link.trim().toLowerCase());
  return k == 'taramalar' || k == 'taramalar_egzersizler_oyun';
}

bool isBoyamaMenuItem(MoreMenuItem e) {
  if (e.routeKey == 'boyama') return true;
  final raw = e.link.trim().toLowerCase();
  final title = e.title.trim().toLowerCase();
  return raw.contains('boyama') || title.contains('boyama');
}

/// SQL yokken Taramalar altına düşen eski çocuklar (yalnız fallback).
bool isTaramalarChildItem(MoreMenuItem e) {
  if (isTaramalarGroupItem(e) || isBoyamaMenuItem(e)) return false;
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

/// parent_id yokken Taramalar sheet’i için varsayılan çocuklar.
const taramalarFallbackChildren = <MoreMenuItem>[
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
        parentId: -10,
      ),
      MoreMenuItem(
        id: -12,
        title: 'CVI görsel egzersizleri',
        subtitle: '20 adımlık yüksek kontrastlı görsel egzersiz',
        linkType: 'route',
        link: 'cvi',
        icon: 'eye',
        sortOrder: 3,
        isActive: true,
        isBuiltin: true,
        parentId: -10,
      ),
      MoreMenuItem(
        id: -13,
        title: 'CVI görsel egzersizleri-2',
        subtitle: 'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
        linkType: 'route',
        link: 'cvi2',
        icon: 'eye',
        sortOrder: 4,
        isActive: true,
        isBuiltin: true,
        parentId: -10,
      ),
      MoreMenuItem(
        id: -14,
        title: 'Otizm tarama modülleri',
        subtitle: 'M-CHAT tarama akışı',
        linkType: 'route',
        link: 'mchat',
        icon: 'search',
        sortOrder: 5,
        isActive: true,
        isBuiltin: true,
        parentId: -10,
      ),
    ];

List<MoreMenuItem> taramalarGroupChildren() => taramalarFallbackChildren;

/// Grup altındaki satırlar: parent_id varsa ondan, yoksa Taramalar fallback.
List<MoreMenuItem> childrenForMoreMenuGroup(
  MoreMenuItem parent,
  List<MoreMenuItem> all,
) {
  final nested = parent.id == 0
      ? const <MoreMenuItem>[]
      : moreMenuChildren(all, parent.id);
  if (hasMoreMenuNesting(all)) return nested;
  if (isTaramalarGroupItem(parent)) {
    final heuristic = all.where(isTaramalarChildItem).toList()
      ..sort(compareMoreMenuOrder);
    if (heuristic.isNotEmpty) return heuristic;
    return taramalarGroupChildren();
  }
  return nested;
}

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
/// Yalnız `parent_id` yokken (SQL çalışmadı) kullanılır.
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

/// Kullanıcı Daha Fazlası: parent_id ağacının kökleri.
/// Sütun yoksa eski Taramalar gruplamasına düşer (çift satır olmasın).
List<MoreMenuItem> prepareUserMoreMenu(List<MoreMenuItem> items) {
  final cleaned = withoutMovedLibraryItems(items);
  if (hasMoreMenuNesting(cleaned)) {
    return moreMenuRoots(cleaned);
  }
  return withTaramalarGroup(
    withProminentHarita(cleaned, pinTop: true),
    pinTop: true,
  );
}

/// Admin: tüm satırlar (ağaç UI’da indent). parent_id sırası korunur.
List<MoreMenuItem> prepareAdminMoreMenu(List<MoreMenuItem> items) {
  final cleaned = withoutMovedLibraryItems(List<MoreMenuItem>.from(items));
  if (!hasMoreMenuNesting(cleaned)) {
    return withTaramalarGroup(
      withProminentHarita(cleaned, pinTop: false),
      pinTop: false,
    );
  }
  cleaned.sort(compareMoreMenuOrder);
  return cleaned;
}

/// DB yoksa / hata olursa kullanılan varsayılan menü.
List<MoreMenuItem> defaultMoreMenuItems() => [
      defaultHaritaMenuItem,
      defaultTaramalarGroupItem,
      defaultBoyamaMenuItem,
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
      ...taramalarGroupChildren(),
    ];
