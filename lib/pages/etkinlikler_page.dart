import 'package:flutter/material.dart';

import 'kampanyalar_page.dart';

/// Etkinlikler — KampanyalarPage (kind: etkinlik); Tümü il başlıklarıyla, il ara ile tek il.
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
