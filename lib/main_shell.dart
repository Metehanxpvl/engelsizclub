import 'package:flutter/material.dart';

import 'home_page.dart';
import 'meto_theme.dart';
import 'pages/forum_page.dart';
import 'pages/haklar_page.dart';
import 'pages/ilanlar_page.dart';
import 'pages/kartlar_page.dart';
import 'pages/merkezler_page.dart';

enum MetoTab { home, merkezler, ilanlar, forum, haklar, kartlar }

enum _KrediStep { paket, kart, basarili }

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
  });

  final AuthUser user;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MetoTab _activeTab = MetoTab.home;
  bool _showProfilPanel = false;
  bool _krediSatin = false;
  late int _userKredi;
  bool _krediHosBonusGosterildi = false;
  int _ilanlarUnread = 0;

  _KrediStep _krediStep = _KrediStep.paket;
  _KrediPaket? _seciliPaket;
  bool _odemeYukleniyor = false;
  final _kartNo = TextEditingController();
  final _kartAd = TextEditingController();
  final _kartSkt = TextEditingController();
  final _kartCvv = TextEditingController();

  static const List<_KrediPaket> _krediPaketleri = [
    (
      adet: 1,
      fiyat: '₺49,90',
      birim: '₺49,90/kredi',
      desc: 'Tek teklif için',
      popular: false,
    ),
    (
      adet: 5,
      fiyat: '₺199,90',
      birim: '₺39,98/kredi',
      desc: 'En çok tercih edilen · %20 indirim',
      popular: true,
    ),
    (
      adet: 10,
      fiyat: '₺349,90',
      birim: '₺34,99/kredi',
      desc: 'Avantajlı paket · %30 indirim',
      popular: false,
    ),
  ];

  bool get _isProf =>
      widget.user.userType == 'uzman' || widget.user.userType == 'bakici';

  @override
  void initState() {
    super.initState();
    _userKredi = _isProf ? 10 : 3;
  }

  @override
  void dispose() {
    _kartNo.dispose();
    _kartAd.dispose();
    _kartSkt.dispose();
    _kartCvv.dispose();
    super.dispose();
  }

  void _resetKredi() {
    _krediSatin = false;
    _krediStep = _KrediStep.paket;
    _seciliPaket = null;
    _odemeYukleniyor = false;
    _kartNo.clear();
    _kartAd.clear();
    _kartSkt.clear();
    _kartCvv.clear();
  }

  bool get _kartValid =>
      _kartNo.text.replaceAll(' ', '').length == 16 &&
      _kartAd.text.trim().length > 3 &&
      _kartSkt.text.length == 5 &&
      _kartCvv.text.length >= 3;

  void _handleOde() {
    final paket = _seciliPaket;
    if (!_kartValid || paket == null) return;
    setState(() => _odemeYukleniyor = true);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _userKredi += paket.adet;
        _odemeYukleniyor = false;
        _krediStep = _KrediStep.basarili;
      });
    });
  }

  String get _initials {
    final parts = widget.user.name.trim().split(RegExp(r'\s+'));
    final letters = parts.map((w) => w.isEmpty ? '' : w[0]).join();
    return letters.toUpperCase().substring(0, letters.length.clamp(0, 2));
  }

  Widget get _body {
    switch (_activeTab) {
      case MetoTab.home:
        return const HomePage();
      case MetoTab.merkezler:
        return const MerkezlerPage();
      case MetoTab.ilanlar:
        return IlanlarPage(
          userKredi: _userKredi,
          onKrediHarca: () => setState(() {
            _userKredi = (_userKredi - 1).clamp(0, 9999);
          }),
          onUnreadChange: (n) {
            if (_ilanlarUnread == n) return;
            setState(() => _ilanlarUnread = n);
          },
          onOpenKrediYukle: () => setState(() {
            _resetKredi();
            _showProfilPanel = true;
            _krediSatin = true;
          }),
        );
      case MetoTab.forum:
        return const ForumPage();
      case MetoTab.haklar:
        return const HaklarPage();
      case MetoTab.kartlar:
        return const KartlarPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _StatusBar(
                  initials: _initials,
                  avatarColor: widget.user.avatarColor,
                  onAvatarTap: () => setState(() {
                    _resetKredi();
                    _showProfilPanel = true;
                  }),
                ),
                Expanded(child: _body),
                _BottomNav(
                  active: _activeTab,
                  ilanlarUnread: _ilanlarUnread,
                  onSelect: (t) => setState(() {
                    _activeTab = t;
                    if (t == MetoTab.ilanlar) _ilanlarUnread = 0;
                  }),
                ),
              ],
            ),
            if (_showProfilPanel) _buildProfilOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _showProfilPanel = false;
                _resetKredi();
              }),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MetoColors.muted,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: _krediSatin
                            ? _buildKrediSatin()
                            : _buildProfilMenu(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilMenu() {
    final tip =
        widget.user.userType == 'uzman' || widget.user.userType == 'bakici'
            ? '💼 Uzman'
            : '👨‍👩‍👧 Aile';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 20),
          child: Row(
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
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
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
                        'Sisteme kayıt olduğunuz için hesabınıza 10 ücretsiz kredi tanımlandı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 kredi = 1 teklif = ₺49,90 değerinde',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _krediHosBonusGosterildi = true),
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
                      'Mevcut Krediniz',
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
                          const TextSpan(
                            text: 'kredi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '1 kredi = 1 teklif · ₺49,90 değerinde',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('🪙', style: TextStyle(fontSize: 36)),
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
          label: const Text(
            'Kredi Yükle',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 16),
        ...[
          ('👶', 'Çocuk Profilim', 'Tanı ve gelişim bilgileri'),
          ('📋', 'İlanlarım', '2 aktif ilan'),
          ('❤️', 'Kaydedilenler', '8 ilan favorilendi'),
          ('🔔', 'Bildirimler', 'Açık'),
          ('🔒', 'Gizlilik & Güvenlik', 'Ayarlarınız'),
        ].map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _menuTile(
              emoji: item.$1,
              label: item.$2,
              sub: item.$3,
              onTap: () {},
            ),
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
            setState(() => _showProfilPanel = false);
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
      builder: (_) => const _IletisimSheet(),
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
                  if (_krediStep == _KrediStep.kart) {
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
                  _KrediStep.paket => 'Kredi Yükle',
                  _KrediStep.kart => 'Kart Bilgileri',
                  _KrediStep.basarili => 'Ödeme Başarılı',
                },
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              if (_krediStep != _KrediStep.basarili) ...[
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
            ],
          ),
        ),
        if (_krediStep == _KrediStep.paket) _buildKrediPaketStep(),
        if (_krediStep == _KrediStep.kart) _buildKrediKartStep(),
        if (_krediStep == _KrediStep.basarili) _buildKrediBasariliStep(),
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
              const Text(
                'Mevcut krediniz',
                style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
              ),
              Text(
                '🪙 $_userKredi kredi',
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
                  _krediStep = _KrediStep.kart;
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
                                  '${p.adet} Kredi',
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
                              p.birim,
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
                        p.fiyat,
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔒', style: TextStyle(fontSize: 14)),
            SizedBox(width: 6),
            Text(
              '256-bit SSL şifreli güvenli ödeme',
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Ödeme güvenli şekilde işlenir. Kredi satın alındıktan sonra iade edilmez.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: MetoColors.mutedFg),
        ),
      ],
    );
  }

  Widget _buildKrediKartStep() {
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
                      'Seçilen Paket',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paket.adet} Kredi',
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
                paket.fiyat,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _kartField(
          label: 'Kart Numarası',
          controller: _kartNo,
          hint: '0000 0000 0000 0000',
          keyboardType: TextInputType.number,
          maxLength: 19,
          formatter: _formatKartNo,
          suffix: _kartNo.text.startsWith('5') ? '🟠' : '💳',
        ),
        const SizedBox(height: 12),
        _kartField(
          label: 'Kart Üzerindeki Ad',
          controller: _kartAd,
          hint: 'AD SOYAD',
          formatter: (v) => v.toUpperCase(),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _kartField(
                label: 'Son Kullanma',
                controller: _kartSkt,
                hint: 'AA/YY',
                keyboardType: TextInputType.number,
                maxLength: 5,
                formatter: _formatSkt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kartField(
                label: 'CVV',
                controller: _kartCvv,
                hint: '•••',
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscure: true,
                formatter: (v) => v.replaceAll(RegExp(r'\D'), ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: MetoColors.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                '🔒 SSL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              Text(
                '🛡️ 3D Secure',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              Text(
                '✅ PCI DSS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _kartValid && !_odemeYukleniyor ? _handleOde : null,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: MetoColors.primary.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _odemeYukleniyor
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'İşleniyor...',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                )
              : Text(
                  '🔒 ${paket.fiyat} Öde · ${paket.adet} Kredi Al',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kredi satın alındıktan sonra iade edilmez.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: MetoColors.mutedFg),
        ),
      ],
    );
  }

  Widget _buildKrediBasariliStep() {
    final paket = _seciliPaket;
    if (paket == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Text('✅', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ödeme Başarılı!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${paket.adet} kredi hesabınıza eklendi.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: MetoColors.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Yeni bakiyeniz',
                style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
              ),
              Text(
                '🪙 $_userKredi kredi',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() {
            _resetKredi();
            _showProfilPanel = false;
          }),
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Tamam',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  static String _formatKartNo(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final capped = digits.substring(0, digits.length.clamp(0, 16));
    final groups = <String>[];
    for (var i = 0; i < capped.length; i += 4) {
      groups.add(capped.substring(i, (i + 4).clamp(0, capped.length)));
    }
    return groups.join(' ');
  }

  static String _formatSkt(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final capped = digits.substring(0, digits.length.clamp(0, 4));
    if (capped.length <= 2) return capped;
    return '${capped.substring(0, 2)}/${capped.substring(2)}';
  }

  Widget _kartField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String Function(String) formatter,
    TextInputType? keyboardType,
    int? maxLength,
    bool obscure = false,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLength: maxLength,
          onChanged: (value) {
            final formatted = formatter(value);
            if (formatted != value) {
              controller.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
            setState(() {});
          },
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MetoColors.foreground,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            suffixText: suffix,
            filled: true,
            fillColor: MetoColors.muted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.primary),
            ),
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
              Text(emoji, style: const TextStyle(fontSize: 20)),
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

