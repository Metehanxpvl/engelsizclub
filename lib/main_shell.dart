import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_config.dart';
import 'bildirim_store.dart';
import 'feed_seen_store.dart';
import 'guest_limit_store.dart';
import 'home_page.dart';
import 'cocuk_profil_store.dart';
import 'data/ilanlar_data.dart'
    show
        SohbetKisi,
        contactAvatarLetter,
        publicContactLabel,
        scrubEmailsInText;
import 'data/location_models.dart';
import 'ilan_store.dart';
import 'content_view_store.dart';
import 'kredi_store.dart';
import 'kullanici_profil_store.dart';
import 'l10n/app_strings.dart';
import 'l10n/locale_controller.dart';
import 'medical_disclaimer_store.dart';
import 'meto_theme.dart';
import 'cvi/cvi_entry.dart';
import 'aile_kocu/aile_kocu_entry.dart';
import 'mchat/mchat_entry.dart';
import 'data/more_menu_data.dart';
import 'more_menu_store.dart';
import 'pages/in_app_web_page.dart';
import 'pages/gelisim_etkinlikleri_page.dart';
import 'widgets/admin_more_menu_sheet.dart';
import 'pages/forum_page.dart';
import 'pages/haklar_page.dart';
import 'pages/ilanlar_page.dart';
import 'pages/legal_document_page.dart';
import 'widgets/location_picker.dart';
import 'legal/legal_texts.dart';
import 'pages/kartlar_page.dart';
import 'pages/merkezler_page.dart';
import 'pages/tibbi_sorumluluk_reddi_page.dart';
import 'presence_store.dart';
import 'profil_foto_store.dart';
import 'services/google_play_availability.dart';
import 'services/play_billing_service.dart';
import 'services/push_notification_service.dart';
import 'services/image_optimize_service.dart';
import 'services/r2_storage_service.dart';
import 'sohbet_store.dart';
import 'user_cloud_store.dart';
import 'user_safety_store.dart';
import 'utils/price_format.dart';
import 'widgets/user_avatar.dart';
import 'widgets/user_safety_sheet.dart';
import 'widgets/admin_iyilik_liderleri_panel.dart';
import 'package:showcaseview/showcaseview.dart';
import 'l10n/l10n_text.dart';

