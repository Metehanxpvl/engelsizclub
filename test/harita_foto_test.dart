import 'package:engelsizclub/harita_foto_store.dart';
import 'package:engelsizclub/harita_yer_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('haritaPlaceSourceKey is stable for name and coords', () {
    expect(
      haritaPlaceSourceKeyParts(
        name: 'Güneş Özel Eğitim',
        lat: 41.0082,
        lng: 28.9784,
      ),
      'gunes ozel egitim|41.00820|28.97840',
    );
  });

  test('isPublicHaritaPhotoUrl allows R2 public HTTPS only', () {
    expect(
      isPublicHaritaPhotoUrl(
        'https://pub-b37e9c19660c4a9994f5f75493eda814.r2.dev/map-photos/a.jpg',
      ),
      isTrue,
    );
    expect(isPublicHaritaPhotoUrl('http://evil.example/x.jpg'), isFalse);
    expect(isPublicHaritaPhotoUrl('https://evil.example/x.jpg'), isFalse);
    expect(isPublicHaritaPhotoUrl('javascript:alert(1)'), isFalse);
  });

  test('note photo urls can be dropped one by one', () {
    const a =
        'https://pub-b37e9c19660c4a9994f5f75493eda814.r2.dev/map-photos/a.jpg';
    const b =
        'https://pub-b37e9c19660c4a9994f5f75493eda814.r2.dev/map-photos/b.jpg';
    final note = haritaEncodeErisimNote(
      const ['Rampa'],
      'Giriş solda',
      photoUrls: const [a, b],
    );
    final kept = haritaParseFotoUrls(note).where((u) => u != a).toList();
    final next = haritaEncodeErisimNote(
      haritaParseErisimTags(note),
      haritaErisimNoteBody(note),
      photoUrls: kept,
    );
    expect(haritaParseFotoUrls(next), [b]);
    expect(haritaErisimNoteBody(next), 'Giriş solda');
  });
}
