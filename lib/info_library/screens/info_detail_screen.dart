import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../meto_theme.dart';
import '../models/info_content.dart';
import '../widgets/info_youtube_player.dart';

/// Başlık → uygulama içi video → açıklama.
class InfoDetailScreen extends StatelessWidget {
  const InfoDetailScreen({super.key, required this.content});

  final InfoContent content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Text(
            content.title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          InfoYoutubePlayer(youtubeUrlOrId: content.youtubeUrl),
          if (content.source.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Kaynak: ${content.source.trim()}',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            content.description.trim().isEmpty
                ? 'Açıklama eklenmemiş.'
                : content.description.trim(),
            style: GoogleFonts.nunito(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bu içerik bilgilendirme amaçlıdır; tıbbi tavsiye değildir.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}
