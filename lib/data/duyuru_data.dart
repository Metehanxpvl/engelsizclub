/// DB'de medya yok — yalnızca kısa işaretçi + Instagram sayfa linki (source_url).
const kInstagramEmbedMarker = 'instagram:embed';

/// Eski kayıtlarda CDN URL metni olabilir; yeni kayıtlarda kullanılmaz.
const kInstagramVideoPrefix = 'instagram:video:';

class DuyuruItem {
  const DuyuruItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    this.sourceUrl,
    required this.createdAt,
    this.isActive = true,
    this.isPopup = false,
    this.publishAt,
    this.expiresAt,
  });

  final int id;
  final String title;
  final String body;
  /// Instagram: daima [kInstagramEmbedMarker] (medya/base64 yok).
  final String imageUrl;
  /// Instagram permalink — yalnızca kısa metin URL.
  final String? sourceUrl;
  final DateTime createdAt;
  final bool isActive;
  final bool isPopup;
  /// Yayın başlangıç (null = hemen / createdAt).
  final DateTime? publishAt;
  /// Yayın bitiş (null = süresiz).
  final DateTime? expiresAt;

  /// Şu an normal kullanıcıya gösterilebilir mi?
  bool isVisibleNow([DateTime? now]) {
    if (!isActive) return false;
    final n = now ?? DateTime.now();
    final start = publishAt ?? createdAt;
    if (start.isAfter(n)) return false;
    final end = expiresAt;
    if (end != null && !end.isAfter(n)) return false;
    return true;
  }

  bool get hasSource {
    final u = (sourceUrl ?? '').trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  bool get isInstagramEmbed {
    final img = imageUrl.trim();
    if (img == kInstagramEmbedMarker) return true;
    if (img.startsWith(kInstagramVideoPrefix)) return true;
    if (img.isEmpty && isInstagramUrl(sourceUrl)) return true;
    return false;
  }

  /// Eski kayıtlardan kalan CDN URL (varsa). Yeni akışta null — istemci çözer.
  String? get playableVideoUrl {
    final img = imageUrl.trim();
    if (img.startsWith(kInstagramVideoPrefix)) {
      final u = img.substring(kInstagramVideoPrefix.length).trim();
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
    }
    return null;
  }

  String? get instagramUrl => normalizeInstagramUrl(sourceUrl);

  DuyuruItem copyWith({
    String? title,
    String? body,
    String? imageUrl,
    String? sourceUrl,
    bool clearSource = false,
    bool? isActive,
    bool? isPopup,
    DateTime? publishAt,
    DateTime? expiresAt,
    bool clearPublishAt = false,
    bool clearExpiresAt = false,
  }) =>
      DuyuruItem(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        imageUrl: imageUrl ?? this.imageUrl,
        sourceUrl: clearSource ? null : (sourceUrl ?? this.sourceUrl),
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
        isPopup: isPopup ?? this.isPopup,
        publishAt: clearPublishAt ? null : (publishAt ?? this.publishAt),
        expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      );
}

bool isInstagramUrl(String? url) {
  final u = (url ?? '').trim().toLowerCase();
  if (u.isEmpty) return false;
  return u.contains('instagram.com') || u.contains('instagr.am');
}

bool looksLikeEmbeddedMediaPayload(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return false;
  if (v.startsWith('http://') || v.startsWith('https://')) return false;
  if (v == kInstagramEmbedMarker || v.startsWith(kInstagramVideoPrefix)) {
    return false;
  }
  return v.startsWith('data:image') ||
      v.startsWith('data:video') ||
      v.startsWith('blob:');
}

bool isInstagramStoryUrl(String? url) {
  final u = (url ?? '').trim().toLowerCase();
  return u.contains('/stories/');
}

class InstagramContentRef {
  const InstagramContentRef({required this.kind, required this.code});
  final String kind;
  final String code;
}

InstagramContentRef? parseInstagramContent(String? url) {
  final raw = (url ?? '').trim();
  if (!isInstagramUrl(raw)) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  for (var i = 0; i < segments.length; i++) {
    final kind = segments[i].toLowerCase();
    if (i + 1 >= segments.length) break;
    final next = segments[i + 1];
    if (next.isEmpty) continue;

    switch (kind) {
      case 'p':
        return InstagramContentRef(kind: 'p', code: next);
      case 'reel':
      case 'reels':
        return InstagramContentRef(kind: 'reel', code: next);
      case 'tv':
        return InstagramContentRef(kind: 'tv', code: next);
      case 'stories':
        if (i + 2 < segments.length && segments[i + 2].isNotEmpty) {
          return InstagramContentRef(kind: 'stories', code: segments[i + 2]);
        }
        return InstagramContentRef(kind: 'stories', code: next);
    }
  }
  return null;
}

String? normalizeInstagramUrl(String? url) {
  final raw = (url ?? '').trim();
  if (!isInstagramUrl(raw)) return null;
  final parsed = parseInstagramContent(raw);
  if (parsed == null) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return Uri(
      scheme: 'https',
      host: 'www.instagram.com',
      path: '/${segments.join('/')}',
    ).toString();
  }

  if (parsed.kind == 'stories') {
    final uri = Uri.tryParse(raw);
    final segs = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
    final userIdx = segs.indexWhere((s) => s.toLowerCase() == 'stories');
    final user = (userIdx >= 0 && userIdx + 1 < segs.length)
        ? segs[userIdx + 1]
        : 'user';
    return 'https://www.instagram.com/stories/$user/${parsed.code}';
  }

  return 'https://www.instagram.com/${parsed.kind}/${parsed.code}';
}

/// Medya Instagram CDN'den gelir; DB'ye dosya yazılmaz.
String? instagramEmbedUrl(String? url) {
  final parsed = parseInstagramContent(url);
  if (parsed == null || parsed.kind == 'stories') return null;
  return Uri(
    scheme: 'https',
    host: 'www.instagram.com',
    path: '/${parsed.kind}/${parsed.code}/embed/',
    queryParameters: const {'autoplay': '1', 'mute': '1'},
  ).toString();
}

String instagramPlaybackUrl(String pageUrl) {
  return instagramEmbedUrl(pageUrl) ?? pageUrl.trim();
}
