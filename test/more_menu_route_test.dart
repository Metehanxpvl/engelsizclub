import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Destek Sorgulama opens hosted .html, not a Flutter route', () {
    expect(normalizeMoreMenuRoute('/destek-sorgu'), isNull);
    expect(normalizeMoreMenuRoute('destek-sorgu'), isNull);
    expect(hostedHtmlWizardUrl('/destek-sorgu'), kDestekSorguHtmlUrl);
    expect(hostedHtmlWizardUrl('destek_sorgu'), kDestekSorguHtmlUrl);
    expect(
      hostedHtmlWizardUrl('https://www.engelsizclub.com/destek-sorgu'),
      kDestekSorguHtmlUrl,
    );
    expect(
      hostedHtmlWizardUrl('https://www.engelsizclub.com/destek-sorgu.html'),
      kDestekSorguHtmlUrl,
    );
    expect(
      hostedHtmlWizardUrl('https://engelsizclub.com/destek-sorgu.html'),
      kDestekSorguHtmlUrl,
    );

    final fromUrlCol = MoreMenuItem.fromJson({
      'id': 15,
      'title': 'Destek Sorgulama',
      'link_type': 'url',
      'url': 'https://www.engelsizclub.com/destek-sorgu.html',
      'icon': 'calculate',
      'sort_order': 22,
      'is_active': true,
    });
    expect(fromUrlCol.isUrl, isTrue);
    expect(fromUrlCol.link, kDestekSorguHtmlUrl);

    final item = MoreMenuItem.fromJson({
      'id': 40,
      'title': 'Destek Sorgulama',
      'subtitle': '',
      'link_type': 'url',
      'link': '/destek-sorgu',
      'icon': 'calculate',
      'sort_order': 22,
      'is_active': true,
    });
    expect(item.isUrl, isTrue);
    expect(item.routeKey, isNull);
    expect(item.link, kDestekSorguHtmlUrl);

    final asRoute = MoreMenuItem.fromJson({
      'id': 40,
      'title': 'Destek Sorgulama',
      'link_type': 'route',
      'link': 'destek_sorgu',
      'icon': 'calculate',
      'sort_order': 22,
      'is_active': true,
    });
    expect(asRoute.isUrl, isTrue);
    expect(asRoute.link, kDestekSorguHtmlUrl);
  });

  test('Evde eğitim sorgu opens hosted .html, not a Flutter route', () {
    expect(normalizeMoreMenuRoute('/evde-egitim'), isNull);
    expect(hostedHtmlWizardUrl('/evde-egitim'), kEvdeEgitimHtmlUrl);
    expect(
      hostedHtmlWizardUrl('https://www.engelsizclub.com/evde-egitim.html'),
      kEvdeEgitimHtmlUrl,
    );

    final item = MoreMenuItem.fromJson({
      'id': 41,
      'title': 'Evde eğitim sorgu',
      'subtitle': '',
      'link_type': 'url',
      'link': '/evde-egitim',
      'icon': 'family',
      'sort_order': 23,
      'is_active': true,
    });
    expect(item.isUrl, isTrue);
    expect(item.link, kEvdeEgitimHtmlUrl);
  });

  test('boyama still maps; unknown HTML stays URL; Harita untouched', () {
    expect(normalizeMoreMenuRoute('/boyama'), 'boyama');
    expect(hostedHtmlWizardUrl('/boyama'), isNull);
    expect(hostedHtmlWizardUrl('harita'), isNull);
    expect(normalizeMoreMenuRoute('https://example.com/other.html'), isNull);
    expect(normalizeMoreMenuRoute('harita'), 'harita');
  });

  test('fallback Daha Fazlası includes Destek Sorgulama and Evde eğitim URLs', () {
    final items = defaultMoreMenuItems();
    expect(
      items.any((e) => e.isUrl && e.link == kDestekSorguHtmlUrl),
      isTrue,
    );
    expect(
      items.any((e) => e.isUrl && e.link == kEvdeEgitimHtmlUrl),
      isTrue,
    );
    expect(MoreMenuItem.builtinRoutes.contains('destek_sorgu'), isFalse);
    expect(MoreMenuItem.builtinRoutes.contains('evde_egitim'), isFalse);
    expect(MoreMenuItem.builtinRoutes.contains('valilikler'), isFalse);
    expect(items.any((e) => e.link == 'valilikler'), isFalse);
  });

  test('Harita is labeled Engelsiz Haritalar and DB extras are not injected', () {
    expect(defaultHaritaMenuItem.title, 'Engelsiz Haritalar');
    expect(moreMenuDisplayTitle(defaultHaritaMenuItem), 'Engelsiz Haritalar');
    final fromDb = [
      MoreMenuItem(
        id: 1,
        title: 'Haklar',
        subtitle: '',
        linkType: 'route',
        link: 'haklar',
        icon: 'balance',
        sortOrder: 20,
        isActive: true,
        isBuiltin: true,
      ),
    ];
    final prepared = prepareUserMoreMenu(fromDb);
    expect(prepared.any((e) => e.link == 'gelisim'), isFalse);
    expect(prepared.any((e) => e.link == 'barkod'), isFalse);
    expect(prepared.any(isHaritaMenuItem), isTrue);
    expect(
      moreMenuDisplayTitle(prepared.firstWhere(isHaritaMenuItem)),
      'Engelsiz Haritalar',
    );
  });

  test('Daha Fazlası kullanıcı sırası ekran görüntüsüyle aynı', () {
    const extra = MoreMenuItem(
      id: 99,
      title: 'Fırsatlar ve Destekler',
      subtitle: 'Kamu ve STK destekleri',
      linkType: 'url',
      link: 'https://www.engelsizclub.com/firsatlar',
      icon: 'newspaper',
      sortOrder: 1,
      isActive: true,
      isBuiltin: false,
    );
    final shuffled = [
      defaultAileKocuMenuItem,
      extra,
      const MoreMenuItem(
        id: 2,
        title: 'Haklar',
        subtitle: '',
        linkType: 'route',
        link: 'haklar',
        icon: 'balance',
        sortOrder: 2,
        isActive: true,
        isBuiltin: true,
      ),
      defaultDestekSorguMenuItem,
      defaultEvdeEgitimMenuItem,
      const MoreMenuItem(
        id: 6,
        title: 'Kartlar',
        subtitle: '',
        linkType: 'route',
        link: 'kartlar',
        icon: 'grid',
        sortOrder: 6,
        isActive: true,
        isBuiltin: true,
      ),
      defaultTaramalarGroupItem,
    ];
    final prepared = prepareUserMoreMenu(shuffled);
    expect(
      prepared.map(moreMenuDisplayTitle).toList(),
      [
        'Engelsiz Haritalar',
        'Taramalar & Egzersizler & Oyun',
        'Hak Sorgulama',
        'Destek Sorgulama',
        'Evde eğitim sorgu',
        'İletişim Kartları',
        'Aile Koçum',
        'MetoBot',
      ],
    );
    expect(prepared.any((e) => e.title.contains('Fırsatlar')), isFalse);
    expect(MoreMenuItem.builtinRoutes.contains('metobot'), isTrue);
  });
}
