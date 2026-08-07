import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Yatay sonsuz döngülü (marquee) otomatik kaydırma.
///
/// ListView offset sarımı ile sürekli döner (başa atlar gibi görünmez).
/// Elle kaydırma serbest; parmak kalkınca akış devam eder.
class StoryMarquee extends StatefulWidget {
  const StoryMarquee({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onItemTap,
    this.onItemLongPress,
    this.contentVersion,
    this.height = 112,
    this.itemWidth = 90,
    this.pixelsPerSecond = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemTap;
  final ValueChanged<int>? onItemLongPress;

  /// İçerik değişince (id / görsel / seen) rebuild için.
  final Object? contentVersion;

  final double height;
  final double itemWidth;
  final double pixelsPerSecond;
  final EdgeInsets padding;

  @override
  State<StoryMarquee> createState() => _StoryMarqueeState();
}

class _StoryMarqueeState extends State<StoryMarquee>
    with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _userDragging = false;
  bool _resumeScheduled = false;

  /// Tek öğede bile akış için yeterli kopya.
  int get _copies {
    if (widget.itemCount <= 0) return 0;
    if (widget.itemCount == 1) return 8;
    if (widget.itemCount < 4) return 5;
    return 4;
  }

  double get _loopWidth => widget.itemCount * widget.itemWidth;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToMiddle());
  }

  @override
  void didUpdateWidget(covariant StoryMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.itemWidth != widget.itemWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _normalizeOffset();
      });
    }
  }

  void _jumpToMiddle() {
    if (!mounted || !_controller.hasClients || _loopWidth <= 0) return;
    _controller.jumpTo(_loopWidth);
  }

  void _normalizeOffset() {
    if (!mounted || !_controller.hasClients || _loopWidth <= 0) return;
    final loop = _loopWidth;
    final o = _controller.offset;
    // Ortadaki bandda tut
    var next = o;
    while (next < loop) {
      next += loop;
    }
    while (next >= loop * (_copies - 1)) {
      next -= loop;
    }
    if ((next - o).abs() > 0.5) {
      _controller.jumpTo(next);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted ||
        _userDragging ||
        !_controller.hasClients ||
        widget.itemCount <= 0 ||
        _loopWidth <= 0) {
      _lastTick = elapsed;
      return;
    }
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    final loop = _loopWidth;
    var next = _controller.offset + widget.pixelsPerSecond * dt;

    // Sonsuz döngü: offset'i orta bantta tut
    final maxKeep = loop * (_copies - 1);
    final minKeep = loop * 0.5;
    while (next >= maxKeep) {
      next -= loop;
    }
    while (next < minKeep) {
      next += loop;
    }

    _controller.jumpTo(next);
  }

  void _scheduleResume() {
    if (_resumeScheduled) return;
    _resumeScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _userDragging = false;
      _resumeScheduled = false;
      _lastTick = Duration.zero;
      _normalizeOffset();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return SizedBox(height: widget.height);

    final total = widget.itemCount * _copies;
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _userDragging = true;
            _resumeScheduled = false;
          } else if (n is ScrollEndNotification) {
            if (_userDragging) _scheduleResume();
          }
          return false;
        },
        child: ListView.builder(
          key: ValueKey('marquee_${widget.contentVersion}'),
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: widget.padding,
          itemCount: total,
          itemExtent: widget.itemWidth,
          // Görsellerin gereksiz rebuild'ini azalt
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final real = index % widget.itemCount;
            return KeyedSubtree(
              key: ValueKey('marquee_item_${index}_$real'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onItemTap == null
                    ? null
                    : () => widget.onItemTap!(real),
                onLongPress: widget.onItemLongPress == null
                    ? null
                    : () => widget.onItemLongPress!(real),
                child: widget.itemBuilder(context, real) ??
                    const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
