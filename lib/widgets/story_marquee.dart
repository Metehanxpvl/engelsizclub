import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Yatay sonsuz döngülü (marquee) otomatik kaydırma.
/// Elle kaydırma serbest; parmak kalkınca akış devam eder.
class StoryMarquee extends StatefulWidget {
  const StoryMarquee({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 112,
    this.itemWidth = 90,
    this.pixelsPerSecond = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
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

  /// En az 2 kopya; tek öğede bile akış için 3 kopya.
  int get _copies {
    if (widget.itemCount <= 0) return 0;
    if (widget.itemCount == 1) return 6;
    if (widget.itemCount < 4) return 4;
    return 3;
  }

  double get _loopWidth => widget.itemCount * widget.itemWidth;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || _loopWidth <= 0) return;
      // Ortadaki kopyadan başla — geri/ileri sonsuz his
      _controller.jumpTo(_loopWidth);
    });
  }

  @override
  void didUpdateWidget(covariant StoryMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients || _loopWidth <= 0) return;
        final o = _controller.offset;
        final normalized = o % _loopWidth;
        _controller.jumpTo(_loopWidth + normalized);
      });
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

    var next = _controller.offset + widget.pixelsPerSecond * dt;
    // Tek döngü genişliğini aşınca pürüzsüz sar
    while (next >= _loopWidth * 2) {
      next -= _loopWidth;
    }
    while (next < _loopWidth * 0.5 && _copies >= 2) {
      next += _loopWidth;
    }
    _controller.jumpTo(next);
  }

  void _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
      _resumeScheduled = false;
    } else if (n is ScrollEndNotification) {
      if (_userDragging && !_resumeScheduled) {
        _resumeScheduled = true;
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _userDragging = false;
          _resumeScheduled = false;
          _lastTick = Duration.zero;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return SizedBox(height: widget.height);

    final total = widget.itemCount * _copies;
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          _onScrollNotification(n);
          return false;
        },
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: widget.padding,
          itemCount: total,
          itemExtent: widget.itemWidth,
          itemBuilder: (context, index) {
            final real = index % widget.itemCount;
            return widget.itemBuilder(context, real);
          },
        ),
      ),
    );
  }
}
