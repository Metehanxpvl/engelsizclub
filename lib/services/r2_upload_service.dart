import 'package:flutter/foundation.dart';

import 'r2_storage_service.dart';

/// Eski ad — etiket yükleme [R2StorageService.upload] üzerinden gider.
class R2UploadService {
  R2UploadService._();

  static const maxBytes = R2StorageService.maxBytes;

  static Future<String?> uploadLabelImage({
    required Uint8List bytes,
    required String objectKey,
    String contentType = 'image/jpeg',
  }) {
    return R2StorageService.upload(
      bytes: bytes,
      objectKey: objectKey,
      contentType: contentType,
    );
  }
}
