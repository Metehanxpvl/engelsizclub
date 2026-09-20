import 'package:engelsizclub/widgets/admin_users_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAdminKrediAmount accepts digits only', () {
    expect(parseAdminKrediAmount('10'), 10);
    expect(parseAdminKrediAmount('  5 '), 5);
    expect(parseAdminKrediAmount('0'), 0);
    expect(parseAdminKrediAmount(''), isNull);
    expect(parseAdminKrediAmount('abc'), isNull);
    expect(parseAdminKrediAmount('-3'), isNull);
  });

  test('nextAdminKrediBalance add and set', () {
    expect(
      nextAdminKrediBalance(current: 5, amount: 10, mode: 'add'),
      15,
    );
    expect(
      nextAdminKrediBalance(current: 12, amount: 0, mode: 'set'),
      0,
    );
    expect(
      nextAdminKrediBalance(current: 8, amount: 3, mode: 'set'),
      3,
    );
    expect(
      nextAdminKrediBalance(current: kAdminKrediMax, amount: 1, mode: 'add'),
      kAdminKrediMax,
    );
  });

  test('aile uses iyilik puanı label', () {
    expect(adminKrediUnitLabel('aile'), 'iyilik puanı');
    expect(adminKrediUnitLabel('uzman'), 'puan');
    expect(adminKrediUnitLabel('bakici'), 'puan');
  });
}
