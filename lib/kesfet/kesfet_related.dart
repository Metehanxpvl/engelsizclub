import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/diseases_data.dart';
import '../info_library/info_library.dart';
import '../info_library/info_library_repository.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../pages/in_app_web_page.dart';
import '../pages/premature_gelisim_rehberi_page.dart';
import '../services/catalog_adapters.dart';
import 'kesfet_models.dart';

/// related_article_id / slug → bilgi kütüphanesi, hastalık veya uygulama içi sayfa.
Future<void> openKesfetRelated(
  BuildContext context, {
  required KesfetVideo video,
  bool isGuest = false,
  VoidCallback? onRequireLogin,
}) async {
  final id = video.relatedArticleId.trim();
  final slug = video.relatedArticleSlug.trim();

  if (id.isNotEmpty) {
    try {
      final row = await Supabase.instance.client
          .from('info_library_contents')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null && context.mounted) {
        final content = InfoContent.fromRow(row);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InfoDetailScreen(content: content),
          ),
        );
        return;
      }
    } catch (_) {}
  }

  if (slug.startsWith('http://') ||
      slug.startsWith('https://') ||
      slug.startsWith('/')) {
    if (!context.mounted) return;
    await InAppWebPage.open(
      context,
      title: video.title,
      url: slug,
      isGuest: isGuest,
      onRequireLogin: onRequireLogin,
    );
    return;
  }

  if (slug.isNotEmpty) {
    if (slug == 'premature' || slug.contains('premature')) {
      if (!context.mounted) return;
      await PrematureGelisimRehberiPage.open(context);
      return;
    }
    DiseaseInfo? disease;
    for (final d in CatalogAdapters.diseases()) {
      if (d.id == slug || d.name.toLowerCase() == slug.toLowerCase()) {
        disease = d;
        break;
      }
    }
    if (disease != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _KesfetDiseasePage(disease: disease!),
        ),
      );
      return;
    }

    try {
      final items = await InfoLibraryRepository.instance.fetchByCategory(slug);
      if (items.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InfoListScreen(
              category: slug,
              title: video.title,
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      await InAppWebPage.open(
        context,
        title: video.title,
        url: '/bilgi-kutuphanesi/$slug',
        isGuest: isGuest,
        onRequireLogin: onRequireLogin,
      );
    }
  }
}

class _KesfetDiseasePage extends StatelessWidget {
  const _KesfetDiseasePage({required this.disease});

  final DiseaseInfo disease;

  @override
  Widget build(BuildContext context) {
    final d = disease;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          d.name,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(d.icon, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            d.desc,
            style: GoogleFonts.nunito(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: MetoColors.foreground,
            ),
          ),
          if (d.symptoms.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Belirtiler',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final s in d.symptoms)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $s',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    color: MetoColors.mutedFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const L10nText(
            'Bu içerik bilgilendirme amaçlıdır; tıbbi tavsiye değildir. '
            'Engelsiz Club klinik hizmet sunmaz.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
