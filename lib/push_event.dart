/// Bildirim tipi → FCM event / tercih anahtarı ve çift gönderim anahtarı.
///
/// Sunucu (`notify-push`) ile istemci (`broadcast-push`) aynı anahtarı kullanır;
/// ikisi birden çalışırsa `push_dedupe` / `push_dispatch` ikincisini atlar.
String? pushEventForType(String type) {
  switch (type.trim()) {
    case 'mesaj':
      return 'MESSAGE_RECEIVED';
    case 'forum_comment':
      return 'POST_COMMENTED';
    case 'forum_reply':
      return 'REPLY_RECEIVED';
    case 'forum_follow':
    case 'forum':
      return 'COMMENT_CREATED';
    case 'forum_like':
      return 'COMMENT_LIKED';
    case 'teklif':
      return 'OFFER_RECEIVED';
    default:
      return null;
  }
}

String pushPrefKeyForType(String type) {
  final t = type.trim();
  if (t == 'mesaj' || t == 'teklif') return 'mesajlar';
  if (t == 'ilan' || t == 'ilan_yorum') return 'ilanlar';
  return 'forum';
}

String pushRef({String? sohbetKey, int? ilanId}) {
  final sk = (sohbetKey ?? '').trim();
  if (sk.isNotEmpty) return sk;
  return 'i:${ilanId ?? 0}';
}

/// INSERT yolu — tetikleyici + istemci aynı dizeyi yazar.
String pushInsertDedupeKey({
  required String type,
  required String ownerEmail,
  required String actorEmail,
  String? sohbetKey,
  int? ilanId,
}) {
  final owner = ownerEmail.trim().toLowerCase();
  final actor = actorEmail.trim().toLowerCase();
  return 'ins:${type.trim()}:$owner:$actor:${pushRef(sohbetKey: sohbetKey, ilanId: ilanId)}';
}

/// Aynı satır güncellenince (üst üste mesaj) yeni FCM için.
String pushUpdateDedupeKey({
  required String type,
  required String ownerEmail,
  required String actorEmail,
  String? sohbetKey,
  int? ilanId,
  required int epochSec,
}) {
  return 'upd:${type.trim()}:${ownerEmail.trim().toLowerCase()}:${actorEmail.trim().toLowerCase()}:${pushRef(sohbetKey: sohbetKey, ilanId: ilanId)}:$epochSec';
}

/// `sohbet_key` `c:123` → yorum id (notify-push ile aynı).
String? pushCommentIdFromKey(String? sohbetKey) {
  final k = (sohbetKey ?? '').trim();
  if (!k.startsWith('c:')) return null;
  final id = k.substring(2).trim();
  return id.isEmpty ? null : id;
}

/// FCM data (kapalı Android tıklanınca deep link). Title/body FCM
/// `notification` alanından gelir; burası yalnızca data.
Map<String, String> pushClientData({
  required String type,
  required String event,
  int? ilanId,
  String? sohbetKey,
  String? actorEmail,
}) {
  final commentId = pushCommentIdFromKey(sohbetKey);
  final actor = (actorEmail ?? '').trim().toLowerCase();
  final sk = (sohbetKey ?? '').trim();
  return {
    'type': type,
    'event': event,
    if (ilanId != null) 'id': '$ilanId',
    if (ilanId != null) 'postId': '$ilanId',
    if (commentId != null) 'commentId': commentId,
    if (sk.isNotEmpty) 'sohbet_key': sk,
    if (actor.isNotEmpty) 'actor_email': actor,
  };
}

/// Kilit ekranı: mesaj gövdesi sızmasın (notify-push ile aynı kopya).
({String title, String body}) pushOsCopy({
  required String type,
  required String title,
  required String body,
}) {
  if (type.trim() == 'mesaj') {
    return (
      title: 'Yeni mesaj',
      body: "Engelsiz Club'da yeni bir mesajınız var.",
    );
  }
  final t = title.trim();
  final b = body.trim();
  return (title: t.isEmpty ? 'Engelsiz Club' : t, body: b.isEmpty ? t : b);
}
