import 'package:engelsizclub/gezi_kampanya_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeKampanyaCode folds and strips junk', () {
    expect(normalizeKampanyaCode('  engel siz-50  '), 'ENGELSIZ-50');
    expect(normalizeKampanyaCode('kod!@#'), 'KOD');
    expect(isValidKampanyaCode('AB'), isFalse);
    expect(isValidKampanyaCode('ENGELSIZ50'), isTrue);
  });

  test('KampanyaItem reads admin code flags from json', () {
    final item = KampanyaItem.fromJson({
      'id': 3,
      'image_url': 'https://example.com/a.jpg',
      'member_code_enabled': true,
      'campaign_code': 'ENGELSIZ50',
      'created_at': '2026-09-20T10:00:00Z',
    });
    expect(item.hasMemberCampaignCode, isTrue);
    expect(item.campaignCode, 'ENGELSIZ50');
    expect(item.myMemberCode, isEmpty);
  });

  test('kampanya categories fold to keys', () {
    expect(normalizeKampanyaCategory('Sağlık'), 'saglik');
    expect(normalizeKampanyaCategory('marka iş birlikleri'), 'marka');
    expect(kampanyaCategoryLabel('egitim'), 'Eğitim');
    expect(kKampanyaCategories.keys.toList(), [
      'saglik',
      'restoran',
      'giyim',
      'egitim',
      'marka',
    ]);
    expect(normalizeKampanyaCategory('Teknoloji'), 'teknoloji');
    expect(normalizeKampanyaCategory('Ev Aletleri'), 'ev-aletleri');
    expect(kampanyaCategoryLabel('teknoloji'), 'Teknoloji');
  });

  test('firma linki https ekler ve markerı açıklamadan ayırır', () {
    expect(normalizeKampanyaCompanyUrl('ornek.com/kampanya'),
        'https://ornek.com/kampanya');
    expect(normalizeKampanyaCompanyUrl(''), '');
    expect(
      () => normalizeKampanyaCompanyUrl('not a url', strict: true),
      throwsStateError,
    );
    expect(
      () => normalizeKampanyaCompanyUrl('ftp://ornek.com', strict: true),
      throwsStateError,
    );
    final split = splitKampanyaCompanyUrl(
      description: 'Yüzde 20 indirim\n$kKampanyaFirmaMarker https://a.com',
    );
    expect(split.description, 'Yüzde 20 indirim');
    expect(split.companyUrl, 'https://a.com');
    final item = KampanyaItem.fromJson({
      'id': 9,
      'image_url': 'https://example.com/a.jpg',
      'description': 'Metin',
      'company_url': 'firma.com',
      'created_at': '2026-09-20T10:00:00Z',
    });
    expect(item.description, 'Metin');
    expect(item.companyUrl, 'https://firma.com');
    expect(item.hasCompanyUrl, isTrue);
  });
}
