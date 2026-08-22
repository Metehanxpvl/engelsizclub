import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_discovery_models.dart';
import 'cvi_discovery_play_page.dart';

/// YILDIZLAR / MEYVELER / ARABALAR — yüksek kontrastlı kategori menüsü.
class CviDiscoveryMenuPage extends StatelessWidget {
  const CviDiscoveryMenuPage({super.key, required this.config});

  final CviDiscoveryConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 28),
                tooltip: 'Geri',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bir kategori seçin',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
              ),
            ),
            const Spacer(),
            for (final cat in config.categories) ...[
              _CategoryButton(
                label: cat.label,
                background: cat.buttonColor,
                foreground: cat.textColor,
                onTap: () => _openCategory(context, cat),
              ),
              const SizedBox(height: 20),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  void _openCategory(BuildContext context, CviDiscoveryCategory category) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CviDiscoveryPlayPage(category: category),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            height: 88,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: background.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: foreground,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
