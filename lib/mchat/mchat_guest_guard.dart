import 'dart:async';

import 'package:flutter/material.dart';

import '../guest_limit_store.dart';
import '../l10n/l10n_text.dart';

/// Misafir otizm tarama oturumunu izler; süre bitince kapatır.
class MchatGuestGuard extends StatefulWidget {
  const MchatGuestGuard({
    super.key,
    required this.isGuest,
    required this.child,
    this.onRequireLogin,
  });

  final bool isGuest;
  final Widget child;
  final VoidCallback? onRequireLogin;

  @override
  State<MchatGuestGuard> createState() => _MchatGuestGuardState();
}

class _MchatGuestGuardState extends State<MchatGuestGuard> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || _expired || !widget.isGuest) return;
    final left = await GuestLimitStore.remainingTimedSeconds('mchat');
    if (!mounted || left > 0) return;
    _expired = true;
    _timer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: L10nText(
          'Misafir süresi doldu (1 dk). Devam etmek için giriş yapın veya üye olun.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onRequireLogin?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
