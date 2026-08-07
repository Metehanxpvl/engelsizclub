import 'dart:convert';

import 'package:http/http.dart' as http;

import 'duyuru_data.dart';

/// Instagram gömülü HTML içinden olası doğrudan video URL'sini çözer.
/// Medya bizim DB/storage'a gelmez; istemci Instagram CDN'den çeker.
Future<String?> resolveInstagramVideoUrl(String? pageUrl) async {
  final parsed = parseInstagramContent(pageUrl);
  if (parsed == null || parsed.kind == 'stories') return null;

  final paths = <String>[
    'https://www.instagram.com/${parsed.kind}/${parsed.code}/embed/captioned/',
    'https://www.instagram.com/${parsed.kind}/${parsed.code}/embed/',
    'https://www.instagram.com/${parsed.kind}/${parsed.code}/',
  ];

  final targets = <String>[
    // Native (Android/iOS) doğrudan erişebilir.
    ...paths,
    // Web CORS için vekiller
    for (final p in paths)
      'https://api.allorigins.win/get?url=${Uri.encodeComponent(p)}',
    for (final p in paths)
      'https://api.allorigins.win/raw?url=${Uri.encodeComponent(p)}',
    for (final p in paths)
      'https://corsproxy.io/?${Uri.encodeComponent(p)}',
  ];

  const headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Referer': 'https://www.instagram.com/',
  };

  for (final target in targets) {
    try {
      final res = await http
          .get(Uri.parse(target), headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) continue;
      var body = res.body;
      // allorigins /get JSON
      if (target.contains('allorigins.win/get')) {
        try {
          final map = jsonDecode(body);
          if (map is Map && map['contents'] is String) {
            body = map['contents'] as String;
          }
        } catch (_) {}
      }
      final found = _extractMp4(body);
      if (found != null) return found;
    } catch (_) {
      // Sonraki hedef.
    }
  }
  return null;
}

String? _extractMp4(String body) {
  final patterns = <RegExp>[
    RegExp(r'"video_url"\s*:\s*"([^"]+)"'),
    RegExp(r'"playback_url"\s*:\s*"([^"]+)"'),
    RegExp(r'"contentUrl"\s*:\s*"([^"]+)"'),
    RegExp(r'"video_versions"\s*:\s*\[\s*\{[^}]*"url"\s*:\s*"([^"]+)"'),
    RegExp(r'property="og:video"\s+content="([^"]+)"'),
    RegExp(r'property="og:video:secure_url"\s+content="([^"]+)"'),
    RegExp(r'<meta[^>]+content="([^"]+\.mp4[^"]*)"[^>]+property="og:video'),
    RegExp(r'"(https:\\?/\\?/[^"]+\.mp4[^"]*)"'),
    RegExp(r'(https://[^\s"<>]+\.mp4[^\s"<>]*)'),
  ];

  for (final re in patterns) {
    final matches = re.allMatches(body);
    for (final m in matches) {
      var url = m.group(1);
      if (url == null || url.isEmpty) continue;
      url = url
          .replaceAll(r'\/', '/')
          .replaceAll(r'\u0026', '&')
          .replaceAll('&amp;', '&')
          .replaceAll(r'\u003d', '=');
      if (!url.startsWith('http')) continue;
      if (!(url.contains('.mp4') || url.contains('.m3u8'))) continue;
      if (url.contains('.jpg') || url.contains('.png') || url.contains('.webp')) {
        continue;
      }
      return url;
    }
  }
  return null;
}

/// Gömülü oynatıcı URL (autoplay parametreli).
String? instagramAutoplayEmbedUrl(String? url) {
  final parsed = parseInstagramContent(url);
  if (parsed == null || parsed.kind == 'stories') return null;
  return Uri(
    scheme: 'https',
    host: 'www.instagram.com',
    path: '/${parsed.kind}/${parsed.code}/embed/',
    queryParameters: const {
      'autoplay': '1',
      'mute': '1',
    },
  ).toString();
}
