import 'package:engelsizclub/gezi_kampanya_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gezi notify copy names the selected city', () {
    expect(
      geziPushBody('Ankara'),
      'Gezi Rehberi’nde bugün Ankara ilinde gezebileceğiniz yerler için lütfen göz atın.',
    );
    expect(
      geziPushBody('İstanbul'),
      'Gezi Rehberi’nde bugün İstanbul ilinde gezebileceğiniz yerler için lütfen göz atın.',
    );
    expect(
      geziPushBody('  '),
      'Gezi Rehberi’nde bugün gezebileceğiniz yerler için lütfen göz atın.',
    );
  });

  test('kampanya notify copy names the selected city or nationwide', () {
    expect(
      kampanyaSehirPushBody('Ankara'),
      'Kampanyalar’da bugün Ankara ilinde yararlanabileceğiniz kampanyalar için lütfen göz atın.',
    );
    expect(
      kampanyaSehirPushBody('İstanbul'),
      'Kampanyalar’da bugün İstanbul ilinde yararlanabileceğiniz kampanyalar için lütfen göz atın.',
    );
    expect(
      kampanyaSehirPushBody(kKampanyaNotifyNationwide),
      'Kampanyalar’da bugün tüm ülkede geçerli kampanyalar için lütfen göz atın.',
    );
    expect(
      kampanyaSehirPushBody('Tüm ülke'),
      'Kampanyalar’da bugün tüm ülkede geçerli kampanyalar için lütfen göz atın.',
    );
    expect(
      kampanyaSehirPushBody('  '),
      'Kampanyalar’da bugün tüm ülkede geçerli kampanyalar için lütfen göz atın.',
    );
  });
}
