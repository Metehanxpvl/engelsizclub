import 'dart:async';

import 'package:flutter/material.dart';

import '../guest_limit_store.dart';
import '../l10n/l10n_text.dart';

/// Misafir süresini izler; bitince ilk rota + üyelik ekranına atar.
class GuestTimedGuard extends StatefulWidget {
  const GuestTimedGuard({
    super.key,
    required this.isGuest,
    required this.tab,
    required this.child,
    this.onRequireLogin,
    this.expiredMessage =
        'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
  });

  final bool isGuest;
  final String tab;
  final Widget child;
  final VoidCallback? onRequireLogin;
  final String expiredMessage;

  @override
  State<GuestTimedGuard> createState() => _GuestTimedGuardState();
}

class _GuestTimedGuardState extends State<GuestTimedGuard> {
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
    final left = await GuestLimitStore.remainingTimedSeconds(widget.tab);
    if (!mounted || left > 0) return;
    _expired = true;
    _timer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: L10nText(widget.expiredMessage),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onRequireLogin?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
