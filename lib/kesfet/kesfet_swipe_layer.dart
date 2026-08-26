import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Full-screen transparent layer: vertical swipe changes video; tap plays/pauses.
/// Stays above the iframe so Flutter (not YouTube) owns the gesture.
///
/// The feed's [PageView] runs with [NeverScrollableScrollPhysics], so this layer
/// drives [controller] directly. With a single clip [ScrollPosition.maxScrollExtent]
/// is `0` and no swipe can move the feed — that is a feed-length problem, not a
/// gesture problem.
class KesfetSwipeLayer extends StatelessWidget {
  const KesfetSwipeLayer({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.reduceMotion,
    required this.onTogglePlay,
    required this.onWheel,
    this.onWrapForward,
  });

  final PageController controller;
  final int itemCount;
  final bool reduceMotion;
  final VoidCallback onTogglePlay;
  final void Function(PointerScrollEvent e) onWheel;
  final VoidCallback? onWrapForward;

  void _onDragUpdate(DragUpdateDetails d) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    final next = (pos.pixels - d.delta.dy).clamp(0.0, pos.maxScrollExtent);
    controller.jumpTo(next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!controller.hasClients || itemCount <= 0) return;
    final page = controller.page ?? 0;
    final v = d.primaryVelocity ?? 0;
    if (itemCount > 1 && page >= itemCount - 1.05 && v < -280) {
      onWrapForward?.call();
      return;
    }
    int target;
    if (v < -280) {
      target = page.ceil();
    } else if (v > 280) {
      target = page.floor();
    } else {
      target = page.round();
    }
    target = target.clamp(0, itemCount - 1);
    if (reduceMotion) {
      controller.jumpToPage(target);
    } else {
      controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) onWheel(e);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTogglePlay,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: const ColoredBox(color: Color(0x00000000)),
      ),
    );
  }
}
