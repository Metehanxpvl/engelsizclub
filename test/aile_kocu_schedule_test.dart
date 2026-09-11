import 'package:engelsizclub/aile_kocu/aile_kocu_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAileKocuScheduledPayload', () {
    test('accepts lesson, med, note, test', () {
      expect(isAileKocuScheduledPayload('lesson|abc|Matematik|18:00'), isTrue);
      expect(isAileKocuScheduledPayload('med|id|İlaç|08:00|5ml'), isTrue);
      expect(isAileKocuScheduledPayload('pnote|n1'), isTrue);
      expect(isAileKocuScheduledPayload('test'), isTrue);
    });

    test('ignores FCM / empty payloads', () {
      expect(isAileKocuScheduledPayload(null), isFalse);
      expect(isAileKocuScheduledPayload(''), isFalse);
      expect(isAileKocuScheduledPayload('{"type":"forum"}'), isFalse);
      expect(isAileKocuScheduledPayload('forum|12'), isFalse);
    });

    test('matches item id without cancelling siblings', () {
      expect(
        isAileKocuPayloadFor(
          payload: 'med|aaa|İlaç|08:00|5ml',
          kind: 'med',
          itemId: 'aaa',
        ),
        isTrue,
      );
      expect(
        isAileKocuPayloadFor(
          payload: 'med|aaa|İlaç|08:00|5ml',
          kind: 'med',
          itemId: 'aa',
        ),
        isFalse,
      );
    });
  });

  group('uniqueHhmmTimes', () {
    test('keeps first of duplicate clock times', () {
      expect(
        uniqueHhmmTimes(['08:00', '12:00', '08:00', ' 12:00 ']),
        ['08:00', '12:00'],
      );
    });
  });
}
