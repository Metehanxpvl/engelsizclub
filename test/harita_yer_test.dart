import 'package:engelsizclub/data/centers_data.dart';
import 'package:engelsizclub/harita_yer_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('haritaFoldName folds Turkish and strips junk', () {
    expect(haritaFoldName('  Güneş Özel Eğitim  '), 'gunes ozel egitim');
    expect(haritaFoldName('İstanbul'), 'istanbul');
  });

  test('haritaYerMatchesQuery finds Turkish names', () {
    expect(
      haritaYerMatchesQuery(
        'istanbul ozel',
        name: 'İstanbul Özel Eğitim',
        address: 'Kadıköy',
      ),
      isTrue,
    );
    expect(
      haritaYerMatchesQuery('gunes', name: 'Güneş Rehabilitasyon'),
      isTrue,
    );
    expect(
      haritaYerMatchesQuery('ankara', name: 'İzmir Fizik Tedavi'),
      isFalse,
    );
  });

  test('erişim note encodes and parses ramp / WC tags', () {
    final note = haritaEncodeErisimNote(
      const ['Rampa', 'Engelli WC'],
      'Kapı biraz dar',
    );
    expect(note.startsWith('Erişim:'), isTrue);
    expect(haritaParseErisimTags(note), ['Rampa', 'Engelli WC']);
    expect(haritaErisimNoteBody(note), 'Kapı biraz dar');
    final center = HaritaYerBildirim(
      id: 1,
      name: 'Cafe',
      category: 'Özel Eğitim',
      city: 'İstanbul',
      note: note,
    ).toCenter();
    expect(center.category, kHaritaErisimKategori);
    expect(center.services, ['Rampa', 'Engelli WC']);
    expect(center.hours, 'Kapı biraz dar');
  });

  test('foto URLs persist in note and stay out of visible body', () {
    const url =
        'https://pub-41d8be38e909416fbb3804b3a3e88569.r2.dev/map-photos/x.jpg';
    final note = haritaEncodeErisimNote(
      const ['Rampa'],
      'Giriş solda',
      photoUrls: [url],
    );
    expect(haritaParseFotoUrls(note), [url]);
    expect(haritaErisimNoteBody(note), 'Giriş solda');
    expect(haritaParseErisimTags(note), ['Rampa']);
    haritaIndexedNotePhotos.clear();
    HaritaYerBildirim(
      id: 2,
      name: 'Panora',
      category: kHaritaErisimKategori,
      city: 'Ankara',
      note: note,
      lat: 39.9,
      lng: 32.8,
    ).toCenter();
    expect(
      haritaIndexedNotePhotos[haritaYerSourceKey(
        name: 'Panora',
        lat: 39.9,
        lng: 32.8,
      )],
      [url],
    );
  });

  test('reporter is recognized as owner of their pin', () {
    haritaUyeYerByCenterId.clear();
    final item = HaritaYerBildirim(
      id: 9,
      name: 'Cafe',
      category: kHaritaErisimKategori,
      city: 'Ankara',
      userEmail: 'ali@example.com',
    );
    final center = item.toCenter();
    expect(haritaYerSahibiMi(center.id, 'ali@example.com'), isTrue);
    expect(haritaYerSahibiMi(center.id, 'baskasi@example.com'), isFalse);
    unindexHaritaUyeYer(9);
    expect(haritaYerSahibiMi(center.id, 'ali@example.com'), isFalse);
  });

  test('aile: every 5 reports awards one iyilik point', () {
    expect(haritaIyilikOdulThisReport(0), isFalse);
    expect(haritaIyilikOdulThisReport(4), isFalse);
    expect(haritaIyilikOdulThisReport(5), isTrue);
    expect(haritaIyilikOdulThisReport(9), isFalse);
    expect(haritaIyilikOdulThisReport(10), isTrue);
    expect(haritaIyilikKalan(0), 5);
    expect(haritaIyilikKalan(1), 4);
    expect(haritaIyilikKalan(5), 0);
    expect(haritaIyilikKalan(7), 3);
  });

  test('nearby member report overlays Google place detail', () {
    haritaUyeYerByCenterId.clear();
    haritaIndexedNotePhotos.clear();
    final note = haritaEncodeErisimNote(
      const ['Rampa', 'Engelli WC'],
      'Giriş soldan',
    );
    HaritaYerBildirim(
      id: 21,
      name: 'Ankara — haritada işaretlenen yer',
      category: kHaritaErisimKategori,
      city: 'Ankara',
      note: note,
      userEmail: 'ali@example.com',
      lat: 39.90100,
      lng: 32.77500,
    ).toCenter();
    const google = MetoCenter(
      id: 800123,
      city: 'Ankara',
      ilce: 'Çankaya',
      name: 'Panora',
      category: 'AVM',
      address: 'Turan Güneş Bulvarı',
      phone: '0312 000 00 00',
      hours: '10:00–22:00',
      services: ['AVM'],
      rating: 4.4,
      reviews: 10,
      color: Color(0xFF1A6B4A),
      lat: 39.90105,
      lng: 32.77510,
    );
    final shown = overlayHaritaYerBildirimi(google);
    expect(shown.id, kHaritaUyeYerIdBase + 21);
    expect(shown.name, 'Panora');
    expect(shown.category, kHaritaErisimKategori);
    expect(shown.services, ['Rampa', 'Engelli WC']);
    expect(shown.hours, 'Giriş soldan');
    expect(haritaYerSahibiMi(shown.id, 'ali@example.com'), isTrue);
    expect(
      findHaritaYerForCenter(google)?.id,
      21,
    );
    expect(haritaYerBildirimSayisi(google), 1);
    HaritaYerBildirim(
      id: 22,
      name: 'Panora',
      category: kHaritaErisimKategori,
      city: 'Ankara',
      note: haritaEncodeErisimNote(const ['Asansör'], ''),
      userEmail: 'ayse@example.com',
      lat: 39.90102,
      lng: 32.77504,
    ).toCenter();
    expect(haritaYerBildirimSayisi(google), 2);
    expect(haritaYerBildirimSayisiLabel(2), '2 kişi bildirdi');
    final counts = haritaYerOzellikSayilari(google);
    expect(counts['Rampa'], 1);
    expect(counts['Engelli WC'], 1);
    expect(counts['Asansör'], 1);
    expect(haritaYerOzellikLabel('Rampa', 2), 'Rampa · 2 kişi');
    unindexHaritaUyeYer(21);
    unindexHaritaUyeYer(22);
  });
}
