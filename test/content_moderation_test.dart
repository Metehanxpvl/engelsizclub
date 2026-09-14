import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/content_moderation.dart';
import 'package:engelsizclub/data/ilanlar_data.dart';

void main() {
  test('bez ve klozet tek kelime olarak engellenir', () {
    expect(containsBlockedContent('bez'), isTrue);
    expect(containsBlockedContent('Klozet alalım'), isTrue);
    expect(containsBlockedContent('BEZ!'), isTrue);
  });

  test('bakım / gıda yanlış pozitif olmaz', () {
    expect(containsBlockedContent('bezelye yedik'), isFalse);
    expect(containsBlockedContent('obezite riski'), isFalse);
    expect(containsBlockedContent('eksik evrak'), isFalse);
    expect(containsBlockedContent('psikoloji seansı'), isFalse);
    expect(containsBlockedContent('klasik müzik'), isFalse);
  });

  test('psikolog ilanı küfür filtresine takılmaz', () {
    expect(containsBlockedContent('Psikolog'), isFalse);
    expect(containsBlockedContent('psikolog arıyoruz'), isFalse);
    expect(containsBlockedContent('Çocuk Psikologu'), isFalse);
    expect(containsBlockedContent('Çocuk psikoloğu aranıyor'), isFalse);
    expect(containsBlockedContent('Evde psikolog seansı'), isFalse);
    expect(containsBlockedContent('Çocuk Psikiyatristi'), isFalse);
    expect(containsBlockedContent('psikiyatrist desteği'), isFalse);
    expect(containsBlockedContent('Nörolog'), isFalse);
    expect(containsBlockedContent('Dil ve Konuşma Terapisti'), isFalse);
    expect(kUzmanlikSecenekleri, contains('Psikolog'));
    for (final uzmanlik in kUzmanlikSecenekleri) {
      expect(
        containsBlockedContent(uzmanlik),
        isFalse,
        reason: 'uzmanlık "$uzmanlik" ilan formunda serbest olmalı',
      );
    }
  });

  test('küfür ve şiddet yumuşak filtreden geçer', () {
    expect(containsBlockedContent('amk ne biçim'), isTrue);
    expect(containsBlockedContent('siktir git'), isTrue);
    expect(containsBlockedContent('seni öldürürüm'), isTrue);
    expect(containsBlockedContent('merhaba aileler'), isFalse);
  });
}
