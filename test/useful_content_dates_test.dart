import 'package:engelsizclub/features/useful_opportunities/useful_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub Action rows show local date and time', () {
    final item = UsefulContentItem.fromJson({
      'id': 'u1',
      'title': 'Engelli bursu',
      'summary': 'Başvuru açık',
      'body': '',
      'category': 'burs',
      'city': 'Ankara',
      'source_name': 'Aile Bakanlığı',
      'source_url': 'https://example.com',
      'external_id': 'ext-1',
      'content_hash': 'abc',
      'status': 'pending_review',
      'created_at': '2026-11-07T07:30:00Z',
      'published_at': '2026-11-06T12:05:00Z',
      'deadline_at': '2026-12-01T14:00:00Z',
    });
    expect(item.collectedAtLabel, contains('07.11.2026'));
    expect(item.collectedAtLabel, contains(':'));
    expect(item.publishedAtLabel, contains('06.11.2026'));
    expect(item.publishedAtLabel, contains(':'));
    expect(item.deadlineAtLabel, contains('01.12.2026'));
    expect(usefulContentDateTimeLabel(DateTime.utc(2026, 11, 7, 7, 30)),
        matches(RegExp(r'\d{2}\.\d{2}\.2026 \d{2}:\d{2}')));
  });
}
