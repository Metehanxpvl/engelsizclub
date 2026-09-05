import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../remote/app_screen_config.dart';
import '../services/force_update_service.dart';

/// İlk kareyi asla geciktirmez / kilitlemez.
/// Android: Play In-App Update (yalnız mağazada daha yeni varsa).
/// iOS: kapatılabilir alt kart. Web: no-op.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  final _svc = ForceUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) return;
      unawaited(_svc.check());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_svc.onResumed());
      unawaited(AppScreenConfigStore.instance.load());
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showIos = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _svc.iosUpdateAvailable;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showIos) _IosUpdateSheet(service: _svc),
      ],
    );
  }
}

class _IosUpdateSheet extends StatelessWidget {
  const _IosUpdateSheet({required this.service});

  final ForceUpdateService service;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          dismissible: true,
          color: const Color(0x990D2B1F),
          onDismiss: service.dismissIosPrompt,
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Material(
                color: MetoColors.card,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: MetoColors.muted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_alt,
                          color: MetoColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      L10nText(
                        'Yeni sürüm var',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      L10nText(
                        service.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          height: 1.45,
                          color: MetoColors.mutedFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => service.openStore(),
                          style: FilledButton.styleFrom(
                            backgroundColor: MetoColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: L10nText(
                            'Güncelle',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: service.dismissIosPrompt,
                          child: L10nText(
                            'Şimdi değil',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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
          ),
        ),
      ],
    );
  }
}
