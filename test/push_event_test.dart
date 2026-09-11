import 'package:engelsizclub/push_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mesaj ve yorum event eşlemesi', () {
    expect(pushEventForType('mesaj'), 'MESSAGE_RECEIVED');
    expect(pushEventForType('forum_comment'), 'POST_COMMENTED');
    expect(pushEventForType('forum_follow'), 'COMMENT_CREATED');
    expect(pushEventForType('forum_reply'), 'REPLY_RECEIVED');
    expect(pushPrefKeyForType('mesaj'), 'mesajlar');
    expect(pushPrefKeyForType('forum_comment'), 'forum');
  });

  test('insert ve update dedupe anahtarları sunucu ile aynı biçimde', () {
    expect(
      pushInsertDedupeKey(
        type: 'mesaj',
        ownerEmail: 'A@X.com',
        actorEmail: 'B@X.com',
        sohbetKey: 'ab',
      ),
      'ins:mesaj:a@x.com:b@x.com:ab',
    );
    expect(
      pushUpdateDedupeKey(
        type: 'forum_comment',
        ownerEmail: 'a@x.com',
        actorEmail: 'b@x.com',
        sohbetKey: 'c:9',
        epochSec: 1710000000,
      ),
      'upd:forum_comment:a@x.com:b@x.com:c:9:1710000000',
    );
  });

  test('mesaj kilit ekranı gövde sızdırmaz', () {
    final copy = pushOsCopy(
      type: 'mesaj',
      title: 'gizli',
      body: 'özel metin',
    );
    expect(copy.title, 'Yeni mesaj');
    expect(copy.body.contains('özel'), isFalse);
  });

  test('yorum sohbet_key → commentId', () {
    expect(pushCommentIdFromKey('c:42'), '42');
    expect(pushCommentIdFromKey('ab'), isNull);
    final data = pushClientData(
      type: 'forum_like',
      event: 'COMMENT_LIKED',
      ilanId: 9,
      sohbetKey: 'c:42',
      actorEmail: 'A@X.com',
    );
    expect(data['commentId'], '42');
    expect(data['postId'], '9');
    expect(data['actor_email'], 'a@x.com');
  });
}
