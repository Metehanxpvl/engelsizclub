import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/duyuru_data.dart';

const kUsefulContentStatuses = <String>{
  'pending_review',
  'published',
  'rejected',
  'expired',
};

const kUsefulContentCategories = <String, String>{
  'tumu': 'Tümü',
  'firsat': 'Fırsat',
  'destek': 'Destek',
  'hak': 'Hak',
  'burs': 'Burs',
  'egitim': 'Eğitim',
  'istihdam': 'İstihdam',
  'haber': 'Haber',
  'diger': 'Diğer',
};

const kGlobalNewsUsefulPrefix = 'gn:';

bool isGlobalNewsUsefulItem(UsefulContentItem item) {
  return item.contentKind == 'global_news' ||
      item.id.startsWith(kGlobalNewsUsefulPrefix);
}

String globalNewsRawId(String id) {
  return id.startsWith(kGlobalNewsUsefulPrefix)
      ? id.substring(kGlobalNewsUsefulPrefix.length)
      : id;
}

String usefulCategoryFromGlobalNews(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'haklar':
      return 'hak';
    case 'egitim':
      return 'egitim';
    case 'istihdam':
      return 'istihdam';
    default:
      return 'haber';
  }
}

/// Collector / eski kayıtlar 'approved' yazarsa yayın filtresi bozulmasın.
String normalizeUsefulContentStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s == 'approved' || s == 'approve' || s == 'onaylandi') {
    return 'published';
  }
  if (s == 'pending' || s == 'review' || s == 'draft') {
    return 'pending_review';
  }
  if (kUsefulContentStatuses.contains(s)) return s;
  return s;
}

bool isUserVisibleUsefulContent(String status) {
  return normalizeUsefulContentStatus(status) == 'published';
}

bool isPendingReviewStatus(String status) {
  return normalizeUsefulContentStatus(status) == 'pending_review';
}

String usefulContentHash({
  required String title,
  required String summary,
  required String sourceUrl,
}) {
  final normalized = [
    title.trim().toLowerCase(),
    summary.trim().toLowerCase(),
    sourceUrl.trim().toLowerCase(),
  ].join('|');
  return sha256.convert(utf8.encode(normalized)).toString();
}

bool isUsefulContentDuplicate({
  required Set<String> existingUrls,
  required Set<String> existingHashes,
  required Set<String> existingExternalIds,
  String? sourceUrl,
  String? contentHash,
  String? externalId,
}) {
  final url = (sourceUrl ?? '').trim();
  final hash = (contentHash ?? '').trim();
  final ext = (externalId ?? '').trim();
  if (url.isNotEmpty && existingUrls.contains(url)) return true;
  if (hash.isNotEmpty && existingHashes.contains(hash)) return true;
  if (ext.isNotEmpty && existingExternalIds.contains(ext)) return true;
  return false;
}

/// Story görseli yoksa ve kaynak Instagram değilse Onayla’dan önce foto gerekir.
bool usefulContentNeedsStoryImage(UsefulContentItem item) {
  if (isGlobalNewsUsefulItem(item)) return false;
  if (item.imageUrl.trim().isNotEmpty) return false;
  if (isInstagramUrl(item.sourceUrl)) return false;
  return true;
}

/// addDuyuru’ya geçilecek görsel: kayıt URL’si veya Instagram marker.
String usefulContentStoryImageUrl(UsefulContentItem item) {
  final u = item.imageUrl.trim();
  if (u.isNotEmpty) return u;
  if (isInstagramUrl(item.sourceUrl)) return kInstagramEmbedMarker;
  return '';
}

/// Onayla, birey Güncel Duyuru paylaşınca olduğu gibi FCM gönderir.
const kUsefulContentApproveNotify = true;

/// Collector deadline geçmişse duyuru gizlenmesin (isVisibleNow).
DateTime? usefulContentDuyuruExpiresAt(
  UsefulContentItem item, [
  DateTime? now,
]) {
  final end = item.expiresAt;
  if (end == null) return null;
  final n = now ?? DateTime.now();
  if (!end.isAfter(n)) return null;
  return end;
}

