import 'package:engelsizclub/yol_haritasi/yol_haritasi_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('her tanıda Gözden kaçabilenler bilgi dalı var', () {
    expect(yolTanilari, isNotEmpty);
    for (final t in yolTanilari) {
      final bilgi = t.dallar.where((d) => d.bilgi).toList();
      expect(bilgi, isNotEmpty, reason: '${t.id} bilgi dalı eksik');
      expect(
        bilgi.every((d) => d.baslik == 'Gözden kaçabilenler'),
        isTrue,
        reason: '${t.id} bilgi dalı başlığı yanlış',
      );
      expect(
        bilgi.every((d) => d.maddeler.isNotEmpty),
        isTrue,
        reason: '${t.id} gözden kaçabilenler boş',
      );
    }
  });

  test('yolNeIseYararBul bilinen başlıklarda açıklama döner', () {
    expect(
      yolNeIseYararBul('Çocuk Nörolojisi'),
      contains('Beyin'),
    );
    expect(
      yolNeIseYararBul('Dil ve konuşma terapisi'),
      isNotNull,
    );
    expect(yolNeIseYararBul('Tamamen bilinmeyen madde'), isNull);
  });

  test('okul dalı sadeceEvetIse okul sorusuna bağlı', () {
    for (final t in yolTanilari) {
      final okul = t.dallar.where((d) => d.baslik == 'Okul ve eğitim');
      expect(okul, isNotEmpty, reason: '${t.id} okul dalı yok');
      expect(okul.every((d) => d.sadeceEvetIse == 'okul'), isTrue);
    }
  });
}
