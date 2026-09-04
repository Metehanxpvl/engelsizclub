import 'package:flutter/material.dart';

import 'kampanyalar_page.dart';

/// Etkinlikler — KampanyalarPage (kind: etkinlik); Tümü il başlıklarıyla (boş il → Tüm ülke), il ara.
class EtkinliklerPage {
  static Future<void> open(
    BuildContext context, {
    required String userEmail,
    bool isGuest = false,
    bool openPending = false,
    VoidCallback? onRequireLogin,
  }) {
    return KampanyalarPage.open(
      context,
      userEmail: userEmail,
      kind: CityFeedKind.etkinlik,
      isGuest: isGuest,
      openPending: openPending,
      onRequireLogin: onRequireLogin,
    );
  }
}
