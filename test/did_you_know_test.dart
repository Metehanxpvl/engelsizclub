import 'package:engelsizclub/services/broadcast_push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('did you know body is the admin message under the title', () {
    expect(kDidYouKnowTitle, 'Bunu biliyor muydunuz?');
    expect(didYouKnowPushBody('  Engelli kotası %4.  '), 'Engelli kotası %4.');
    expect(didYouKnowPushBody('   '), '');
  });
}
