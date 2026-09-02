import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/in_app_web_page.dart';

/// Resmi KT PDF / e-KT: web'de yeni sekme (TİTCK iframe'i engeller),
/// mobilde uygulama içi WebView.
class ProspectusViewer {
  ProspectusViewer._();

  static Future<void> open(
    BuildContext context, {
    required String url,
    String title = 'Prospektüs (resmi)',
    bool isGuest = false,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz prospektüs bağlantısı.')),
        );
      }
      return;
    }

    if (kIsWeb) {
      final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prospektüs sekmesi açılamadı.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await InAppWebPage.open(
      context,
      title: title,
      url: uri.toString(),
      isGuest: isGuest,
      guestTab: 'tarama',
    );
  }
}
