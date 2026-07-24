import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'main_shell.dart';
import 'meto_theme.dart';

export 'meto_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qycrkqwqrysypvqnipqn.supabase.co',
    publishableKey: 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MetoCareApp());
}

class MetoCareApp extends StatefulWidget {
  const MetoCareApp({super.key});

  @override
  State<MetoCareApp> createState() => _MetoCareAppState();
}

class _MetoCareAppState extends State<MetoCareApp> {
  AuthUser? _user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EngelsizClub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: MetoColors.background,
        colorScheme: const ColorScheme.light(
          primary: MetoColors.primary,
          onPrimary: Colors.white,
          surface: MetoColors.card,
          onSurface: MetoColors.foreground,
        ),
      ),
      home: _user == null
          ? AuthScreen(onLogin: (u) => setState(() => _user = u))
          : MainShell(
              user: _user!,
              onLogout: () => setState(() => _user = null),
            ),
    );
  }
}

const _googleAccounts = [
  AuthUser(
    name: 'Ayşe Kaya',
    email: 'ayse.kaya@gmail.com',
    avatar: 'AK',
    avatarColor: Color(0xFFE07A5F),
  ),
  AuthUser(
    name: 'Mehmet Demir',
    email: 'mehmet.demir@gmail.com',
    avatar: 'MD',
    avatarColor: MetoColors.primary,
  ),
  AuthUser(
    name: 'Fatma Yılmaz',
    email: 'fatma.yilmaz@gmail.com',
    avatar: 'FY',
    avatarColor: Color(0xFF9C6DB3),
  ),
];

const _uzmanlikAlanlari = [
  'Fizyoterapist',
  'Ergoterapist',
  'Dil ve Konuşma Terapisti',
  'Özel Eğitim Öğretmeni',
  'Çocuk Psikologu',
  'Çocuk Psikiyatristi',
  'Nörolog',
  'Bakıcı',
];

