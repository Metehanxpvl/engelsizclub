import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../social_links_store.dart';
import 'store_download_prompt.dart';

/// Ana sayfa en altı: mağaza rozetleri + Instagram / Facebook.
class HomeSocialFooter extends StatefulWidget {
  const HomeSocialFooter({super.key, this.adminEmail = ''});

  final String adminEmail;

  @override
  State<HomeSocialFooter> createState() => _HomeSocialFooterState();
}

class _HomeSocialFooterState extends State<HomeSocialFooter> {
  SocialLinksConfig _cfg = const SocialLinksConfig();
  bool _loading = true;

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final cfg = await SocialLinksStore.instance.load();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _loading = false;
    });
  }

  String _resolved(String configured, String fallback) {
    final u = configured.trim();
    return u.isEmpty ? fallback : u;
  }

  Future<void> _open(String url) async {
    final u = url.trim();
    if (u.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Link henüz eklenmedi.')),
      );
      return;
    }
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bağlantı açılamadı')),
      );
    }
  }

  Future<void> _edit() async {
    final result = await showModalBottomSheet<SocialLinksConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SocialLinksEditSheet(initial: _cfg),
    );
    if (result == null || !mounted) return;
    setState(() => _cfg = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 24);

    final isIosApp =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    // iOS incelemesi: Google Play rozeti Guideline 2.3.10 ihlali.
    // Native iOS uygulamasında mağaza rozetleri yok; web + Android’de göster.
    final showPlay = !isIosApp;
    final showApp = !isIosApp;
    final appUrl = _resolved(
      _cfg.appStoreUrl,
      SocialLinksConfig.kDefaultAppStoreUrl,
    );
    final playUrl = _resolved(
      _cfg.playStoreUrl,
      SocialLinksConfig.kDefaultPlayStoreUrl,
    );
    final showStores = showApp || showPlay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bizi takip edin',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const L10nText('Linkleri düzenle'),
                  style: TextButton.styleFrom(
                    foregroundColor: MetoColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SocialTile(
                  assetSvg: 'assets/images/instagram.svg',
                  label: 'Instagram',
                  onTap: () => _open(_cfg.instagramUrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SocialTile(
                  assetSvg: 'assets/images/facebook.svg',
                  label: 'Facebook',
                  onTap: () => _open(_cfg.facebookUrl),
                ),
              ),
            ],
          ),
          if (showStores) ...[
            const SizedBox(height: 16),
            Text(
              'Uygulamayı indir',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (showApp)
                  Expanded(
                    child: StoreBadgeButton(
                      assetPng: 'assets/images/badge_app_store.png',
                      assetSvgFallback: 'assets/images/badge_app_store.svg',
                      semanticLabel: S.t('download_on_app_store'),
                      onTap: () => _open(appUrl),
                    ),
                  ),
                if (showApp && showPlay)
                  const SizedBox(width: 10),
                if (showPlay)
                  Expanded(
                    child: StoreBadgeButton(
                      assetPng: 'assets/images/badge_google_play.png',
                      assetSvgFallback: 'assets/images/badge_google_play.svg',
                      semanticLabel: S.t('download_on_google_play'),
                      onTap: () => _open(playUrl),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.assetSvg,
    required this.label,
    required this.onTap,
  });

  final String assetSvg;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MetoColors.border),
          ),
          child: Row(
            children: [
              SvgPicture.asset(assetSvg, width: 26, height: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new, size: 16, color: MetoColors.mutedFg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLinksEditSheet extends StatefulWidget {
  const _SocialLinksEditSheet({required this.initial});

  final SocialLinksConfig initial;

  @override
  State<_SocialLinksEditSheet> createState() => _SocialLinksEditSheetState();
}

class _SocialLinksEditSheetState extends State<_SocialLinksEditSheet> {
  late final TextEditingController _ig;
  late final TextEditingController _fb;
  late final TextEditingController _app;
  late final TextEditingController _play;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _ig = TextEditingController(text: i.instagramUrl);
    _fb = TextEditingController(text: i.facebookUrl);
    _app = TextEditingController(text: i.appStoreUrl);
    _play = TextEditingController(text: i.playStoreUrl);
  }

  @override
  void dispose() {
    _ig.dispose();
    _fb.dispose();
    _app.dispose();
    _play.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final next = SocialLinksConfig(
      instagramUrl: _ig.text.trim().isEmpty
          ? SocialLinksConfig.kDefaultInstagramUrl
          : _ig.text.trim(),
      facebookUrl: _fb.text.trim().isEmpty
          ? SocialLinksConfig.kDefaultFacebookUrl
          : _fb.text.trim(),
      appStoreUrl: _app.text.trim(),
      playStoreUrl: _play.text.trim(),
    );
    try {
      await SocialLinksStore.instance.save(next);
      if (!mounted) return;
      Navigator.pop(context, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sosyal & mağaza linkleri',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ig,
                decoration: const InputDecoration(
                  labelText: 'Instagram URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fb,
                decoration: const InputDecoration(
                  labelText: 'Facebook URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _app,
                decoration: const InputDecoration(
                  labelText: 'App Store URL',
                  hintText: 'https://apps.apple.com/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) ...[
                TextField(
                  controller: _play,
                  decoration: const InputDecoration(
                    labelText: 'Google Play URL',
                    hintText: 'https://play.google.com/store/apps/...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
