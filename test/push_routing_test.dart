import 'package:engelsizclub/services/broadcast_push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uzman and bakici listings go to prof topic', () {
    expect(isProfSeekIlanKind('uzman'), isTrue);
    expect(isProfSeekIlanKind('bakici'), isTrue);
    expect(isProfSeekIlanKind('ikinciel'), isFalse);
    expect(ilanPushTopicForKind('uzman'), kIlanlarProfTopic);
    expect(ilanPushTopicForKind('Bakici'), kIlanlarProfTopic);
    expect(ilanPushTopicForKind('ikinciel'), kIlanlarTopic);
    expect(ilanPushTopicForKind('otomobil'), kIlanlarTopic);
  });
}