String usefulContentDuyuruBody(
  UsefulContentItem item, {
  String? summary,
}) {
  final s = (summary ?? item.summary).trim();
  if (s.isNotEmpty) return s;
  if (item.body.trim().isNotEmpty) return item.body.trim();
  return item.sourceUrl.trim();
}

/// Onayla → addDuyuru alanları (notify = birey paylaşınca).
({
  String title,
  String body,
  String imageUrl,
  String? sourceUrl,
  DateTime? expiresAt,
  bool requireImage,
  bool notify,
}) usefulContentToDuyuruDraft(
  UsefulContentItem item, {
  String imageUrl = '',
  String? title,
  String? summary,
  DateTime? now,
}) {
  var photo = imageUrl.trim();
  if (photo.isEmpty) photo = usefulContentStoryImageUrl(item);
  final headline = (title ?? item.title).trim();
  final src = item.sourceUrl.trim();
  return (
    title: headline.isEmpty ? 'Fırsat / destek' : headline,
    body: usefulContentDuyuruBody(item, summary: summary),
    imageUrl: photo,
    sourceUrl: src.isEmpty ? null : src,
    expiresAt: usefulContentDuyuruExpiresAt(item, now),
    requireImage: photo.isNotEmpty,
    notify: kUsefulContentApproveNotify,
  );
}

class UsefulContentItem {
  const UsefulContentItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    required this.city,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl = '',
    required this.externalId,
    required this.contentHash,
    required this.status,
    this.deadlineAt,
    this.expiresAt,
    this.createdAt,
    this.publishedAt,
    this.dateStatus = '',
    this.contentKind = '',
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final String category;
  final String city;
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final String? externalId;
  final String contentHash;
  final String status;
  final DateTime? deadlineAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final String dateStatus;
  final String contentKind;

  bool get isRecentFifteenDays =>
      contentKind == 'recent' || dateStatus == 'recent';

  bool get isActiveOpportunityBadge => contentKind == 'active_opportunity';

  UsefulContentItem copyWith({
    String? title,
    String? summary,
    String? imageUrl,
  }) =>
      UsefulContentItem(
        id: id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        body: body,
        category: category,
        city: city,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        externalId: externalId,
        contentHash: contentHash,
        status: status,
        deadlineAt: deadlineAt,
        expiresAt: expiresAt,
        createdAt: createdAt,
        publishedAt: publishedAt,
        dateStatus: dateStatus,
        contentKind: contentKind,
      );

  String get categoryLabel =>
      kUsefulContentCategories[category] ?? kUsefulContentCategories['diger']!;

  factory UsefulContentItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
    }

    return UsefulContentItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      summary: json['summary']?.toString().trim() ?? '',
      body: json['body']?.toString().trim() ?? '',
      category: (json['category']?.toString().trim().toLowerCase().isEmpty ??
              true)
          ? 'diger'
          : json['category'].toString().trim().toLowerCase(),
      city: json['city']?.toString().trim() ?? '',
      sourceName: json['source_name']?.toString().trim() ?? '',
      sourceUrl: json['source_url']?.toString().trim() ?? '',
      imageUrl: json['image_url']?.toString().trim() ?? '',
      externalId: json['external_id']?.toString().trim(),
      contentHash: json['content_hash']?.toString().trim() ?? '',
      status: normalizeUsefulContentStatus(
        json['status']?.toString() ?? 'pending_review',
      ),
      deadlineAt: parseTs(json['deadline_at']),
      expiresAt: parseTs(json['expires_at']),
      createdAt: parseTs(json['created_at']),
      publishedAt: parseTs(json['published_at']),
      dateStatus: json['date_status']?.toString().trim().toLowerCase() ?? '',
      contentKind: json['content_kind']?.toString().trim().toLowerCase() ?? '',
    );
  }
}
