import 'package:flutter/material.dart';

import 'in_app_web_page.dart';

/// 0–2 Yaş Gelişim Rehberi — mevcut statik içerik (yeniden yazılmaz).
///
/// Web SEO HTML: /bilgi-kutuphanesi/0-2-yas-gelisim-rehberi
class Yas02GelisimRehberiPage {
  Yas02GelisimRehberiPage._();

  static const routePath = '/bilgi-kutuphanesi/0-2-yas-gelisim-rehberi';
  static const title = '0-2 Yaş Gelişim Rehberi';

  static Future<void> open(
    BuildContext context, {
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return InAppWebPage.open(
      context,
      title: title,
      url: routePath,
      isGuest: isGuest,
      onRequireLogin: onRequireLogin,
    );
  }
}
