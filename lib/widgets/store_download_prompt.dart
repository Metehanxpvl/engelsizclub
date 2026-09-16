import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../meto_theme.dart';
import '../services/force_update_service.dart';
import '../social_links_store.dart';

const kPromptAppStoreUrl =
    'https://apps.apple.com/tr/app/engelsiz-club/id6799422264';

/// Web localStorage (SharedPreferences) — first visit on home only.
const kWebStorePromptPrefsKey = 'web_store_download_prompt_seen_v2';
const kWebStorePromptDelay = Duration(milliseconds: 1200);

bool webStorePromptConsumed(SharedPreferences prefs) =>
    prefs.getBool(kWebStorePromptPrefsKey) == true;

Future<void> webStorePromptMarkConsumed(SharedPreferences prefs) =>
    prefs.setBool(kWebStorePromptPrefsKey, true);

/// Home-page-only web popup: first visit, then never again after dismiss.
/// Native apps skip this. Destek Sorgu / Evde Eğitim HTML pages do not
/// mount [HomePage], so they never show it.
class WebStoreDownloadPrompt extends StatefulWidget {
  const WebStoreDownloadPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<WebStoreDownloadPrompt> createState() => _WebStoreDownloadPromptState();
}

class _WebStoreDownloadPromptState extends State<WebStoreDownloadPrompt> {
  static bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShow());
    });
  }

  bool _homeTabOnScreen() {
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return false;
    final offset = object.localToGlobal(Offset.zero);
    final width = object.size.width;
    if (width < 8) return false;
    return offset.dx > -width / 2 && offset.dx < width / 2;
  }

  Future<void> _maybeShow() async {
    await Future<void>.delayed(kWebStorePromptDelay);
    if (!mounted || !kIsWeb || _dialogOpen) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (webStorePromptConsumed(prefs)) return;
    } catch (_) {
      // Prefs failure: still offer once this session.
    }
    if (!mounted || !_homeTabOnScreen()) return;

    var appUrl = kPromptAppStoreUrl;
    var playUrl = ForceUpdateService.defaultPlayUrl;
    try {
      final cfg = await SocialLinksStore.instance.load();
      if (cfg.appStoreUrl.trim().isNotEmpty) appUrl = cfg.appStoreUrl.trim();
      if (cfg.playStoreUrl.trim().isNotEmpty) playUrl = cfg.playStoreUrl.trim();
    } catch (_) {}
    if (!mounted || !_homeTabOnScreen()) return;

    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierColor: MetoColors.foreground.withValues(alpha: 0.46),
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: StoreDownloadDialog(
              onLater: () => Navigator.of(ctx).pop(),
              onOpenAppStore: () {
                Navigator.of(ctx).pop();
                unawaited(_open(appUrl));
              },
              onOpenPlay: () {
                Navigator.of(ctx).pop();
                unawaited(_open(playUrl));
              },
            ),
          );
        },
      );
    } finally {
      _dialogOpen = false;
      await _markConsumed();
    }
  }

  Future<void> _markConsumed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await webStorePromptMarkConsumed(prefs);
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Compact store-download popup (çeviri anahtarları [S.t]).
class StoreDownloadDialog extends StatelessWidget {
  const StoreDownloadDialog({
    super.key,
    required this.onLater,
    required this.onOpenAppStore,
    required this.onOpenPlay,
  });

  final VoidCallback onLater;
  final VoidCallback onOpenAppStore;
  final VoidCallback onOpenPlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        final prompt = S.t('download_app_prompt');
        final later = S.t('download_app_later');
        return Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: prompt,
          child: Material(
            color: MetoColors.card,
            elevation: 12,
            shadowColor: MetoColors.foreground.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: MetoColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smartphone_outlined,
                            color: MetoColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              prompt,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 1.25,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: later,
                          onPressed: onLater,
                          icon: const Icon(Icons.close, size: 20),
                          color: MetoColors.mutedFg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: StoreBadgeButton(
                              assetPng: 'assets/images/badge_app_store.png',
                              assetSvgFallback:
                                  'assets/images/badge_app_store.svg',
                              semanticLabel: S.t('download_on_app_store'),
                              onTap: onOpenAppStore,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StoreBadgeButton(
                              assetPng: 'assets/images/badge_google_play.png',
                              assetSvgFallback:
                                  'assets/images/badge_google_play.svg',
                              semanticLabel: S.t('download_on_google_play'),
                              onTap: onOpenPlay,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: onLater,
                        child: Text(
                          later,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Resmi mağaza rozeti; dokununca [onTap] (mağaza URL’si) çalışır.
class StoreBadgeButton extends StatelessWidget {
  const StoreBadgeButton({
    super.key,
    required this.assetPng,
    required this.assetSvgFallback,
    required this.semanticLabel,
    required this.onTap,
  });

  final String assetPng;
  final String assetSvgFallback;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 3.1,
            child: Image.asset(
              assetPng,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => SvgPicture.asset(
                assetSvgFallback,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