class _IletisimSheet extends StatefulWidget {
  const _IletisimSheet();

  @override
  State<_IletisimSheet> createState() => _IletisimSheetState();
}

class _IletisimSheetState extends State<_IletisimSheet> {
  String _type = 'dilek';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sent = false;

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
                          onPressed: _subject.text.trim().isEmpty ||
                                  _message.text.trim().isEmpty
                              ? null
                              : () => setState(() => _sent = true),
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
                          child: const Text(
                            'Gönder',
                            style: TextStyle(fontWeight: FontWeight.w800),
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

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.initials,
    required this.avatarColor,
    required this.onAvatarTap,
  });

  final String initials;
  final Color avatarColor;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: Transform.scale(
                scale: 1.5,
                child: Image.asset(
                  'src/imports/119686.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '9:41',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          const Spacer(),
          const Text(
            '●●●',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.active,
    required this.onSelect,
    this.ilanlarUnread = 0,
  });

  final MetoTab active;
  final ValueChanged<MetoTab> onSelect;
  final int ilanlarUnread;

  static const _items = [
    (MetoTab.home, 'Anasayfa', Icons.home_outlined, Icons.home),
    (MetoTab.merkezler, 'Harita', Icons.place_outlined, Icons.place),
    (MetoTab.ilanlar, 'İlanlar', Icons.work_outline, Icons.work),
    (MetoTab.forum, 'Forum', Icons.chat_bubble_outline, Icons.chat_bubble),
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
        4,
        6,
        4,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in _items)
            _NavItem(
              label: item.$2,
              icon: active == item.$1 ? item.$4 : item.$3,
              active: active == item.$1,
              badge: item.$1 == MetoTab.ilanlar ? ilanlarUnread : 0,
              onTap: () => onSelect(item.$1),
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
        width: 52,
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
