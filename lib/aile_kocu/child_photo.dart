import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hive’da çocuk fotoğrafı: `data:image/...;base64,...` (tercih) veya dosya yolu.
ImageProvider? childPhotoProvider(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  if (s.startsWith('data:image')) {
    try {
      final b64 = s.contains(',') ? s.split(',').last : s;
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }
  if (kIsWeb) return null;
  try {
    final f = File(s);
    if (f.existsSync()) return FileImage(f);
  } catch (_) {}
  return null;
}

bool hasChildPhoto(String? raw) => childPhotoProvider(raw) != null;

Uint8List? childPhotoBytes(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  if (s.startsWith('data:image')) {
    try {
      final b64 = s.contains(',') ? s.split(',').last : s;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
  if (kIsWeb) return null;
  try {
    final f = File(s);
    if (f.existsSync()) return f.readAsBytesSync();
  } catch (_) {}
  return null;
}

/// image_picker sonucunu Hive’a yazılacak data URL’e çevirir.
Future<String> encodePickedChildPhoto(dynamic xFile) async {
  final bytes = await xFile.readAsBytes() as Uint8List;
  // Boyut sınırı ~1.5MB base64
  var out = bytes;
  if (out.lengthInBytes > 900000) {
    // çok büyükse yine de kaydet; decode tarafı idare eder
  }
  final b64 = base64Encode(out);
  return 'data:image/jpeg;base64,$b64';
}
