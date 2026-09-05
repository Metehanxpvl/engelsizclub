import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/in_app_web_page.dart';

/// Resmi KT PDF / e-KT.
/// Web: yeni sekme (TİTCK iframe'i engeller).
/// Native: Android WebView PDF gösteremez — Chrome Custom Tabs / Safari.
/// HTML sayfalar WebView’de kalabilir; TITCK / PDF her zaman harici görüntüleyici.
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

    if (_needsExternalViewer(uri)) {
      final opened = await _openExternal(uri);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prospektüs açılamadı')),
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

  static bool _needsExternalViewer(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf')) return true;
    if (uri.query.toLowerCase().contains('pdf')) return true;
    if (host.contains('titck.gov.tr')) return true;
    return false;
  }

  static Future<bool> _openExternal(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        return true;
      }
    } catch (e) {
      debugPrint('ProspectusViewer inAppBrowserView: $e');
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('ProspectusViewer external: $e');
      return false;
    }
  }
}
