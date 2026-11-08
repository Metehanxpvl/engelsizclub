import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meto_theme.dart';
import 'metobot_avatar.dart';
import 'metobot_entry.dart';

/// Rotalink-style circular MetoBot chip: pan to move, small motion = tap.
class MetobotDraggableFab extends StatefulWidget {
  const MetobotDraggableFab({
    super.key,
    this.isGuest = false,
    this.onRequireLogin,
    this.onOpenRoute,
  });

  final bool isGuest;
  final VoidCallback? onRequireLogin;
  final ValueChanged<String>? onOpenRoute;

  @override
  State<MetobotDraggableFab> createState() => _MetobotDraggableFabState();
}

class _MetobotDraggableFabState extends State<MetobotDraggableFab> {
  static const _kSize = 68.0;
  static const _kTapSlop = 8.0;
  static const _kEdgeGap = 16.0;
  static const _kNavClearance = 72.0;
  static const _prefDx = 'metobot_draggable_fab_dx';
  static const _prefDy = 'metobot_draggable_fab_dy';

  Offset? _offset;
  Offset? _pointerStartGlobal;
  Offset? _offsetAtDown;
  double _maxMove = 0;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _loadOffset();
  }

  Future<void> _loadOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dx = prefs.getDouble(_prefDx);
      final dy = prefs.getDouble(_prefDy);
      if (!mounted || dx == null || dy == null) return;
      setState(() => _offset = Offset(dx, dy));
    } catch (_) {}
  }

  Future<void> _saveOffset(Offset offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefDx, offset.dx);
      await prefs.setDouble(_prefDy, offset.dy);
    } catch (_) {}
  }

  Offset _defaultOffset(
    BoxConstraints constraints,
    EdgeInsets pad, {
    required bool keyboardOpen,
  }) {
    final nav = keyboardOpen ? _kEdgeGap : _kNavClearance;
    return Offset(
      constraints.maxWidth - _kSize - _kEdgeGap - pad.right,
      constraints.maxHeight - _kSize - nav - pad.bottom,
    );
  }

  Offset _clampToSafeArea(
    Offset offset,
    BoxConstraints constraints,
    EdgeInsets pad,
  ) {
    final maxX = constraints.maxWidth - _kSize - pad.right;
    final maxY = constraints.maxHeight - _kSize - pad.bottom;
    final minX = pad.left;
    final minY = pad.top;
    return Offset(
      offset.dx.clamp(minX, maxX < minX ? minX : maxX),
      offset.dy.clamp(minY, maxY < minY ? minY : maxY),
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    _pointerStartGlobal = e.position;
    _offsetAtDown = null;
    _maxMove = 0;
  }

  void _onPointerMove(
    PointerMoveEvent e,
    BoxConstraints constraints,
    EdgeInsets pad, {
    required bool keyboardOpen,
  }) {
    if (e.pointer != _activePointer) return;
    final start = _pointerStartGlobal;
    if (start == null) return;
    _offsetAtDown ??=
        _offset ?? _defaultOffset(constraints, pad, keyboardOpen: keyboardOpen);
    final dist = (e.position - start).distance;
    if (dist > _maxMove) _maxMove = dist;
    final proposed = _offsetAtDown! + (e.position - start);
    setState(() => _offset = _clampToSafeArea(proposed, constraints, pad));
  }

  void _onPointerEnd(
    PointerEvent e, {
    required BoxConstraints constraints,
    required EdgeInsets pad,
    required bool keyboardOpen,
    required bool cancelled,
  }) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    final start = _pointerStartGlobal;
    if (start != null) {
      final dist = (e.position - start).distance;
      if (dist > _maxMove) _maxMove = dist;
    }
    _pointerStartGlobal = null;
    _offsetAtDown = null;

    final current = _offset ??
        _defaultOffset(constraints, pad, keyboardOpen: keyboardOpen);
    final clamped = _clampToSafeArea(current, constraints, pad);

    if (!cancelled && _maxMove < _kTapSlop) {
      _maxMove = 0;
      _openChat();
      return;
    }

    _maxMove = 0;
    _offset = clamped;
    if (!cancelled) _saveOffset(clamped);
  }

  void _openChat() {
    openMetobot(
      context,
      isGuest: widget.isGuest,
      onRequireLogin: widget.onRequireLogin,
    ).then((route) {
      if (!mounted) return;
      final cb = widget.onOpenRoute;
      if (route != null && route.isNotEmpty && cb != null) cb(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pushed routes (including MetoBot) cover this overlay; hide if easy.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return const SizedBox.shrink();
    }

    final pad = MediaQuery.paddingOf(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shown = _clampToSafeArea(
            _offset ??
                _defaultOffset(
                  constraints,
                  pad,
                  keyboardOpen: keyboardOpen,
                ),
            constraints,
            pad,
          );
          return Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: SizedBox.expand()),
              ),
              Positioned(
                left: shown.dx,
                top: shown.dy,
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: (e) => _onPointerMove(
                    e,
                    constraints,
                    pad,
                    keyboardOpen: keyboardOpen,
                  ),
                  onPointerUp: (e) => _onPointerEnd(
                    e,
                    constraints: constraints,
                    pad: pad,
                    keyboardOpen: keyboardOpen,
                    cancelled: false,
                  ),
                  onPointerCancel: (e) => _onPointerEnd(
                    e,
                    constraints: constraints,
                    pad: pad,
                    keyboardOpen: keyboardOpen,
                    cancelled: true,
                  ),
                  child: const _MetobotChip(size: _kSize),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetobotChip extends StatelessWidget {
  const _MetobotChip({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'MetoBot',
      child: Material(
        elevation: 10,
        shadowColor: const Color(0x661A6B4A),
        shape: const CircleBorder(),
        color: MetoColors.card,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            color: const Color(0xFF3D6364),
          ),
          child: MetoBotAvatar(size: size, zoom: 1.26),
        ),
      ),
    );
  }
}
