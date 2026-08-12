export 'models/info_content.dart';
export 'screens/info_list_screen.dart';
export 'screens/info_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../meto_theme.dart';
import 'screens/info_list_screen.dart';

/// Rehber sayfalarının altına konan video kütüphanesi kartı.
class InfoLibraryMoreCard extends StatelessWidget {
  const InfoLibraryMoreCard({
    super.key,
    required this.category,
    this.title = 'Daha fazla içerik',
    this.subtitle = 'Bilgilendirici Videolar İçin Tıklayınız',
    this.listTitle = 'Bilgi Kütüphanesi',
    this.adminEmail = '',
  });

  final String category;
  final String title;
  final String subtitle;
  final String listTitle;
  final String adminEmail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InfoListScreen(
                category: category,
                title: listTitle,
                adminEmail: adminEmail,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.primary, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetoColors.selectedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: MetoColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: MetoColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: MetoColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
