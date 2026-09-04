import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../remote/app_screen_config.dart';
import '../services/force_update_service.dart';

/// Native uygulamada zorunlu güncelleme varsa içeriği kilitler.
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
      _svc.check();
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
      _svc.check();
      unawaited(AppScreenConfigStore.instance.load());
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 1.0.94 hotfix: never cover the first frame. A remote min-build
    // misconfig or overlay throw painted a grey/blank launch on iOS+Android.
    return widget.child;
  }

  Widget _lockOverlay() {

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        const ModalBarrier(dismissible: false, color: Color(0xE60D2B1F)),
        SafeArea(
          child: PopScope(
            canPop: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                        const L10nText(
                          'Güncelleme gerekli',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 10),
                        L10nText(
                          _svc.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                            onPressed: () => _svc.openStore(),
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const L10nText(
                              'Mağazadan güncelle',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
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
        ),
      ],
    );
  }
}
