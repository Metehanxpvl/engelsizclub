import 'package:engelsizclub/widgets/photo_gallery_lightbox.dart';
import 'package:engelsizclub/widgets/user_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only real photo sources can open avatar lightbox', () {
    expect(isAvatarImageSource('https://cdn.example.com/a.png'), isTrue);
    expect(isAvatarImageSource('data:image/png;base64,abc'), isTrue);
    expect(isAvatarImageSource('ŞÇ'), isFalse);
    expect(isAvatarImageSource('A'), isFalse);
    expect(galleryImageProvider('https://cdn.example.com/a.png'), isNotNull);
    expect(galleryImageProvider('ŞÇ'), isNull);
  });
}
