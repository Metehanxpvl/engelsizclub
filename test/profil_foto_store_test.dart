import 'package:engelsizclub/profil_foto_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only http(s) URLs are kept for the database', () {
    expect(isProfilFotoUrl('https://cdn.example/a.jpg'), isTrue);
    expect(isProfilFotoUrl('http://cdn.example/a.jpg'), isTrue);
    expect(sanitizeProfilFotoUrl('https://cdn.example/a.jpg'),
        'https://cdn.example/a.jpg');
    expect(
      sanitizeProfilFotoUrl('data:image/jpeg;base64,AAAA'),
      isNull,
    );
    expect(sanitizeProfilFotoUrl(''), isNull);
    expect(sanitizeProfilFotoUrl(null), isNull);
  });
}