/// Birebir Flutter port of Figma Make `AuthScreen`.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onLogin});

  final void Function(AuthUser user)? onLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// splash | signin | choosing | loading
  String _step = 'splash';
  String _authTab = 'giris'; // giris | kayit

  String _girisEmail = '';
  String _girisSifre = '';
  String? _girisHesapTip; // aile | uzman | bakici

  String _kayitAd = '';
  String _kayitEmail = '';
  String _kayitSifre = '';
  String _kayitSifre2 = '';
  String _kayitTip = 'aile'; // aile | uzman
  String? _kayitUzmanlik;
  bool _kayitSozlesme = false;
  bool _kayitLoading = false;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleGoogleTap() => setState(() => _step = 'choosing');

  void _handleAccountSelect(AuthUser account) {
    setState(() => _step = 'loading');
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      widget.onLogin?.call(account);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hoş geldin, ${account.name}!')),
        );
        setState(() => _step = 'splash');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW =
              constraints.maxWidth >= 720 ? 420.0 : constraints.maxWidth;
          return ColoredBox(
            color: MetoColors.background,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: constraints.maxWidth >= 720
                      ? constraints.maxHeight * 0.92
                      : double.infinity,
                ),
                child: Container(
                  decoration: constraints.maxWidth >= 720
                      ? BoxDecoration(
                          color: MetoColors.background,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: MetoColors.primaryDark
                                  .withValues(alpha: 0.14),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        )
                      : null,
                  clipBehavior: Clip.antiAlias,
                  child: switch (_step) {
                    'splash' => _SplashStep(
                        onStart: () => setState(() => _step = 'signin'),
                      ),
                    'loading' => const _LoadingStep(),
                    'choosing' => _ChoosingStep(
                        onBack: () => setState(() => _step = 'signin'),
                        onSelect: _handleAccountSelect,
                      ),
                    _ => _SignInStep(
                        authTab: _authTab,
                        onTab: (t) => setState(() => _authTab = t),
                        girisHesapTip: _girisHesapTip,
                        onGirisHesapTip: (v) =>
                            setState(() => _girisHesapTip = v),
                        girisEmail: _girisEmail,
                        girisSifre: _girisSifre,
                        onGirisEmail: (v) => setState(() => _girisEmail = v),
                        onGirisSifre: (v) => setState(() => _girisSifre = v),
                        onGoogle: _handleGoogleTap,
                        kayitAd: _kayitAd,
                        kayitEmail: _kayitEmail,
                        kayitSifre: _kayitSifre,
                        kayitSifre2: _kayitSifre2,
                        kayitTip: _kayitTip,
                        kayitUzmanlik: _kayitUzmanlik,
                        kayitSozlesme: _kayitSozlesme,
                        kayitLoading: _kayitLoading,
                        onKayitAd: (v) => setState(() => _kayitAd = v),
                        onKayitEmail: (v) => setState(() => _kayitEmail = v),
                        onKayitSifre: (v) => setState(() => _kayitSifre = v),
                        onKayitSifre2: (v) => setState(() => _kayitSifre2 = v),
                        onKayitTip: (v) => setState(() => _kayitTip = v),
                        onKayitUzmanlik: (v) =>
                            setState(() => _kayitUzmanlik = v),
                        onKayitSozlesme: () =>
                            setState(() => _kayitSozlesme = !_kayitSozlesme),
                        onCreateAccount: _createAccount,
                      ),
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _createAccount() {
    if (_kayitAd.isEmpty ||
        _kayitEmail.isEmpty ||
        _kayitSifre.isEmpty ||
        !_kayitSozlesme) {
      return;
    }
    setState(() => _kayitLoading = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      final parts = _kayitAd.trim().split(RegExp(r'\s+'));
      final initials = parts
          .where((p) => p.isNotEmpty)
          .map((p) => p[0])
          .take(2)
          .join()
          .toUpperCase();
      final user = AuthUser(
        name: _kayitAd,
        email: _kayitEmail,
        avatar: initials,
        avatarColor: MetoColors.primary,
        userType: _kayitTip,
      );
      setState(() => _kayitLoading = false);
      widget.onLogin?.call(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap oluşturuldu: ${user.name}')),
        );
        setState(() => _step = 'splash');
      }
    });
  }
}

// ─── Splash (Başlayalım) ─────────────────────────────────────────────────────

class _SplashStep extends StatelessWidget {
  const _SplashStep({required this.onStart});

  final VoidCallback onStart;

