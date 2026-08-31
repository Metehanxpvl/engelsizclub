import 'package:flutter/material.dart';

import 'kampanyalar_page.dart';

/// Etkinlikler — Kampanyalar ile aynı il / tüm ülke akışı.
class EtkinliklerPage {
  static Future<void> open(
    BuildContext context, {
    required String userEmail,
  }) {
    return KampanyalarPage.open(
      context,
      userEmail: userEmail,
      kind: CityFeedKind.etkinlik,
    );
  }
}
