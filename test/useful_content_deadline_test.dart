import 'package:engelsizclub/features/useful_opportunities/useful_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

UsefulContentItem _item({
  required String id,
  DateTime? deadline,
  DateTime? created,
}) {
  return UsefulContentItem(
    id: id,
    title: id,
    summary: 'özet',
    body: '',
    category: 'firsat',
    city: 'Ulusal',
    sourceName: 'SGK',
    sourceUrl: 'https://www.sgk.gov.tr/$id',
    externalId: id,
    contentHash: id,
    status: 'published',
    deadlineAt: deadline,
    createdAt: created,
  );
}

void main() {
  final now = DateTime(2026, 10, 24);

  test('expired deadline is hidden; remaining sorted ascending; <=7 days urgent', () {
    final expired = _item(id: 'old', deadline: DateTime(2026, 10, 20));
    final urgent = _item(id: 'soon', deadline: DateTime(2026, 10, 28));
    final later = _item(id: 'later', deadline: DateTime(2026, 12, 1));
    final none = _item(id: 'none', created: DateTime(2026, 10, 23));

    expect(expired.daysLeft(now), -4);
    expect(urgent.daysLeft(now), 4);
    expect(later.daysLeft(now), greaterThan(7));

    final sorted = sortUsefulOpportunities(
      [none, later, expired, urgent],
      now,
    );
    expect(sorted.map((e) => e.id).toList(), ['soon', 'later', 'none']);
  });
}
