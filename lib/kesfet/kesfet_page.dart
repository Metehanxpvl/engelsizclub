import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../guest_limit_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'kesfet_models.dart';
import 'kesfet_player.dart';
import 'kesfet_related.dart';
import 'kesfet_store.dart';
import 'kesfet_web_pointers.dart';

class KesfetPage extends StatefulWidget {
  const KesfetPage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.isGuest,
    required this.isTabActive,
    this.onRequireLogin,
    this.onOpenAdmin,
  });

  final String userEmail;
  final String userName;
  final bool isGuest;
  final bool isTabActive;
  final VoidCallback? onRequireLogin;
  final VoidCallback? onOpenAdmin;

  @override
  State<KesfetPage> createState() => _KesfetPageState();
}

class _KesfetPageState extends State<KesfetPage> with WidgetsBindingObserver {
  final _store = KesfetStore.instance;
  final _pageCtrl = PageController();
  final _playback = KesfetPlayback();
  final _focus = FocusNode();
  List<KesfetVideo> _videos = const [];
  bool _loading = true;
  String? _error;
  int _index = 0;
  DateTime? _lastWheel;
  final _viewed = <String>{};
  bool _wrapping = false;
  Timer? _guestTimer;
  DateTime? _guestSegmentStart;
  bool _quotaExhausted = false;
  bool _guestQuotaReady = false;

  bool get _guestLimited =>
      widget.isGuest && !isAppAdmin(widget.userEmail);

  bool get _kesfetSurfaceActive {
    if (!widget.isTabActive || _quotaExhausted) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _guestQuotaReady = !_guestLimited;
    unawaited(_reload());
    unawaited(_bootstrapGuestQuota());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWebPointers();
    _syncGuestTimer();
  }