enum MetoTab { home, merkezler, ilanlar, forum, haklar, kartlar }

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
    this.onRequireLogin,
  });

  final AuthUser user;
  final VoidCallback onLogout;
  final ValueChanged<AuthUser>? onUserChanged;
  /// Misafir kısıtında Giriş/Üye Ol ekranına dön.
  final VoidCallback? onRequireLogin;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MetoTab _activeTab = MetoTab.home;
  /// Alt menüden hedef sekmeye giderken ara sayfaların (ör. Mesajlar) guest
  /// kilidini tetiklememesi için.
  MetoTab? _programmaticNavTarget;
  late final PageController _tabPageController;
  bool _showProfilPanel = false;
  bool _krediSatin = false;
  bool _storeLoadingOpen = false;
  bool _showCocukProfil = false;
  bool _showIlanlarim = false;
  bool _showKullaniciProfil = false;
  bool _showKaydedilenler = false;
  bool _showBildirimler = false;
  bool _showHakkinda = false;
  bool _showEngellenenler = false;
  bool _showIyilikLiderleri = false;
  bool _showDilSecimi = false;
  /// Android geri: ana sayfadayken ikinci basışta çıkış için zaman damgası.
  DateTime? _lastExitBackAt;
  /// Profil panelini aşağı kaydırarak kapatırken biriken dikey ofset.
  double _profilDragY = 0;
  CocukProfil _cocukProfil = const CocukProfil();
  KullaniciProfil _kullaniciProfil = const KullaniciProfil();
  List<FavoriIlanRef> _favoriler = const [];
  String? _openIlanKind;
  int? _openIlanId;
  int _openIlanToken = 0;
  int? _openForumPostId;
  int? _openForumCommentId;
  int _openForumToken = 0;
  String? _openEditIlanKind;
  int? _openEditIlanId;
  int _openEditIlanToken = 0;
  BildirimAyarlari _bildirimler = const BildirimAyarlari();
  String? _profilFoto;
  late int _userKredi;
  bool _krediHosBonusGosterildi = false;
  int _ilanlarUnread = 0;
  int _newIlanlarCount = 0;
  int _newForumCount = 0;
  bool _navTourStarted = false;

  final _navTourKeys = <MetoTab, GlobalKey>{
    for (final t in MetoTab.values) t: GlobalKey(),
  };
  final _moreNavTourKey = GlobalKey();
  final _messagesTourKey = GlobalKey();
  final _forumPageKey = GlobalKey<ForumPageState>();
  final _ilanlarPageKey = GlobalKey<IlanlarPageState>();
  bool _showMesajlar = false;

  static const _navTourDoneKey = 'nav_feature_tour_v2';

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
  Timer? _guestTabTimer;

  bool get _isGuest => widget.user.isGuest;

  void _requireLogin([String? message]) {
    if (!_isGuest) return;
    final msg = message ??
        'Bu özellik için giriş yapmanız veya üye olmanız gerekiyor.';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
    widget.onRequireLogin?.call();
  }

  Future<bool> _gateTimedTab(MetoTab t) async {
    if (!_isGuest) return true;
    final key = t == MetoTab.haklar
        ? 'haklar'
        : t == MetoTab.kartlar
            ? 'kartlar'
            : null;
    if (key == null) return true;
    final ok = await GuestLimitStore.allowTimedTab(key);
    if (ok) return true;
    if (!mounted) return false;
    // Süre dolmuş — uyarı + üyelik ekranı
    _requireLogin(
      'Misafir erişimi 2 dakika ile sınırlıdır. Devam etmek için üye olun.',
    );
    return false;
  }

  void _armGuestTabTimer(MetoTab t) {
    _guestTabTimer?.cancel();
    _guestTabTimer = null;
    if (!_isGuest) return;
    if (t != MetoTab.haklar && t != MetoTab.kartlar) return;
    _guestTabTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !_isGuest) return;
      if (_activeTab != MetoTab.haklar && _activeTab != MetoTab.kartlar) {
        _guestTabTimer?.cancel();
        return;
      }
      final key = _activeTab == MetoTab.haklar ? 'haklar' : 'kartlar';
      final left = await GuestLimitStore.remainingTimedSeconds(key);
      if (!mounted) return;
      if (left <= 0) {
        _guestTabTimer?.cancel();
        _requireLogin(
          'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
        );
      }
    });
  }

  int get _sohbetUnreadCount =>
      _sohbetOzetleri.fold<int>(0, (s, o) => s + o.unreadCount);

  /// Header zil rozeti: mesaj haricindeki okunmamis bildirimler.
  int get _bellUnreadCount => _bildirimlerInbox
      .where((b) => !b.read && !b.isMesaj)
      .length
      .clamp(0, 99);

  int get _teklifBildirimUnread =>
      _bildirimlerInbox.where((b) => !b.read && b.isTeklif).length;

  List<AppBildirim> _tekliflerForIlan(int ilanId) => _bildirimlerInbox
      .where((b) => b.isTeklif && b.ilanId == ilanId)
      .toList();

  static const List<_KrediPaket> _krediPaketleri = [
    (
      adet: 1,
      fiyat: '₺69,90',
      birim: '₺69,90/puan',
      desc: '1 teklif = 1 puan',
      popular: false,
    ),
    (
      adet: 5,
      fiyat: '₺314,55',
      birim: '₺62,91/puan',
      desc: '%10 indirim',
      popular: true,
    ),
    (
      adet: 10,
      fiyat: '₺594,15',
      birim: '₺59,42/puan',
      desc: '%15 indirim',
      popular: false,
    ),
    (
      adet: 30,
      fiyat: '₺1.677,60',
      birim: '₺55,92/puan',
      desc: '%20 indirim',
      popular: false,
    ),
    (
      adet: 50,
      fiyat: '₺2.621,25',
      birim: '₺52,43/puan',
      desc: '%25 indirim',
      popular: false,
    ),
    (
      adet: 100,
      fiyat: '₺4.893,00',
      birim: '₺48,93/puan',
      desc: 'En avantajlı · %30 indirim',
      popular: false,
    ),
  ];

  String get _role =>
      (widget.user.userType ?? 'aile').trim().toLowerCase();

  bool get _isProf => _role == 'uzman' || _role == 'bakici';
  /// Rol bazlı; admin aile rolündeyken ₺69 puan fiyatı / teklif metni gösterilmez.
  bool get _isAileRole => !_isProf;
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

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocaleChanged);
    unawaited(LocaleController.instance.ensureLoaded());
    _tabPageController = PageController(initialPage: MetoTab.home.index);
    if (_isGuest) {
      _userKredi = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowMedicalWelcome());
      });
      return;
    }
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
      const Duration(seconds: 12),
      (_) {
        _loadSohbetOzetleri();
        unawaited(_refreshFeedDots());
      },
    );
    unawaited(_refreshFeedDots());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowMedicalWelcome());
    });
  }

  Future<void> _maybeShowMedicalWelcome() async {
    if (!mounted) return;
    final accepted = await isMedicalWelcomeAccepted();
    if (accepted || !mounted) {
      unawaited(_maybeStartNavTour());
      return;
    }
    await showMedicalWelcomeDialog(context);
    await acceptMedicalWelcome();
    if (!mounted) return;
    unawaited(_maybeStartNavTour());
  }

  Future<void> _refreshFeedDots() async {
    final ilan = await FeedSeenStore.countNewIlanlar();
    final forum = await FeedSeenStore.countNewForum();
    if (!mounted) return;
    if (_newIlanlarCount == ilan && _newForumCount == forum) return;
    setState(() {
      _newIlanlarCount = ilan;
      _newForumCount = forum;
    });
  }

  Future<void> _maybeStartNavTour() async {
    if (!mounted || _navTourStarted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_navTourDoneKey) == true) return;
    _navTourStarted = true;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ShowcaseView.get().startShowCase([
      _navTourKeys[MetoTab.home]!,
      _navTourKeys[MetoTab.merkezler]!,
      _navTourKeys[MetoTab.ilanlar]!,
      _navTourKeys[MetoTab.forum]!,
      _moreNavTourKey,
      _messagesTourKey,
    ]);
  }

  Future<void> _finishNavTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_navTourDoneKey, true);
  }

  void _showCenteredNotice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final h = MediaQuery.sizeOf(context).height;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(24, 0, 24, h * 0.42),
        duration: const Duration(seconds: 4),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showCenteredLoading(String message) async {
    if (!mounted) return;
    _storeLoadingOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: MetoColors.card,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: MetoColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _storeLoadingOpen = false;
  }

  void _hideCenteredLoading() {
    if (!_storeLoadingOpen || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _initStoreBilling() async {
    try {
      await StoreBillingService.instance.init(
        onPurchased: (purchase, adet) async {
          if (!mounted) return;
          setState(() => _userKredi += adet);
          await _saveKredi();
          if (!mounted) return;
          _showCenteredNotice(
            '${StoreBillingService.instance.storeName} ödemesi alındı · +$adet $_krediBirimLabel',
          );
          setState(() {
            _krediStep = _KrediStep.paket;
            _krediSatin = false;
            _seciliPaket = null;
          });
        },
        onError: (msg) {
          debugPrint('Store billing: $msg');
        },
      );
    } catch (e) {
      debugPrint('Store billing init: $e');
    }
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocaleChanged);
    unawaited(StoreBillingService.instance.dispose());
    stopPresenceHeartbeat();
    _sohbetTimer?.cancel();
    _guestTabTimer?.cancel();
    unawaited(unsubscribeRealtime(_inboxChannel));
    _inboxChannel = null;
    _tabPageController.dispose();
    super.dispose();
  }

  void _openMesajlar() {
    if (_isGuest) {
      _requireLogin('Mesajlar için giriş yapmanız gerekiyor.');
      return;
    }
    if (_showMesajlar) {
      _closeMesajlar();
      return;
    }
    _lastExitBackAt = null;
    setState(() {
      _showMesajlar = true;
      _showProfilPanel = false;
      _showCocukProfil = false;
      _showIlanlarim = false;
      _showKullaniciProfil = false;
      _showKaydedilenler = false;
      _showBildirimler = false;
      _showHakkinda = false;
      _showEngellenenler = false;
      _showIyilikLiderleri = false;
      _showDilSecimi = false;
      _profilDragY = 0;
    });
    _loadSohbetOzetleri();
  }

  void _closeMesajlar() {
    if (!_showMesajlar) return;
    setState(() => _showMesajlar = false);
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
        final isAdmin = isAppAdmin(widget.user.email);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: FutureBuilder<List<MoreMenuItem>>(
              future: loadMoreMenu(forceRefresh: true),
              builder: (context, snap) {
                final items = snap.data ??
                    cachedMoreMenu ??
                    defaultMoreMenuItems()
                        .where((e) => e.isActive)
                        .toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      decoration: BoxDecoration(
                        color: MetoColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              S.t('nav_more'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                          if (isAdmin) ...[
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                unawaited(_openMoreMenuAdmin());
                              },
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('Yönet'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (snap.connectionState == ConnectionState.waiting &&
                        snap.data == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.link == 'aile_kocu'
                                    ? const Color(0xFFE8F5E9)
                                    : MetoColors.primary
                                        .withValues(alpha: 0.12),
                                child: _moreMenuLeading(item),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: item.subtitle.isEmpty
                                  ? null
                                  : Text(
                                      item.subtitle,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(ctx);
                                unawaited(_openMoreMenuItem(item));
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _moreMenuLeading(MoreMenuItem item) {
    if (item.icon == 'eye' || item.link == 'cvi') {
      return SvgPicture.asset(
        'assets/cvi/eye_icon.svg',
        width: 22,
        height: 22,
      );
    }
    final IconData icon;
    final Color color;
    switch (item.icon) {
      case 'family':
        icon = Icons.family_restroom;
        color = Colors.green.shade700;
      case 'balance':
        icon = Icons.balance_outlined;
        color = MetoColors.primary;
      case 'grid':
        icon = Icons.grid_view_outlined;
        color = MetoColors.primary;
      case 'search':
        icon = Icons.search;
        color = MetoColors.primary;
      case 'extension':
        icon = Icons.extension_outlined;
        color = MetoColors.primary;
      default:
        icon = Icons.link;
        color = MetoColors.primary;
    }
    return Icon(icon, color: color);
  }

  Future<void> _openMoreMenuAdmin() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdminMoreMenuSheet(adminEmail: widget.user.email),
    );
    invalidateMoreMenuCache();
  }

  Future<void> _openMoreMenuItem(MoreMenuItem item) async {
    final extraApp = item.isUrl ||
        item.link == 'aile_kocu' ||
        item.link == 'gelisim' ||
        item.link.startsWith('http') ||
        item.link.startsWith('/');
    if (_isGuest && extraApp && item.link != 'haklar' && item.link != 'kartlar' &&
        item.link != 'mchat' && item.link != 'cvi') {
      final ok = await GuestLimitStore.allowTimedTab('daha_fazlasi');
      if (!ok) {
        if (mounted) {
          _requireLogin(
            'Misafir erişimi 2 dakika ile sınırlıdır. Devam etmek için üye olun.',
          );
        }
        return;
      }
      if (!mounted) return;
      final left = await GuestLimitStore.remainingTimedSeconds('daha_fazlasi');
      if (mounted && left > 0) {
        final mins = (left / 60).ceil().clamp(1, 2);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: L10nText(
              'Misafir erişimi: yaklaşık $mins dk. Süre bitince üyelik gerekir.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    if (!mounted) return;

    if (item.isUrl) {
      await InAppWebPage.open(
        context,
        title: item.title,
        url: item.link,
        isGuest: _isGuest,
        onRequireLogin: () => _requireLogin(
          'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
        ),
      );
      return;
    }

    switch (item.link) {
      case 'aile_kocu':
        await openAileKocu(
          context,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(
            'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
          ),
        );
        return;
      case 'haklar':
        _goToTab(MetoTab.haklar);
        return;
      case 'kartlar':
        _goToTab(MetoTab.kartlar);
        return;
      case 'mchat':
        await openMchatFlow(
          context,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(
            'Otizm tarama için giriş yapmanız veya üye olmanız gerekiyor.',
          ),
        );
        return;
      case 'cvi':
        await openCviFlow(
          context,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(
            'CVI egzersizi için giriş yapmanız veya üye olmanız gerekiyor.',
          ),
        );
        return;
      case 'gelisim':
        await GelisimEtkinlikleriPage.open(
          context,
          adminEmail: widget.user.email,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(
            'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
          ),
        );
        return;
      default:
        if (item.link.startsWith('http') || item.link.startsWith('/')) {
          await InAppWebPage.open(
            context,
            title: item.title,
            url: item.link,
            isGuest: _isGuest,
            onRequireLogin: () => _requireLogin(
              'Misafir süresi doldu (2 dk). Devam etmek için giriş yapın veya üye olun.',
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bilinmeyen menü: ${item.link}')),
          );
        }
    }
  }

  /// Alt menü / kaydırma / bildirimlerden sekme değiştir.
  void _goToTab(MetoTab t, {bool animate = true}) {
    if (t != MetoTab.home) {
      _lastExitBackAt = null;
    }
    // Misafir: haklar/kartlar süreye bağlı
    if (_isGuest && (t == MetoTab.haklar || t == MetoTab.kartlar)) {
      unawaited(() async {
        final ok = await _gateTimedTab(t);
        if (!ok || !mounted) return;
        _applyGoToTab(t, animate: animate);
        _armGuestTabTimer(t);
        final key = t == MetoTab.haklar ? 'haklar' : 'kartlar';
        final left = await GuestLimitStore.remainingTimedSeconds(key);
        if (!mounted || left <= 0) return;
        final mins = (left / 60).ceil().clamp(1, 2);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: L10nText(
              'Misafir erişimi: yaklaşık $mins dk. Süre bitince üyelik gerekir.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }());
      return;
    }
    _applyGoToTab(t, animate: animate);
    _armGuestTabTimer(t);
  }

  void _applyGoToTab(MetoTab t, {bool animate = true}) {
    final changed = _activeTab != t || _showMesajlar;
    if (changed) {
      setState(() {
        _showMesajlar = false;
        _activeTab = t;
        if (t == MetoTab.ilanlar) {
          _ilanlarUnread = 0;
          _newIlanlarCount = 0;
        }
        if (t == MetoTab.forum) {
          _newForumCount = 0;
        }
      });
      if (t == MetoTab.ilanlar) {
        unawaited(FeedSeenStore.markIlanlarSeen());
      }
      if (t == MetoTab.forum) {
        unawaited(FeedSeenStore.markForumSeen());
      }
      if (t != MetoTab.ilanlar && t != MetoTab.forum) {
        unawaited(_refreshFeedDots());
      }
    }
    if (_tabPageController.hasClients) {
      final current = _tabPageController.page?.round() ?? _activeTab.index;
      if (current != t.index) {
        _programmaticNavTarget = t;
        // Misafirde animasyon ara sekmelerden geçirip yanlış uyarı verir.
        final useJump = _isGuest || !animate;
        if (useJump) {
          _tabPageController.jumpToPage(t.index);
          _programmaticNavTarget = null;
        } else {
          unawaited(
            _tabPageController
                .animateToPage(
                  t.index,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                )
                .whenComplete(() {
              if (_programmaticNavTarget == t) {
                _programmaticNavTarget = null;
              }
            }),
          );
        }
      }
    }
    if (t == MetoTab.ilanlar && !_isGuest) {
      loadAllIlanlar(preferEmail: widget.user.email).then((_) {
        if (mounted) setState(() {});
      });
    }
    if (t == MetoTab.forum && !_isGuest) {
      // forum kendi yükler
    }
    if (t != MetoTab.ilanlar && t != MetoTab.forum && !_isGuest) {
      unawaited(_refreshFeedDots());
    }
  }

  void _onTabPageChanged(int index) {
    if (index < 0 || index >= MetoTab.values.length) return;
    final t = MetoTab.values[index];
    if (_activeTab == t) return;

    // Programatik geçişte ara sayfalar (home→haklar iken mesajlar) yok sayılır.
    final target = _programmaticNavTarget;
    if (target != null && t != target) {
      return;
    }
    if (target != null && t == target) {
      _programmaticNavTarget = null;
    }

    if (_isGuest && (t == MetoTab.haklar || t == MetoTab.kartlar)) {
      unawaited(() async {
        final ok = await _gateTimedTab(t);
        if (!ok || !mounted) {
          if (_tabPageController.hasClients) {
            _tabPageController.jumpToPage(_activeTab.index);
          }
          return;
        }
        _finishTabPageChange(t);
        _armGuestTabTimer(t);
      }());
      return;
    }
    _finishTabPageChange(t);
    _armGuestTabTimer(t);
  }

  void _finishTabPageChange(MetoTab t) {
    setState(() {
      _showMesajlar = false;
      _activeTab = t;
      if (t == MetoTab.ilanlar) {
        _ilanlarUnread = 0;
        _newIlanlarCount = 0;
      }
      if (t == MetoTab.forum) {
        _newForumCount = 0;
      }
    });
    if (t == MetoTab.ilanlar) {
      unawaited(FeedSeenStore.markIlanlarSeen());
      if (!_isGuest) {
        loadAllIlanlar(preferEmail: widget.user.email).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
    if (t == MetoTab.forum) {
      unawaited(FeedSeenStore.markForumSeen());
    }
    if (t != MetoTab.ilanlar && t != MetoTab.forum) {
      unawaited(_refreshFeedDots());
    }
  }

  Future<void> _loadSohbetOzetleri() async {
    unawaited(touchMyPresence());
    final results = await Future.wait([
      loadSohbetOzetleri(widget.user.email),
      loadBildirimler(),
      loadBlockedEmails(forceRefresh: true),
    ]);
    if (!mounted) return;
    final ozetler = results[0] as List<SohbetOzet>;
    final bildirimler = results[1] as List<AppBildirim>;
    final blocked = results[2] as Set<String>;
    final filtered = [
      for (final o in ozetler)
        if (!blocked.contains(o.peerEmail.trim().toLowerCase())) o,
    ];
    final merged = _mergeUnreadFromBildirim(filtered, bildirimler);
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

  String _peerDisplayName(String peerEmail) {
    final key = peerEmail.trim().toLowerCase();
    for (final b in _bildirimlerInbox) {
      if (b.actorEmail.trim().toLowerCase() == key &&
          b.actorName.trim().isNotEmpty &&
          !b.actorName.contains('@') &&
          !b.actorName.contains('****')) {
        return publicContactLabel(b.actorName);
      }
    }
    final fromIlan = revealedPosterNameForOwner(key);
    if (fromIlan != null &&
        fromIlan.isNotEmpty &&
        !fromIlan.contains('****')) {
      return publicContactLabel(fromIlan);
    }
    return publicContactLabel(peerEmail);
  }

  void _openSohbet(SohbetOzet o) {
    final display = _peerDisplayName(o.peerEmail);
    final peerKey = o.peerEmail.trim().toLowerCase();
    final kisi = SohbetKisi(
      ad: display,
      avatar: contactAvatarLetter(display),
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
          myDisplayName: _publicDisplayName,
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
        title: const L10nText('Bildirimi sil'),
        content: Text(
          b.body.isNotEmpty
              ? '"${scrubEmailsInText(b.body)}" bildirimini silmek istiyor musunuz?'
              : 'Bu bildirimi silmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Sil'),
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
        const SnackBar(content: L10nText('Bildirim silindi')),
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

  Future<bool> _confirmDeleteAllBildirimler() async {
    final visible =
        _bildirimlerInbox.where((b) => !b.isMesaj).toList(growable: false);
    if (visible.isEmpty) return false;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const L10nText('Tüm bildirimleri sil'),
        content: L10nText(
          '${visible.length} bildirim kalıcı olarak silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Tümünü sil'),
          ),
        ],
      ),
    );
    if (onay != true) return false;
    try {
      await deleteAllBildirimler();
      if (!mounted) return true;
      setState(() {
        _bildirimlerInbox = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Tüm bildirimler silindi')),
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
        title: const L10nText('Sohbeti sil'),
        content: L10nText(
          '${_peerDisplayName(o.peerEmail)} ile olan tüm mesajlar silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const L10nText('Sil'),
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
        const SnackBar(content: L10nText('Sohbet silindi')),
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

  Future<void> _openBildirimInbox() async {
    await _loadSohbetOzetleri();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final list =
                _bildirimlerInbox.where((b) => !b.isMesaj).toList();
            final unread = list.where((b) => !b.read).length;
            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: MetoColors.card,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MetoColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: L10nText(
                                'Bildirimler',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (unread > 0)
                              TextButton(
                                onPressed: () async {
                                  await markAllBildirimlerOkundu();
                                  await _loadSohbetOzetleri();
                                  if (mounted) setState(() {});
                                  setModalState(() {});
                                },
                                child: const L10nText('Tümünü okundu'),
                              ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: L10nText(
                                    'Henüz bildiriminiz yok.',
                                    style:
                                        TextStyle(color: MetoColors.mutedFg),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final b = list[i];
                                  return Dismissible(
                                    key: ValueKey('bell_bildirim_${b.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: _bildirimSwipeDeleteBg(
                                      alignStart: false,
                                    ),
                                    confirmDismiss: (_) async {
                                      final ok =
                                          await _confirmDeleteBildirim(b);
                                      if (ok) setModalState(() {});
                                      return ok;
                                    },
                                    child: Material(
                                      color: b.read
                                          ? MetoColors.background
                                          : const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(14),
                                      child: ListTile(
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          await _openBildirim(b);
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          side: BorderSide(
                                            color: b.read
                                                ? MetoColors.border
                                                : const Color(0xFFFDBA74),
                                          ),
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: b.read
                                              ? MetoColors.muted
                                              : (b.isForumLike
                                                  ? const Color(0xFFEC4899)
                                                  : b.isForumFollow
                                                      ? const Color(
                                                          0xFF2563EB)
                                                      : b.isForum
                                                          ? const Color(
                                                              0xFF7C3AED)
                                                          : b.isKredi
                                                              ? const Color(
                                                                  0xFF16A34A)
                                                              : b.isGorus
                                                                  ? const Color(
                                                                      0xFF0EA5E9)
                                                                  : const Color(
                                                                      0xFFEF4444)),
                                          child: Icon(
                                            b.isForumLike
                                                ? Icons.favorite
                                                : b.isForumFollow
                                                    ? Icons
                                                        .notifications_active
                                                    : b.isForumReply
                                                        ? Icons.reply
                                                        : b.isForum
                                                            ? Icons
                                                                .forum_outlined
                                                            : b.isKredi
                                                                ? Icons
                                                                    .payments_outlined
                                                                : b.isGorus
                                                                    ? Icons
                                                                        .feedback_outlined
                                                                    : Icons
                                                                        .campaign_outlined,
                                            color: b.read
                                                ? MetoColors.mutedFg
                                                : Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        title: L10nText(
                                          b.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        subtitle: L10nText(
                                          b.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: b.read
                                            ? null
                                            : Container(
                                                width: 8,
                                                height: 8,
                                                decoration:
                                                    const BoxDecoration(
                                                  color: Color(0xFFEF4444),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (list.isNotEmpty)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final ok =
                                      await _confirmDeleteAllBildirimler();
                                  if (ok) setModalState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: const BorderSide(
                                    color: Color(0xFFEF4444),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const L10nText(
                                  'Tüm bildirimleri sil',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
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

    if (b.isGorus || b.isKredi) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: L10nText(b.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  publicContactLabel(
                    b.actorEmail,
                    preferredName: b.actorName,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  scrubEmailsInText(b.body),
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
                  final name = publicContactLabel(
                    b.actorEmail,
                    preferredName: b.actorName,
                  );
                  final kisi = SohbetKisi(
                    ad: name,
                    avatar: contactAvatarLetter(name),
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
                        myDisplayName: _publicDisplayName,
                      ),
                    ),
                  );
                },
                child: const L10nText('Yanıtla'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const L10nText('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    if (b.isForum) {
      if (!mounted) return;
      final postId = b.forumPostId;
      final commentId = b.forumCommentId;
      if (postId != null && postId > 0) {
        setState(() {
          _openForumPostId = postId;
          _openForumCommentId = commentId;
          _openForumToken++;
        });
      }
      _goToTab(MetoTab.forum);
      return;
    }

    final name = publicContactLabel(
      b.actorEmail,
      preferredName: b.actorName,
    );
    final kisi = SohbetKisi(
      ad: name,
      avatar: contactAvatarLetter(name),
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
          myDisplayName: _publicDisplayName,
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
    final empty = list.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: S.auto('Geri'),
                onPressed: _closeMesajlar,
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: L10nText(
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
                  child: const L10nText(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              IconButton(
                tooltip: S.auto('Yenile'),
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
                    child: L10nText(
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
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final o = list[i];
                      return Dismissible(
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
                            onLongPress: () {
                              final peer = o.peerEmail.trim().toLowerCase();
                              if (!peer.contains('@')) return;
                              showUserSafetySheet(
                                context,
                                targetEmail: peer,
                                targetDisplayName: _peerDisplayName(peer),
                                contextLabel: 'mesajlar',
                                onBlocked: () => _loadSohbetOzetleri(),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                                          contactAvatarLetter(
                                            _peerDisplayName(o.peerEmail),
                                          ),
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
                                          _peerDisplayName(o.peerEmail),
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
                                          scrubEmailsInText(o.lastMsg),
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
                                      L10nText(
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
                      );
                    },
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
      cacheOwnUserPhoto(widget.user.email, cloud.photoData);
      _favoriler = cloud.favorites;
      _bildirimler = cloud.notifications;
    });
    unawaited(
      PushNotificationService.instance.syncTopics(cloud.notifications),
    );
    unawaited(PushNotificationService.instance.registerTokenWithServer());
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
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 80,
    );
    if (file == null) return;
    try {
      final raw = await file.readAsBytes();
      if (raw.isEmpty) throw StateError('Boş görsel seçildi.');
      final optimized = await ImageOptimizeService.forAvatar(raw);
      // DB şişmesin: R2’ye yükle, sadece URL sakla (cihazda da URL önbelleklenir).
      final url = await R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: optimized.fileName,
        contentType: optimized.contentType,
      );
      await upsertUserCloudProfile(
        email: widget.user.email,
        photoData: url,
      );
      await saveProfilFoto(widget.user.email, url);
      cacheOwnUserPhoto(widget.user.email, url);
      if (!mounted) return;
      setState(() => _profilFoto = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Profil fotoğrafı kaydedildi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: L10nText(
            e.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
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
                ? 'Rol: $label. İlan paylaşabilirsiniz; yalnızca 2. el ilanlarına ücretsiz iletişim kurabilirsiniz.'
                : 'Rol: $label. İlan paylaşmak için Aile rolüne geçmeniz gerekir · uzman/bakıcı ilanlarına teklifte 1 puan düşer',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Rol değiştirilemedi: $e')),
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
          const L10nText(
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
                ? 'İlan paylaşabilirsiniz. Yalnızca 2. el ilanlarına ücretsiz iletişim kurabilirsiniz; uzman/bakıcı ilanlarına teklif için Uzman veya Bakıcı rolüne geçin.'
                : 'İlan paylaşmak için Aile rolüne geçin. Uzman ve bakıcı ilanlarına teklifte 1 puan düşer.',
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

  String get _publicDisplayName {
    final ad = _kullaniciProfil.adSoyad.trim();
    if (ad.isNotEmpty && !ad.contains('@')) return ad;
    final n = widget.user.name.trim();
    if (n.isNotEmpty && !n.contains('@')) return n;
    return 'Üye';
  }

  String get _initials {
    final parts = _publicDisplayName.split(RegExp(r'\s+'));
    final letters = parts.map((w) => w.isEmpty ? '' : w[0]).join();
    return letters.toUpperCase().substring(0, letters.length.clamp(0, 2));
  }

  Widget get _body {
    // Harita sekmesi KeepAlive ile canlı tutulur — her girişte yeniden
    // konum/merkez araması tetiklenmesin. Sağa/sola kaydırarak sekmeler arası geçiş.
    return PageView(
      controller: _tabPageController,
      // Sekmeler arası kaydırma açık; mesaj silme yalnız sola kaydırma (endToStart).
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: _onTabPageChanged,
      children: [
        _KeepAliveTab(
          child: HomePage(
            key: ValueKey('home_$_homeRefreshToken'),
            userEmail: widget.user.email,
            isGuest: _isGuest,
            onRequireLogin: () => _requireLogin(),
          ),
        ),
        const _KeepAliveTab(child: MerkezlerPage()),
        IlanlarPage(
          key: _ilanlarPageKey,
          userKredi: _userKredi,
          userEmail: widget.user.email,
          userName: _publicDisplayName,
          userType: _role,
          profilFoto: _profilFoto,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(),
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
          key: _forumPageKey,
          userName: widget.user.name,
          userEmail: widget.user.email,
          userType: _role,
          profilFoto: _profilFoto,
          isGuest: _isGuest,
          onRequireLogin: () => _requireLogin(),
          openPostId: _openForumPostId,
          openCommentId: _openForumCommentId,
          openPostToken: _openForumToken,
        ),
        HaklarPage(adminEmail: widget.user.email),
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
      _showMesajlar = false;
      _showProfilPanel = false;
      _showCocukProfil = false;
      _showIlanlarim = false;
      _showKullaniciProfil = false;
      _showKaydedilenler = false;
      _showBildirimler = false;
      _showHakkinda = false;
      _showEngellenenler = false;
      _showIyilikLiderleri = false;
      _showDilSecimi = false;
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
    if (_isGuest) {
      _requireLogin('Profil için giriş yapmanız gerekiyor.');
      return;
    }
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
        const SnackBar(content: L10nText('Bağlantı açılamadı')),
      );
    }
  }

  void _closeProfilPanel() {
    setState(() {
      _showProfilPanel = false;
      _showCocukProfil = false;
      _showIlanlarim = false;
      _showKullaniciProfil = false;
      _showKaydedilenler = false;
      _showBildirimler = false;
      _showHakkinda = false;
      _showEngellenenler = false;
      _showIyilikLiderleri = false;
      _showDilSecimi = false;
      _profilDragY = 0;
      _resetKredi();
    });
  }

  /// Android sistem geri tuşu:
  /// 1) profil paneli açıksa kapat
  /// 2) ana sayfada değilse ana sayfaya dön (bu 1. basış sayılır)
  /// 3) kısa süre içinde 2. basışta uygulamadan çık
  void _handleSystemBack() {
    if (_showProfilPanel) {
      _lastExitBackAt = null;
      _closeProfilPanel();
      return;
    }

    if (_showMesajlar) {
      _lastExitBackAt = null;
      _closeMesajlar();
      return;
    }

    // Alt sekme içi detay (ilan / forum) önce kapansın
    if (_activeTab == MetoTab.ilanlar &&
        (_ilanlarPageKey.currentState?.consumeBack() ?? false)) {
      _lastExitBackAt = null;
      return;
    }
    if (_activeTab == MetoTab.forum &&
        (_forumPageKey.currentState?.consumeBack() ?? false)) {
      _lastExitBackAt = null;
      return;
    }

    if (_activeTab != MetoTab.home) {
      _goToTab(MetoTab.home);
      _lastExitBackAt = DateTime.now();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Çıkmak için tekrar geri tuşuna basın'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final last = _lastExitBackAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastExitBackAt = now;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: L10nText('Çıkmak için tekrar geri tuşuna basın'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: ShowCaseWidget(
        onFinish: () {
          unawaited(_finishNavTour());
        },
        builder: (context) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: MetoColors.background,
          body: Stack(
            children: [
              Column(
                children: [
                  _BrandBar(
                    initials: _initials,
                    avatarColor: widget.user.avatarColor,
                    photoBytes: _profilFotoBytes,
                    notificationBadge: _bellUnreadCount,
                    messageBadge: _sohbetUnreadCount,
                    messagesTourKey: _messagesTourKey,
                    messagesSelected: _showMesajlar,
                    onBellTap: _openBildirimInbox,
                    onMessagesTap: _openMesajlar,
                    onAvatarTap: _openProfilPanel,
                    onMenuTap: _openProfilPanel,
                    onHomeTap: _goHomeAndRefresh,
                  ),
                  Expanded(child: _showMesajlar ? _buildMesajlarPage() : _body),
                  // Klavye açıkken alt menüyü gizle — yazı alanı yukarı kaçmasın
                  if (!keyboardOpen)
                    _BottomNav(
                      active: _activeTab,
                      tourKeys: _navTourKeys,
                      moreTourKey: _moreNavTourKey,
                      moreActive: !_showMesajlar &&
                          (_activeTab == MetoTab.haklar ||
                              _activeTab == MetoTab.kartlar),
                      ilanlarNewCount: _newIlanlarCount,
                      forumNewCount: _newForumCount,
                      onSelect: (t) => _goToTab(t),
                      onMoreTap: _openMoreSheet,
                      onSkipTour: () {
                        ShowcaseView.get().dismiss();
                        unawaited(_finishNavTour());
                      },
                    ),
                ],
              ),
              if (_showProfilPanel) _buildProfilOverlay(),
            ],
          ),
        );
        },
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
                                S.t('profile_swipe_close'),
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
                                              content: L10nText(
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
                                                      content: L10nText(
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
                                                    : _showDilSecimi
                                                        ? _buildDilSecimi()
                                                        : _showEngellenenler
                                                        ? _buildEngellenenler()
                                                        : _showHakkinda
                                                            ? _buildHakkinda()
                                                            : _showIyilikLiderleri
                                                                ? AdminIyilikLiderleriPanel(
                                                                    onBack: () =>
                                                                        setState(() =>
                                                                            _showIyilikLiderleri =
                                                                                false),
                                                                  )
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
      int views,
    })>[
      ...myUzmanIlanlar(email).map((i) => (
            kind: 'uzman',
            id: i.id,
            kategori: 'Uzman Arıyorum',
            emoji: '🏃',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.budget,
            views: i.views,
          )),
      ...myBakiciIlanlar(email).map((i) => (
            kind: 'bakici',
            id: i.id,
            kategori: 'Bakıcı/Temizlik Görevlisi Arıyorum',
            emoji: '🤝',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.budget,
            views: i.views,
          )),
      ...myIkincielIlanlar(email).map((i) => (
            kind: 'ikinciel',
            id: i.id,
            kategori: '2. El',
            emoji: '♻️',
            title: i.title,
            konum: '${i.district.isEmpty ? '' : '${i.district}, '}${i.city}',
            fiyat: i.price,
            views: i.views,
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
                child: L10nText(
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
                  child: L10nText(
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
          const L10nText(
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
                    });
                    _openMesajlar();
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
                      contactAvatarLetter(
                        publicContactLabel(
                          b.actorEmail,
                          preferredName: b.actorName,
                        ),
                      ),
                      style: TextStyle(
                        color: b.read ? MetoColors.mutedFg : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    scrubEmailsInText(b.body),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: b.read ? FontWeight.w500 : FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: S.auto('Sil'),
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
          const L10nText(
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
                const L10nText('📋', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                const L10nText(
                  'Henüz ilanınız yok',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                const L10nText(
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
                  label: const L10nText(
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
                            child: L10nText(
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
                        L10nText(
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
                        L10nText(
                          '${e.konum} · ${formatPriceTl(e.fiyat)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '👁 ${ilanViewLabel(e.views)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                        if (teklifler.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          L10nText(
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
                      tooltip: S.auto('Teklifleri gör'),
                      onPressed: () {
                        final b = teklifler.first;
                        setState(() {
                          _showIlanlarim = false;
                          _showProfilPanel = false;
                        });
                        _openMesajlar();
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
                    tooltip: S.auto('Satıldı olarak işaretle'),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const L10nText('Satıldığını onaylıyor musunuz?'),
                          content: L10nText(
                            '"${e.title}" ilanı satıldı olarak işaretlenecek ve yayından kalkacak.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const L10nText('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFCA8A04),
                              ),
                              child: const L10nText('Evet, satıldı'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !mounted) return;
                      await markIlanSold(
                        email: widget.user.email,
                        kind: e.kind,
                        id: e.id,
                      );
                      if (!mounted) return;
                      setState(() {});
                      _persistIlanlar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: L10nText(
                            'İlan satıldı olarak işaretlendi ve yayından kaldırıldı',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.sell_outlined,
                      color: Color(0xFFCA8A04),
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: S.auto('İlanı düzenle'),
                    onPressed: () => _openEditIlanFromProfil(e.kind, e.id),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: MetoColors.primary,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: S.auto('İlanı sil'),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const L10nText('İlanı sil'),
                          content: L10nText(
                            '"${e.title}" ilanını silmek istediğinize emin misiniz?',
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
                      await deleteUserIlan(
                        email: widget.user.email,
                        kind: e.kind,
                        id: e.id,
                      );
                      if (!mounted) return;
                      setState(() {});
                      _persistIlanlar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: L10nText('İlan silindi')),
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
                child: L10nText(
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
                L10nText('❤️', style: TextStyle(fontSize: 28)),
                SizedBox(height: 8),
                L10nText(
                  'Henüz favori ilan yok',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.foreground,
                  ),
                ),
                SizedBox(height: 4),
                L10nText(
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
                        L10nText(
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
                              if (f.fiyat.isNotEmpty) formatPriceTl(f.fiyat),
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
                    tooltip: S.auto('Favoriden çıkar'),
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
      unawaited(PushNotificationService.instance.syncTopics(next));
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
                child: L10nText(
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
                : 'Tercihleriniz hesabınıza kaydedilir; çıkış yapınca da korunur. Push bildirimleri (telefon) bu anahtarlara bağlıdır.',
            style: const TextStyle(fontSize: 12, color: MetoColors.foreground),
          ),
        ),
        toggleRow(
          emoji: '📋',
          title: 'Yeni ilanlar',
          sub: 'Yeni ilan paylaşıldığında bildirim',
          value: _bildirimler.ilanlar,
          onChanged: (v) => save(_bildirimler.copyWith(ilanlar: v)),
        ),
        toggleRow(
          emoji: '💬',
          title: 'Forum paylaşımları',
          sub: 'Yeni forum gönderisi bildirimi',
          value: _bildirimler.forum,
          onChanged: (v) => save(_bildirimler.copyWith(forum: v)),
        ),
        toggleRow(
          emoji: '✉️',
          title: 'Mesajlar',
          sub: 'Teklif ve sohbet bildirimleri',
          value: _bildirimler.mesajlar,
          onChanged: (v) => save(_bildirimler.copyWith(mesajlar: v)),
        ),
        toggleRow(
          emoji: '📣',
          title: 'Duyurular / Haberler',
          sub: 'Görselli haber ve duyuru bildirimleri',
          value: _bildirimler.duyurular,
          onChanged: (v) => save(_bildirimler.copyWith(duyurular: v)),
        ),
      ],
    );
  }

  Widget _buildProfilMenu() {
    final tip = switch (_role) {
      'uzman' => S.t('profile_role_expert'),
      'bakici' => S.t('profile_role_care'),
      _ => S.t('profile_role_family'),
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
                          ? S.t('profile_complete')
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
                          ? S.t('profile_photo_add')
                          : S.t('profile_photo_hint'),
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
                          S.t('profile_verified'),
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
        if (isAppAdmin(widget.user.email)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _menuTile(
              emoji: '💚',
              label: 'İyilik Puanı Liderleri',
              sub: 'En yüksek 10 · ekran görüntüsü için',
              highlight: true,
              onTap: () => setState(() => _showIyilikLiderleri = true),
            ),
          ),
        ],
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
                const L10nText('🎁', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const L10nText(
                        'Hoş Geldin Hediyesi!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      L10nText(
                        'Sisteme kayıt olduğunuz için hesabınıza $kWelcomeKredi ücretsiz puan tanımlandı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      L10nText(
                        '1 teklif = 1 puan = ₺69,90',
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
                        L10nText(
                          '1 teklif = 1 puan = ₺69,90 · Uzman & bakıcı ortak bakiye',
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
            label: S.t('menu_my_profile'),
            sub: _kullaniciProfil.menuSub,
            onTap: () => setState(() => _showKullaniciProfil = true),
          ),
        ),
        if (_role == 'aile')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _menuTile(
              emoji: '👶',
              label: S.t('menu_child_profile'),
              sub: _cocukProfil.menuSub,
              onTap: () => setState(() => _showCocukProfil = true),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '📋',
            label: S.t('menu_my_listings'),
            sub: _teklifBildirimUnread > 0
                ? S.t('menu_new_offers').replaceAll('{n}', '$_teklifBildirimUnread')
                : (_ilanlarimCount == 0
                    ? S.t('menu_my_listings_empty')
                    : S.t('menu_my_listings_active').replaceAll('{n}', '$_ilanlarimCount')),
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
            label: S.t('menu_saved'),
            sub: _favoriler.isEmpty
                ? S.t('menu_saved_empty')
                : S.t('menu_saved_count').replaceAll('{n}', '${_favoriler.length}'),
            onTap: () => setState(() => _showKaydedilenler = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🔔',
            label: S.t('menu_notifications'),
            sub: _bildirimler.menuSub,
            onTap: () => setState(() => _showBildirimler = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🗣️',
            label: S.t('menu_language'),
            sub:
                '${LocaleController.instance.lang.flagEmoji} ${LocaleController.instance.lang.nativeLabel}',
            onTap: () => setState(() => _showDilSecimi = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🚫',
            label: S.t('menu_blocked'),
            sub: S.t('menu_blocked_sub'),
            onTap: () => setState(() => _showEngellenenler = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: 'ℹ️',
            label: S.t('menu_about'),
            sub: S.t('menu_about_sub'),
            onTap: () => setState(() => _showHakkinda = true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '⚖️',
            label: S.t('menu_terms'),
            sub: S.t('menu_terms_sub'),
            onTap: () {
              _closeProfilPanel();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const LegalDocumentPage(kind: LegalDocKind.terms),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '⚕️',
            label: S.t('menu_info_note'),
            sub: S.t('menu_info_note_sub'),
            onTap: () {
              _closeProfilPanel();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TibbiSorumlulukReddiPage(),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🔒',
            label: S.t('menu_privacy'),
            sub: S.t('menu_privacy_sub'),
            onTap: () {
              _closeProfilPanel();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const LegalDocumentPage(kind: LegalDocKind.privacy),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '💬',
            label: S.t('menu_feedback'),
            sub: S.t('menu_feedback_sub'),
            highlight: true,
            onTap: () => _showIletisimModal(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _menuTile(
            emoji: '🗑️',
            label: S.t('menu_delete'),
            sub: S.t('menu_delete_sub'),
            danger: true,
            onTap: _showHesapSilDialog,
          ),
        ),
        _menuTile(
          emoji: '🚪',
          label: S.t('logout'),
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
              _showHakkinda = false;
              _showEngellenenler = false;
              _showIyilikLiderleri = false;
      _showDilSecimi = false;
            });
            clearRuntimeIlanlar();
            widget.onLogout();
          },
        ),
      ],
    );
  }

  Widget _buildDilSecimi() {
    final current = LocaleController.instance.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showDilSecimi = false),
                icon: const Icon(Icons.arrow_back),
                tooltip: S.t('back'),
              ),
              Expanded(
                child: Text(
                  S.t('lang_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          S.t('lang_hint'),
          style: const TextStyle(
            fontSize: 13,
            color: MetoColors.mutedFg,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        for (final lang in AppLang.values) ...[
          Material(
            color: lang == current
                ? MetoColors.primary.withValues(alpha: 0.10)
                : MetoColors.background,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: lang == current
                      ? MetoColors.primary
                      : MetoColors.border,
                ),
              ),
              leading: Text(lang.flagEmoji, style: const TextStyle(fontSize: 22)),
              title: Text(
                lang.nativeLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: lang == current
                  ? const Icon(Icons.check_circle, color: MetoColors.primary)
                  : null,
              onTap: () async {
                await LocaleController.instance.setLang(lang);
                if (!mounted) return;
                setState(() => _showDilSecimi = false);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.t('lang_applied'))),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildEngellenenler() {
    return FutureBuilder<List<BlockedUser>>(
      future: loadBlockedUsers(forceRefresh: true),
      builder: (context, snap) {
        final list = snap.data ?? const <BlockedUser>[];
        final loading = snap.connectionState == ConnectionState.waiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _showEngellenenler = false),
                    style:
                        IconButton.styleFrom(backgroundColor: MetoColors.muted),
                    icon: const Icon(Icons.arrow_back, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: L10nText(
                      'Engellenenler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: S.auto('Yenile'),
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
            ),
            const L10nText(
              'Engellediğiniz kullanıcılar size mesaj gönderemez; sohbetleri listede görünmez.',
              style: TextStyle(
                fontSize: 12,
                color: MetoColors.mutedFg,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: L10nText(
                  'Engellenen kullanıcı yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MetoColors.mutedFg),
                ),
              )
            else
              ...list.map((b) {
                final name = _peerDisplayName(b.email);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            MetoColors.primary.withValues(alpha: 0.85),
                        child: Text(
                          contactAvatarLetter(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await unblockUser(b.email);
                            if (!mounted) return;
                            setState(() {});
                            unawaited(_loadSohbetOzetleri());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: L10nText('$name engeli kaldırıldı.'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: L10nText('Kaldırılamadı: $e')),
                            );
                          }
                        },
                        child: const L10nText(
                          'Engeli kaldır',
                          style: TextStyle(
                            color: MetoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildHakkinda() {
    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
        );

    Widget body(String text) => Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: MetoColors.mutedFg,
            fontWeight: FontWeight.w500,
          ),
        );

    Widget feature({
      required String title,
      required String desc,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showHakkinda = false),
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: L10nText(
                  'Hakkında',
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle('Engelsiz Club'),
              body(
                'Engelsiz Club, özel gereksinimli bireylerin ve ailelerinin '
                'yaşamını kolaylaştırmak, ihtiyaç duydukları bilgiye, haklara '
                've toplumsal destek ağlarına en hızlı şekilde ulaşmalarını '
                'sağlamak amacıyla geliştirilmiş kapsamlı bir dayanışma ve '
                'rehberlik platformudur.',
              ),
              const SizedBox(height: 12),
              body(
                'Yola çıkış amacımız; engelli bireylerin toplumsal hayata tam '
                've etkin katılımını desteklemek, ailelerin hayatını '
                'zorlaştıran süreçlerde rehberlik etmek ve yardımlaşma '
                'köprüleri kurmaktır.',
              ),
              const SizedBox(height: 20),
              sectionTitle('Uygulamamızda Neler Bulabilirsiniz?'),
              feature(
                title: 'Bilgi Kütüphanesi',
                desc:
                    'Özel gereksinimli bireyler ve aileler için bilgilendirme '
                    'amaçlı içerikler sunar. Bu bölüm klinik hizmet değildir; '
                    'kaynaklara ve topluluk bilgisine erişimi kolaylaştırır.',
              ),
              feature(
                title: 'Harita ve Lokasyonlar',
                desc:
                    'Yakındaki destek merkezlerini ve kamuya açık konumları '
                    'bulmanıza yardımcı olur.',
              ),
              feature(
                title: 'İlanlar Platformu',
                desc:
                    'Yardımcı ekipman satıcılarını bulmak, bakıcı ilanları yayınlamak '
                    've ikinci el ekipman paylaşımı için dayanışma alanı sunar.',
              ),
              feature(
                title: 'Topluluk & Forum',
                desc:
                    'Ailelerin birbirleriyle iletişim kurmasını ve bilgi '
                    'paylaşımını destekleyen topluluk alanıdır.',
              ),
              feature(
                title: 'Haklar ve Mevzuat',
                desc:
                    'Engelli hakları, sosyal yardımlar ve yasal düzenlemeler '
                    'hakkında bilgilendirme amaçlı rehberlik sunar.',
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MetoColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: MetoColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const L10nText(
                          'Platform Hakkında',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    body(
                      'Engelsiz Club sosyal destek ve topluluk platformudur; '
                      'klinik hizmet sunmaz.\n\n'
                      'Uygulamanın amacı;\n'
                      '• ailelerin birbirleriyle iletişim kurmasını sağlamak\n'
                      '• bilgi paylaşımını desteklemek\n'
                      '• destek merkezlerini bulmak\n'
                      '• yardımcı ekipman satıcılarını bulmak\n'
                      '• bakıcı ilanları yayınlamak\n'
                      '• ikinci el ekipman paylaşımını sağlamak\n'
                      '• açık bilimsel kaynaklarda arama kolaylığı sunmaktır.\n\n'
                      'Uygulama hiçbir şekilde kişisel tavsiye üretmez.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TibbiSorumlulukReddiPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MetoColors.primary,
                          side: const BorderSide(color: MetoColors.primary),
                        ),
                        child: const L10nText('Bilgilendirme Notu'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MetoColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const L10nText(
                  'Engelsiz Club ile kimse yalnız değil; engelleri birlikte aşıyoruz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: MetoColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showHesapSilDialog() async {
    final email = widget.user.email.trim();
    final onay = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const L10nText('Hesabımı sil'),
        content: const L10nText(
          'Hesabınız ve ilişkili verileriniz silme sürecine alınır. '
          'Bu işlem geri alınamaz.\n\n'
          'Onayladığınızda destek ekibimize e-posta ile talep gönderilir. '
          'Detaylı bilgi için hesap silme sayfasını da inceleyebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const L10nText('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(
                'https://engelsizclub-e5842.web.app/delete-account.html',
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const L10nText('Bilgi sayfası'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Silme talebi gönder'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    final mailto = Uri.parse(
      'mailto:sakir.caykara@gmail.com'
      '?subject=${Uri.encodeComponent('Engelsiz Club Hesap Silme Talebi')}'
      '&body=${Uri.encodeComponent(
        'Merhaba,\n\nEngelsiz Club hesabımın ve ilişkili verilerimin '
        'silinmesini talep ediyorum.\n\nHesap e-posta adresim: $email\n\n'
        'Teşekkürler.',
      )}',
    );
    final ok = await launchUrl(mailto);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-posta açılamadı. sakir.caykara@gmail.com adresine yazın.',
          ),
        ),
      );
    }
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
              L10nText(
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
        const L10nText(
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
                                L10nText(
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
                                    child: const L10nText(
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
                            L10nText(
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
        L10nText(
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
                    L10nText(
                      'Ödenecek Tutar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    L10nText(
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
          title: const L10nText('Mağaza ödemesi'),
          content: const L10nText(
            'Ödeme yalnızca Android (Google Play) veya iPhone/iPad (App Store) '
            'uygulamasında yapılır.\n\n'
            'Play Console / App Store Connect’te point_1, point_5, point_10, '
            'point_30, point_50, point_100 ürünlerini tanımlayın; '
            'mağaza, payınıza düşen tutarı hesabınıza yatırır.\n\n'
            'Web tarayıcıda mağaza ödemesi desteklenmez.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const L10nText('Tamam'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _odemeYukleniyor = true);
    unawaited(
      _showCenteredLoading('${store.storeName} açılıyor…'),
    );
    try {
      if (store.isAndroid) {
        final playOk = await isGooglePlayAvailable();
        if (!playOk) {
          _hideCenteredLoading();
          if (mounted) {
            _showCenteredNotice(
              'Google Play şu an kullanılamıyor. Play Store ve Google Play '
              'Hizmetleri’nin güncel ve açık olduğundan emin olun, ardından '
              'uygulamayı yeniden başlatın.',
            );
          }
          return;
        }
      }
      await _initStoreBilling();
      final ok = await store.buyKrediPaket(paket.adet);
      _hideCenteredLoading();
      if (!ok && mounted) {
        _showCenteredNotice(
          'Ürün bulunamadı. ${store.storeName}’da point_1…point_100 ürünleri tanımlı ve etkin mi kontrol edin.',
        );
      }
    } catch (e) {
      _hideCenteredLoading();
      if (mounted) {
        _showCenteredNotice('${store.storeName} ödeme başlatılamadı: $e');
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
  late LocationData _loc;
  bool _saving = false;

  bool get _isUzman => widget.role == 'uzman';
  bool get _isBakici => widget.role == 'bakici';
  bool get _isAile => !_isUzman && !_isBakici;

  String get _roleLabel => _isUzman
      ? 'Uzman'
      : _isBakici
          ? 'Bakıcı'
          : 'Aile';

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
    _loc = p.location.countryCode.isEmpty && p.sehir.isEmpty
        ? LocationData(
            countryCode: countryCodeForLang(LocaleController.instance.lang),
          )
        : p.location;
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
        const SnackBar(content: L10nText('Lütfen ad ve soyadınızı girin')),
      );
      return;
    }
    setState(() => _saving = true);
    widget.onSaved(KullaniciProfil(
      adSoyad: _adSoyad.text.trim(),
      countryCode: _loc.countryCode,
      sehir: _loc.legacyCity,
      ilce: _loc.legacyDistrict,
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
                child: L10nText(
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
          child: L10nText(
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
        LocationCascadePicker(
          value: _loc,
          requireFullSelection: false,
          showAnywhereOption: false,
          onChanged: (loc) => setState(() => _loc = loc),
        ),
        const SizedBox(height: 14),
        if (_isUzman) ...[
          _field('Meslek / Uzmanlık Unvanı', _meslek,
              'Örn. Fizyoterapist, Dil Terapisti'),
          _field('Eğitim', _egitim, 'Okul, bölüm ve mezuniyet yılı'),
          _field('Deneyim', _deneyim, 'Örn. 8 yıl'),
          _field('Çalışma Alanları', _uzmanliklar,
              'Durumlar, destek ve uzmanlık alanları',
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
        const SnackBar(content: L10nText('Lütfen çocuğun adını girin')),
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
                child: L10nText(
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
          child: const L10nText(
            'Durum ve gelişim bilgileri yalnızca sizin hesabınızda saklanır; ilan ve tekliflerde otomatik paylaşılmaz.',
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
        _label('Durum(lar)'),
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
        SnackBar(content: L10nText('Gönderilemedi: $e')),
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
                          L10nText(
                            'İletişim',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          L10nText(
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
                      const L10nText(
                        'İletildi!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const L10nText(
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
                        child: const L10nText(
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
                        const L10nText(
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
                            hintText: S.auto('Kısaca konuyu yazın...'),
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
                            hintText: S.auto('Detaylı olarak açıklayın...'),
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
                              L10nText('📧', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Expanded(
                                child: L10nText(
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
    this.onBellTap,
    this.onMessagesTap,
    this.photoBytes,
    this.notificationBadge = 0,
    this.messageBadge = 0,
    this.messagesTourKey,
    this.messagesSelected = false,
  });

  final String initials;
  final Color avatarColor;
  final VoidCallback onAvatarTap;
  final VoidCallback onMenuTap;
  final VoidCallback onHomeTap;
  final VoidCallback? onBellTap;
  final VoidCallback? onMessagesTap;
  final Uint8List? photoBytes;
  final int notificationBadge;
  final int messageBadge;
  final GlobalKey? messagesTourKey;
  final bool messagesSelected;

  Widget _badgeIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required int badge,
    bool selected = false,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: selected
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFF1A6B4A), width: 1.5),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final messagesButton = _badgeIcon(
      icon: messagesSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
      tooltip: S.auto('Mesajlar'),
      onPressed: onMessagesTap,
      badge: messageBadge,
      selected: messagesSelected,
    );

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
                      child: L10nText(
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
          _badgeIcon(
            icon: Icons.notifications_outlined,
            tooltip: S.auto('Bildirimler'),
            onPressed: onBellTap,
            badge: notificationBadge,
          ),
          if (messagesTourKey != null)
            Showcase(
              key: messagesTourKey!,
              title: 'Mesajlar',
              description:
                  'Anlaştığın uzmanlar ve bakıcılarla güvenle mesajlaş, iletişimde kal.',
              child: messagesButton,
            )
          else
            messagesButton,
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
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
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onMenuTap,
            tooltip: S.auto('Menü'),
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
    required this.onMoreTap,
    required this.tourKeys,
    required this.moreTourKey,
    this.moreActive = false,
    this.ilanlarNewCount = 0,
    this.forumNewCount = 0,
    this.onSkipTour,
  });

  final MetoTab active;
  final ValueChanged<MetoTab> onSelect;
  final VoidCallback onMoreTap;
  final Map<MetoTab, GlobalKey> tourKeys;
  final GlobalKey moreTourKey;
  final bool moreActive;
  final int ilanlarNewCount;
  final int forumNewCount;
  final VoidCallback? onSkipTour;

  static List<(MetoTab, String, IconData, IconData, String)> get _primaryItems => [
    (
      MetoTab.home,
      S.t('nav_home'),
      Icons.home_outlined,
      Icons.home,
      S.t('tour_home'),
    ),
    (
      MetoTab.merkezler,
      S.t('nav_map'),
      Icons.place_outlined,
      Icons.place,
      S.t('tour_map'),
    ),
    (
      MetoTab.ilanlar,
      S.t('nav_listings'),
      Icons.work_outline,
      Icons.work,
      S.t('tour_listings'),
    ),
    (
      MetoTab.forum,
      S.t('nav_forum'),
      Icons.forum_outlined,
      Icons.forum,
      S.t('tour_forum'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryItems = _primaryItems;
    final primaryActive =
        active == MetoTab.home ||
        active == MetoTab.merkezler ||
        active == MetoTab.ilanlar ||
        active == MetoTab.forum;

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
          for (final item in primaryItems)
            Expanded(
              child: Showcase(
                key: tourKeys[item.$1]!,
                title: item.$2,
                description: item.$5,
                tooltipActions: [
                  TooltipActionButton(
                    type: TooltipDefaultActionType.skip,
                    name: S.t('nav_skip'),
                    onTap: onSkipTour,
                  ),
                ],
                child: _NavItem(
                  label: item.$2,
                  icon: (primaryActive && active == item.$1)
                      ? item.$4
                      : item.$3,
                  active: primaryActive && active == item.$1,
                  badge: item.$1 == MetoTab.ilanlar
                      ? ilanlarNewCount
                      : item.$1 == MetoTab.forum
                          ? forumNewCount
                          : 0,
                  onTap: () => onSelect(item.$1),
                ),
              ),
            ),
          Expanded(
            child: Showcase(
              key: moreTourKey,
              title: S.t('nav_more'),
              description: S.t('tour_more'),
              tooltipActions: [
                TooltipActionButton(
                  type: TooltipDefaultActionType.skip,
                  name: S.t('nav_skip'),
                  onTap: onSkipTour,
                ),
              ],
              child: _NavItem(
                label: S.t('nav_more'),
                icon: Icons.more_horiz,
                iconSize: 34,
                active: moreActive,
                onTap: onMoreTap,
              ),
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
    this.iconSize,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badge;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = iconSize ?? (active ? 27.0 : 26.0);
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
                  width: 52,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? MetoColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
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
                    size: resolvedSize,
                    color: active ? Colors.white : MetoColors.mutedFg,
                  ),
                ),
                if (badge > 0 && !active)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: MetoColors.card, width: 1.5),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
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
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: label.length > 7 ? 10 : 11,
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
