import 'package:engelsizclub/widgets/admin_iyilik_liderleri_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('top 10 iyilik points are ranked highest first', () {
    final rows = [
      for (var i = 0; i < 12; i++)
        {
          'owner_email': 'kisi$i@example.com',
          'display_name': 'Kişi $i',
          'kredi': i * 10,
        },
      {
        'owner_email': 'sakir.caykara@gmail.com',
        'display_name': 'Admin',
        'kredi': 99999,
      },
      {
        'owner_email': 'bos@example.com',
        'display_name': 'Sıfır',
        'kredi': 0,
      },
    ];

    final top = rankIyilikLeaders(rows, limit: 10);
    expect(top, hasLength(10));
    expect(top.first.displayName, 'Kişi 11');
    expect(top.first.kredi, 110);
    expect(top.first.rank, 1);
    expect(top.last.rank, 10);
    expect(top.any((e) => e.ownerEmail.contains('sakir')), isFalse);
    expect(top.any((e) => e.kredi == 0), isFalse);
    expect(top[0].kredi, greaterThan(top[1].kredi));
  });
}
