import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'firebase_options.dart';
import 'google_auth_service.dart';
import 'kredi_store.dart';
import 'main_shell.dart';
import 'meto_theme.dart';
import 'services/app_catalog_service.dart';

export 'meto_theme.dart';

String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final letters = parts
      .where((p) => p.isNotEmpty)
      .map((p) => p[0])
      .take(2)
      .join()
      .toUpperCase();
  return letters.isEmpty ? '?' : letters;
}

AuthUser authUserFromSupabase(User user, {String? fallbackUserType}) {
  final meta = user.userMetadata ?? const <String, dynamic>{};
  final rawName = meta['name'] ?? meta['full_name'];
  final name = rawName is String && rawName.trim().isNotEmpty
      ? rawName.trim()
      : (user.email?.split('@').first ?? 'Kullanıcı');
  final rawType = meta['user_type'];
  final userType =
      rawType is String && rawType.isNotEmpty ? rawType : fallbackUserType;
  return AuthUser(
    name: name,
    email: user.email ?? '',
    avatar: _initialsFromName(name),
    avatarColor: MetoColors.primary,
    userType: userType,
  );
}

String _roleLabel(String? role) {
  switch (role) {
    case 'uzman':
      return 'Uzman';
    case 'bakici':
      return 'Bakıcı';
    case 'aile':
      return 'Aile';
    default:
      return role ?? '';
  }
}

/// Google OAuth sonrası seçilen rolü metadata'ya yazar.
/// Rol uyuşmazlığında oturumu kapatır ve `null` döner.
Future<User?> finalizePendingGoogleRole(User user) async {
  final pending = await readPendingGoogleRole();
  if (pending == null || pending.isEmpty) return user;

  final meta = Map<String, dynamic>.from(user.userMetadata ?? const {});
  final existing = meta['user_type'];
  final existingType =
      existing is String && existing.isNotEmpty ? existing : null;

  if (existingType != null && existingType != pending) {
    await clearPendingGoogleRole();
    await Supabase.instance.client.auth.signOut();
    throw StateError(
      'Bu Google hesabı ${_roleLabel(existingType)} olarak kayıtlı. '
      'Giriş için ${_roleLabel(existingType)} rolünü seçin '
      '(seçtiğiniz: ${_roleLabel(pending)}).',
    );
  }

  final isNewRole = existingType == null;
  if (isNewRole || existingType == pending) {
    final name = meta['name'] ?? meta['full_name'];
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {
          ...meta,
          if (name is String && name.trim().isNotEmpty) 'name': name.trim(),
          'user_type': pending,
          if (pending == 'bakici') 'uzmanlik': 'Bakıcı',
          if (isNewRole)
            'welcome_credits': kWelcomeKredi,
        },
      ),
    );
    if (isNewRole) {
      await seedWelcomeCredits(email: user.email ?? '', userType: pending);
    }
  }

  await clearPendingGoogleRole();
  return Supabase.instance.client.auth.currentUser ?? user;
}

