import 'package:engelsizclub/admin_config.dart';
import 'package:engelsizclub/kredi_store.dart';
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

  test('aile starts at 1 iyilik, uzman/bakici at 5', () {
    expect(startingKrediFor('aile@example.com', userType: 'aile'), 1);
    expect(startingKrediFor('uzman@example.com', userType: 'uzman'), 5);
    expect(startingKrediFor('bakici@example.com', userType: 'bakici'), 5);
    expect(
      startingKrediFor(kAppAdminEmails.first, userType: 'aile'),
      kAdminKredi,
    );
  });

  test('switching to uzman/bakici tops aile gift 1 up to 5 once', () {
    expect(
      profStartTopUpAmount(
        current: 1,
        userType: 'uzman',
        alreadyGranted: false,
        email: 'a@x.com',
      ),
      5,
    );
    expect(
      profStartTopUpAmount(
        current: 1,
        userType: 'bakici',
        alreadyGranted: false,
        email: 'a@x.com',
      ),
      5,
    );
    expect(
      profStartTopUpAmount(
        current: 1,
        userType: 'uzman',
        alreadyGranted: true,
        email: 'a@x.com',
      ),
      isNull,
    );
    expect(
      profStartTopUpAmount(
        current: 1,
        userType: 'aile',
        alreadyGranted: false,
        email: 'a@x.com',
      ),
      isNull,
    );
    expect(
      profStartTopUpAmount(
        current: 5,
        userType: 'uzman',
        alreadyGranted: false,
        email: 'a@x.com',
      ),
      isNull,
    );
  });
}
