// File generated for Engelsiz Club Firebase project (engelsizclub-e5842).
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Engelsiz Club.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  /// Google hesap seçicide "engelsizclub.com uygulamasına devam edin" görünür.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDbcRvVaEQSDQJ2y-0kHZUsxtW_O2Xb_bQ',
    appId: '1:59695056324:web:ea6c93f11bd19d395b9091',
    messagingSenderId: '59695056324',
    projectId: 'engelsizclub-e5842',
    authDomain: 'engelsizclub.com',
    storageBucket: 'engelsizclub-e5842.firebasestorage.app',
    measurementId: 'G-8YPB15NZPJ',
  );

  /// Android paket: com.sakircaykara.engelsizclub
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_Vr-DwlmtH6Of_0SNo2gDpqyQJba9zF8',
    appId: '1:59695056324:android:4e3e2858da075b865b9091',
    messagingSenderId: '59695056324',
    projectId: 'engelsizclub-e5842',
    storageBucket: 'engelsizclub-e5842.firebasestorage.app',
  );

  // iOS Firebase app eklenince Console’dan güncelle.
  static const FirebaseOptions ios = web;
}