  static const _features = [
    ('🏥', 'Hastalık & Tanı Bilgisi', '100+ tanı için güvenilir rehber'),
    ('🗺️', 'Yakınımdaki Merkezler', 'Terapi merkezi ve uzman bul'),
    ('🗣️', 'AAC İletişim Kartları', 'Görsel iletişim desteği'),
    ('⚖️', 'Yasal Haklar & Destek', 'Devlet yardımlarına kolayca ulaş'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _BrandHeader(
          height: 256,
          logoSize: 112,
          titleSize: 24,
          subtitle: 'Özel gereksinimli kahramanlarımız için rehber',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            children: [
              for (final f in _features) ...[
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: MetoColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(f.$1, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          Text(
                            f.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: MetoColors.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Başlayalım'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ücretsiz · Reklamsız · Güvenli',
                style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Sign-in / Sign-up (Giriş Yap · Üye Ol) ──────────────────────────────────

class _SignInStep extends StatelessWidget {
  const _SignInStep({
    required this.authTab,
    required this.onTab,
    required this.girisHesapTip,
    required this.onGirisHesapTip,
    required this.girisEmail,
    required this.girisSifre,
    required this.onGirisEmail,
    required this.onGirisSifre,
    required this.onGoogle,
    required this.kayitAd,
    required this.kayitEmail,
    required this.kayitSifre,
    required this.kayitSifre2,
    required this.kayitTip,
    required this.kayitUzmanlik,
    required this.kayitSozlesme,
    required this.kayitLoading,
    required this.onKayitAd,
    required this.onKayitEmail,
    required this.onKayitSifre,
    required this.onKayitSifre2,
    required this.onKayitTip,
    required this.onKayitUzmanlik,
    required this.onKayitSozlesme,
    required this.onCreateAccount,
  });

  final String authTab;
  final ValueChanged<String> onTab;
  final String? girisHesapTip;
  final ValueChanged<String> onGirisHesapTip;
  final String girisEmail;
  final String girisSifre;
  final ValueChanged<String> onGirisEmail;
  final ValueChanged<String> onGirisSifre;
  final VoidCallback onGoogle;

  final String kayitAd;
  final String kayitEmail;
  final String kayitSifre;
  final String kayitSifre2;
  final String kayitTip;
  final String? kayitUzmanlik;
  final bool kayitSozlesme;
  final bool kayitLoading;
  final ValueChanged<String> onKayitAd;
  final ValueChanged<String> onKayitEmail;
  final ValueChanged<String> onKayitSifre;
  final ValueChanged<String> onKayitSifre2;
  final ValueChanged<String> onKayitTip;
  final ValueChanged<String?> onKayitUzmanlik;
  final VoidCallback onKayitSozlesme;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _BrandHeader(
          height: 176,
          logoSize: 64,
          titleSize: 20,
          subtitle: 'Özel gereksinimli kahramanlarımız için',
          logoRadius: 16,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MetoColors.muted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _AuthTab(
                  label: 'Giriş Yap',
                  selected: authTab == 'giris',
                  onTap: () => onTab('giris'),
                ),
                _AuthTab(
                  label: 'Üye Ol',
                  selected: authTab == 'kayit',
                  onTap: () => onTab('kayit'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: authTab == 'giris' ? _buildGiris() : _buildKayit(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
              children: [
                TextSpan(text: 'Ücretsiz · Reklamsız · '),
                TextSpan(
                  text: 'Güvenli',
                  style: TextStyle(
                    color: MetoColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildGiris() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hesap Türü',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _HesapTipCard(
              emoji: '👨‍👩‍👧',
              label: 'Aile',
              desc: 'Destek ara',
              selected: girisHesapTip == 'aile',
              onTap: () => onGirisHesapTip('aile'),
            ),
            const SizedBox(width: 8),
            _HesapTipCard(
              emoji: '🏥',
              label: 'Uzman',
              desc: 'Hizmet ver',
              selected: girisHesapTip == 'uzman',
              onTap: () => onGirisHesapTip('uzman'),
            ),
            const SizedBox(width: 8),
            _HesapTipCard(
              emoji: '🤲',
              label: 'Bakıcı',
              desc: 'Bakım ver',
              selected: girisHesapTip == 'bakici',
              onTap: () => onGirisHesapTip('bakici'),
            ),
          ],
        ),
        if (girisHesapTip != null) ...[
          const SizedBox(height: 12),
          _GoogleButton(label: 'Google ile devam et', onTap: onGoogle),
          const SizedBox(height: 12),
          const _DividerLabel(label: 'veya e-posta ile'),
          const SizedBox(height: 12),
          _AuthField(
            hint: 'E-posta adresiniz',
            value: girisEmail,
            onChanged: onGirisEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _AuthField(
            hint: 'Şifre',
            value: girisSifre,
            onChanged: onGirisSifre,
            obscure: true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Giriş Yap'),
            ),
          ),
          const SizedBox(height: 12),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
              children: [
                TextSpan(text: 'Şifrenizi mi unuttunuz? '),
                TextSpan(
                  text: 'Sıfırla',
                  style: TextStyle(
                    color: MetoColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 20),
          const Text(
            'Devam etmek için lütfen hesap türünüzü seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      ],
    );
  }

  Widget _buildKayit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoogleButton(label: 'Google ile hızlı kayıt', onTap: onGoogle),
        const SizedBox(height: 12),
        const _DividerLabel(label: 'veya formu doldurun'),
        const SizedBox(height: 12),
        const Text(
          'Hesap Türü',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _HesapTipCard(
              emoji: '👨‍👩‍👧',
              label: 'Aile',
              desc: 'Uzman & destek ara',
              selected: kayitTip == 'aile',
              onTap: () => onKayitTip('aile'),
              padded: true,
            ),
            const SizedBox(width: 8),
            _HesapTipCard(
              emoji: '🏥',
              label: 'Uzman',
              desc: 'İlan ver & teklif al',
              selected: kayitTip == 'uzman',
              onTap: () => onKayitTip('uzman'),
              padded: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AuthField(hint: 'Ad Soyad', value: kayitAd, onChanged: onKayitAd),
        const SizedBox(height: 12),
        _AuthField(
          hint: 'E-posta adresiniz',
          value: kayitEmail,
          onChanged: onKayitEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _AuthField(
          hint: 'Şifre (en az 8 karakter)',
          value: kayitSifre,
          onChanged: onKayitSifre,
          obscure: true,
        ),
        const SizedBox(height: 12),
        _AuthField(
          hint: 'Şifreyi tekrar girin',
          value: kayitSifre2,
          onChanged: onKayitSifre2,
          obscure: true,
        ),
        if (kayitTip == 'uzman') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetoColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: kayitUzmanlik,
                hint: const Text(
                  'Uzmanlık Alanı Seçin',
                  style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
                ),
                items: _uzmanlikAlanlari
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(u, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: onKayitUzmanlik,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onKayitSozlesme,
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color:
                      kayitSozlesme ? MetoColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        kayitSozlesme ? MetoColors.primary : MetoColors.mutedFg,
                    width: 2,
                  ),
                ),
                child: kayitSozlesme
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: MetoColors.mutedFg,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(
                        text: "Kullanım Koşulları",
                        style: TextStyle(
                          color: MetoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: "'nı, "),
                      TextSpan(
                        text: 'Gizlilik Politikası',
                        style: TextStyle(
                          color: MetoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: "'nı ve "),
                      TextSpan(
                        text: 'KVKK Aydınlatma Metni',
                        style: TextStyle(
                          color: MetoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: "'ni okudum, kabul ediyorum."),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MetoColors.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: MetoColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kişisel verileriniz güvende',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    Text(
                      '256-bit şifreleme · KVKK uyumlu · Reklam yok',
                      style: TextStyle(fontSize: 10, color: MetoColors.mutedFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: kayitSozlesme && !kayitLoading ? onCreateAccount : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  kayitSozlesme ? MetoColors.primary : const Color(0xFFDCEEE4),
              foregroundColor:
                  kayitSozlesme ? Colors.white : MetoColors.mutedFg,
              disabledBackgroundColor: const Color(0xFFDCEEE4),
              disabledForegroundColor: MetoColors.mutedFg,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: kayitLoading
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
                      SizedBox(width: 8),
                      Text('Hesap Oluşturuluyor…'),
                    ],
                  )
                : const Text('Hesap Oluştur'),
          ),
        ),
      ],
    );
  }
}

// ─── Google account chooser ──────────────────────────────────────────────────

class _ChoosingStep extends StatelessWidget {
  const _ChoosingStep({required this.onBack, required this.onSelect});

  final VoidCallback onBack;
  final ValueChanged<AuthUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: MetoColors.muted,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hesap seçin',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    Text(
                      'EngelsizClub uygulamasına giriş için',
                      style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MetoColors.muted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                _GoogleGlyph(size: 16),
                SizedBox(width: 8),
                Text(
                  'Google Hesaplarım',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final acc in _googleAccounts) ...[
                  Material(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onSelect(acc),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MetoColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: acc.avatarColor,
                              child: Text(
                                acc.avatar,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: MetoColors.foreground,
                                    ),
                                  ),
                                  Text(
                                    acc.email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: MetoColors.mutedFg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: MetoColors.mutedFg,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MetoColors.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: MetoColors.muted,
                        child: Icon(Icons.add, color: MetoColors.mutedFg),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Başka bir hesap kullan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: MetoColors.mutedFg,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'Devam ederek '),
                      TextSpan(
                        text: 'Kullanım Koşulları',
                        style: TextStyle(
                          color: MetoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' ve '),
                      TextSpan(
                        text: 'Gizlilik Politikası',
                        style: TextStyle(
                          color: MetoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: "'nı kabul etmiş olursunuz."),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStep extends StatefulWidget {
  const _LoadingStep();

  @override
  State<_LoadingStep> createState() => _LoadingStepState();
}

class _LoadingStepState extends State<_LoadingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: const _EngelsizLogo(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Giriş yapılıyor…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hesabınız doğrulanıyor',
            style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_c.value + i * 0.15) % 1.0;
                  final dy = (t < 0.5 ? t : 1 - t) * -8;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    transform: Matrix4.translationValues(0, dy, 0),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: MetoColors.primary,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Shared UI pieces ────────────────────────────────────────────────────────

class _EngelsizLogo extends StatelessWidget {
  const _EngelsizLogo();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 8),
      child: Transform.scale(
        scale: 1.5,
        child: Image.asset(
          'src/imports/119686.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.height,
    required this.logoSize,
    required this.titleSize,
    required this.subtitle,
    this.logoRadius = 24,
  });

  final double height;
  final double logoSize;
  final double titleSize;
  final String subtitle;
  final double logoRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: const _AuthWaveClipper(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8, -1),
              end: Alignment(1, 1.2),
              colors: [
                MetoColors.primary,
                MetoColors.primaryDark,
                MetoColors.accentGold,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: height > 200 ? 24 : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(logoRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const _EngelsizLogo(),
                  ),
                  SizedBox(height: height > 200 ? 16 : 8),
                  Text(
                    'EngelsizClub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: height > 200 ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthWaveClipper extends CustomClipper<Path> {
  const _AuthWaveClipper();

  @override
  Path getClip(Size size) {
    // borderBottomLeft/RightRadius: 60% 30% ≈ elliptical bottom curve
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.08,
        0,
        size.height * 0.72,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? MetoColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: MetoColors.primary.withValues(alpha: 0.27),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}

class _HesapTipCard extends StatelessWidget {
  const _HesapTipCard({
    required this.emoji,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
    this.padded = false,
  });

  final String emoji;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            vertical: padded ? 12 : 10,
            horizontal: padded ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: selected ? MetoColors.selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? MetoColors.primary
                  : MetoColors.primary.withValues(alpha: 0.20),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? MetoColors.primary : MetoColors.mutedFg,
                ),
              ),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: selected ? MetoColors.primary : MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.hint,
    required this.value,
    required this.onChanged,
    this.obscure = false,
    this.keyboardType,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _AuthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      style: const TextStyle(fontSize: 14, color: MetoColors.foreground),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: MetoColors.mutedFg, fontSize: 14),
        filled: true,
        fillColor: MetoColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
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
          borderSide: const BorderSide(color: MetoColors.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.googleBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleGlyph(size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.googleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: MetoColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ),
        const Expanded(child: Divider(color: MetoColors.border)),
      ],
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromLTWH(2 * s, 2 * s, 20 * s, 20 * s);

    stroke.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.6, false, stroke);
    stroke.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.25, 1.3, false, stroke);
    stroke.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.55, 1.0, false, stroke);
    stroke.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.55, 1.2, false, stroke);

    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(11 * s, 10.2 * s, 10 * s, 3.4 * s),
        Radius.circular(1 * s),
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
