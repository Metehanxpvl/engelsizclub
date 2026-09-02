import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';

/// Android / iOS — ML Kit Data Matrix + QR + EAN.
class MlkitBarcode {
  MlkitBarcode._();

  static const isAvailable = true;

  static const _formats = <BarcodeFormat>[
    BarcodeFormat.dataMatrix,
    BarcodeFormat.qrCode,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
    BarcodeFormat.code128,
  ];

  static Future<String?> scanPath(String path) async {
    if (path.isEmpty) return null;
    final scanner = BarcodeScanner(formats: _formats);
    try {
      final barcodes = await scanner.processImage(InputImage.fromFilePath(path));
      String? first;
      for (final b in barcodes) {
        final raw = (b.rawValue ?? '').trim();
        if (raw.isEmpty) continue;
        first ??= raw;
        if (b.format == BarcodeFormat.dataMatrix ||
            b.format == BarcodeFormat.qrCode) {
          debugPrint(
            'ML Kit barcode format=${b.format.name} len=${raw.length}',
          );
          return raw;
        }
      }
      if (first != null) {
        debugPrint('ML Kit barcode 1D len=${first.length}');
      }
      return first;
    } catch (e, st) {
      debugPrint('ML Kit barcode atlandı: $e\n$st');
      return null;
    } finally {
      await scanner.close();
    }
  }

  static Future<String?> scanBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}mlkit_gtin_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      try {
        return await scanPath(file.path);
      } finally {
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('ML Kit barcode bytes: $e\n$st');
      return null;
    }
  }
}
