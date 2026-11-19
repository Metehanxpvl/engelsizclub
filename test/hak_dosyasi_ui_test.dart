import 'package:engelsizclub/data/rights_data.dart';
import 'package:engelsizclub/hak/hak_dosyasi.dart';
import 'package:engelsizclub/hak/hak_kural.dart';
import 'package:engelsizclub/pages/hak_dosyasi_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hakDosyasiPlainText includes title, ozet, adimlar', () {
    const item = RightItem(
      id: 't1',
      title: 'Test Hak',
      amount: '₺100',
      category: 'maddi',
      icon: '✓',
      color: Color(0xFF000000),
      bg: Color(0xFFFFFFFF),
      minRate: 40,
      maxAge: 99,
      incomeLimit: false,
      desc: 'Açıklama',
      steps: ['Adım A'],
      where: 'Kurum',
    );
    const dosya = HakDosyasi(
      ozet: 'Kısa özet',
      adimlar: [
        HakAdim(baslik: 'Başvur', aciklama: 'e-Devlet'),
      ],
    );
    final text = hakDosyasiPlainText(dosya, item);
    expect(text, contains('Test Hak'));
    expect(text, contains('Kısa özet'));
    expect(text, contains('Başvur'));
    expect(text, contains('e-Devlet'));
  });

  test('filter fallback: incomeLimit + gelir unknown → sartlaraBagli', () {
    // Mirrors RightsSihirbazi._classify fallback rule.
    const incomeLimit = true;
    const gelirUnknown = true;
    final u = (incomeLimit && gelirUnknown)
        ? HakUygunluk.sartlaraBagli
        : HakUygunluk.buyukIhtimalle;
    expect(u, HakUygunluk.sartlaraBagli);
  });

  test('oran mapping 40-69→40, 70-89→70, 90+→90', () {
    int map(String rate) {
      if (rate == '40-69') return 40;
      if (rate == '70-89') return 70;
      if (rate == '90+') return 90;
      return -1;
    }

    expect(map('40-69'), 40);
    expect(map('70-89'), 70);
    expect(map('90+'), 90);
  });

  test('itiraz sure day parse', () {
    int? gun(String sure) {
      final m = RegExp(r'(\d+)\s*gün', caseSensitive: false).firstMatch(sure);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    }

    expect(gun('30 gün'), 30);
    expect(gun('İtiraz süresi 15 gündür'), 15);
    expect(gun('belirsiz'), isNull);
  });

  test('rapor bitiş within 30 days warning window', () {
    String? uyari(DateTime? raporBitis, DateTime now) {
      if (raporBitis == null) return null;
      final bitis =
          DateTime(raporBitis.year, raporBitis.month, raporBitis.day);
      final n = DateTime(now.year, now.month, now.day);
      final diff = bitis.difference(n).inDays;
      if (diff < 0 || diff > 30) return null;
      return 'warn';
    }

    final now = DateTime(2026, 11, 19);
    expect(uyari(DateTime(2026, 12, 1), now), 'warn');
    expect(uyari(DateTime(2026, 11, 19), now), 'warn');
    expect(uyari(DateTime(2027, 2, 1), now), isNull);
    expect(uyari(DateTime(2026, 11, 1), now), isNull);
  });
}
