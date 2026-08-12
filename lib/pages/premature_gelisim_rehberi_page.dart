import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../info_library/info_library.dart';
import '../medical_disclaimer_store.dart';
import '../meto_theme.dart';

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

    final gone = await isInfoCardDismissed(kDismissPrematureGelisimDisclaimer);
    if (!gone && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Sorumluluk Beyanı',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Bu rehber ve videolar yalnızca bilgilendirme amaçlıdır; tıbbi '
            'teşhis veya tedavi yerine geçmez.\n\n'
            'Bebeğinizin özel durumu için mutlaka çocuk doktoru veya ilgili '
            'uzmana danışın. Uygulama klinik hizmet sunmaz.',
            style: GoogleFonts.nunito(fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () async {
                await dismissInfoCard(kDismissPrematureGelisimDisclaimer);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Bir daha gösterme'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
              child: const Text('Anladım'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

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
