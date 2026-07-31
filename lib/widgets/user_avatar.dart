import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Avatar alanı görsel mi (data URL / http), yoksa baş harf mi?
bool isAvatarImageSource(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return false;
  return s.startsWith('data:image') ||
      s.startsWith('http://') ||
      s.startsWith('https://');
}

String avatarInitialsFallback(String nameOrInitials) {
  final t = nameOrInitials.trim();
  if (t.isEmpty) return '?';
  if (isAvatarImageSource(t)) return '?';
  if (t.length <= 3 && !t.contains(' ')) return t.toUpperCase();
  final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return t.substring(0, 1).toUpperCase();
}

/// Profil fotoğrafı veya baş harf gösteren dairesel avatar.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatar,
    required this.color,
    this.radius = 18,
    this.fallbackName = '',
  });

  /// data:image… / http(s) veya baş harf metni
  final String avatar;
  final Color color;
  final double radius;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final src = avatar.trim();
    Widget child;
    if (isAvatarImageSource(src)) {
      child = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: _buildImage(src, size),
        ),
      );
    } else {
      final initials = avatarInitialsFallback(
        src.isNotEmpty ? src : fallbackName,
      );
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.72,
          ),
        ),
      );
    }
    return child;
  }

  Widget _buildImage(String src, double size) {
    if (src.startsWith('data:image')) {
      try {
        final b64 = src.contains(',') ? src.split(',').last : src;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackBox(size),
        );
      } catch (_) {
        return _fallbackBox(size);
      }
    }
    return Image.network(
      src,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackBox(size),
    );
  }

  Widget _fallbackBox(double size) {
    final initials = avatarInitialsFallback(fallbackName);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

/// owner_email → photo_data (bellek önbelleği).
final Map<String, String> _photoCache = {};

Future<Map<String, String>> loadUserPhotosByEmail(
  Iterable<String> emails,
) async {
  final needed = <String>{};
  final result = <String, String>{};
  for (final raw in emails) {
    final e = raw.trim().toLowerCase();
    if (e.isEmpty) continue;
    final cached = _photoCache[e];
    if (cached != null) {
      if (cached.isNotEmpty) result[e] = cached;
    } else {
      needed.add(e);
    }
  }
  if (needed.isEmpty) return result;

  try {
    final client = Supabase.instance.client;
    // Önce RPC (güvenli); yoksa sınırlı select dene.
    try {
      final rows = await client.rpc(
        'get_user_photos',
        params: {'emails': needed.toList()},
      );
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          final email = (row['owner_email']?.toString() ?? '').toLowerCase();
          final photo = row['photo_data']?.toString() ?? '';
          if (email.isEmpty) continue;
          _photoCache[email] = photo;
          if (photo.isNotEmpty) result[email] = photo;
        }
      }
    } catch (_) {
      final rows = await client
          .from('user_profiles')
          .select('owner_email, photo_data')
          .inFilter('owner_email', needed.toList());
      for (final row in (rows as List).whereType<Map>()) {
        final email = (row['owner_email']?.toString() ?? '').toLowerCase();
        final photo = row['photo_data']?.toString() ?? '';
        if (email.isEmpty) continue;
        _photoCache[email] = photo;
        if (photo.isNotEmpty) result[email] = photo;
      }
    }
    for (final e in needed) {
      _photoCache.putIfAbsent(e, () => '');
    }
  } catch (_) {
    for (final e in needed) {
      _photoCache.putIfAbsent(e, () => '');
    }
  }
  return result;
}

void cacheOwnUserPhoto(String email, String? photoData) {
  final e = email.trim().toLowerCase();
  if (e.isEmpty) return;
  _photoCache[e] = (photoData ?? '').trim();
}

String resolveAvatar({
  required String storedAvatar,
  required String ownerEmail,
  Map<String, String>? photosByEmail,
  String? ownPhoto,
  String? ownEmail,
  bool anonymous = false,
}) {
  // Anonim paylaşımlarda profil fotoğrafı asla gösterilmez.
  if (anonymous) return 'A';
  if (isAvatarImageSource(storedAvatar)) return storedAvatar;
  final email = ownerEmail.trim().toLowerCase();
  final me = (ownEmail ?? '').trim().toLowerCase();
  if (email.isNotEmpty && me.isNotEmpty && email == me) {
    final p = (ownPhoto ?? '').trim();
    if (isAvatarImageSource(p)) return p;
  }
  final fromMap = photosByEmail?[email];
  if (isAvatarImageSource(fromMap)) return fromMap!;
  final cached = _photoCache[email];
  if (isAvatarImageSource(cached)) return cached!;
  return storedAvatar;
}
