import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_config.dart';
import 'bildirim_store.dart';
import 'home_page.dart';
import 'cocuk_profil_store.dart';
import 'data/centers_data.dart' show kAllIlceler;
import 'data/ilanlar_data.dart' show SohbetKisi;
import 'data/turkish_cities_data.dart';
import 'ilan_store.dart';
import 'kredi_store.dart';
import 'kullanici_profil_store.dart';
import 'meto_theme.dart';
import 'pages/forum_page.dart';
import 'pages/haklar_page.dart';
import 'pages/ilanlar_page.dart';
import 'pages/kartlar_page.dart';
import 'pages/merkezler_page.dart';
import 'presence_store.dart';
import 'profil_foto_store.dart';
import 'services/play_billing_service.dart';
import 'sohbet_store.dart';
import 'user_cloud_store.dart';

enum MetoTab { home, merkezler, ilanlar, forum, mesajlar, haklar, kartlar }

enum _KrediStep { paket, odeme }

typedef _KrediPaket = ({
  int adet,
  String fiyat,
  String birim,
  String desc,
  bool popular,
});

/// Figma Make `App` shell — bottom nav + profil paneli.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.user,
    required this.onLogout,
    this.onUserChanged,
  });

  final AuthUser user;
  final VoidCallback onLogout;
  final ValueChanged<AuthUser>? onUserChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MetoTab _activeTab = MetoTab.home;
  late final PageController _tabPageController;
  bool _showProfilPanel = false;
  bool _krediSatin = false;
  bool _showCocukProfil = false;
  bool _showIlanlarim = false;
  bool _showKullaniciProfil = false;
  bool _showKaydedilenler = false;
  bool _showBildirimler = false;
  /// Profil panelini aşağı kaydırarak kapatırken biriken dikey ofset.
  double _profilDragY = 0;
  CocukProfil _cocukProfil = const CocukProfil();
  KullaniciProfil _kullaniciProfil = const KullaniciProfil();
  List<FavoriIlanRef> _favoriler = const [];
  String? _openIlanKind;
  int? _openIlanId;
  int _openIlanToken = 0;
  String? _openEditIlanKind;
  int? _openEditIlanId;
  int _openEditIlanToken = 0;
  BildirimAyarlari _bildirimler = const BildirimAyarlari();
  String? _profilFoto;
  late int _userKredi;
  bool _krediHosBonusGosterildi = false;
  int _ilanlarUnread = 0;

  _KrediStep _krediStep = _KrediStep.paket;
  _KrediPaket? _seciliPaket;
  bool _odemeYukleniyor = false;

  /// Logoya basınca ana sayfayı sıfırdan kurmak için artan sayaç.
  int _homeRefreshToken = 0;

  // Mesajlarım sekmesi
  List<SohbetOzet> _sohbetOzetleri = const [];
  List<AppBildirim> _bildirimlerInbox = const [];
  Map<String, bool> _peerOnline = const {};
  Timer? _sohbetTimer;
  RealtimeChannel? _inboxChannel;

  int get _sohbetUnreadCount =>
      _sohbetOzetleri.fold<int>(0, (s, o) => s + o.unreadCount);

  bool get _yeniMesajVar => _sohbetUnreadCount > 0;

  int get _mesajUnreadCount {
    // Mesaj bildirimleri sohbet sayacına yansıdığı için burada yalnız
    // mesaj dışı (teklif vb.) bildirimler eklenir.
    final digerBildirim =
        _bildirimlerInbox.where((b) => !b.read && !b.isMesaj).length;
    return (digerBildirim + _sohbetUnreadCount).clamp(0, 99);
  }

  int get _teklifBildirimUnread =>
      _bildirimlerInbox.where((b) => !b.read && b.isTeklif).length;

  List<AppBildirim> _tekliflerForIlan(int ilanId) => _bildirimlerInbox
      .where((b) => b.isTeklif && b.ilanId == ilanId)
      .toList();

  static const List<_KrediPaket> _krediPaketleri = [
    (
      adet: 1,
      fiyat: '₺49,90',
      birim: '₺49,90/puan',
      desc: '1 teklif = 1 puan',
      popular: false,
    ),
    (
      adet: 5,
      fiyat: '₺199,90',
      birim: '₺39,98/puan',
      desc: 'En çok tercih edilen · %20 indirim',
      popular: true,
    ),
    (
      adet: 10,
      fiyat: '₺349,90',
      birim: '₺34,99/puan',
      desc: 'Avantajlı paket · %30 indirim',
      popular: false,
    ),
  ];

  String get _role =>
      (widget.user.userType ?? 'aile').trim().toLowerCase();

  bool get _isProf => _role == 'uzman' || _role == 'bakici';
  bool get _isAileRole => !_isProf && !isAppAdmin(widget.user.email);
  bool get _canBuyKredi =>
      _isProf || _isAileRole || isAppAdmin(widget.user.email);
  String get _krediBirimLabel => _isAileRole ? 'iyilik puanı' : 'puan';
  String get _krediBirimLabelCap =>
      _isAileRole ? 'İyilik Puanı' : 'Puan';
  String get _krediYukleLabel =>
      _isAileRole ? 'İyilik Puanı Yükle' : 'Puan Yükle';

  String _paketFiyatLabel(_KrediPaket p) =>
      StoreBillingService.instance.storePriceForAdet(p.adet) ?? p.fiyat;

  String get _krediPrefsKey =>
      krediPrefsKeyFor(widget.user.email, fallback: widget.user.name);

  String get _welcomeDismissKey => '${_krediPrefsKey}_welcome_dismissed';

  @override
  void initState() {
    super.initState();
    _tabPageController = PageController(initialPage: MetoTab.home.index);
    // Herkese rolüne göre başlangıç · Admin: 10000
    _userKredi = startingKrediFor(widget.user.email, userType: widget.user.userType);
    _loadKredi();
    _loadUserCloud();
    _loadIlanlarVeFoto();
    _loadSohbetOzetleri();
    startPresenceHeartbeat();
    _inboxChannel = subscribeInboxRealtime(
      myEmail: widget.user.email,
      onChange: () {
        if (mounted) unawaited(_loadSohbetOzetleri());
      },
    );
    // Realtime yedek poll (ağ kopması / publication eksikse)
    _sohbetTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadSohbetOzetleri(),
    );
    unawaited(_initStoreBilling());
  }

  Future<void> _initStoreBilling() async {
    await StoreBillingService.instance.init(
      onPurchased: (purchase, adet) async {
        if (!mounted) return;
        setState(() => _userKredi += adet);
        await _saveKredi();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${StoreBillingService.instance.storeName} ödemesi alındı · +$adet $_krediBirimLabel',
            ),
          ),
        );
        setState(() {
          _krediStep = _KrediStep.paket;
          _krediSatin = false;
          _seciliPaket = null;
        });
      },
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  @override
  void dispose() {
    unawaited(StoreBillingService.instance.dispose());
    stopPresenceHeartbeat();
    _sohbetTimer?.cancel();
    unawaited(unsubscribeRealtime(_inboxChannel));
    _inboxChannel = null;
    _tabPageController.dispose();
    super.dispose();
  }

  /// Alt menü / kaydırma / bildirimlerden sekme değiştir.
  void _goToTab(MetoTab t, {bool animate = true}) {
    final changed = _activeTab != t;
    if (changed) {
      setState(() {
        _activeTab = t;
        if (t == MetoTab.ilanlar) _ilanlarUnread = 0;
      });
    }
    if (_tabPageController.hasClients) {
      final current = _tabPageController.page?.round() ?? _activeTab.index;
      if (current != t.index) {
        if (animate) {
          unawaited(
            _tabPageController.animateToPage(
              t.index,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            ),
          );
        } else {
          _tabPageController.jumpToPage(t.index);
        }
      }
    }
    if (t == MetoTab.ilanlar) {
      loadAllIlanlar(preferEmail: widget.user.email).then((_) {
        if (mounted) setState(() {});
      });
    }
    if (t == MetoTab.mesajlar) {
      _loadSohbetOzetleri();
    }
  }

  void _onTabPageChanged(int index) {
    if (index < 0 || index >= MetoTab.values.length) return;
    final t = MetoTab.values[index];
    if (_activeTab == t) return;
    setState(() {
      _activeTab = t;
      if (t == MetoTab.ilanlar) _ilanlarUnread = 0;
    });
    if (t == MetoTab.ilanlar) {
      loadAllIlanlar(preferEmail: widget.user.email).then((_) {
        if (mounted) setState(() {});
      });
    }
    if (t == MetoTab.mesajlar) {
      _loadSohbetOzetleri();
    }
  }

  Future<void> _loadSohbetOzetleri() async {
    unawaited(touchMyPresence());
    final results = await Future.wait([
      loadSohbetOzetleri(widget.user.email),
      loadBildirimler(),
    ]);
    if (!mounted) return;
    final ozetler = results[0] as List<SohbetOzet>;
    final bildirimler = results[1] as List<AppBildirim>;
    final merged = _mergeUnreadFromBildirim(ozetler, bildirimler);
    final online = await loadPresenceOnlineMap(
      merged.map((o) => o.peerEmail),
    );
    if (!mounted) return;
    setState(() {
      _sohbetOzetleri = merged;
      _bildirimlerInbox = bildirimler;
      _peerOnline = online;
    });
  }

  /// Okunmamış teklif/mesaj bildirimleri de sohbeti okunmadı sayar.
  List<SohbetOzet> _mergeUnreadFromBildirim(
    List<SohbetOzet> ozetler,
    List<AppBildirim> bildirimler,
  ) {
    final byKey = <String, int>{};
    for (final b in bildirimler) {
      if (b.read) continue;
      final key = b.sohbetKey;
      if (key == null || key.isEmpty) continue;
      byKey[key] = (byKey[key] ?? 0) + 1;
    }
    if (byKey.isEmpty) return ozetler;
    return [
      for (final o in ozetler)
        if ((byKey[o.sohbetKey] ?? 0) > o.unreadCount)
          SohbetOzet(
            sohbetKey: o.sohbetKey,
            peerEmail: o.peerEmail,
            lastMsg: o.lastMsg,
            lastTime: o.lastTime,
            unreadCount: byKey[o.sohbetKey]!,
            lastFromPeer: true,
          )
        else
          o,
    ];
  }

  Future<void> _markSohbetThreadOkundu(SohbetOzet o) async {
    await markSohbetMesajlariOkundu(o.sohbetKey);
    // Aynı sohbete ait mesaj bildirimlerini de okundu yap
    final related = _bildirimlerInbox
        .where((b) => !b.read && b.sohbetKey == o.sohbetKey)
        .toList();
    for (final b in related) {
      await markBildirimOkundu(b.id);
    }
    if (!mounted || related.isEmpty) return;
    final ids = related.map((b) => b.id).toSet();
    setState(() {
      _bildirimlerInbox = [
        for (final x in _bildirimlerInbox)
          if (ids.contains(x.id))
            AppBildirim(
              id: x.id,
              ownerEmail: x.ownerEmail,
              actorEmail: x.actorEmail,
              actorName: x.actorName,
              type: x.type,
              title: x.title,
              body: x.body,
              ilanId: x.ilanId,
              sohbetKey: x.sohbetKey,
              read: true,
              createdAt: x.createdAt,
            )
          else
            x,
      ];
    });
  }

  void _openSohbet(SohbetOzet o) {
    final display = o.peerEmail.contains('↔')
        ? o.peerEmail
        : o.peerEmail.split('@').first;
    final peerKey = o.peerEmail.trim().toLowerCase();
    final kisi = SohbetKisi(
      ad: display.isEmpty ? o.peerEmail : display,
      avatar: (display.isNotEmpty ? display.substring(0, 1) : '?').toUpperCase(),
      avatarColor: MetoColors.primary,
      isOnline: _peerOnline[peerKey] == true,
      peerEmail: o.peerEmail,
    );
    // Sohbet açılır açılmaz okundu — badge anında düşsün
    if (o.hasUnread) {
      setState(() {
        _sohbetOzetleri = [
          for (final x in _sohbetOzetleri)
            if (x.sohbetKey == o.sohbetKey)
              SohbetOzet(
                sohbetKey: x.sohbetKey,
                peerEmail: x.peerEmail,
                lastMsg: x.lastMsg,
                lastTime: x.lastTime,
                unreadCount: 0,
                lastFromPeer: x.lastFromPeer,
              )
            else
              x,
        ];
      });
      _markSohbetThreadOkundu(o);
    }
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: kisi,
          myEmail: widget.user.email,
          sohbetKey: o.sohbetKey,
        ),
      ),
    )
        .then((_) {
      _loadSohbetOzetleri();
    });
  }

  Future<bool> _confirmDeleteBildirim(AppBildirim b) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Bildirimi sil'),
        content: Text(
          b.body.isNotEmpty
              ? '"${b.body}" bildirimini silmek istiyor musunuz?'
              : 'Bu bildirimi silmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return false;
    try {
      await deleteBildirim(b.id);
      if (!mounted) return true;
      setState(() {
        _bildirimlerInbox =
            _bildirimlerInbox.where((x) => x.id != b.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirim silindi')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('policy') || e.toString().contains('42501')
                ? 'Silme yetkisi yok. bildirimler_delete.sql çalıştırın.'
                : 'Silinemedi: $e',
          ),
        ),
      );
      return false;
    }
  }

  Widget _bildirimSwipeDeleteBg({required bool alignStart}) {
    return Container(
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.only(
        left: alignStart ? 20 : 0,
        right: alignStart ? 0 : 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Future<bool> _confirmDeleteSohbet(SohbetOzet o) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Sohbeti sil'),
        content: Text(
          '${o.peerEmail.split('@').first} ile olan tüm mesajlar silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return false;
    try {
      await deleteSohbet(o.sohbetKey);
      if (!mounted) return true;
      setState(() {
        _sohbetOzetleri =
            _sohbetOzetleri.where((x) => x.sohbetKey != o.sohbetKey).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet silindi')),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('policy') || e.toString().contains('42501')
                  ? 'Silme yetkisi yok. sohbet_mesajlari_delete.sql çalıştırın.'
                  : 'Silinemedi: $e',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _openBildirim(AppBildirim b) async {
    if (!b.read) {
      await markBildirimOkundu(b.id);
      if (mounted) {
        setState(() {
          _bildirimlerInbox = [
            for (final x in _bildirimlerInbox)
              if (x.id == b.id)
                AppBildirim(
                  id: x.id,
                  ownerEmail: x.ownerEmail,
                  actorEmail: x.actorEmail,
                  actorName: x.actorName,
                  type: x.type,
                  title: x.title,
                  body: x.body,
                  ilanId: x.ilanId,
                  sohbetKey: x.sohbetKey,
                  read: true,
                  createdAt: x.createdAt,
                )
              else
                x,
          ];
        });
      }
    }

    if (b.isGorus) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(b.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.actorName.isNotEmpty
                      ? '${b.actorName} · ${b.actorEmail}'
                      : b.actorEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  b.body,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            if (b.actorEmail.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final name = b.actorName.isNotEmpty
                      ? b.actorName
                      : b.actorEmail.split('@').first;
                  final kisi = SohbetKisi(
                    ad: name.isEmpty ? b.actorEmail : name,
                    avatar: (name.isNotEmpty ? name.substring(0, 1) : '?')
                        .toUpperCase(),
                    avatarColor: MetoColors.primary,
                    isOnline:
                        _peerOnline[b.actorEmail.trim().toLowerCase()] == true,
                    peerEmail: b.actorEmail,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SohbetPage(
                        kisi: kisi,
                        myEmail: widget.user.email,
                      ),
                    ),
                  );
                },
                child: const Text('Yanıtla'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final name = b.actorName.isNotEmpty
        ? b.actorName
        : b.actorEmail.split('@').first;
    final kisi = SohbetKisi(
      ad: name.isEmpty ? b.actorEmail : name,
      avatar: (name.isNotEmpty ? name.substring(0, 1) : '?').toUpperCase(),
      avatarColor: MetoColors.primary,
      isOnline:
          _peerOnline[b.actorEmail.trim().toLowerCase()] == true,
      peerEmail: b.actorEmail,
      ilanId: b.ilanId,
    );
    if (!mounted) return;
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: kisi,
          myEmail: widget.user.email,
        ),
      ),
    )
        .then((_) {
      if (b.sohbetKey != null && b.sohbetKey!.isNotEmpty) {
        markSohbetMesajlariOkundu(b.sohbetKey!);
      }
      _loadSohbetOzetleri();
    });
  }

  Widget _buildMesajlarPage() {
    final list = _sohbetOzetleri;
    final bildirimler = _bildirimlerInbox;
    final unreadBildirim = bildirimler.where((b) => !b.read).length;
    final empty = list.isEmpty && bildirimler.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Mesajlarım',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              if (isAppAdmin(widget.user.email))
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MetoColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (unreadBildirim > 0)
                TextButton(
                  onPressed: () async {
                    await markAllBildirimlerOkundu();
                    await _loadSohbetOzetleri();
                  },
                  child: const Text('Tümünü okundu'),
                ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _loadSohbetOzetleri,
                icon: const Icon(Icons.refresh, color: MetoColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: empty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Henüz mesajınız yok.\nBir ilana teklif vererek sohbet başlatabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: MetoColors.mutedFg,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: MetoColors.primary,
                  onRefresh: _loadSohbetOzetleri,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      if (bildirimler.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Text(
                            'BİLDİRİMLER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ),
                        for (final b in bildirimler) ...[
                          Dismissible(
                            key: ValueKey('bildirim_${b.id}'),
                            direction: DismissDirection.horizontal,
                            background: _bildirimSwipeDeleteBg(alignStart: true),
                            secondaryBackground:
                                _bildirimSwipeDeleteBg(alignStart: false),
                            confirmDismiss: (_) => _confirmDeleteBildirim(b),
                            child: Material(
                              color: b.read
                                  ? MetoColors.card
                                  : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                onTap: () => _openBildirim(b),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: b.read
                                        ? MetoColors.border
                                        : const Color(0xFFFDBA74),
                                  ),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: b.read
                                      ? MetoColors.muted
                                      : (b.isMesaj
                                          ? MetoColors.primary
                                          : b.isGorus
                                              ? const Color(0xFF0EA5E9)
                                              : const Color(0xFFEF4444)),
                                  child: Icon(
                                    b.isMesaj
                                        ? Icons.chat_bubble_outline
                                        : b.isGorus
                                            ? Icons.feedback_outlined
                                            : Icons.campaign_outlined,
                                    color: b.read
                                        ? MetoColors.mutedFg
                                        : Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  b.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                                subtitle: Text(
                                  b.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MetoColors.mutedFg,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${b.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${b.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: MetoColors.mutedFg,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Sil',
                                      onPressed: () =>
                                          _confirmDeleteBildirim(b),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: MetoColors.mutedFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (list.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Text(
                            'SOHBETLER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ),
                      for (final o in list) ...[
                        Dismissible(
                          key: ValueKey(o.sohbetKey),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) => _confirmDeleteSohbet(o),
                          child: Material(
                            color: o.hasUnread
                                ? const Color(0xFFE8F5EF)
                                : MetoColors.card,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _openSohbet(o),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: o.hasUnread
                                        ? MetoColors.primary
                                        : MetoColors.border,
                                    width: o.hasUnread ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: o.hasUnread
                                              ? MetoColors.primary
                                              : MetoColors.primary
                                                  .withValues(alpha: 0.75),
                                          child: Text(
                                            o.peerEmail.isNotEmpty
                                                ? o.peerEmail
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -1,
                                          bottom: -1,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: (_peerOnline[o.peerEmail
                                                          .trim()
                                                          .toLowerCase()] ==
                                                      true)
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFEF4444),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.peerEmail.contains('↔')
                                                ? o.peerEmail
                                                : o.peerEmail.split('@').first,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: o.hasUnread
                                                  ? FontWeight.w900
                                                  : FontWeight.w500,
                                              color: o.hasUnread
                                                  ? const Color(0xFF111827)
                                                  : MetoColors.mutedFg,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            o.lastMsg,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: o.hasUnread
                                                  ? FontWeight.w800
                                                  : FontWeight.w400,
                                              color: o.hasUnread
                                                  ? const Color(0xFF111827)
                                                  : MetoColors.mutedFg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${o.lastTime.toLocal().hour.toString().padLeft(2, '0')}:${o.lastTime.toLocal().minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: o.hasUnread
                                                ? FontWeight.w800
                                                : FontWeight.w400,
                                            color: o.hasUnread
                                                ? MetoColors.primary
                                                : MetoColors.mutedFg,
                                          ),
                                        ),
                                        if (o.hasUnread) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                              minHeight: 20,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MetoColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              o.unreadCount > 99
                                                  ? '99+'
                                                  : '${o.unreadCount.clamp(1, 99)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _loadUserCloud() async {
    final cloud = await loadUserCloudProfile(widget.user.email);
    if (!mounted) return;
    setState(() {
      _kullaniciProfil = cloud.profil;
      _cocukProfil = cloud.cocuk;
      _profilFoto = cloud.photoData;
      _favoriler = cloud.favorites;
      _bildirimler = cloud.notifications;
    });
  }

  Future<void> _loadIlanlarVeFoto() async {
    await loadAllIlanlar(preferEmail: widget.user.email);
    // Foto _loadUserCloud ile gelir; burada sadece ilanları yenile.
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _persistIlanlar() async {
    await loadAllIlanlar(preferEmail: widget.user.email);
    if (mounted) setState(() {});
  }

  Uint8List? get _profilFotoBytes {
    final raw = _profilFoto;
    if (raw == null || raw.isEmpty) return null;
    try {
      var data = raw;
      if (data.contains(',')) data = data.split(',').last;
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickProfilFoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 55,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // ~200KB üstü ise daha agresif küçült (web localStorage / bulut limiti).
    var mime = file.mimeType ?? 'image/jpeg';
    var encoded = base64Encode(bytes);
    if (encoded.length > 220000 && mime != 'image/jpeg') {
      mime = 'image/jpeg';
    }
    final dataUrl = 'data:$mime;base64,$encoded';
    await upsertUserCloudProfile(
      email: widget.user.email,
      photoData: dataUrl,
    );
    await saveProfilFoto(widget.user.email, dataUrl);
    if (!mounted) return;
    setState(() => _profilFoto = dataUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil fotoğrafı kaydedildi ✅')),
    );
  }

  Future<void> _removeProfilFoto() async {
    await upsertUserCloudProfile(
      email: widget.user.email,
      clearPhoto: true,
    );
    await clearProfilFoto(widget.user.email);
    if (!mounted) return;
    setState(() => _profilFoto = null);
  }

  Future<void> _loadKredi() async {
    final prefs = await SharedPreferences.getInstance();
    final snap = await loadUserKredi(
      email: widget.user.email,
      userType: widget.user.userType,
    );
    if (mounted) {
      setState(() {
        _userKredi = snap.balance;
        _krediHosBonusGosterildi = _isProf
            ? (prefs.getBool(_welcomeDismissKey) ?? false)
            : true;
      });
    }

  }

  bool _roleSwitching = false;

  Future<void> _switchRole(String role) async {
    final next = role.trim().toLowerCase();
    if (next != 'aile' && next != 'uzman' && next != 'bakici') return;
    if (next == _role || _roleSwitching) return;

    setState(() => _roleSwitching = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final meta = <String, dynamic>{
        ...?user?.userMetadata,
        'user_type': next,
      };
      if (next == 'bakici') {
        meta['uzmanlik'] = meta['uzmanlik'] ?? 'Bakıcı';
      }
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: meta),
      );

      final updated = widget.user.copyWith(userType: next);
      widget.onUserChanged?.call(updated);

      // Aynı e-posta = aynı kredi havuzu (uzman ↔ bakıcı bağlı)
      await _loadKredi();

      if (!mounted) return;
      final label = switch (next) {
        'uzman' => 'Uzman',
        'bakici' => 'Bakıcı',
        _ => 'Aile',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == 'aile'
                ? 'Rol: $label. İlan verebilirsiniz; teklif yalnız 2. el ilanlarda.'
                : 'Rol: $label. Uzman ve bakıcı aynı puan bakiyesini kullanır · $_userKredi puan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rol değiştirilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _roleSwitching = false);
    }
  }

  Widget _buildRoleSwitcher() {
    const roles = <(String, String, String)>[
      ('aile', '👨‍👩‍👧', 'Aile'),
      ('uzman', '💼', 'Uzman'),
      ('bakici', '🤝', 'Bakıcı'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetoColors.muted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesap rolü',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _role == 'aile'
                ? 'İlan verebilirsiniz. Teklif yalnız 2. el ilanlarda.'
                : 'Uzman & bakıcı aynı puan bakiyesini paylaşır; teklifte 1 puan düşer.',
            style: TextStyle(
              fontSize: 11,
              color: MetoColors.mutedFg.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final r in roles) ...[
                if (r.$1 != roles.first.$1) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: _role == r.$1
                        ? MetoColors.primary
                        : MetoColors.card,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _roleSwitching ? null : () => _switchRole(r.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Column(
                          children: [
                            Text(r.$2, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(
                              r.$3,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _role == r.$1
                                    ? Colors.white
                                    : MetoColors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_roleSwitching) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Future<void> _saveKredi() async {
    await saveUserKredi(
      email: widget.user.email,
      balance: _userKredi,
      welcomeGiftGiven: true,
    );
  }

  /// Teklif için 1 kredi düş (buluta yazar).
  Future<bool> _harcaBirKredi() async {
    final next = await spendOneKredi(email: widget.user.email);
    if (next == null) return false;
    if (mounted) setState(() => _userKredi = next);
    return true;
  }

  void _resetKredi() {
    _krediSatin = false;
    _krediStep = _KrediStep.paket;
    _seciliPaket = null;
    _odemeYukleniyor = false;
  }

  String get _initials {
    final parts = widget.user.name.trim().split(RegExp(r'\s+'));
    final letters = parts.map((w) => w.isEmpty ? '' : w[0]).join();
    return letters.toUpperCase().substring(0, letters.length.clamp(0, 2));
  }

  Widget get _body {
    // Harita sekmesi KeepAlive ile canlı tutulur — her girişte yeniden
    // konum/merkez araması tetiklenmesin. Sağa/sola kaydırarak sekmeler arası geçiş.
    return PageView(
      controller: _tabPageController,
      // Mesajlar'da yatay kaydırma bildirim silmeye gitsin (sekme kaydırması kapalı).
      physics: _activeTab == MetoTab.mesajlar
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
      onPageChanged: _onTabPageChanged,
      children: [
        HomePage(key: ValueKey('home_$_homeRefreshToken')),
        const _KeepAliveTab(child: MerkezlerPage()),
        IlanlarPage(
          userKredi: _userKredi,
          userEmail: widget.user.email,
          userName: widget.user.name,
          userType: _role,
          onKrediHarca: _harcaBirKredi,
          onUnreadChange: (n) {
            if (_ilanlarUnread == n) return;
            setState(() => _ilanlarUnread = n);
          },
          onOpenKrediYukle: () => setState(() {
            _resetKredi();
            _showProfilPanel = true;
            _krediSatin = true;
          }),
          onIlanlarChanged: _persistIlanlar,
          openIlanKind: _openIlanKind,
          openIlanId: _openIlanId,
          openIlanToken: _openIlanToken,
          openEditIlanKind: _openEditIlanKind,
          openEditIlanId: _openEditIlanId,
          openEditIlanToken: _openEditIlanToken,
        ),
        ForumPage(
          userName: widget.user.name,
          userEmail: widget.user.email,
          userType: _role,
        ),
        _buildMesajlarPage(),
        const HaklarPage(),
        const KartlarPage(),
      ],
    );
  }

  /// Logo / uygulama adı → ana sayfaya dön ve içeriği yenile.
  void _goHomeAndRefresh() {
    // Açık detay sayfaları varsa kapat
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() {
      _activeTab = MetoTab.home;
      _homeRefreshToken++;
      _showProfilPanel = false;
      _showCocukProfil = false;
      _showIlanlarim = false;
      _showKullaniciProfil = false;
      _showKaydedilenler = false;
      _showBildirimler = false;
      _profilDragY = 0;
      _resetKredi();
    });
    if (_tabPageController.hasClients) {
      _tabPageController.jumpToPage(MetoTab.home.index);
    }
    _loadUserCloud();
    _loadIlanlarVeFoto();
    _loadSohbetOzetleri();
  }

  void _openProfilPanel() {
    _loadUserCloud();
    _loadSohbetOzetleri();
    setState(() {
      _profilDragY = 0;
      _resetKredi();
      _showProfilPanel = true;
    });
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı')),
      );
    }
  }

  void _showSosyalMedyaSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                const Text(
                  'Sosyal medya hesaplarımız',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Takip etmek için bir hesap seçin',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: MetoColors.border),
                  ),
                  leading: SvgPicture.asset(
                    'assets/images/instagram.svg',
                    width: 28,
                    height: 28,
                  ),
                  title: const Text(
                    'Instagram',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('@engelsizclub'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openExternalUrl(
                      'https://www.instagram.com/engelsizclub',
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: MetoColors.border),
                  ),
                  leading: SvgPicture.asset(
                    'assets/images/facebook.svg',
                    width: 28,
                    height: 28,
                  ),
                  title: const Text(
                    'Facebook',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Engelsiz Club'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openExternalUrl(
                      'https://www.facebook.com/share/1QAzdknz5M/',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeProfilPanel() {
    setState(() {
      _showProfilPanel = false;
      _showCocukProfil = false;
      _showIlanlarim = false;
      _showKullaniciProfil = false;
      _showKaydedilenler = false;
      _showBildirimler = false;
      _profilDragY = 0;
      _resetKredi();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _BrandBar(
                initials: _initials,
                avatarColor: widget.user.avatarColor,
                photoBytes: _profilFotoBytes,
                notificationBadge:
                    _teklifBildirimUnread + (_yeniMesajVar ? 1 : 0),
                onAvatarTap: _openProfilPanel,
                onMenuTap: _openProfilPanel,
                onHomeTap: _goHomeAndRefresh,
              ),
              Expanded(child: _body),
              _BottomNav(
                active: _activeTab,
                ilanlarUnread: _ilanlarUnread,
                mesajlarUnread: _mesajUnreadCount,
                onSelect: (t) => _goToTab(t),
              ),
            ],
          ),
          if (_showProfilPanel) _buildProfilOverlay(),
        ],
      ),
    );
  }

  Widget _buildProfilOverlay() {
    final screenH = MediaQuery.sizeOf(context).height;
    final dragProgress = (_profilDragY / 280).clamp(0.0, 1.0);
    final scrimAlpha = 0.4 * (1 - dragProgress);

    void onDragUpdate(DragUpdateDetails d) {
      final next = (_profilDragY + d.delta.dy).clamp(0.0, screenH * 0.85);
      if (next == _profilDragY) return;
      setState(() => _profilDragY = next);
    }

    void onDragEnd(DragEndDetails d) {
      final fling = d.primaryVelocity ?? 0;
      if (_profilDragY > 110 || fling > 700) {
        _closeProfilPanel();
      } else {
        setState(() => _profilDragY = 0);
      }
    }

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: _closeProfilPanel,
              child: Container(color: Colors.black.withValues(alpha: scrimAlpha)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, _profilDragY),
                child: Container(
                  constraints: BoxConstraints(maxHeight: screenH * 0.9),
                  decoration: const BoxDecoration(
                    color: MetoColors.card,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: onDragUpdate,
                        onVerticalDragEnd: onDragEnd,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: MetoColors.mutedFg
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Aşağı kaydırarak kapat',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: MetoColors.mutedFg
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is OverscrollNotification &&
                                n.overscroll < 0 &&
                                n.metrics.pixels <= 0) {
                              setState(() {
                                _profilDragY = (_profilDragY - n.overscroll)
                                    .clamp(0.0, screenH * 0.85);
                              });
                              return false;
                            }
                            if (n is ScrollEndNotification &&
                                _profilDragY > 0) {
                              onDragEnd(DragEndDetails(
                                primaryVelocity:
                                    n.dragDetails?.primaryVelocity,
                              ));
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 28),
                            child: _krediSatin
                                ? _buildKrediSatin()
                                : _showCocukProfil
                                    ? _CocukProfilForm(
                                        initial: _cocukProfil,
                                        onBack: () => setState(
                                            () => _showCocukProfil = false),
                                        onSaved: (p) async {
                                          await upsertUserCloudProfile(
                                            email: widget.user.email,
                                            cocuk: p,
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            _cocukProfil = p;
                                            _showCocukProfil = false;
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Çocuk profili kaydedildi ✅'),
                                            ),
                                          );
                                        },
                                      )
                                    : _showIlanlarim
                                        ? _buildIlanlarim()
                                        : _showKullaniciProfil
                                            ? _KullaniciProfilForm(
                                                initial: _kullaniciProfil,
                                                role: _role,
                                                email: widget.user.email,
                                                onBack: () => setState(() =>
                                                    _showKullaniciProfil =
                                                        false),
                                                onSaved: (profil) async {
                                                  await upsertUserCloudProfile(
                                                    email: widget.user.email,
                                                    profil: profil,
                                                  );
                                                  if (!mounted) return;
                                                  setState(() {
                                                    _kullaniciProfil = profil;
                                                    _showKullaniciProfil =
                                                        false;
                                                  });
                                                  ScaffoldMessenger.of(
                                                          context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Profiliniz kaydedildi ✅',
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : _showKaydedilenler
                                                ? _buildKaydedilenler()
                                                : _showBildirimler
                                                    ? _buildBildirimler()
                                                    : _buildProfilMenu(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  int get _ilanlarimCount => myIlanCount(widget.user.email);

  void _openIlanDetay({required String kind, required int id}) {
    setState(() {
      _showIlanlarim = false;
      _showKaydedilenler = false;
      _showProfilPanel = false;
      _activeTab = MetoTab.ilanlar;
      _openIlanKind = kind;
      _openIlanId = id;
      _openIlanToken++;
    });
    if (_tabPageController.hasClients) {
      _tabPageController.jumpToPage(MetoTab.ilanlar.index);
    }
  }

  void _openEditIlanFromProfil(String kind, int id) {
    setState(() {
      _showIlanlarim = false;
      _showKaydedilenler = false;
      _showProfilPanel = false;
      _activeTab = MetoTab.ilanlar;
      _openEditIlanKind = kind;
      _openEditIlanId = id;
      _openEditIlanToken++;
    });
    if (_tabPageController.hasClients) {
      _tabPageController.jumpToPage(MetoTab.ilanlar.index);
    }
  }

  Widget _buildIlanlarim() {
    final email = widget.user.email;
    // Sadece bu kullanıcının ilanları.
    final entries = <({
      String kind,
      int id,
      String kategori,
      String emoji,
      String title,
      String konum,
      String fiyat,
    })>[
      ...myUzmanIlanlar(email).map((i) => (
            kind: 'uzman',
            id: i.id,
            kategori: 'Uzman Arıyorum',
            emoji: '🏃',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.budget,
          )),
      ...myBakiciIlanlar(email).map((i) => (
            kind: 'bakici',
            id: i.id,
            kategori: 'Bakıcı Arıyorum',
            emoji: '🤝',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.budget,
          )),
      ...myIkincielIlanlar(email).map((i) => (
            kind: 'ikinciel',
            id: i.id,
            kategori: '2. El',
            emoji: '♻️',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.price,
          )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showIlanlarim = false),
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'İlanlarım (${entries.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              if (_teklifBildirimUnread > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$_teklifBildirimUnread teklif',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_bildirimlerInbox.any((b) => b.isTeklif)) ...[
          const Text(
            'TEKLİF BİLDİRİMLERİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          for (final b in _bildirimlerInbox.where((x) => x.isTeklif)) ...[
            Dismissible(
              key: ValueKey('ilan_bildirim_${b.id}'),
              direction: DismissDirection.horizontal,
              background: _bildirimSwipeDeleteBg(alignStart: true),
              secondaryBackground: _bildirimSwipeDeleteBg(alignStart: false),
              confirmDismiss: (_) => _confirmDeleteBildirim(b),
              child: Material(
                color:
                    b.read ? MetoColors.background : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  dense: true,
                  onTap: () {
                    setState(() {
                      _showIlanlarim = false;
                      _showProfilPanel = false;
                      _activeTab = MetoTab.mesajlar;
                    });
                    if (_tabPageController.hasClients) {
                      _tabPageController.jumpToPage(MetoTab.mesajlar.index);
                    }
                    _openBildirim(b);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: b.read
                          ? MetoColors.border
                          : const Color(0xFFFDBA74),
                    ),
                  ),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        b.read ? MetoColors.muted : const Color(0xFFEF4444),
                    child: Text(
                      b.actorName.isNotEmpty
                          ? b.actorName.substring(0, 1).toUpperCase()
                          : '!',
                      style: TextStyle(
                        color: b.read ? MetoColors.mutedFg : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    b.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: b.read ? FontWeight.w500 : FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Sil',
                    onPressed: () => _confirmDeleteBildirim(b),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: b.read
                          ? MetoColors.mutedFg
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          const Text(
            'İLANLARIM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: MetoColors.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('📋', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                const Text(
                  'Henüz ilanınız yok',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'İlanlar sekmesinden "İlan Ver" ile ücretsiz ilan yayınlayabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _showIlanlarim = false;
                      _showProfilPanel = false;
                      _activeTab = MetoTab.ilanlar;
                    });
                    if (_tabPageController.hasClients) {
                      _tabPageController.jumpToPage(MetoTab.ilanlar.index);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'İlan Ver',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          )
        else
          ...entries.map((e) {
            final teklifler = _tekliflerForIlan(e.id);
            final yeniTeklif = teklifler.where((t) => !t.read).length;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openIlanDetay(kind: e.kind, id: e.id),
                child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: yeniTeklif > 0
                    ? const Color(0xFFFFF7ED)
                    : MetoColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: yeniTeklif > 0
                      ? const Color(0xFFFDBA74)
                      : MetoColors.border,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 20)),
                      if (yeniTeklif > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16),
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$yeniTeklif',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip(
                              e.kategori,
                              MetoColors.selectedBg,
                              MetoColors.primary,
                            ),
                            const SizedBox(width: 6),
                            _chip(
                              'Aktif',
                              const Color(0xFFF0FDF4),
                              const Color(0xFF15803D),
                            ),
                            if (yeniTeklif > 0) ...[
                              const SizedBox(width: 6),
                              _chip(
                                '$yeniTeklif yeni teklif',
                                const Color(0xFFFEE2E2),
                                const Color(0xFFDC2626),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.konum} · ${e.fiyat}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        if (teklifler.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            teklifler.first.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: yeniTeklif > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: yeniTeklif > 0
                                  ? const Color(0xFFC2410C)
                                  : MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (teklifler.isNotEmpty)
                    IconButton(
                      tooltip: 'Teklifleri gör',
                      onPressed: () {
                        final b = teklifler.first;
                        setState(() {
                          _showIlanlarim = false;
                          _showProfilPanel = false;
                          _activeTab = MetoTab.mesajlar;
                        });
                        if (_tabPageController.hasClients) {
                          _tabPageController.jumpToPage(MetoTab.mesajlar.index);
                        }
                        _openBildirim(b);
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: MetoColors.primary,
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    tooltip: 'İlanı düzenle',
                    onPressed: () => _openEditIlanFromProfil(e.kind, e.id),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: MetoColors.primary,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'İlanı sil',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('İlanı sil'),
                          content: Text(
                            '"${e.title}" ilanını silmek istediğinize emin misiniz?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !mounted) return;
                      await deleteUserIlan(
                        email: widget.user.email,
                        kind: e.kind,
                        id: e.id,
                      );
                      if (!mounted) return;
                      setState(() {});
                      _persistIlanlar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İlan silindi')),
                      );
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildKaydedilenler() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showKaydedilenler = false),
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kaydedilenler (${_favoriler.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_favoriler.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MetoColors.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text('❤️', style: TextStyle(fontSize: 28)),
                SizedBox(height: 8),
                Text(
                  'Henüz favori ilan yok',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.foreground,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'İlanlar sekmesinde beğendiğiniz ilanı kalp ile kaydedin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ],
            ),
          )
        else
          ..._favoriler.map((f) {
            final emoji = switch (f.kind) {
              'bakici' => '🤝',
              'ikinciel' => '♻️',
              _ => '🏃',
            };
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openIlanDetay(kind: f.kind, id: f.id),
                child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetoColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MetoColors.border),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        if (f.konum.isNotEmpty || f.fiyat.isNotEmpty)
                          Text(
                            [
                              if (f.konum.isNotEmpty) f.konum,
                              if (f.fiyat.isNotEmpty) f.fiyat,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favoriden çıkar',
                    onPressed: () async {
                      final next =
                          _favoriler.where((e) => e.key != f.key).toList();
                      await upsertUserCloudProfile(
                        email: widget.user.email,
                        favorites: next,
                      );
                      if (!mounted) return;
                      setState(() => _favoriler = next);
                    },
                    icon: const Icon(
                      Icons.favorite,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBildirimler() {
    Widget toggleRow({
      required String emoji,
      required String title,
      required String sub,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MetoColors.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: MetoColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      );
    }

    Future<void> save(BildirimAyarlari next) async {
      await upsertUserCloudProfile(
        email: widget.user.email,
        notifications: next,
      );
      if (!mounted) return;
      setState(() => _bildirimler = next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showBildirimler = false),
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bildirimler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetoColors.selectedBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _bildirimler.acikSayisi == 0
                ? 'Tüm bildirimler kapalı. İsterseniz aşağıdan açabilirsiniz.'
                : 'Tercihleriniz hesabınıza kaydedilir; çıkış yapınca da korunur.',
            style: const TextStyle(fontSize: 12, color: MetoColors.foreground),
          ),
        ),
        toggleRow(
          emoji: '📋',
          title: 'Yeni ilanlar',
          sub: 'İlginizi çekebilecek ilan bildirimleri',
          value: _bildirimler.ilanlar,
          onChanged: (v) => save(_bildirimler.copyWith(ilanlar: v)),
        ),
        toggleRow(
          emoji: '💬',
          title: 'Mesajlar',
          sub: 'Teklif ve sohbet bildirimleri',
          value: _bildirimler.mesajlar,
          onChanged: (v) => save(_bildirimler.copyWith(mesajlar: v)),
        ),
        toggleRow(
          emoji: '📣',
          title: 'Duyurular',
          sub: 'Kampanya ve platform haberleri',
          value: _bildirimler.duyurular,
          onChanged: (v) => save(_bildirimler.copyWith(duyurular: v)),
        ),
      ],
    );
  }

  Widget _buildProfilMenu() {
    final tip = switch (_role) {
      'uzman' => '💼 Uzman',
      'bakici' => '🤝 Bakıcı',
      _ => '👨‍👩‍👧 Aile',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickProfilFoto,
                onLongPress: _profilFoto != null ? _removeProfilFoto : null,
                child: Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.user.avatarColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                        image: _profilFotoBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_profilFotoBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilFotoBytes == null
                          ? Text(
                              _initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: MetoColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kullaniciProfil.adSoyad.trim().isEmpty
                          ? 'Profilinizi tamamlayın'
                          : _kullaniciProfil.adSoyad.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profilFoto == null
                          ? 'Fotoğraf eklemek için avatara dokun'
                          : 'Değiştir: dokun · Kaldır: basılı tut',
                      style: const TextStyle(
                        fontSize: 11,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip(tip, MetoColors.selectedBg, MetoColors.primary),
                        const SizedBox(width: 6),
                        _chip(
                          '✓ Doğrulandı',
                          const Color(0xFFF0FDF4),
                          const Color(0xFF15803D),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildRoleSwitcher(),
        const SizedBox(height: 12),
        if (_isProf && !_krediHosBonusGosterildi) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4A832), Color(0xFFE8932A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hoş Geldin Hediyesi!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sisteme kayıt olduğunuz için hesabınıza $kWelcomeKredi ücretsiz puan tanımlandı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 teklif = 1 puan = ₺49,90',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => _krediHosBonusGosterildi = true);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_welcomeDismissKey, true);
                  },
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(24, 24),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.close, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_canBuyKredi) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [MetoColors.primary, MetoColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAileRole ? 'İyilik Puanım' : 'Mevcut Puanım',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$_userKredi ',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: _krediBirimLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isAileRole)
                        Text(
                          '1 teklif = 1 puan = ₺49,90 · Uzman & bakıcı ortak bakiye',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(_isAileRole ? '💚' : '🪙',
                    style: const TextStyle(fontSize: 36)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => setState(() {
              _krediStep = _KrediStep.paket;
              _krediSatin = true;
            }),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.monetization_on_outlined, size: 18),
            label: Text(
              _krediYukleLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '👤',
            label: 'Profilim & Özgeçmişim',
            sub: _kullaniciProfil.menuSub,
            onTap: () => setState(() => _showKullaniciProfil = true),
          ),
        ),
        if (_role == 'aile')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _menuTile(
              emoji: '👶',
              label: 'Çocuk Profilim',
              sub: _cocukProfil.menuSub,
              onTap: () => setState(() => _showCocukProfil = true),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '📋',
            label: 'İlanlarım',
            sub: _teklifBildirimUnread > 0
                ? '$_teklifBildirimUnread yeni teklif'
                : (_ilanlarimCount == 0
                    ? 'Henüz ilanınız yok'
                    : '$_ilanlarimCount aktif ilan'),
            badge: _teklifBildirimUnread,
            highlight: _teklifBildirimUnread > 0,
            onTap: () {
              _loadSohbetOzetleri();
              setState(() => _showIlanlarim = true);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '❤️',
            label: 'Kaydedilenler',
            sub: _favoriler.isEmpty
                ? 'Henüz favori yok'
                : '${_favoriler.length} ilan favorilendi',
            onTap: () => setState(() => _showKaydedilenler = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🔔',
            label: 'Bildirimler',
            sub: _bildirimler.menuSub,
            onTap: () => setState(() => _showBildirimler = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🌐',
            label: 'Sosyal medya hesaplarımız',
            sub: 'Instagram · Facebook',
            onTap: _showSosyalMedyaSheet,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🔒',
            label: 'Gizlilik & Güvenlik',
            sub: 'Ayarlarınız',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Hesabınız Supabase ile korunuyor. İletişim bilgileri ilanlarda gizlenir.',
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '💬',
            label: 'Dilek, Şikayet & Öneri',
            sub: 'Görüşlerinizi ekibimizle paylaşın',
            highlight: true,
            onTap: () => _showIletisimModal(),
          ),
        ),
        _menuTile(
          emoji: '🚪',
          label: 'Çıkış Yap',
          sub: null,
          danger: true,
          onTap: () {
            setState(() {
              _showProfilPanel = false;
              _showCocukProfil = false;
              _showIlanlarim = false;
              _showKullaniciProfil = false;
              _showKaydedilenler = false;
              _showBildirimler = false;
            });
            clearRuntimeIlanlar();
            widget.onLogout();
          },
        ),
      ],
    );
  }

  void _showIletisimModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IletisimSheet(
        userName: widget.user.name,
        userEmail: widget.user.email,
      ),
    );
  }

  Widget _buildKrediSatin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  if (_krediStep == _KrediStep.odeme) {
                    _krediStep = _KrediStep.paket;
                  } else {
                    _resetKredi();
                  }
                }),
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                switch (_krediStep) {
                  _KrediStep.paket => _krediYukleLabel,
                  _KrediStep.odeme => 'Mağaza Ödemesi',
                },
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const Spacer(),
              Text(
                _krediStep == _KrediStep.paket ? '1/2' : '2/2',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
        if (_krediStep == _KrediStep.paket) _buildKrediPaketStep(),
        if (_krediStep == _KrediStep.odeme) _buildKrediOdemeStep(),
      ],
    );
  }

  Widget _buildKrediPaketStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MetoColors.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAileRole ? 'Mevcut iyilik puanınız' : 'Mevcut puanınız',
                style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg),
              ),
              Text(
                '${_isAileRole ? '💚' : '🪙'} $_userKredi $_krediBirimLabel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'PAKET SEÇ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 12),
        ..._krediPaketleri.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: p.popular ? MetoColors.selectedBg : MetoColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: p.popular ? MetoColors.primary : MetoColors.border,
                  width: 2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _seciliPaket = p;
                  _krediStep = _KrediStep.odeme;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${p.adet} $_krediBirimLabelCap',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                                if (p.popular) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MetoColors.primary,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text(
                                      'Popüler',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.desc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                            Text(
                              p.birim.replaceAll(
                                '/puan',
                                _isAileRole ? '/iyilik puanı' : '/puan',
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                    MetoColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _paketFiyatLabel(p),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        Text(
          'Ödeme ${StoreBillingService.instance.storeName} üzerinden alınır',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
        ),
      ],
    );
  }

  Widget _buildKrediOdemeStep() {
    final paket = _seciliPaket;
    if (paket == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MetoColors.primary, Color(0xFF1A5C51)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ödenecek Tutar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paket.adet} $_krediBirimLabelCap',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _paketFiyatLabel(paket),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStoreOdemeForm(),
      ],
    );
  }

  Future<void> _handleStoreOdeme() async {
    final paket = _seciliPaket;
    if (paket == null) return;
    final store = StoreBillingService.instance;
    if (!store.isSupported) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mağaza ödemesi'),
          content: const Text(
            'Ödeme yalnızca Android (Google Play) veya iPhone/iPad (App Store) '
            'uygulamasında yapılır.\n\n'
            'Play Console / App Store Connect’te kredi_1, kredi_5, kredi_10 '
            'ürünlerini tanımlayın; mağaza, payınıza düşen tutarı hesabınıza yatırır.\n\n'
            'Web tarayıcıda mağaza ödemesi desteklenmez.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _odemeYukleniyor = true);
    try {
      final ok = await store.buyKrediPaket(paket.adet);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ürün bulunamadı. ${store.storeName}’da kredi_1 / kredi_5 / kredi_10 tanımlı mı kontrol edin.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${store.storeName} ödeme başlatılamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _odemeYukleniyor = false);
    }
  }

  Widget _buildStoreOdemeForm() {
    final store = StoreBillingService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _odemeYukleniyor ? null : _handleStoreOdeme,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _odemeYukleniyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(store.isIos ? Icons.phone_iphone : Icons.shop),
          label: Text(
            _odemeYukleniyor
                ? '${store.storeName} açılıyor…'
                : '${store.storeName} ile ${_seciliPaket == null ? '' : _paketFiyatLabel(_seciliPaket!)} Öde',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _menuTile({
    required String emoji,
    required String label,
    required String? sub,
    required VoidCallback onTap,
    bool danger = false,
    bool highlight = false,
    int badge = 0,
  }) {
    return Material(
      color: danger
          ? const Color(0xFFFEF2F2)
          : highlight
              ? const Color(0xFFF0FAF5)
              : MetoColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: danger
              ? const Color(0xFFFEE2E2)
              : highlight
                  ? const Color(0x551A6B4A)
                  : MetoColors.border,
          width: highlight ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: danger
                            ? const Color(0xFFDC2626)
                            : MetoColors.foreground,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                  ],
                ),
              ),
              if (!danger)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: highlight ? MetoColors.primary : MetoColors.mutedFg,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KullaniciProfilForm extends StatefulWidget {
  const _KullaniciProfilForm({
    required this.initial,
    required this.role,
    required this.email,
    required this.onBack,
    required this.onSaved,
  });

  final KullaniciProfil initial;
  final String role;
  final String email;
  final VoidCallback onBack;
  final ValueChanged<KullaniciProfil> onSaved;

  @override
  State<_KullaniciProfilForm> createState() => _KullaniciProfilFormState();
}

class _KullaniciProfilFormState extends State<_KullaniciProfilForm> {
  late final TextEditingController _adSoyad;
  late final TextEditingController _meslek;
  late final TextEditingController _egitim;
  late final TextEditingController _deneyim;
  late final TextEditingController _uzmanliklar;
  late final TextEditingController _sertifikalar;
  late final TextEditingController _calismaSekli;
  late final TextEditingController _hakkimda;
  String? _sehir;
  String? _ilce;
  bool _saving = false;

  bool get _isUzman => widget.role == 'uzman';
  bool get _isBakici => widget.role == 'bakici';
  bool get _isAile => !_isUzman && !_isBakici;

  String get _roleLabel => _isUzman
      ? 'Uzman'
      : _isBakici
          ? 'Bakıcı'
          : 'Aile';

  List<String> get _ilceler {
    final city = _sehir;
    if (city == null) return const [];
    return kTurkishCities[city]
            ?.ilceler
            .where((item) => item != kAllIlceler)
            .toList() ??
        const [];
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _adSoyad = TextEditingController(text: p.adSoyad);
    _meslek = TextEditingController(text: p.meslek);
    _egitim = TextEditingController(text: p.egitim);
    _deneyim = TextEditingController(text: p.deneyimYili);
    _uzmanliklar = TextEditingController(text: p.uzmanliklar);
    _sertifikalar = TextEditingController(text: p.sertifikalar);
    _calismaSekli = TextEditingController(text: p.calismaSekli);
    _hakkimda = TextEditingController(text: p.hakkimda);
    _sehir = p.sehir.isEmpty ? null : p.sehir;
    _ilce = p.ilce.isEmpty ? null : p.ilce;
  }

  @override
  void dispose() {
    _adSoyad.dispose();
    _meslek.dispose();
    _egitim.dispose();
    _deneyim.dispose();
    _uzmanliklar.dispose();
    _sertifikalar.dispose();
    _calismaSekli.dispose();
    _hakkimda.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: MetoColors.mutedFg, fontSize: 14),
        filled: true,
        fillColor: MetoColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MetoColors.mutedFg,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec(hint),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_adSoyad.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen ad ve soyadınızı girin')),
      );
      return;
    }
    setState(() => _saving = true);
    widget.onSaved(KullaniciProfil(
      adSoyad: _adSoyad.text.trim(),
      sehir: _sehir ?? '',
      ilce: _ilce ?? '',
      meslek: _meslek.text.trim(),
      egitim: _egitim.text.trim(),
      deneyimYili: _deneyim.text.trim(),
      uzmanliklar: _uzmanliklar.text.trim(),
      sertifikalar: _sertifikalar.text.trim(),
      calismaSekli: _calismaSekli.text.trim(),
      hakkimda: _hakkimda.text.trim(),
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_roleLabel Profili & Özgeçmiş',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: MetoColors.selectedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Profiliniz başlangıçta boştur. Bilgileri siz doldurur ve istediğiniz zaman güncellersiniz.',
            style: const TextStyle(
              fontSize: 12,
              color: MetoColors.primary,
              height: 1.4,
            ),
          ),
        ),
        _field('Ad Soyad', _adSoyad, 'Adınız ve soyadınız'),
        _label('E-posta'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: MetoColors.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.email,
            style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('İl'),
                  DropdownButtonFormField<String>(
                    initialValue: _sehir,
                    isExpanded: true,
                    decoration: _dec('İl seçin'),
                    items: kCityNames
                        .map((city) =>
                            DropdownMenuItem(value: city, child: Text(city)))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _sehir = value;
                      _ilce = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('İlçe'),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$_sehir-$_ilce'),
                    initialValue: _ilce,
                    isExpanded: true,
                    decoration: _dec(_sehir == null ? 'Önce il' : 'İlçe seçin'),
                    items: _ilceler
                        .map((district) => DropdownMenuItem(
                              value: district,
                              child: Text(district),
                            ))
                        .toList(),
                    onChanged: _sehir == null
                        ? null
                        : (value) => setState(() => _ilce = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isUzman) ...[
          _field('Meslek / Uzmanlık Unvanı', _meslek,
              'Örn. Fizyoterapist, Dil Terapisti'),
          _field('Eğitim', _egitim, 'Okul, bölüm ve mezuniyet yılı'),
          _field('Deneyim', _deneyim, 'Örn. 8 yıl'),
          _field('Çalışma Alanları', _uzmanliklar,
              'Tanılar, terapi ve uzmanlık alanları',
              maxLines: 3),
          _field('Sertifikalar', _sertifikalar, 'Sertifika ve eğitimleri yazın',
              maxLines: 3),
          _field('Çalışma Şekli', _calismaSekli,
              'Evde, merkezde, online; uygun gün ve saatler'),
        ] else if (_isBakici) ...[
          _field('Mesleki Tanım', _meslek,
              'Örn. Özel gereksinimli çocuk bakıcısı'),
          _field('Eğitim', _egitim, 'Okul ve alınan eğitimler'),
          _field('Deneyim', _deneyim, 'Örn. 5 yıl'),
          _field('Deneyim Alanları', _uzmanliklar,
              'Çalıştığınız yaş grupları ve tanılar',
              maxLines: 3),
          _field('Sertifikalar', _sertifikalar,
              'İlk yardım ve bakım sertifikaları',
              maxLines: 3),
          _field('Çalışma Tercihi', _calismaSekli,
              'Tam/yarı zamanlı, yatılı, uygun günler'),
        ] else ...[
          _field('Aile / Veli Bilgisi', _meslek,
              'Örn. Anne, baba veya yasal vasi'),
          _field('Aradığınız Destek', _uzmanliklar,
              'Uzman, bakım veya eğitim ihtiyaçlarınız',
              maxLines: 3),
          _field(
              'Tercihler', _calismaSekli, 'Uygun gün, saat ve çalışma şekli'),
        ],
        _field(
          'Hakkımda',
          _hakkimda,
          _isAile
              ? 'Ailenizi ve beklentilerinizi kısaca tanıtın'
              : 'Kendinizi ve mesleki yaklaşımınızı tanıtın',
          maxLines: 5,
        ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _saving ? 'Kaydediliyor...' : 'Profili Kaydet',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _CocukProfilForm extends StatefulWidget {
  const _CocukProfilForm({
    required this.initial,
    required this.onBack,
    required this.onSaved,
  });

  final CocukProfil initial;
  final VoidCallback onBack;
  final ValueChanged<CocukProfil> onSaved;

  @override
  State<_CocukProfilForm> createState() => _CocukProfilFormState();
}

class _CocukProfilFormState extends State<_CocukProfilForm> {
  late final TextEditingController _ad;
  late final TextEditingController _dogum;
  late final TextEditingController _not;
  late final TextEditingController _terapi;
  late String _cinsiyet;
  late List<String> _tanilar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _ad = TextEditingController(text: p.ad);
    _dogum = TextEditingController(text: p.dogumTarihi);
    _not = TextEditingController(text: p.gelisimNotu);
    _terapi = TextEditingController(text: p.terapiler);
    _cinsiyet = p.cinsiyet;
    _tanilar = List<String>.from(p.tanilar);
  }

  @override
  void dispose() {
    _ad.dispose();
    _dogum.dispose();
    _not.dispose();
    _terapi.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dogum.text) ??
        DateTime(now.year - 5, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Doğum tarihi',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked == null) return;
    setState(() {
      _dogum.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen çocuğun adını girin')),
      );
      return;
    }
    setState(() => _saving = true);
    final profil = CocukProfil(
      ad: ad,
      dogumTarihi: _dogum.text.trim(),
      cinsiyet: _cinsiyet,
      tanilar: List<String>.from(_tanilar),
      gelisimNotu: _not.text.trim(),
      terapiler: _terapi.text.trim(),
    );
    widget.onSaved(profil);
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: MetoColors.mutedFg, fontSize: 14),
        filled: true,
        fillColor: MetoColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MetoColors.mutedFg,
            letterSpacing: 0.4,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Çocuk Profilim',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetoColors.selectedBg,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: MetoColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'Tanı ve gelişim bilgileri yalnızca sizin hesabınızda saklanır; ilan ve tekliflerde otomatik paylaşılmaz.',
            style: TextStyle(
              fontSize: 12,
              color: MetoColors.primary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Çocuk adı'),
        TextField(
          controller: _ad,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('Örn. Elif'),
        ),
        const SizedBox(height: 14),
        _label('Doğum tarihi'),
        TextField(
          controller: _dogum,
          readOnly: true,
          onTap: _pickDate,
          decoration: _dec('Tarih seçin').copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        _label('Cinsiyet'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCocukCinsiyetSecenekleri.map((c) {
            final active = _cinsiyet == c;
            return ChoiceChip(
              label: Text(c),
              selected: active,
              onSelected: (_) => setState(() => _cinsiyet = c),
              selectedColor: MetoColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : MetoColors.foreground,
              ),
              backgroundColor: MetoColors.muted,
              side: BorderSide.none,
              showCheckmark: false,
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _label('Tanı(lar)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCocukTaniSecenekleri.map((t) {
            final active = _tanilar.contains(t);
            return FilterChip(
              label: Text(t),
              selected: active,
              onSelected: (v) => setState(() {
                if (v) {
                  _tanilar.add(t);
                } else {
                  _tanilar.remove(t);
                }
              }),
              selectedColor: MetoColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : MetoColors.foreground,
              ),
              backgroundColor: MetoColors.muted,
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _label('Devam eden terapiler'),
        TextField(
          controller: _terapi,
          decoration: _dec('Örn. Fizyoterapi, ABA, dil terapisi'),
        ),
        const SizedBox(height: 14),
        _label('Gelişim notları'),
        TextField(
          controller: _not,
          maxLines: 4,
          decoration: _dec('Gözlemleriniz, hedefler, önemli notlar...'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _saving ? 'Kaydediliyor...' : 'Kaydet',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _IletisimSheet extends StatefulWidget {
  const _IletisimSheet({
    required this.userName,
    required this.userEmail,
  });

  final String userName;
  final String userEmail;

  @override
  State<_IletisimSheet> createState() => _IletisimSheetState();
}

class _IletisimSheetState extends State<_IletisimSheet> {
  String _type = 'dilek';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sent = false;
  bool _sending = false;

  static const _types = [
    ('dilek', 'Dilek', '🌟'),
    ('sikayet', 'Şikayet', '⚠️'),
    ('oneri', 'Öneri', '💡'),
    ('diger', 'Diğer', '📝'),
  ];

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await submitGorusToAdmin(
        type: _type,
        subject: _subject.text,
        message: _message.text,
        actorName: widget.userName,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $e')),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MetoColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İletişim',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          Text(
                            'Dilek, şikayet ve önerilerinizi iletin',
                            style: TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: MetoColors.muted,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: MetoColors.border),
              if (_sent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MetoColors.selectedBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('✅', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'İletildi!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mesajınız ekibimize ulaştı. En kısa sürede dönüş yapacağız.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetoColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Kapat',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Mesaj Türü',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final t in _types)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Material(
                                    color: _type == t.$1
                                        ? MetoColors.selectedBg
                                        : MetoColors.muted,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: _type == t.$1
                                            ? MetoColors.primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => setState(() => _type = t.$1),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              t.$3,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              t.$2,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _type == t.$1
                                                    ? MetoColors.primary
                                                    : MetoColors.mutedFg,
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
                        ),
                        const SizedBox(height: 16),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Konu ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _subject,
                          maxLength: 80,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Kısaca konuyu yazın...',
                            filled: true,
                            fillColor: MetoColors.muted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MetoColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MetoColors.border,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Mesajınız ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _message,
                          maxLength: 1000,
                          maxLines: 5,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Detaylı olarak açıklayın...',
                            filled: true,
                            fillColor: MetoColors.muted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MetoColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: MetoColors.border,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MetoColors.selectedBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📧', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Yanıt için hesabınızdaki e-posta adresiniz kullanılacaktır. Lütfen güncel tutun.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MetoColors.primary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _sending ||
                                  _subject.text.trim().isEmpty ||
                                  _message.text.trim().isEmpty
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: MetoColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                MetoColors.primary.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _sending ? 'Gönderiliyor…' : 'Gönder',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
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

class _BrandBar extends StatelessWidget {
  const _BrandBar({
    required this.initials,
    required this.avatarColor,
    required this.onAvatarTap,
    required this.onMenuTap,
    required this.onHomeTap,
    this.photoBytes,
    this.notificationBadge = 0,
  });

  final String initials;
  final Color avatarColor;
  final VoidCallback onAvatarTap;
  final VoidCallback onMenuTap;
  final VoidCallback onHomeTap;
  final Uint8List? photoBytes;
  final int notificationBadge;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B1F), Color(0xFF1A6B4A)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onHomeTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Transform.translate(
                        offset: const Offset(0, 3),
                        child: Transform.scale(
                          scale: 1.5,
                          child: Image.asset(
                            'src/imports/119686.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Engelsiz Club',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    image: photoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(photoBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoBytes == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                if (notificationBadge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        notificationBadge > 9 ? '9+' : '$notificationBadge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onMenuTap,
            tooltip: 'Menü',
            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.active,
    required this.onSelect,
    this.ilanlarUnread = 0,
    this.mesajlarUnread = 0,
  });

  final MetoTab active;
  final ValueChanged<MetoTab> onSelect;
  final int ilanlarUnread;
  final int mesajlarUnread;

  static const _items = [
    (MetoTab.home, 'Ana', Icons.home_outlined, Icons.home),
    (MetoTab.merkezler, 'Harita', Icons.place_outlined, Icons.place),
    (MetoTab.ilanlar, 'İlanlar', Icons.work_outline, Icons.work),
    (MetoTab.forum, 'Forum', Icons.forum_outlined, Icons.forum),
    (MetoTab.mesajlar, 'Mesaj', Icons.chat_bubble_outline, Icons.chat_bubble),
    (MetoTab.haklar, 'Haklar', Icons.balance_outlined, Icons.balance),
    (MetoTab.kartlar, 'Kartlar', Icons.grid_view_outlined, Icons.grid_view),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MetoColors.card,
        border: Border(top: BorderSide(color: MetoColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        2,
        6,
        2,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _NavItem(
                label: item.$2,
                icon: active == item.$1 ? item.$4 : item.$3,
                active: active == item.$1,
                badge: item.$1 == MetoTab.ilanlar
                    ? ilanlarUnread
                    : (item.$1 == MetoTab.mesajlar ? mesajlarUnread : 0),
                onTap: () => onSelect(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? MetoColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x551A6B4A),
                              blurRadius: 14,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: active ? 23 : 22,
                    color: active ? Colors.white : MetoColors.mutedFg,
                  ),
                ),
                if (badge > 0 && !active)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: MetoColors.card, width: 2),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else if (active && badge == 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: MetoColors.accentGold,
                        shape: BoxShape.circle,
                        border: Border.all(color: MetoColors.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
                color: active ? MetoColors.primary : MetoColors.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
