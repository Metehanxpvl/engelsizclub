import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/async_timeout.dart';
import 'kesfet_models.dart';

/// YouTube oEmbed — genel, API anahtarı yok. Data API çağrılmaz.
Future<KesfetOEmbed> fetchYoutubeOEmbed(String rawUrl) async {
  final id = extractYoutubeVideoId(rawUrl);
  if (id == null) {
    throw StateError('Geçerli bir YouTube veya Shorts bağlantısı girin.');
  }
  final canonical = 'https://www.youtube.com/watch?v=$id';
  final uri = Uri.https('www.youtube.com', '/oembed', {
    'url': canonical,
    'format': 'json',
  });
  try {
    final res = await withNetworkTimeout(
      http.get(uri, headers: const {'Accept': 'application/json'}),
      timeout: const Duration(seconds: 12),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map is Map) {
        return KesfetOEmbed(
          title: map['title']?.toString() ?? '',
          authorName: map['author_name']?.toString() ?? '',
          authorUrl: map['author_url']?.toString() ?? '',
          thumbnailUrl: map['thumbnail_url']?.toString() ??
              'https://i.ytimg.com/vi/$id/hqdefault.jpg',
        );
      }
    }
  } catch (_) {
    // CORS / ağ: başlık admin doldurur, küçük resim yine ytimg’den gelir.
  }
  return KesfetOEmbed(
    title: '',
    authorName: '',
    authorUrl: '',
    thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  );
}

String canonicalYoutubeUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';
