import 'package:engelsizclub/features/daily_news/daily_news_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending news candidate parses admin card fields', () {
    final item = DailyNewsCandidate.fromJson({
      'id': 'n1',
      'source_name': 'Hürriyet',
      'source_url': 'https://www.hurriyet.com.tr',
      'article_url': 'https://www.hurriyet.com.tr/haber',
      'title': 'Engelli aylığında düzenleme',
      'summary': 'Kısa özet.',
      'published_at': '2026-10-08T08:00:00Z',
      'category': 'Engelli Aylığı',
      'categories': ['Engelli Aylığı', 'Ekonomik Destek'],
      'relevance_score': 94,
      'importance_level': 'very_high',
      'ai_reason': 'Yeni kamu düzenlemesi.',
      'status': 'pending',
    });
    expect(item.title, contains('aylığında'));
    expect(item.importanceLabelTr, 'Çok önemli');
    expect(item.relevanceScore, 94);
    expect(item.status, 'pending');
    expect(item.publishedAt, isNotNull);
  });

  test('edit keeps the article and replaces title, summary, and image', () {
    final item = DailyNewsCandidate.fromJson({
      'id': 'n2',
      'article_url': 'https://example.com/haber',
      'title': 'Eski başlık',
      'summary': 'Eski özet',
      'image_url': '',
      'status': 'pending',
    });
    final edited = item.copyWith(
      title: 'Yeni başlık',
      summary: 'Görselli özet',
      imageUrl: 'https://cdn.example/haber.jpg',
    );
    expect(edited.id, item.id);
    expect(edited.articleUrl, item.articleUrl);
    expect(edited.title, 'Yeni başlık');
    expect(edited.summary, 'Görselli özet');
    expect(edited.imageUrl, 'https://cdn.example/haber.jpg');
  });
}
