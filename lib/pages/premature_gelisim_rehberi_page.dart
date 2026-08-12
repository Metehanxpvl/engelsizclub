import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../info_library/info_library.dart';

/// Prematüre Bebek Gelişim Rehberi — Otizm bilgi kütüphanesi ile aynı CMS:
/// Blok ekle · YouTube · başlık · kaynak · açıklama · düzenle / sil / sıra.
///
/// Web SEO HTML: /bilgi-kutuphanesi/premature-bebek (statik hosting).
/// Uygulama içi: [InfoListScreen] (`category: premature`).
class PrematureGelisimRehberiPage {
  PrematureGelisimRehberiPage._();

  static const routePath = '/bilgi-kutuphanesi/premature-bebek';

  static Future<void> open(BuildContext context) async {
    final email =
        Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InfoListScreen(
          category: InfoLibraryCategories.premature,
          title: 'Prematüre Bebek — Gelişim Rehberi',
          adminEmail: email,
        ),
        settings: const RouteSettings(name: routePath),
      ),
    );
  }
}