Future<void> ensureFirebaseInitialized() async {
  // Web'de Google girişi index.html Firebase JS ile yapılır.
  // FlutterFire pigeon (initializeCore) webde channel-error veriyor.
  if (kIsWeb) return;
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (Firebase.apps.isNotEmpty) return;
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate-app') || msg.contains('already exists')) {
      return;
    }
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google girişi Firebase Auth kullanır.
  try {
    await ensureFirebaseInitialized();
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  try {
    await Supabase.initialize(
      url: 'https://qycrkqwqrysypvqaipqn.supabase.co',
      anonKey: 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
    );
  } catch (e, st) {
    debugPrint('Supabase init failed: $e\n$st');
  }

  try {
    // Dinamik katalog: diskten yükle + arka planda Supabase sync (kota dostu)
    await AppCatalogService.instance.bootstrap();
  } catch (e, st) {
    debugPrint('Catalog bootstrap failed: $e\n$st');
  }

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
  bool _booting = true;
  StreamSubscription<AuthState>? _authSub;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    try {
      _restoreSession();
      _authSub =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session == null) {
          if (mounted) setState(() => _user = null);
          return;
        }
        try {
          final user = await finalizePendingGoogleRole(session.user);
          if (!mounted) return;
          if (user == null) {
            setState(() => _user = null);
            return;
          }
          setState(() => _user = authUserFromSupabase(user));
        } catch (e) {
          if (!mounted) return;
          setState(() => _user = null);
          final msg = e is StateError ? e.message : 'Google giriş başarısız.';
          _messengerKey.currentState
              ?.showSnackBar(SnackBar(content: Text(msg)));
        }
      });
    } catch (e, st) {
      debugPrint('Auth bootstrap failed: $e\n$st');
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _restoreSession() async {
    try {
      // Firebase redirect dönüşü (popup engellendiğinde)
      final redirected = await GoogleAuthService.completeRedirectIfAny();
      if (redirected?.user != null) {
        final user = await finalizePendingGoogleRole(redirected!.user!);
        if (mounted) {
          setState(() {
            _user = user == null ? null : authUserFromSupabase(user);
            _booting = false;
          });
        }
        return;
      }
    } catch (_) {
      // Redirect yok / başarısız → normal oturum kontrolüne devam
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _booting = false);
      return;
    }
    try {
      final user = await finalizePendingGoogleRole(session.user);
      if (mounted) {
        setState(() {
          _user = user == null ? null : authUserFromSupabase(user);
          _booting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = null;
          _booting = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) setState(() => _user = null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EngelsizClub',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: MetoColors.background,
        textTheme: GoogleFonts.nunitoTextTheme(),
        primaryTextTheme: GoogleFonts.nunitoTextTheme(),
        colorScheme: const ColorScheme.light(
          primary: MetoColors.primary,
          onPrimary: Colors.white,
          surface: MetoColors.card,
          onSurface: MetoColors.foreground,
        ),
      ),
      home: _booting
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _user == null
              ? AuthScreen(onLogin: (u) => setState(() => _user = u))
              : MainShell(
                  user: _user!,
                  onLogout: _logout,
                  onUserChanged: (u) => setState(() => _user = u),
                ),
    );
  }
}

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
  /// splash | signin | loading
  String _step = 'splash';
  String _authTab = 'giris'; // giris | kayit

  String _girisEmail = '';
  String _girisSifre = '';
  String? _girisHesapTip; // aile | uzman | bakici
  bool _girisLoading = false;

  String _kayitAd = '';
  String _kayitEmail = '';
  String _kayitSifre = '';
  String _kayitSifre2 = '';
  String? _kayitTip; // aile | uzman | bakici — seçilmeden form/Google açılmaz
  String? _kayitUzmanlik;
  bool _kayitSozlesme = false;
  bool _kayitLoading = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _authErrorMessage(Object error) {
    final raw = error is AuthException
        ? error.message
        : error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered') ||
        lower.contains('email address is already')) {
      return 'Bu e-posta ile zaten bir hesap var. Giriş yapın.';
    }
    if (lower.contains('password should be at least') ||
        lower.contains('password is known to be weak')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (lower.contains('unable to validate email') ||
        lower.contains('invalid email') ||
        (lower.contains('email address') && lower.contains('invalid'))) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    if (lower.contains('email rate limit') || lower.contains('over_email_send_rate_limit')) {
      return 'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar deneyin.';
    }
    if (lower.contains('signup is disabled')) {
      return 'Yeni üyelik şu an kapalı. Lütfen daha sonra deneyin.';
    }
    if (lower.contains('network') || lower.contains('failed host lookup') || lower.contains('socket')) {
      return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.';
    }
    // Kullanıcıya anlamlı bir mesaj göster (ham hata gömülmesin)
    if (raw.isNotEmpty && raw.length < 120 && !raw.startsWith('Exception')) {
      return raw;
    }
    return 'Kayıt/giriş sırasında bir hata oluştu. Lütfen tekrar deneyin.';
  }

  Future<void> _signIn() async {
    final email = _girisEmail.trim();
    final password = _girisSifre;
    if (_girisHesapTip == null) {
      _snack('Devam etmek için hesap türünü seçin.');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _snack(
        'E-posta ile giriş için e-posta ve şifre girin. '
        'Google için üstteki Google butonuna basın.',
      );
      return;
    }
    setState(() {
      _girisLoading = true;
      _step = 'loading';
    });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw Exception('Giriş başarısız');
      }
      final authUser = authUserFromSupabase(
        user,
        fallbackUserType: _girisHesapTip,
      );
      widget.onLogin?.call(authUser);
      _snack('Hoş geldin, ${authUser.name}!');
      if (mounted) setState(() => _step = 'signin');
    } catch (e) {
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _girisLoading = false);
    }
  }

  Future<void> _signInWithGoogle(String? role) async {
    if (role == null || role.isEmpty) {
      _snack('Devam etmek için önce hesap türünü seçin.');
      return;
    }
    setState(() {
      _girisLoading = true;
      _kayitLoading = true;
      _step = 'loading';
    });
    try {
      await savePendingGoogleRole(role);

      // Web: yalnız JS Firebase popup. Mobil: FlutterFire.
      if (!kIsWeb) {
        try {
          await ensureFirebaseInitialized();
        } catch (e) {
          throw StateError(
            'Firebase başlatılamadı. Uygulamayı yeniden açın. ($e)',
          );
        }
      }

      // Firebase JS popup → Google idToken → Supabase (supabase.co görünmez).
      final res = await GoogleAuthService.signIn();
      final user = res?.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // İptal veya redirect (sayfa yenilenecek)
        if (mounted) setState(() => _step = 'signin');
        return;
      }

      final finalized = await finalizePendingGoogleRole(user);
      if (finalized == null) {
        throw StateError('Google oturumu tamamlanamadı.');
      }
      final authUser = authUserFromSupabase(
        finalized,
        fallbackUserType: role,
      );
      widget.onLogin?.call(authUser);
      _snack('Hoş geldin, ${authUser.name}!');
      if (mounted) setState(() => _step = 'signin');
    } catch (e) {
      await clearPendingGoogleRole();
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_googleErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _girisLoading = false;
          _kayitLoading = false;
        });
      }
    }
  }

  String _googleErrorMessage(Object error) {
    final raw = error is AuthException
        ? error.message
        : (error is firebase_auth.FirebaseAuthException
            ? (error.message ?? error.code)
            : error.toString());
    final lower = raw.toLowerCase();
    if (lower.contains('popup-closed') ||
        lower.contains('cancelled') ||
        lower.contains('canceled')) {
      return 'Google girişi iptal edildi.';
    }
    if (lower.contains('provider is not enabled') ||
        lower.contains('unsupported provider') ||
        lower.contains('operation-not-allowed')) {
      return 'Google girişi henüz etkin değil. Supabase → Authentication → '
          'Providers → Google’ı açın.';
    }
    if (lower.contains('unacceptable audience') ||
        lower.contains('unexpected_audience')) {
      return 'Google Client ID Supabase ile uyuşmuyor. Supabase → '
          'Authentication → Providers → Google → Client IDs alanını kontrol edin.';
    }
    if (lower.contains('redirect') && lower.contains('not allowed') ||
        lower.contains('invalid redirect')) {
      return 'Bu adres Supabase izin listesinde yok. Redirect URL olarak '
          'https://engelsizclub.com/** ekleyin.';
    }
    if (lower.contains('channel-error') ||
        lower.contains('initializecore') ||
        lower.contains('unable to establish connection')) {
      return 'Google girişi şu an webde JS ile yapılıyor. '
          'Sayfayı Ctrl+Shift+R ile yenileyip tekrar deneyin.';
    }
    // StateError / gerçek mesajı kullanıcıya göster
    final cleaned = raw
        .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty
        ? 'Google girişi başarısız. Lütfen tekrar deneyin.'
        : cleaned;
  }

  Future<void> _createAccount() async {
    final name = _kayitAd.trim();
    final email = _kayitEmail.trim();
    final tip = _kayitTip;
    if (tip == null) {
      _snack('Devam etmek için hesap türünü seçin.');
      return;
    }
    if (name.isEmpty || email.isEmpty || _kayitSifre.isEmpty) {
      _snack('Ad, e-posta ve şifre gerekli.');
      return;
    }
    if (_kayitSifre.length < 6) {
      _snack('Şifre en az 6 karakter olmalı.');
      return;
    }
    if (_kayitSifre != _kayitSifre2) {
      _snack('Şifreler eşleşmiyor.');
      return;
    }
    if (!_kayitSozlesme) {
      _snack('Devam etmek için sözleşmeyi kabul edin.');
      return;
    }
    if (tip == 'uzman' &&
        (_kayitUzmanlik == null || _kayitUzmanlik!.isEmpty)) {
      _snack('Uzmanlık alanını seçin.');
      return;
    }

    setState(() {
      _kayitLoading = true;
      _step = 'loading';
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _kayitSifre,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
        data: {
          'name': name,
          'user_type': tip,
          if (tip == 'uzman' && _kayitUzmanlik != null)
            'uzmanlik': _kayitUzmanlik,
          if (tip == 'bakici') 'uzmanlik': 'Bakıcı',
          'welcome_credits':
              (tip == 'uzman' || tip == 'bakici') ? kWelcomeKredi : 0,
        },
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('Kayıt başarısız. Lütfen tekrar deneyin.');
      }

      // Supabase: mevcut e-posta için bazen boş identities döner (hata yerine).
      final identities = user.identities;
      if (identities != null && identities.isEmpty) {
        throw const AuthException(
          'Bu e-posta ile zaten bir hesap var. Giriş yapın.',
        );
      }

      await seedWelcomeCredits(email: email, userType: tip);

      final hediyeKredi =
          startingKrediFor(email, userType: tip);

      if (res.session == null) {
        if (mounted) {
          setState(() {
            _step = 'signin';
            _authTab = 'giris';
            _girisEmail = email;
            _girisHesapTip = tip;
          });
        }
        _snack(
          hediyeKredi > 0
              ? 'Hesap oluşturuldu! Giriş yapınca $hediyeKredi hediye puan hesabınızda olacak.'
              : 'Hesap oluşturuldu! Aile rolünde hediye puan yok; 2. el ilanlara ücretsiz teklif verebilirsiniz.',
        );
        return;
      }
      final authUser = authUserFromSupabase(
        user,
        fallbackUserType: tip,
      );
      widget.onLogin?.call(authUser);
      _snack(
        hediyeKredi > 0
            ? 'Hoş geldin ${authUser.name}! $hediyeKredi hediye puan hesabına tanımlandı.'
            : 'Hoş geldin ${authUser.name}! Aile rolünde hediye puan yok; ilan verebilir, 2. el ilanlara teklif verebilirsiniz.',
      );
      if (mounted) setState(() => _step = 'signin');
    } catch (e) {
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _kayitLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Masaüstünde telefon çerçevesi yok — arka plan tam sayfa; form ortalanır.
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ColoredBox(
        color: MetoColors.background,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height - pad.vertical,
                child: switch (_step) {
                  'splash' => _SplashStep(
                      onStart: () => setState(() => _step = 'signin'),
                    ),
                  'loading' => const _LoadingStep(),
                  _ => _SignInStep(
                      authTab: _authTab,
                      onTab: (t) => setState(() => _authTab = t),
                      girisHesapTip: _girisHesapTip,
                      onGirisHesapTip: (v) =>
                          setState(() => _girisHesapTip = v),
                      girisEmail: _girisEmail,
                      girisSifre: _girisSifre,
                      girisLoading: _girisLoading,
                      onGirisEmail: (v) => setState(() => _girisEmail = v),
                      onGirisSifre: (v) => setState(() => _girisSifre = v),
                      onSignIn: _signIn,
                      onGoogleSignIn: _signInWithGoogle,
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
        ),
      ),
    );
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
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          Text(
                            f.$3,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                    textStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Başlayalım'),
                ),
              ),
              const SizedBox(height: 12),
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
    required this.girisLoading,
    required this.onGirisEmail,
    required this.onGirisSifre,
    required this.onSignIn,
    required this.onGoogleSignIn,
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
  final bool girisLoading;
  final ValueChanged<String> onGirisEmail;
  final ValueChanged<String> onGirisSifre;
  final VoidCallback onSignIn;
  final ValueChanged<String?> onGoogleSignIn;

  final String kayitAd;
  final String kayitEmail;
  final String kayitSifre;
  final String kayitSifre2;
  final String? kayitTip;
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: authTab == 'giris' ? _buildGiris() : _buildKayit(),
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
        const SizedBox(height: 16),
        _GoogleSignInButton(
          enabled: !girisLoading && girisHesapTip != null,
          label: girisHesapTip == null
              ? 'Google ile giriş (önce hesap türü seçin)'
              : 'Google ile ${_roleLabel(girisHesapTip)} olarak giriş',
          onPressed: () => onGoogleSignIn(girisHesapTip),
        ),
        if (girisHesapTip == null) ...[
          const SizedBox(height: 10),
          const Text(
            'Google butonu için önce Aile, Uzman veya Bakıcı seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
        if (girisHesapTip != null) ...[
          const SizedBox(height: 16),
          const _OrDivider(label: 'veya e-posta ile'),
          const SizedBox(height: 16),
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
              onPressed: girisLoading ? null : onSignIn,
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
              child: girisLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('E-posta ile Giriş Yap'),
            ),
          ),
          const SizedBox(height: 12),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
              children: [
                TextSpan(text: 'Hesabınız yok mu? '),
                TextSpan(
                  text: 'Üye Ol sekmesine geçin',
                  style: TextStyle(
                    color: MetoColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildKayit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Yeni hesap oluşturun',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
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
              desc: 'Destek ara',
              selected: kayitTip == 'aile',
              onTap: () => onKayitTip('aile'),
              padded: true,
            ),
            const SizedBox(width: 8),
            _HesapTipCard(
              emoji: '🏥',
              label: 'Uzman',
              desc: 'Hizmet ver',
              selected: kayitTip == 'uzman',
              onTap: () => onKayitTip('uzman'),
              padded: true,
            ),
            const SizedBox(width: 8),
            _HesapTipCard(
              emoji: '🤲',
              label: 'Bakıcı',
              desc: 'Bakım ver',
              selected: kayitTip == 'bakici',
              onTap: () => onKayitTip('bakici'),
              padded: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GoogleSignInButton(
          enabled: !kayitLoading && kayitTip != null,
          label: kayitTip == null
              ? 'Google ile üye ol (önce hesap türü seçin)'
              : 'Google ile ${_roleLabel(kayitTip)} olarak üye ol',
          onPressed: () => onGoogleSignIn(kayitTip),
        ),
        if (kayitTip == null) ...[
          const SizedBox(height: 10),
          const Text(
            'Google ile üye olmak için önce Aile, Uzman veya Bakıcı seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ] else ...[
        if (kayitTip == 'uzman' || kayitTip == 'bakici') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MetoColors.selectedBg,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: MetoColors.primary.withValues(alpha: 0.25)),
            ),
            child: Text(
              '🎁 Hoş geldin hediyesi: hesabınıza $kWelcomeKredi ücretsiz puan tanımlanır.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MetoColors.primary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Google ile devam ederseniz ${_roleLabel(kayitTip)} rolüyle hesap '
          'oluşturulur ve sözleşmeleri kabul etmiş sayılırsınız.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 16),
        const _OrDivider(label: 'veya e-posta ile'),
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
          hint: 'Şifre (en az 6 karakter)',
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
      ],
    );
  }
}

// ─── Google account chooser ──────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: MetoColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
        ),
        const Expanded(child: Divider(color: MetoColors.border, thickness: 1)),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  static const _logoUrl = 'https://authjs.dev/img/providers/google.svg';

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF757575),
        disabledForegroundColor: const Color(0xFFBDBDBD),
        side: const BorderSide(color: Color(0xFFDADCE0)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: const Size.fromHeight(48),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.network(
            _logoUrl,
            height: 22,
            width: 22,
            placeholderBuilder: (_) => const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
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
              // Alt kıvrım yazıyı kesmesin diye içerik hafif yukarıda durur
              padding: EdgeInsets.only(
                top: height > 200 ? 16 : 0,
                bottom: height * 0.10,
              ),
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
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: height > 200 ? 14 : 12,
                      fontWeight: FontWeight.w500,
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
    // Kıvrım biraz aşağıda başlar ki alt yazı kesilmesin
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.12,
        0,
        size.height * 0.80,
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
