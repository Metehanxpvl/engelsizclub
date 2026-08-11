import 'dart:io';
import 'package:image/image.dart' as img;

/// Kullanıcının verdiği blur rozet görselini ikiye ayırıp kırpar.
void main() {
  final src = File(
    r'C:\Users\sakir\.cursor\projects\c-engelsizclub\assets\c__Users_sakir_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_image-c1e35b4c-48fd-415b-b04b-4e1a129b8e02.png',
  );
  final bytes = src.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    stderr.writeln('decode failed');
    exit(1);
  }

  // Üstteki metin / chevron kırpılsın — rozetler alt bantta.
  final top = (image.height * 0.22).round().clamp(0, image.height - 1);
  final bottomPad = (image.height * 0.06).round();
  final h = (image.height - top - bottomPad).clamp(1, image.height);
  final band = img.copyCrop(image, x: 0, y: top, width: image.width, height: h);

  final mid = band.width ~/ 2;
  final gap = (band.width * 0.02).round();
  final sidePad = (band.width * 0.03).round();

  final apple = img.copyCrop(
    band,
    x: sidePad,
    y: 0,
    width: (mid - gap - sidePad).clamp(1, band.width),
    height: band.height,
  );
  final play = img.copyCrop(
    band,
    x: mid + gap,
    y: 0,
    width: (band.width - mid - gap - sidePad).clamp(1, band.width),
    height: band.height,
  );

  // Kenarlardaki açık arka planı sıkıca kırp (siyaha yakın pikseller).
  final appleTight = _tightCropDarkBadge(apple);
  final playTight = _tightCropDarkBadge(play);

  // Kalite için 3x büyüt (nearest değil — cubic)
  final appleHi = img.copyResize(
    appleTight,
    width: appleTight.width * 3,
    height: appleTight.height * 3,
    interpolation: img.Interpolation.cubic,
  );
  final playHi = img.copyResize(
    playTight,
    width: playTight.width * 3,
    height: playTight.height * 3,
    interpolation: img.Interpolation.cubic,
  );

  Directory('assets/images').createSync(recursive: true);
  File('assets/images/badge_app_store.png')
      .writeAsBytesSync(img.encodePng(appleHi));
  File('assets/images/badge_google_play.png')
      .writeAsBytesSync(img.encodePng(playHi));
  stdout.writeln(
    'wrote badges '
    '${appleHi.width}x${appleHi.height} / ${playHi.width}x${playHi.height}',
  );
}

img.Image _tightCropDarkBadge(img.Image src) {
  var minX = src.width;
  var minY = src.height;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      // Açık gri arka plan değilse (rozet siyah + renkli ikon)
      final bright = (r + g + b) / 3;
      if (bright < 210) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX <= minX || maxY <= minY) return src;
  final pad = 2;
  minX = (minX - pad).clamp(0, src.width - 1);
  minY = (minY - pad).clamp(0, src.height - 1);
  maxX = (maxX + pad).clamp(0, src.width - 1);
  maxY = (maxY + pad).clamp(0, src.height - 1);
  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}
