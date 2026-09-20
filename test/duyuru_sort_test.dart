import 'package:engelsizclub/data/duyuru_data.dart';
import 'package:engelsizclub/duyuru_store.dart';
import 'package:flutter_test/flutter_test.dart';

DuyuruItem _item({
  required int id,
  DateTime? createdAt,
  DateTime? publishAt,
  bool isActive = true,
  bool isPopup = false,
}) {
  return DuyuruItem(
    id: id,
    title: 'Duyuru $id',
    body: '',
    imageUrl: 'https://example.com/$id.jpg',
    createdAt: createdAt ?? DateTime(2026, 1, id),
    publishAt: publishAt,
    isActive: isActive,
    isPopup: isPopup,
  );
}

void main() {
  group('sortDuyurularByDate', () {
    test('newest first uses publishAt then createdAt', () {
      final a = _item(
        id: 1,
        createdAt: DateTime(2026, 1, 10),
        publishAt: DateTime(2026, 3, 1),
      );
      final b = _item(
        id: 2,
        createdAt: DateTime(2026, 5, 1),
      );
      final c = _item(
        id: 3,
        createdAt: DateTime(2026, 2, 1),
        publishAt: DateTime(2026, 4, 1),
      );
      final newest = sortDuyurularByDate([a, b, c], newestFirst: true);
      expect(newest.map((e) => e.id), [b.id, c.id, a.id]);
      final oldest = sortDuyurularByDate([a, b, c], newestFirst: false);
      expect(oldest.map((e) => e.id), [a.id, c.id, b.id]);
    });

    test('stable id tie-break when dates match', () {
      final t = DateTime(2026, 6, 1);
      final a = _item(id: 10, createdAt: t, publishAt: t);
      final b = _item(id: 20, createdAt: t, publishAt: t);
      expect(
        sortDuyurularByDate([a, b], newestFirst: true).map((e) => e.id),
        [20, 10],
      );
      expect(
        sortDuyurularByDate([a, b], newestFirst: false).map((e) => e.id),
        [10, 20],
      );
    });
  });

  test('isVisibleNow matches home strip rules', () {
    final now = DateTime(2026, 6, 15);
    final live = _item(
      id: 1,
      publishAt: DateTime(2026, 6, 1),
    );
    final future = _item(
      id: 2,
      publishAt: DateTime(2026, 7, 1),
    );
    final expired = _item(id: 3, createdAt: DateTime(2026, 1, 1)).copyWith(
      expiresAt: DateTime(2026, 6, 1),
    );
    final inactive = _item(id: 4, isActive: false);
    expect(live.isVisibleNow(now), isTrue);
    expect(future.isVisibleNow(now), isFalse);
    expect(expired.isVisibleNow(now), isFalse);
    expect(inactive.isVisibleNow(now), isFalse);
  });

  group('all-screen vs home strip', () {
    test('all-screen lists every currently visible item, including popups', () {
      final now = DateTime(2026, 6, 15);
      final live = _item(id: 1, publishAt: DateTime(2026, 6, 1));
      final popup = _item(
        id: 2,
        publishAt: DateTime(2026, 6, 2),
        isPopup: true,
      );
      final future = _item(id: 3, publishAt: DateTime(2026, 7, 1));
      final expired = _item(id: 4, createdAt: DateTime(2026, 1, 1)).copyWith(
        expiresAt: DateTime(2026, 6, 1),
      );
      final inactive = _item(id: 5, isActive: false);
      final all = duyurularForAllScreen(
        [live, popup, future, expired, inactive],
        now: now,
      );
      expect(all.map((e) => e.id), [popup.id, live.id]);
      expect(all.any((e) => e.isPopup), isTrue);
    });

    test('home strip hides popups and caps length; all-screen does not', () {
      final now = DateTime(2026, 9, 1);
      final items = [
        for (var i = 1; i <= 28; i++)
          _item(
            id: i,
            createdAt: DateTime(2026, 8, i > 31 ? 31 : i),
            publishAt: DateTime(2026, 8, 1).add(Duration(hours: i)),
          ),
        _item(
          id: 99,
          publishAt: DateTime(2026, 8, 20),
          isPopup: true,
        ),
      ];
      final strip = duyurularForHomeStrip(items, now: now);
      final catalog = duyurularForAllScreen(items, now: now);
      expect(strip.length, kDuyuruHomeStripMax);
      expect(strip.every((d) => !d.isPopup), isTrue);
      expect(catalog.length, 29);
      expect(catalog.any((d) => d.isPopup), isTrue);
      expect(catalog.length, greaterThan(strip.length));
      expect(kDuyuruFetchLimit, greaterThanOrEqualTo(500));
      expect(kDuyuruHomeStripMax, lessThan(kDuyuruFetchLimit));
    });

    test('popup-only list still appears on all-screen, not on home strip', () {
      final popup = _item(
        id: 7,
        publishAt: DateTime(2026, 6, 1),
        isPopup: true,
      );
      final now = DateTime(2026, 6, 15);
      expect(duyurularForHomeStrip([popup], now: now), isEmpty);
      expect(
        duyurularForAllScreen([popup], now: now).map((e) => e.id),
        [7],
      );
    });
  });
}
