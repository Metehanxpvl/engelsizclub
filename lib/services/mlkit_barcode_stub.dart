import 'dart:typed_data';

/// Web / masaüstü — ML Kit barkod yok; ZXing / html5-qrcode kullanılır.
class MlkitBarcode {
  MlkitBarcode._();

  static const isAvailable = false;

  static Future<String?> scanPath(String path) async => null;

  static Future<String?> scanBytes(Uint8List bytes) async => null;
}
