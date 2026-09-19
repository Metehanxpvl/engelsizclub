import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:engelsizclub/features/global_news/global_news_model.dart';
import 'package:engelsizclub/features/useful_opportunities/useful_content_model.dart';
import 'package:engelsizclub/features/useful_opportunities/useful_content_repository.dart';

void main() {
  test('parse catalog and apply override', () {
    const raw = '''
{
  "items": [
    {
      "id": "abc",
      "title": "WCAG taslağı",
      "summary": "Özet",
      "category": "erisilebilirlik",
      "source_name": "W3C WAI",
      "source_url": "https://www.w3.org/WAI/news/1",
      "status": "pending_review"
    }
  ]
}
''';
    final items = parseGlobalNewsJson(raw);
    expect(items, hasLength(1));
    expect(items.first.categoryLabel, 'Erişilebilirlik');
    expect(isPendingGlobalNews(items.first.status), isTrue);

    final published = items.first.applyOverride(
      const GlobalNewsOverride(
        newsId: 'abc',
        status: 'published',
        title: 'Onaylı başlık',
      ),
    );
    expect(isPublishedGlobalNews(published.status), isTrue);
    expect(published.title, 'Onaylı başlık');
  });

  test('reject aliases hide from users', () {
    expect(normalizeGlobalNewsStatus('gizle'), 'rejected');
    expect(isPublishedGlobalNews('gizle'), isFalse);
  });

  test('news maps onto Fırsatlar Haber chip without a new screen', () {
    expect(kUsefulContentCategories['haber'], 'Haber');
    expect(usefulCategoryFromGlobalNews('erisilebilirlik'), 'haber');
    expect(usefulCategoryFromGlobalNews('haklar'), 'hak');
    expect(MoreMenuItem.builtinRoutes.contains('global_news'), isFalse);
    expect(
      defaultMoreMenuItems().any((e) => e.link == 'global_news'),
      isFalse,
    );

    const news = GlobalNewsItem(
      id: 'abc',
      title: 'WCAG taslağı',
      summary: 'Özet',
      category: 'erisilebilirlik',
      sourceName: 'W3C WAI',
      sourceUrl: 'https://www.w3.org/WAI/news/1',
      status: 'published',
    );
    final item = usefulContentFromGlobalNews(news);
    expect(item.id, 'gn:abc');
    expect(item.category, 'haber');
    expect(item.categoryLabel, 'Haber');
    expect(isGlobalNewsUsefulItem(item), isTrue);
    expect(usefulContentNeedsStoryImage(item), isFalse);
    expect(globalNewsRawId(item.id), 'abc');
  });
}
