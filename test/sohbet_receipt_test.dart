import 'package:engelsizclub/sohbet_store.dart';
import 'package:flutter_test/flutter_test.dart';

SohbetMesaj _msg({
  int id = 1,
  DateTime? deliveredAt,
  DateTime? readAt,
}) {
  return SohbetMesaj(
    id: id,
    sohbetKey: 'a|b',
    senderEmail: 'a@x.com',
    receiverEmail: 'b@x.com',
    body: 'selam',
    createdAt: DateTime.utc(2026, 10, 10),
    deliveredAt: deliveredAt,
    readAt: readAt,
  );
}

void main() {
  test('peer email is taken from sohbet key, not display labels', () {
    expect(
      peerEmailFromSohbetKey('a@x.com|b@x.com', 'a@x.com'),
      'b@x.com',
    );
    expect(
      peerEmailFromSohbetKey('b@x.com|a@x.com', 'a@x.com'),
      'b@x.com',
    );
    expect(peerEmailFromSohbetKey('üye ↔ ahmet', 'a@x.com'), '');
    expect(peerEmailFromSohbetKey('a@x.com|b@x.com', ''), 'a@x.com');
  });

  test('local bubble is sending until server id exists', () {
    expect(sohbetReceiptOf(_msg(id: 0)), SohbetReceipt.sending);
  });

  test('server id without delivered/read is sent', () {
    expect(sohbetReceiptOf(_msg()), SohbetReceipt.sent);
  });

  test('delivered_at is iletildi until read', () {
    expect(
      sohbetReceiptOf(_msg(deliveredAt: DateTime.utc(2026, 10, 10, 1))),
      SohbetReceipt.delivered,
    );
  });

  test('read_at is okundu even if delivered_at is missing', () {
    expect(
      sohbetReceiptOf(_msg(readAt: DateTime.utc(2026, 10, 10, 2))),
      SohbetReceipt.read,
    );
    expect(_msg(readAt: DateTime.utc(2026, 10, 10, 2)).isDelivered, isTrue);
  });

  test('fromJson maps delivered_at and read_at', () {
    final m = SohbetMesaj.fromJson({
      'id': 9,
      'sohbet_key': 'a|b',
      'sender_email': 'A@X.com',
      'receiver_email': 'b@x.com',
      'body': 'ok',
      'created_at': '2026-10-10T10:00:00Z',
      'delivered_at': '2026-10-10T10:00:02Z',
      'read_at': '2026-10-10T10:01:00Z',
    });
    expect(m.receipt, SohbetReceipt.read);
    expect(m.deliveredAt, isNotNull);
    expect(m.readAt, isNotNull);
  });
}
