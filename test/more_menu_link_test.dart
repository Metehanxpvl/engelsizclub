import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:engelsizclub/pages/in_app_web_page.dart';

MoreMenuItem menuItem(String linkType, String link) {
  return MoreMenuItem.fromJson(<String, dynamic>{
    'id': 99,
    'title': 'Destek Sorgu',
    'subtitle': '',
    'link_type': linkType,
    'link': link,
    'icon': 'calculate',
    'sort_order': 22,
    'is_active': true,
    'is_builtin': false,
  });
}

void main() {
  test('nokta veya bölü içeren satır web bağlantısıdır', () {
    expect(looksLikeWebLink('/destek-sorgu'), isTrue);
    expect(looksLikeWebLink('destek-sorgu.html'), isTrue);
    expect(looksLikeWebLink('daha-fazlasi/ozel'), isTrue);
    expect(looksLikeWebLink('https://www.engelsizclub.com/evde-egitim'), isTrue);
    expect(looksLikeWebLink('firsatlar'), isFalse);
    expect(looksLikeWebLink('route:cvi2'), isFalse);
    expect(looksLikeWebLink('   '), isFalse);
  });

  test('link_type route yazılsa da html satırı link sayılır', () {
    expect(menuItem('route', 'destek-sorgu.html').isUrl, isTrue);
    expect(menuItem('route', '/destek-sorgu').isUrl, isTrue);
    expect(menuItem('url', 'https://www.engelsizclub.com/evde-egitim').isUrl,
        isTrue);
  });

  test('bilinen route ve gruplar link sayılmaz', () {
    expect(menuItem('route', '/cvi2').isUrl, isFalse);
    expect(menuItem('url', 'boyama.html').isUrl, isFalse);
    expect(menuItem('folder', 'folder').isUrl, isFalse);
    expect(menuItem('route', 'taramalar').isUrl, isFalse);
  });

  test('site içi yollar origin ile tamamlanır', () {
    expect(
      InAppWebPage.resolveUri('/destek-sorgu').toString(),
      'https://www.engelsizclub.com/destek-sorgu',
    );
    expect(
      InAppWebPage.resolveUri('destek-sorgu.html').toString(),
      'https://www.engelsizclub.com/destek-sorgu.html',
    );
    expect(
      InAppWebPage.resolveUri('daha-fazlasi/ozel/index.html').toString(),
      'https://www.engelsizclub.com/daha-fazlasi/ozel/index.html',
    );
  });

  test('şemasız dış adres https ile açılır', () {
    expect(
      InAppWebPage.resolveUri('www.meb.gov.tr/evde-egitim').toString(),
      'https://www.meb.gov.tr/evde-egitim',
    );
    expect(
      InAppWebPage.resolveUri('orgm.meb.gov.tr/kilavuz.pdf').toString(),
      'https://orgm.meb.gov.tr/kilavuz.pdf',
    );
    expect(
      InAppWebPage.resolveUri('//engelsizclub.com/destek-sorgu').toString(),
      'https://engelsizclub.com/destek-sorgu',
    );
  });

  test('http(s) dışı şema ve boş satır açılmaz', () {
    expect(InAppWebPage.resolveUri('mailto:destek@engelsizclub.com'), isNull);
    expect(InAppWebPage.resolveUri('tel:05555555555'), isNull);
    expect(InAppWebPage.resolveUri('   '), isNull);
    expect(
      InAppWebPage.resolveUri('https://www.engelsizclub.com/x').toString(),
      'https://www.engelsizclub.com/x',
    );
  });
}
