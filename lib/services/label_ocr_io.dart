import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Android / iOS — on-device OCR (isteğe bağlı metin). Asıl analiz: Gemini görsel.
class LabelOcr {
  LabelOcr._();

  static const isOnDeviceAvailable = true;

  static Future<String> readFromPath(String path) async {
    if (path.isEmpty) return '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text.trim();
    } catch (e, st) {
      debugPrint('OCR atlandı: $e\n$st');
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