  @override
  void didUpdateWidget(covariant KesfetPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest && !widget.isGuest) {
      _guestTimer?.cancel();
      _guestTimer = null;
      _guestSegmentStart = null;
      _guestQuotaReady = true;
      if (_quotaExhausted) {
        setState(() => _quotaExhausted = false);
      }
    }
    if (widget.isTabActive && _videos.isNotEmpty && !_quotaExhausted) {
      unawaited(_maybeRecordView(_index));
      _focus.requestFocus();
    }
    _syncWebPointers();
    _syncGuestTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncGuestTimer();
      return;
    }
    unawaited(_flushGuestSegment());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guestTimer?.cancel();
    final start = _guestSegmentStart;
    _guestSegmentStart = null;
    if (start != null && _guestLimited) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (ms > 0) unawaited(GuestLimitStore.addKesfetUsedMs(ms));
    }
    setKesfetIframePointerPassthrough(false);
    _focus.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _syncWebPointers() {
    final top = ModalRoute.of(context)?.isCurrent ?? true;
    setKesfetIframePointerPassthrough(
      widget.isTabActive &&
          top &&
          !_loading &&
          _videos.isNotEmpty &&
          !_quotaExhausted,
    );
  }

  Future<void> _bootstrapGuestQuota() async {
    if (!_guestLimited) {
      if (mounted && !_guestQuotaReady) {
        setState(() => _guestQuotaReady = true);
      }
      return;
    }
    final left = await GuestLimitStore.kesfetRemainingMs();
    if (!mounted) return;
    _guestQuotaReady = true;
    if (left <= 0) {
      _expireGuestQuota();
      return;
    }
    if (mounted) setState(() {});
    _syncGuestTimer();
  }

  void _syncGuestTimer() {
    if (!_guestLimited || _quotaExhausted || !_kesfetSurfaceActive) {
      unawaited(_flushGuestSegment());
      _guestTimer?.cancel();
      _guestTimer = null;
      return;
    }
    _guestSegmentStart ??= DateTime.now();
    _guestTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickGuestQuota());
    });
  }

  Future<void> _flushGuestSegment() async {
    final start = _guestSegmentStart;
    _guestSegmentStart = null;
    if (start == null || !_guestLimited) return;
    final ms = DateTime.now().difference(start).inMilliseconds;
    if (ms <= 0) return;
    final used = await GuestLimitStore.addKesfetUsedMs(ms);
    if (!mounted) return;
    if (used >= GuestLimitStore.kesfetTimedAccess.inMilliseconds) {
      _expireGuestQuota();
    }
  }

  Future<void> _tickGuestQuota() async {
    if (!mounted || !_guestLimited || _quotaExhausted) return;
    if (!_kesfetSurfaceActive) {
      await _flushGuestSegment();
      return;
    }
    _guestSegmentStart ??= DateTime.now();
    final start = _guestSegmentStart!;
    final ms = DateTime.now().difference(start).inMilliseconds;
    if (ms < 250) return;
    _guestSegmentStart = DateTime.now();
    final used = await GuestLimitStore.addKesfetUsedMs(ms);
    if (!mounted) return;
    if (used >= GuestLimitStore.kesfetTimedAccess.inMilliseconds) {
      _expireGuestQuota();
    }
  }

  void _expireGuestQuota() {
    if (_quotaExhausted) return;
    _guestTimer?.cancel();
    _guestTimer = null;
    _guestSegmentStart = null;
    unawaited(_playback.pause());
    setState(() => _quotaExhausted = true);
    _syncWebPointers();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _store.fetchApproved();
      if (!mounted) return;
      setState(() {
        _videos = list;
        _loading = false;
        _index = 0;
      });
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
      _syncWebPointers();
      if (widget.isTabActive && list.isNotEmpty) {
        unawaited(_maybeRecordView(0));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _videos = const [];
      });
      _syncWebPointers();
    }
  }

  Future<void> _maybeRecordView(int i) async {
    if (_quotaExhausted) return;
    if (i < 0 || i >= _videos.length) return;
    final id = _videos[i].id;
    if (_viewed.contains(id)) return;
    _viewed.add(id);
    await _store.recordView(id);
  }

  /// New permutation when the feed loops. Current clip is not first in the
  /// next pass so the same sequence does not restart.
  void _wrapWithNewShuffle() {
    if (_quotaExhausted || _wrapping || _videos.length < 2) return;
    _wrapping = true;
    final currentId = _videos[_index].id;
    final mixed = shuffleKesfetVideos(_videos);
    if (mixed.first.id == currentId) {
      final tmp = mixed[0];
      mixed[0] = mixed[1];
      mixed[1] = tmp;
    }
    setState(() {
      _videos = mixed;
      _index = 0;
    });
    if (_pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(0);
    }
    unawaited(_maybeRecordView(0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wrapping = false;
    });
  }

  void _goPage(int delta) {
    if (_quotaExhausted || !_pageCtrl.hasClients || _videos.isEmpty) return;
    if (delta > 0 && _index >= _videos.length - 1) {
      _wrapWithNewShuffle();
      return;
    }
    final next = (_index + delta).clamp(0, _videos.length - 1);
    if (next == _index) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pageCtrl.jumpToPage(next);
    } else {
      unawaited(
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _onWheel(PointerScrollEvent e) {
    final now = DateTime.now();
    if (_lastWheel != null &&
        now.difference(_lastWheel!) < const Duration(milliseconds: 380)) {
      return;
    }
    if (e.scrollDelta.dy > 28) {
      _lastWheel = now;
      _goPage(1);
    } else if (e.scrollDelta.dy < -28) {
      _lastWheel = now;
      _goPage(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _body(reduce),
          if (_quotaExhausted)
            _KesfetGuestLimitOverlay(
              onSignIn: widget.onRequireLogin ?? () {},
            ),
        ],
      ),
    );
  }

  Widget _body(bool reduce) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: MetoColors.primary),
      );
    }
    final adminOpen = isAppAdmin(widget.userEmail) ? widget.onOpenAdmin : null;
    if (_error != null && _videos.isEmpty) {
      final missing = _error!.toLowerCase().contains('kesfet_') ||
          _error!.toLowerCase().contains('does not exist') ||
          _error!.toLowerCase().contains('schema cache');
      return _EmptyKesfet(
        title: missing
            ? 'Keşfet henüz kurulmadı'
            : 'Videolar yüklenemedi',
        body: missing
            ? 'Yöneticinin Supabase SQL Editor’de kesfet_schema.sql, kesfet_scoring.sql, kesfet_seed.sql ve kesfet_admin.sql dosyalarını çalıştırması gerekir. Sahte video gösterilmez.'
            : _error!,
        onRetry: _reload,
        onOpenAdmin: adminOpen,
      );
    }
    if (_videos.isEmpty) {
      return _EmptyKesfet(
        title: 'Henüz onaylanmış video yok',
        body:
            'Engelsiz Club Keşfet’te yalnızca engellilik, sağlık, haklar ve aileyle ilgili, editör onaylı kısa videolar yer alır.\n\nEğlence veya alakasız içerik yayınlanmaz. Onaylanan videolar burada görünecek.',
        onRetry: _reload,
        onOpenAdmin: adminOpen,
      );
    }

    Widget pages = PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      // Web: iframe overlay owns the swipe. Android/iOS: native PageView.
      physics: kIsWeb
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: _videos.length,
      onPageChanged: (i) {
        setState(() => _index = i);
        unawaited(_maybeRecordView(i));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncWebPointers();
        });
      },
      itemBuilder: (context, i) {
        final v = _videos[i];
        final active = widget.isTabActive &&
            i == _index &&
            !_quotaExhausted &&
            (_guestQuotaReady || !_guestLimited);
        return _KesfetSlide(
          video: v,
          isActive: active,
          reduceMotion: reduce,
          pageController: _pageCtrl,
          itemCount: _videos.length,
          playback: _playback,
          onWheel: _onWheel,
          onWrapForward: _wrapWithNewShuffle,
          onRelated: v.hasRelatedArticle
              ? () => openKesfetRelated(
                    context,
                    video: v,
                    isGuest: widget.isGuest,
                    onRequireLogin: widget.onRequireLogin,
                  )
              : null,
        );
      },
    );
    if (!kIsWeb) {
      pages = NotificationListener<OverscrollNotification>(
        onNotification: (n) {
          if (n.overscroll > 20 && _index >= _videos.length - 1) {
            _wrapWithNewShuffle();
          }
          return false;
        },
        child: pages,
      );
    }
    final feed = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _goPage(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _goPage(-1),
        const SingleActivator(LogicalKeyboardKey.space): _playback.toggle,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: widget.isTabActive,
        child: pages,
      ),
    );
    if (adminOpen == null) return feed;
    return Stack(
      children: [
        feed,
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: const Color(0xCC111827),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: adminOpen,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: L10nText(
                  'Keşfet İçerikleri',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _KesfetGuestLimitOverlay extends StatelessWidget {
  const _KesfetGuestLimitOverlay({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final limit = GuestLimitStore.kesfetTimedAccess;
    final limitLabel = limit.inMinutes >= 1
        ? '${limit.inMinutes} dakika'
        : '${limit.inSeconds} saniye';
    return Semantics(
      namesRoute: true,
      label: 'Keşfet misafir süresi doldu',
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: MetoColors.primary,
                        ),
                        const SizedBox(height: 14),
                        L10nText(
                          'Keşfet için üye olun',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 10),
                        L10nText(
                          'Misafir olarak Keşfet’i en fazla $limitLabel izleyebilirsiniz. '
                          'Videolara devam etmek için giriş yapın veya üye olun.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onSignIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                              minimumSize: const Size(48, 48),
                            ),
                            child: const L10nText('Giriş yap / Üye ol'),
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
      ),
    );
  }
}

class _EmptyKesfet extends StatelessWidget {
  const _EmptyKesfet({
    required this.title,
    required this.body,
    required this.onRetry,
    this.onOpenAdmin,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;
  final VoidCallback? onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MetoColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline,
                    size: 56, color: MetoColors.primary),
                const SizedBox(height: 16),
                L10nText(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                L10nText(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const L10nText('Yenile'),
                ),
                if (onOpenAdmin != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenAdmin,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const L10nText('Keşfet İçerikleri'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KesfetSlide extends StatelessWidget {
  const _KesfetSlide({
    required this.video,
    required this.isActive,
    required this.reduceMotion,
    required this.pageController,
    required this.itemCount,
    required this.playback,
    required this.onWheel,
    this.onWrapForward,
    this.onRelated,
  });

  final KesfetVideo video;
  final bool isActive;
  final bool reduceMotion;
  final PageController pageController;
  final int itemCount;
  final KesfetPlayback playback;
  final void Function(PointerScrollEvent e) onWheel;
  final VoidCallback? onWrapForward;
  final VoidCallback? onRelated;

  @override
  Widget build(BuildContext context) {
    final channel = video.channelName.trim().isEmpty
        ? 'Kanal'
        : video.channelName.trim();
    // Live chrome sits on the video (not a band below). Player is always
    // IgnorePointer so the native WebView cannot steal Kaynak taps.
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: KesfetStage(
              videoId: video.youtubeVideoId,
              thumbnailUrl: video.resolvedThumb,
              isActive: isActive,
              reduceMotion: reduceMotion,
              title: video.title,
              playback: playback,
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0, 0.25, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _KesfetSwipeLayer(
              controller: pageController,
              itemCount: itemCount,
              reduceMotion: reduceMotion,
              onTogglePlay: playback.toggle,
              onWheel: onWheel,
              onWrapForward: onWrapForward,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (video.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          video.description.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    IgnorePointer(child: _MetaPill(video.categoryTitle)),
                    _MetaPill(
                      'Kaynak: YouTube · $channel',
                      onTap: () =>
                          unawaited(_openKesfetYoutube(context, video)),
                      semanticLabel:
                          'Kaynak: YouTube, orijinal videoyu tarayıcıda aç',
                    ),
                  ],
                ),
                if (onRelated != null) ...[
                  const SizedBox(height: 8),
                  _TextLink(
                    label: 'Detayları Engelsiz Club’da Gör',
                    onTap: onRelated!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen transparent layer: tap plays/pauses.
/// On web, vertical drag also changes video (iframe cannot host PageView).
/// On Android/iOS, PageView owns the swipe so YouTube's overlay cannot eat it.
class _KesfetSwipeLayer extends StatelessWidget {
  const _KesfetSwipeLayer({
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
        onVerticalDragUpdate: kIsWeb ? _onDragUpdate : null,
        onVerticalDragEnd: kIsWeb ? _onDragEnd : null,
        child: const ColoredBox(color: Color(0x00000000)),
      ),
    );
  }
}

Future<void> _openKesfetYoutube(BuildContext context, KesfetVideo video) async {
  final uri = Uri.tryParse(video.externalYoutubeUrl);
  if (uri == null) return;
  Future<bool> open(LaunchMode mode) async {
    return launchUrl(
      uri,
      mode: mode,
      webOnlyWindowName: '_blank',
    );
  }

  try {
    var ok = await open(LaunchMode.externalApplication);
    if (!ok) ok = await open(LaunchMode.platformDefault);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YouTube açılamadı')),
      );
    }
  } catch (_) {
    try {
      final ok = await open(LaunchMode.platformDefault);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube açılamadı')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube açılamadı')),
        );
      }
    }
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(this.text, {this.onTap, this.semanticLabel});
  final String text;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          decoration:
              onTap == null ? TextDecoration.none : TextDecoration.underline,
          decorationColor: Colors.white,
        ),
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      link: true,
      label: semanticLabel ?? text,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: pill,
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: MetoColors.primary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
