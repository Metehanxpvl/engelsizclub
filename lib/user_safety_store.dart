import 'package:supabase_flutter/supabase_flutter.dart';

import 'bildirim_store.dart';

class BlockedUser {
  const BlockedUser({
    required this.email,
    required this.createdAt,
  });

  final String email;
  final DateTime createdAt;
}

/// Bellek önbelleği — sohbet / forum filtreleri için.
Set<String> _blockedEmailsCache = {};
DateTime? _blockedCacheAt;
const _blockedCacheTtl = Duration(minutes: 5);

Set<String> get cachedBlockedEmails => Set<String>.from(_blockedEmailsCache);

bool get hasFreshBlockCache {
  final at = _blockedCacheAt;
  if (at == null) return false;
  return DateTime.now().difference(at) < _blockedCacheTtl;
}

void invalidateBlockCache() {
  _blockedEmailsCache = {};
  _blockedCacheAt = null;
}

String? _myEmail() {
  final e =
      (Supabase.instance.client.auth.currentUser?.email ?? '').trim().toLowerCase();
  return e.isEmpty ? null : e;
}

bool isBlockedEmail(String email) {
  final t = email.trim().toLowerCase();
  if (t.isEmpty) return false;
  return _blockedEmailsCache.contains(t);
}

/// Karşılıklı engel: ben onu veya o beni engellemiş olabilir (gönderim kontrolü).
Future<bool> isEitherBlocked(String peerEmail) async {
  final me = _myEmail();
  final peer = peerEmail.trim().toLowerCase();
  if (me == null || peer.isEmpty || me == peer) return false;
  if (_blockedEmailsCache.contains(peer)) return true;
  try {
    final rows = await Supabase.instance.client
        .from('user_blocks')
        .select('id')
        .eq('blocker_email', peer)
        .eq('blocked_email', me)
        .limit(1);
    return (rows as List).isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<Set<String>> loadBlockedEmails({bool forceRefresh = false}) async {
  final me = _myEmail();
  if (me == null) return {};
  if (!forceRefresh && hasFreshBlockCache) {
    return Set<String>.from(_blockedEmailsCache);
  }
  try {
    final rows = await Supabase.instance.client
        .from('user_blocks')
        .select('blocked_email, created_at')
        .eq('blocker_email', me)
        .order('created_at', ascending: false);
    final set = <String>{
      for (final e in (rows as List).whereType<Map>())
        if ((e['blocked_email']?.toString() ?? '').trim().isNotEmpty)
          e['blocked_email'].toString().trim().toLowerCase(),
    };
    _blockedEmailsCache = set;
    _blockedCacheAt = DateTime.now();
    return set;
  } catch (_) {
    return Set<String>.from(_blockedEmailsCache);
  }
}

Future<List<BlockedUser>> loadBlockedUsers({bool forceRefresh = false}) async {
  final me = _myEmail();
  if (me == null) return const [];
  try {
    final rows = await Supabase.instance.client
        .from('user_blocks')
        .select('blocked_email, created_at')
        .eq('blocker_email', me)
        .order('created_at', ascending: false);
    final list = <BlockedUser>[];
    for (final e in (rows as List).whereType<Map>()) {
      final email = (e['blocked_email']?.toString() ?? '').trim().toLowerCase();
      if (email.isEmpty) continue;
      list.add(
        BlockedUser(
          email: email,
          createdAt: DateTime.tryParse(e['created_at']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }
    _blockedEmailsCache = {for (final b in list) b.email};
    _blockedCacheAt = DateTime.now();
    return list;
  } catch (_) {
    return const [];
  }
}

Future<void> blockUser(String targetEmail) async {
  final me = _myEmail();
  final target = targetEmail.trim().toLowerCase();
  if (me == null) throw StateError('Engellemek için giriş yapın.');
  if (target.isEmpty) throw StateError('Kullanıcı bulunamadı.');
  if (target == me) throw StateError('Kendinizi engelleyemezsiniz.');

  await Supabase.instance.client.from('user_blocks').upsert(
    {
      'blocker_email': me,
      'blocked_email': target,
    },
    onConflict: 'blocker_email,blocked_email',
  );
  _blockedEmailsCache = {..._blockedEmailsCache, target};
  _blockedCacheAt = DateTime.now();
}

Future<void> unblockUser(String targetEmail) async {
  final me = _myEmail();
  final target = targetEmail.trim().toLowerCase();
  if (me == null || target.isEmpty) return;
  await Supabase.instance.client
      .from('user_blocks')
      .delete()
      .eq('blocker_email', me)
      .eq('blocked_email', target);
  _blockedEmailsCache = {..._blockedEmailsCache}..remove(target);
  _blockedCacheAt = DateTime.now();
}

const kReportReasons = <String>[
  'Hakaret / küfür',
  'Taciz / rahatsız etme',
  'Spam / reklam',
  'Sahte profil / dolandırıcılık',
  'Uygunsuz içerik',
  'Diğer',
];

Future<void> reportUser({
  required String targetEmail,
  required String reason,
  String context = 'genel',
  String detail = '',
  String? targetDisplayName,
  String contentType = '',
  String contentId = '',
}) async {
  final me = _myEmail();
  var target = targetEmail.trim().toLowerCase();
  if (me == null) throw StateError('Şikayet için giriş yapın.');
  // Yalnızca içerik ID’si varsa anonim/şüpheli hedef için yer tutucu
  if (target.isEmpty || !target.contains('@')) {
    if (contentType.trim().isEmpty || contentId.trim().isEmpty) {
      throw StateError('Kullanıcı veya içerik bulunamadı.');
    }
    target = 'content@$contentType.local';
  }
  if (target == me) throw StateError('Kendinizi şikayet edemezsiniz.');
  final r = reason.trim();
  if (r.isEmpty) throw StateError('Şikayet nedeni seçin.');

  final row = <String, dynamic>{
    'reporter_email': me,
    'target_email': target,
    'reason': r,
    'context': context.trim().isEmpty ? 'genel' : context.trim(),
    'detail': detail.trim(),
    'status': 'pending',
  };
  if (contentType.trim().isNotEmpty) {
    row['content_type'] = contentType.trim();
  }
  if (contentId.trim().isNotEmpty) {
    row['content_id'] = contentId.trim();
  }

  try {
    await Supabase.instance.client.from('user_reports').insert(row);
  } catch (e) {
    // Eski şema (content_* yoksa) temel alanlarla dene
    final msg = e.toString().toLowerCase();
    if (msg.contains('content_type') ||
        msg.contains('content_id') ||
        msg.contains('status')) {
      await Supabase.instance.client.from('user_reports').insert({
        'reporter_email': me,
        'target_email': target,
        'reason': r,
        'context': context.trim().isEmpty ? 'genel' : context.trim(),
        'detail': [
          detail.trim(),
          if (contentType.isNotEmpty) 'content_type=$contentType',
          if (contentId.isNotEmpty) 'content_id=$contentId',
        ].where((s) => s.isNotEmpty).join('\n'),
      });
    } else {
      rethrow;
    }
  }

  final label = (targetDisplayName ?? '').trim().isNotEmpty
      ? targetDisplayName!.trim()
      : target;
  try {
    await submitGorusToAdmin(
      type: 'sikayet',
      subject: 'Kullanıcı / içerik şikayeti: $label',
      message:
          'Şikayet edilen: $label ($target)\n'
          'Neden: $r\n'
          'Bağlam: $context\n'
          '${contentType.isEmpty ? '' : 'İçerik tipi: $contentType\n'}'
          '${contentId.isEmpty ? '' : 'İçerik id: $contentId\n'}'
          '${detail.trim().isEmpty ? '' : 'Detay: ${detail.trim()}\n'}'
          'Şikayetçi: $me',
    );
  } catch (_) {}
}
