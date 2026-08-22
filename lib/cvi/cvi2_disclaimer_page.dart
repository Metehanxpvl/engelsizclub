import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_colors.dart';
import 'discovery/cvi_discovery_config_loader.dart';
import 'discovery/cvi_discovery_menu_page.dart';
import '../l10n/l10n_text.dart';

/// CVI Egzersizleri-2 — Görsel Keşif sorumluluk reddi.
class Cvi2DisclaimerPage extends StatefulWidget {
  const Cvi2DisclaimerPage({
    super.key,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<Cvi2DisclaimerPage> createState() => _Cvi2DisclaimerPageState();
}

class _Cvi2DisclaimerPageState extends State<Cvi2DisclaimerPage> {
  bool _accepted = false;
  bool _busy = false;

  Future<void> _start() async {
    if (!_accepted || _busy) return;
    setState(() => _busy = true);
    try {
      final config = await CviDiscoveryConfigLoader.load();
      if (!mounted) return;
      if (config.categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: L10nText('Keşif yapılandırması yüklenemedi.')),
        );
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CviDiscoveryMenuPage(config: config),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Yükleme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CviColors.bg,
      appBar: AppBar(
        backgroundColor: CviColors.card,
        foregroundColor: CviColors.text,
        elevation: 0,
        title: L10nText(
          'CVI Egzersizleri-2',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: CviColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CviColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF9C4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFF9A825),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        L10nText(
                          'Görsel Keşif',
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: CviColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        L10nText(
                          'Yıldızlar, meyveler ve arabalar ile yüksek kontrastlı '
                          'görsel keşif. Tıbbi tanı veya tedavi amacı taşımaz.',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            height: 1.45,
                            color: CviColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _Bullet(
                          'Cortical Visual Impairment (CVI) / görme ile ilgili herhangi bir tıbbi teşhis vermez.',
                        ),
                        const _Bullet(
                          'Sonuçlar yalnızca görsel etkileşim içindir; tıbbi karar vermek için kullanılamaz.',
                        ),
                        const _Bullet(
                          'Sağlık endişeniz varsa göz doktoru / nöroloji / gelişim uzmanına danışın.',
                        ),
                        if (widget.isGuest) ...[
                          const SizedBox(height: 8),
                          const _Bullet(
                            'Misafir oturumu süre sınırlıdır (yaklaşık 1 dk).',
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CviColors.warnBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CviColors.warnBorder),
                          ),
                          child: L10nText(
                            'Bu uygulama tıbbi tanı koymaz. Sadece görsel egzersiz içindir.',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: CviColors.warnFg,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: CviColors.card,
                borderRadius: BorderRadius.circular(14),
                child: CheckboxListTile(
                  value: _accepted,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _accepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: CviColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: L10nText(
                    'Okudum ve kabul ediyorum',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: CviColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: (_accepted && !_busy) ? _start : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF9A825),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        const Color(0xFFF9A825).withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : L10nText(
                          'Kabul Et ve Başla',
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CviColors.muted,
                    side: const BorderSide(color: CviColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: L10nText(
                    'Vazgeç',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 16, height: 1.4)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 15,
                height: 1.4,
                color: CviColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
