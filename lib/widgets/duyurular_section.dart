import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../data/duyuru_data.dart';
import '../duyuru_store.dart';
import '../meto_theme.dart';
import '../services/r2_storage_service.dart';
import 'instagram_embed.dart';
import 'story_marquee.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';

/// Ana sayfa: disclaimer altı / hastalıklar üstü — story tarzı duyurular.
class DuyurularSection extends StatefulWidget {
  const DuyurularSection({
    super.key,
    required this.userEmail,
  });

  final String userEmail;

  @override
  State<DuyurularSection> createState() => _DuyurularSectionState();
}

class _DuyurularSectionState extends State<DuyurularSection> {
  List<DuyuruItem> _items = const [];
  Set<int> _seen = {};
  bool _loading = true;
  bool _popupChecked = false;
  List<DuyuruItem> _stripItems = const [];
  String _stripVersion = '';

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  List<DuyuruItem> get _sorted => sortDuyurular(_items, _seen);

  void _syncStripCache() {
    final sorted = _sorted.where((d) => !d.isPopup).toList();
    final visible =
        _isAdmin ? sorted.where((d) => d.isActive).toList() : sorted;
    final version = visible
        .map(
          (d) =>
              '${d.id}|${d.imageUrl.hashCode}|${d.title.hashCode}|${_seen.contains(d.id)}',
        )
        .join(';');
    _stripItems = visible;
    _stripVersion = version;
  }

  @override
  void initState() {
    super.initState();
    // Önbellek varsa anında göster; arka planda sessiz yenile.
    final cached = cachedDuyurular;
    if (cached != null) {
      _items = cached;
      _loading = false;
      _syncStripCache();
      // Okundu bilgisi prefs'ten gelsin (sıralama doğru kalsın)
      loadSeenDuyuruIds(widget.userEmail).then((seen) async {
        if (!mounted) return;
        setState(() {
          _seen = seen;
          _syncStripCache();
        });
        await _maybeShowPopup();
      });
    }
    _reload(silent: cached != null);
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final items = await loadDuyurular(
      forceRefresh: !hasFreshDuyuruCache,
      viewerEmail: widget.userEmail,
    );
    final seen = await loadSeenDuyuruIds(widget.userEmail);
    if (!mounted) return;

    // Aynı veri ise setState yok → marquee / görseller flicker etmez
    final sameItems = items.length == _items.length &&
        items.asMap().entries.every((e) {
          final a = e.value;
          final b = _items[e.key];
          return a.id == b.id &&
              a.imageUrl == b.imageUrl &&
              a.title == b.title &&
              a.body == b.body &&
              a.isActive == b.isActive &&
              a.isPopup == b.isPopup &&
              a.publishAt == b.publishAt &&
              a.expiresAt == b.expiresAt;
        });
    final sameSeen =
        seen.length == _seen.length && seen.every(_seen.contains);
    if (sameItems && sameSeen && !_loading) {
      await _maybeShowPopup();
      return;
    }

    setState(() {
      _items = items;
      _seen = seen;
      _loading = false;
      _syncStripCache();
    });
    final popup = latestActivePopup(items);
    if (popup != null && !seen.contains(popup.id)) {
      _popupChecked = false;
    }
    await _maybeShowPopup();
  }

  List<DuyuruItem> get _visibleForStrip => _stripItems;

  Future<void> _maybeShowPopup() async {
    if (!mounted || _popupChecked) return;
    _popupChecked = true;
    final popup = latestActivePopup(_items);
    if (popup == null) return;
    if (_seen.contains(popup.id)) return;

    // Ana sayfa yerleşsin diye kısa gecikme
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DuyuruPopupDialog(
        item: popup,
        onClosed: () {
          markDuyuruSeen(email: widget.userEmail, id: popup.id);
          if (!mounted) return;
          setState(() {
            _seen = {..._seen, popup.id};
            _syncStripCache();
          });
        },
      ),
    );
  }

  Future<void> _openAdminForm({DuyuruItem? edit}) async {
    final result = await showModalBottomSheet<DuyuruItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminDuyuruSheet(
        adminEmail: widget.userEmail,
        edit: edit,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final rest = _items.where((d) => d.id != result.id).toList();
      _items = [result, ...rest];
      if (edit == null) {
        _seen = {..._seen}..remove(result.id);
      }
      _syncStripCache();
    });
  }

  Future<void> _openAdminManage() async {
    // Yönetim paneli için pasifler dahil taze liste
    final all = await loadDuyurular(
      forceRefresh: true,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    setState(() {
      _items = all;
      _syncStripCache();
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminManageSheet(
        items: List<DuyuruItem>.from(_items),
        onChanged: (next) {
          if (!mounted) return;
          setState(() {
            _items = next;
            _syncStripCache();
          });
        },
        onAdd: () async {
          Navigator.pop(ctx);
          await _openAdminForm();
        },
        onEdit: (item) async {
          Navigator.pop(ctx);
          await _openAdminForm(edit: item);
        },
        onDelete: (item) async {
          await deleteDuyuru(item.id);
          if (!mounted) return;
          setState(() {
            _items = _items.where((d) => d.id != item.id).toList();
            _syncStripCache();
          });
        },
        onToggleActive: (item) async {
          final updated = await updateDuyuru(
            id: item.id,
            title: item.title,
            body: item.body,
            imageUrl: item.imageUrl,
            sourceUrl: item.sourceUrl,
            isActive: !item.isActive,
            isPopup: item.isPopup,
            publishAt: item.publishAt ?? item.createdAt,
            expiresAt: item.expiresAt,
          );
          if (!mounted) return;
          setState(() {
            _items = [
              for (final d in _items)
                if (d.id == updated.id) updated else d,
            ];
            _syncStripCache();
          });
        },
      ),
    );
    // Manage sheet içindeki sil/toggle local state'i güncelledi; yeniden yükle
    await _reload(silent: true);
  }

  Future<void> _confirmDelete(DuyuruItem item) async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(
          'Duyuruyu sil?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: L10nText(
          '"${item.title}" kalıcı olarak silinecek.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteDuyuru(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((d) => d.id != item.id).toList();
        _seen = {..._seen}..remove(item.id);
        _syncStripCache();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Duyuru silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Silinemedi: $e')),
      );
    }
  }

  Future<void> _openViewer(DuyuruItem item) async {
    await markDuyuruSeen(email: widget.userEmail, id: item.id);
    if (!mounted) return;
    setState(() {
      _seen = {..._seen, item.id};
      _syncStripCache();
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return _DuyuruFullscreen(
          item: item,
          isAdmin: _isAdmin,
          onClose: () => Navigator.of(ctx).pop(),
          onDelete: () async {
            Navigator.of(ctx).pop();
            await _confirmDelete(item);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: L10nText(
                    'Güncel Duyurular & Haberler',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (_isAdmin) ...[
                  IconButton(
                    tooltip: S.auto('Story yönetimi'),
                    onPressed: _openAdminManage,
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                      foregroundColor: MetoColors.primary,
                    ),
                    icon: const Icon(Icons.tune, size: 20),
                  ),
                  IconButton(
                    tooltip: S.auto('Duyuru ekle'),
                    onPressed: () => _openAdminForm(),
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                      foregroundColor: MetoColors.primary,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
                ],
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              height: 108,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_visibleForStrip.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetoColors.border),
                ),
                child: Text(
                  _isAdmin
                      ? 'Henüz aktif story yok. + veya Yönet ile ekleyin.'
                      : 'Şu an görüntülenecek duyuru yok.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ),
            )
          else
            StoryMarquee(
              height: 112,
              itemWidth: 90,
              pixelsPerSecond: 30,
              itemCount: _visibleForStrip.length,
              contentVersion: _stripVersion,
              onItemTap: (i) {
                if (i < 0 || i >= _visibleForStrip.length) return;
                _openViewer(_visibleForStrip[i]);
              },
              onItemLongPress: _isAdmin
                  ? (i) {
                      if (i < 0 || i >= _visibleForStrip.length) return;
                      _openAdminForm(edit: _visibleForStrip[i]);
                    }
                  : null,
              itemBuilder: (context, i) {
                final item = _visibleForStrip[i];
                final seen = _seen.contains(item.id);
                return RepaintBoundary(
                  child: _StoryCircle(
                    key: ValueKey('story_${item.id}'),
                    item: item,
                    seen: seen,
                    isAdmin: false,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    super.key,
    required this.item,
    required this.seen,
    this.isAdmin = false,
  });

  final DuyuruItem item;
  final bool seen;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: seen
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              MetoColors.primary,
                              Color(0xFF2F9B6A),
                              MetoColors.accentGold,
                            ],
                          ),
                    color: seen ? const Color(0xFFCBD5E1) : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: MetoColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: item.isInstagramEmbed
                          ? const _InstagramStoryThumb(size: 58)
                          : _DuyuruImage(
                              source: item.imageUrl,
                              width: 58,
                              height: 58,
                            ),
                    ),
                  ),
                ),
                if (isAdmin)
                  const Positioned(
                    top: -2,
                    right: -2,
                    child: Material(
                      color: Color(0xFFDC2626),
                      shape: CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (item.title.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              L10nText(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: seen
                      ? MetoColors.mutedFg
                      : MetoColors.foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// data:image ve network görselleri için basit bellek önbelleği.
final Map<String, Uint8List> _duyuruMemoryImageCache = {};
const int _duyuruMemoryImageCacheMax = 40;

Uint8List? _cachedDataImageBytes(String src) {
  final hit = _duyuruMemoryImageCache[src];
  if (hit != null) return hit;
  try {
    final b64 = src.contains(',') ? src.split(',').last : src;
    final bytes = base64Decode(b64);
    if (_duyuruMemoryImageCache.length >= _duyuruMemoryImageCacheMax) {
      _duyuruMemoryImageCache.remove(_duyuruMemoryImageCache.keys.first);
    }
    _duyuruMemoryImageCache[src] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class _DuyuruImage extends StatelessWidget {
  const _DuyuruImage({
    required this.source,
    this.width,
    this.height,
  });

  final String source;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final src = source.trim();
    Widget fallback() => ColoredBox(
          color: MetoColors.muted,
          child: SizedBox(
            width: width,
            height: height,
            child: const Icon(
              Icons.campaign_outlined,
              color: MetoColors.primary,
            ),
          ),
        );

    if (src.isEmpty) return fallback();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null ? (width! * dpr).round() : null;
    final cacheH = height != null ? (height! * dpr).round() : null;

    if (src.startsWith('data:image')) {
      final bytes = _cachedDataImageBytes(src);
      if (bytes == null) return fallback();
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return ColoredBox(
            color: MetoColors.muted,
            child: SizedBox(width: width, height: height),
          );
        },
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return Image.asset(
      src,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}

class _InstagramStoryThumb extends StatelessWidget {
  const _InstagramStoryThumb({this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
            Color(0xFF515BD4),
          ],
        ),
      ),
      child: Icon(
        Icons.camera_alt_outlined,
        color: Colors.white.withValues(alpha: 0.95),
        size: size * 0.42,
      ),
    );
  }
}

class _DuyuruFullscreen extends StatefulWidget {
  const _DuyuruFullscreen({
    required this.item,
    required this.onClose,
    this.isAdmin = false,
    this.onDelete,
  });

  final DuyuruItem item;
  final VoidCallback onClose;
  final bool isAdmin;
  final VoidCallback? onDelete;

  @override
  State<_DuyuruFullscreen> createState() => _DuyuruFullscreenState();
}

class _DuyuruFullscreenState extends State<_DuyuruFullscreen> {
  double _dragY = 0;

  DuyuruItem get item => widget.item;
  bool get isAdmin => widget.isAdmin;
  VoidCallback get onClose => widget.onClose;
  VoidCallback? get onDelete => widget.onDelete;

  Future<void> _openSource(BuildContext context) async {
    final raw = item.sourceUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bağlantı açılamadı.')),
      );
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragY = (_dragY + details.delta.dy).clamp(0.0, 480.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragY > 100 || velocity > 650) {
      onClose();
      return;
    }
    setState(() => _dragY = 0);
  }

  Widget _closeChrome({required bool dark}) {
    final fg = dark ? Colors.white : MetoColors.foreground;
    final btnBg = dark ? Colors.black54 : MetoColors.muted.withValues(alpha: 0.85);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        color: dark ? const Color(0xFF0F172A) : MetoColors.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  L10nText(
                    'Aşağı sürükleyerek kapat',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin && onDelete != null) ...[
              Material(
                color: const Color(0xCCDC2626),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: S.auto('Sil'),
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Material(
              color: btnBg,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: S.auto('Kapat'),
                onPressed: onClose,
                icon: Icon(Icons.close, color: fg, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim();
    final body = item.body.trim();
    final ig = item.isInstagramEmbed;
    final hasText = !ig && (title.isNotEmpty || body.isNotEmpty);
    final screenH = MediaQuery.sizeOf(context).height;
    final dragOpacity = (1 - (_dragY / 320)).clamp(0.35, 1.0);

    final card = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ig ? 440 : 520,
        maxHeight: screenH * 0.92,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        height: ig
            ? screenH * 0.88
            : (hasText ? screenH * 0.85 : screenH * 0.55),
        decoration: BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // Platform view (Instagram iframe) clip ile bozulmasın.
        clipBehavior: ig ? Clip.hardEdge : Clip.antiAlias,
        child: ig
            ? Column(
                children: [
                  // X + sürükleme: iframe DIŞINDA (web'de iframe üstündeki Flutter butonları tıklanmaz).
                  _closeChrome(dark: true),
                  Expanded(
                    child: InstagramEmbedView(
                      pageUrl:
                          item.instagramUrl ?? item.sourceUrl?.trim() ?? '',
                      embedUrl: instagramEmbedUrl(
                        item.instagramUrl ?? item.sourceUrl,
                      ),
                      initialVideoUrl: item.playableVideoUrl,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    flex: hasText ? 5 : 1,
                    child: _fullscreenImageStack(context),
                  ),
                  if (hasText)
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: MetoColors.foreground,
                                  height: 1.25,
                                ),
                              ),
                            if (title.isNotEmpty && body.isNotEmpty)
                              const SizedBox(height: 12),
                            if (body.isNotEmpty)
                              Text(
                                body,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: MetoColors.mutedFg,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (item.hasSource)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openSource(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: MetoColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: L10nText(
                            'Haberin Kaynağına Git / Detaylı Bilgi',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (hasText)
                    const SizedBox(height: 8),
                ],
              ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Opacity(
          opacity: dragOpacity,
          child: Transform.translate(
            offset: Offset(0, _dragY),
            child: ig
                ? GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    behavior: HitTestBehavior.deferToChild,
                    child: Center(child: card),
                  )
                : Dismissible(
                    key: ValueKey('duyuru_fs_${item.id}'),
                    direction: DismissDirection.down,
                    onDismissed: (_) => onClose(),
                    child: Center(child: card),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fullscreenImageStack(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: _DuyuruImage(source: item.imageUrl),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin && onDelete != null) ...[
                Material(
                  color: const Color(0xCCDC2626),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: S.auto('Sil'),
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: S.auto('Kapat'),
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(999),
            ),
            child: L10nText(
              'Aşağı kaydırarak kapat',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _DuyuruKind { haber, popup, instagram }

/// Ana sayfa ortasında gösterilen pop-up duyuru (5 sn otomatik / X ile kapat).
class _DuyuruPopupDialog extends StatefulWidget {
  const _DuyuruPopupDialog({
    required this.item,
    required this.onClosed,
  });

  final DuyuruItem item;
  final VoidCallback onClosed;

  @override
  State<_DuyuruPopupDialog> createState() => _DuyuruPopupDialogState();
}

class _DuyuruPopupDialogState extends State<_DuyuruPopupDialog> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 5), _close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    widget.onClosed();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.5;
    final item = widget.item;
    final title = item.title.trim();
    final body = item.body.trim();
    final hasText = title.isNotEmpty || body.isNotEmpty;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: h,
          width: MediaQuery.sizeOf(context).width * 0.88,
          constraints: const BoxConstraints(maxWidth: 420),
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
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!hasText)
                Positioned.fill(
                  child: _DuyuruImage(source: item.imageUrl),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: body.isEmpty && title.isNotEmpty ? 7 : 5,
                      child: SizedBox.expand(
                        child: _DuyuruImage(source: item.imageUrl),
                      ),
                    ),
                    if (hasText)
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              if (title.isNotEmpty && body.isNotEmpty)
                                const SizedBox(height: 8),
                              if (body.isNotEmpty)
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      body,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        color: MetoColors.mutedFg,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: S.auto('Kapat'),
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDuyuruSheet extends StatefulWidget {
  const _AdminDuyuruSheet({
    required this.adminEmail,
    this.edit,
  });

  final String adminEmail;
  final DuyuruItem? edit;

  @override
  State<_AdminDuyuruSheet> createState() => _AdminDuyuruSheetState();
}

class _AdminDuyuruSheetState extends State<_AdminDuyuruSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sourceUrl;
  Uint8List? _pickedBytes;
  bool _isActive = true;
  bool _isPopup = false;
  bool _isInstagram = false;
  bool _saving = false;
  late DateTime _publishAt;
  DateTime? _expiresAt;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _imageUrl = TextEditingController(
      text: (e != null && e.isInstagramEmbed) ? '' : (e?.imageUrl ?? ''),
    );
    _sourceUrl = TextEditingController(text: e?.sourceUrl ?? '');
    _isActive = e?.isActive ?? true;
    _isPopup = e?.isPopup ?? false;
    _isInstagram = e?.isInstagramEmbed ?? false;
    _publishAt = e?.publishAt ?? e?.createdAt ?? DateTime.now();
    _expiresAt = e?.expiresAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _imageUrl.clear();
    });
  }

  Future<String> _resolveImagePayload() async {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      // Push için https URL gerekir — önce R2'ye yükle
      try {
        return await R2StorageService.uploadBytes(
          bytes: _pickedBytes!,
          fileName:
              'duyuru_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
        );
      } catch (_) {
        final b64 = base64Encode(_pickedBytes!);
        return 'data:image/jpeg;base64,$b64';
      }
    }
    return _imageUrl.text.trim();
  }

  Future<void> _pickPublishAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _publishAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishAt),
    );
    if (!mounted) return;
    setState(() {
      _publishAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _publishAt.hour,
        time?.minute ?? _publishAt.minute,
      );
    });
  }

  Future<void> _pickExpiresAt() async {
    final initial = _expiresAt ?? _publishAt.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final src = _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim();

    if (_expiresAt != null && !_expiresAt!.isAfter(_publishAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Bitiş tarihi, başlangıç tarihinden sonra olmalı.'),
        ),
      );
      return;
    }

    String image;
    if (_isInstagram) {
      if (normalizeInstagramUrl(src) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: L10nText(
              'Geçerli Instagram gönderi/reel/hikaye linki yapıştırın.',
            ),
          ),
        );
        return;
      }
      // DB'ye yalnız marker; video istemci tarafında çözülür / oynatılır.
      image = kInstagramEmbedMarker;
    } else {
      image = await _resolveImagePayload();
      if (image.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: L10nText('Görsel yükleyin veya URL girin.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final DuyuruItem item;
      if (_isInstagram && !_isEdit) {
        item = await addInstagramStoryLink(
          instagramUrl: src!,
          title: title,
          adminEmail: widget.adminEmail,
          isActive: _isActive,
          publishAt: _publishAt,
          expiresAt: _expiresAt,
        );
      } else if (_isEdit) {
        item = await updateDuyuru(
          id: widget.edit!.id,
          title: title.isEmpty && _isInstagram ? 'Instagram' : title,
          body: _isInstagram ? '' : body,
          imageUrl: image,
          sourceUrl: src,
          isActive: _isActive,
          isPopup: _isInstagram ? false : _isPopup,
          publishAt: _publishAt,
          expiresAt: _expiresAt,
        );
      } else {
        item = await addDuyuru(
          title: title.isEmpty && _isInstagram ? 'Instagram' : title,
          body: _isInstagram ? '' : body,
          imageUrl: image,
          sourceUrl: src,
          adminEmail: widget.adminEmail,
          isActive: _isActive,
          isPopup: _isInstagram ? false : _isPopup,
          publishAt: _publishAt,
          expiresAt: _expiresAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('duyurular') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema')
                ? 'Tablo yok. duyurular.sql / duyurular_schedule.sql çalıştırın.'
                : 'Kaydedilemedi: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isEdit ? 'Duyuru düzenle' : 'Yeni Duyuru / Haber',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 14),
              L10nText(
                'İçerik türü',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 6),
              RadioGroup<_DuyuruKind>(
                groupValue: _isInstagram
                    ? _DuyuruKind.instagram
                    : (_isPopup ? _DuyuruKind.popup : _DuyuruKind.haber),
                onChanged: (v) {
                  if (_saving || v == null) return;
                  setState(() {
                    _isInstagram = v == _DuyuruKind.instagram;
                    _isPopup = v == _DuyuruKind.popup;
                    if (_isInstagram) {
                      _pickedBytes = null;
                      _imageUrl.clear();
                    }
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<_DuyuruKind>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: L10nText(
                        'Güncel Haber Ekle',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: L10nText(
                        'Yatay listede görünür (is_popup = false)',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      value: _DuyuruKind.haber,
                      activeColor: MetoColors.primary,
                    ),
                    RadioListTile<_DuyuruKind>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: L10nText(
                        'Pop-up Haber Ekle',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: L10nText(
                        'Ana sayfada otomatik pop-up (is_popup = true)',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      value: _DuyuruKind.popup,
                      activeColor: MetoColors.primary,
                    ),
                    RadioListTile<_DuyuruKind>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: L10nText(
                        'Instagram Story / Gönderi',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: L10nText(
                        'Sadece link — görsel/video DB\'ye yüklenmez',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      value: _DuyuruKind.instagram,
                      activeColor: MetoColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_isInstagram) ...[
                TextField(
                  controller: _sourceUrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: S.auto('Instagram linki (yalnızca URL)'),
                    hintText:
                        'https://www.instagram.com/reel/... veya /p/...',
                    border: OutlineInputBorder(),
                    helperText: S.auto('Görsel/video sunucuya yüklenmez. Gönderi/Reel Instagram üzerinden oynar; geçici Stories Instagram\'da açılır.'),
                    helperMaxLines: 4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: S.auto('Kısa liste başlığı (opsiyonel)'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
              L10nText(
                'Dairesel görsel',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _pickedBytes != null
                          ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                          : _DuyuruImage(
                              source: _imageUrl.text,
                              width: 64,
                              height: 64,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const L10nText('Galeriden yükle'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrl,
                enabled: !_saving && _pickedBytes == null,
                decoration: InputDecoration(
                  hintText: S.auto('veya görsel URL (https://...)'),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_saving,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: S.auto('Kısa liste başlığı'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                enabled: !_saving,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: S.auto('Tam ekran detay metni'),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sourceUrl,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: S.auto('Hedef link / kaynak (target_link)'),
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: L10nText(
                  'İlan başlangıç tarihi',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _fmtDateTime(_publishAt),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                trailing: IconButton(
                  tooltip: S.auto('Tarih seç'),
                  onPressed: _saving ? null : _pickPublishAt,
                  icon: const Icon(Icons.edit_calendar_outlined),
                ),
                onTap: _saving ? null : _pickPublishAt,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: L10nText(
                  'İlan bitiş tarihi',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _expiresAt == null
                      ? 'Süresiz (bitiş yok)'
                      : _fmtDateTime(_expiresAt!),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiresAt != null)
                      IconButton(
                        tooltip: S.auto('Bitişi kaldır'),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _expiresAt = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: S.auto('Tarih seç'),
                      onPressed: _saving ? null : _pickExpiresAt,
                      icon: const Icon(Icons.edit_calendar_outlined),
                    ),
                  ],
                ),
                onTap: _saving ? null : _pickExpiresAt,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: L10nText(
                  'Aktif (is_active)',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: L10nText(
                  'Kapalıysa normal kullanıcılar görmez.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
                value: _isActive,
                activeThumbColor: MetoColors.primary,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Güncelle' : 'Kaydet',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminManageSheet extends StatefulWidget {
  const _AdminManageSheet({
    required this.items,
    required this.onChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final List<DuyuruItem> items;
  final ValueChanged<List<DuyuruItem>> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<DuyuruItem> onEdit;
  final Future<void> Function(DuyuruItem item) onDelete;
  final Future<void> Function(DuyuruItem item) onToggleActive;

  @override
  State<_AdminManageSheet> createState() => _AdminManageSheetState();
}

class _AdminManageSheetState extends State<_AdminManageSheet> {
  late List<DuyuruItem> _items;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _items = List<DuyuruItem>.from(widget.items);
  }

  String _shortDt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _emit(List<DuyuruItem> next) {
    setState(() => _items = next);
    widget.onChanged(next);
  }

  Future<void> _toggle(DuyuruItem item) async {
    setState(() => _busyId = item.id);
    try {
      await widget.onToggleActive(item);
      _emit([
        for (final d in _items)
          if (d.id == item.id) d.copyWith(isActive: !d.isActive) else d,
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(DuyuruItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(
          'Story sil?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: L10nText(
          '"${item.title}" kalıcı olarak silinecek.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = item.id);
    try {
      await widget.onDelete(item);
      _emit(_items.where((d) => d.id != item.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MetoColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: L10nText(
                    'Story yönetimi',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const L10nText('Ekle'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: L10nText(
                      'Henüz story yok.',
                      style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final busy = _busyId == item.id;
                      return Material(
                        color: MetoColors.background,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                          child: Row(
                            children: [
                              ClipOval(
                                child: item.isInstagramEmbed
                                    ? const _InstagramStoryThumb(size: 48)
                                    : _DuyuruImage(
                                        source: item.imageUrl,
                                        width: 48,
                                        height: 48,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    L10nText(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (item.isInstagramEmbed)
                                          'Instagram'
                                        else if (item.isPopup)
                                          'Pop-up'
                                        else
                                          'Haber',
                                        item.isActive ? 'Aktif' : 'Pasif',
                                        if (!item.isVisibleNow()) 'Zamanlı',
                                      ].join(' · '),
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: item.isActive
                                            ? MetoColors.primary
                                            : MetoColors.mutedFg,
                                      ),
                                    ),
                                    if (item.publishAt != null ||
                                        item.expiresAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (item.publishAt != null)
                                            'Baş: ${_shortDt(item.publishAt!)}',
                                          if (item.expiresAt != null)
                                            'Bit: ${_shortDt(item.expiresAt!)}'
                                          else
                                            'Bit: süresiz',
                                        ].join(' · '),
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          color: MetoColors.mutedFg,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else ...[
                                IconButton(
                                  tooltip: item.isActive
                                      ? 'Pasife al'
                                      : 'Aktif et',
                                  onPressed: () => _toggle(item),
                                  icon: Icon(
                                    item.isActive
                                        ? Icons.visibility
                                        : Icons.visibility_off_outlined,
                                    color: item.isActive
                                        ? MetoColors.primary
                                        : MetoColors.mutedFg,
                                  ),
                                ),
                                IconButton(
                                  tooltip: S.auto('Düzenle'),
                                  onPressed: () => widget.onEdit(item),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: S.auto('Sil'),
                                  onPressed: () => _delete(item),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
