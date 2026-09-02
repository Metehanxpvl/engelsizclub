import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'aile_kocu/aile_kocu_entry.dart';
import 'admin_catalog_extras.dart';
import 'apple_auth_service.dart';
import 'firebase_options.dart';
import 'google_auth_service.dart';
import 'guest_limit_store.dart';
import 'kredi_store.dart';
import 'legal/legal_texts.dart';
import 'l10n/content_translator.dart';
import 'l10n/locale_controller.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n_text.dart';
import 'main_shell.dart';
import 'meto_theme.dart';
import 'pages/legal_document_page.dart';
import 'services/app_catalog_service.dart';
import 'services/force_update_service.dart';
import 'services/push_notification_service.dart';
import 'utils/async_timeout.dart';
import 'widgets/force_update_gate.dart';
import 'widgets/loading_error_view.dart';

export 'meto_theme.dart';

/// iPhone Safari alt araç çubuğu buton dokunuşunu yutmasın diye ekstra boşluk.
double _webBottomTapInset(BuildContext context) {
  final pad = MediaQuery.viewPaddingOf(context).bottom;
  if (!kIsWeb) return pad;
  return pad > 20 ? pad : 48;
}

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

/// Son Google girişinde kullanıcıya gösterilecek bilgi (rol uyuşmazlığı vb.).
String? googleAuthNotice;

Future<User?>? _finalizeGoogleRoleInFlight;

/// Google OAuth sonrası seçilen rolü metadata'ya yazar.
///
/// Hesapta zaten farklı bir rol varsa oturumu KAPATMAZ; mevcut rolle devam eder
/// (aksi halde giriş başarılı görünüp tekrar giriş ekranına düşülüyordu).
Future<User?> finalizePendingGoogleRole(User user) {
  final existing = _finalizeGoogleRoleInFlight;
  if (existing != null) return existing;
  final run = _finalizePendingGoogleRoleImpl(user);
  _finalizeGoogleRoleInFlight = run;
  return run.whenComplete(() {
    if (identical(_finalizeGoogleRoleInFlight, run)) {
      _finalizeGoogleRoleInFlight = null;
    }
  });
}

Future<User?> _finalizePendingGoogleRoleImpl(User user) async {
  googleAuthNotice = null;
  final pending = await readPendingGoogleRole();
  if (pending == null || pending.isEmpty) return user;

  final meta = Map<String, dynamic>.from(user.userMetadata ?? const {});
  final existing = meta['user_type'];
  final existingType =
      existing is String && existing.isNotEmpty ? existing : null;

  // Rol uyuşmazlığı: çıkış yapma — kayıtlı rolle gir, bilgilendir
  if (existingType != null && existingType != pending) {
    await clearPendingGoogleRole();
    googleAuthNotice =
        'Bu Google hesabı ${_roleLabel(existingType)} olarak kayıtlı. '
        'O rolle giriş yapıldı '
        '(seçtiğiniz: ${_roleLabel(pending)}).';
    return user;
  }

  final isNewRole = existingType == null;
  if (isNewRole || existingType == pending) {
    final name = meta['name'] ?? meta['full_name'];
    try {
      await withNetworkTimeout(
        Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              ...meta,
              if (name is String && name.trim().isNotEmpty) 'name': name.trim(),
              'user_type': pending,
              if (pending == 'bakici') 'uzmanlik': 'Bakıcı',
              if (isNewRole) 'welcome_credits': kMemberStartKredi,
            },
          ),
        ),
        message: 'Rol kaydı zaman aşımına uğradı.',
      );
    } catch (e, st) {
      debugPrint('Google rol metadata yazılamadı: $e\n$st');
      // Oturumu düşürme — seçilen rolü fallback olarak kullanacağız
      googleAuthNotice =
          'Rol kaydı gecikti; ${_roleLabel(pending)} olarak devam ediliyor.';
      await clearPendingGoogleRole();
      return user;
    }
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

Future<void> _bootstrapPlatformServices() async {
  // Firebase/FCM Play Services kullanır; uygulama açıldıktan sonra başlat ki
  // bazı cihazlarda görünen "Google Play is enabled" diyalogu ana ekranı kilitlemesin.
  try {
    await ensureFirebaseInitialized();
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  try {
    await PushNotificationService.instance.init();
  } catch (e, st) {
    debugPrint('FCM init failed: $e\n$st');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Theme Nunito (same family as İlanlar/Keşfet) — full TTF, not a latin-only subset.

  try {
    await withNetworkTimeout(
      Supabase.initialize(
        url: 'https://qycrkqwqrysypvqaipqn.supabase.co',
        anonKey: 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          // Oturum URL’si _bootstrapAuth içinde dinleyici hazır olduktan sonra işlenir
          // (şifre sıfırlama + mobil deep link; Google OAuth ayrı akış).
          detectSessionInUri: false,
        ),
      ),
      timeout: kBootstrapTimeout,
      message: 'Sunucu bağlantısı zaman aşımına uğradı.',
    );
  } catch (e, st) {
    debugPrint('Supabase init failed: $e\n$st');
  }

  try {
    await GoogleAuthService.startMobileDeepLinkListener();
  } catch (e, st) {
    debugPrint('Deep link listener failed: $e\n$st');
  }

  try {
    // Dinamik katalog: diskten yükle + arka planda Supabase sync (kota dostu)
    await withNetworkTimeout(
      AppCatalogService.instance.bootstrap(),
      timeout: kBootstrapTimeout,
    );
  } catch (e, st) {
    debugPrint('Catalog bootstrap failed: $e\n$st');
    // Diskten yüklemeyi yine de dene — ağ yavaşsa uygulama açılsın
    try {
      await AppCatalogService.instance.bootstrap();
    } catch (_) {}
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: MetoCareApp()));
  unawaited(_bootstrapPlatformServices());
}

class MetoCareApp extends StatefulWidget {
  const MetoCareApp({super.key});

  @override
  State<MetoCareApp> createState() => _MetoCareAppState();
}

class _MetoCareAppState extends State<MetoCareApp> {
  AuthUser? _user;
  bool _booting = true;
  bool _bootTimedOut = false;
  bool _needsPasswordReset = false;
  StreamSubscription<AuthState>? _authSub;
  Timer? _bootWatchdog;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  void _finishBooting({bool timedOut = false}) {
    if (!mounted || !_booting) return;
    _bootWatchdog?.cancel();
    setState(() {
      _booting = false;
      if (timedOut) _bootTimedOut = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _bootWatchdog = Timer(kBootstrapTimeout, () {
      if (_booting) {
        debugPrint('Auth bootstrap watchdog fired');
        _finishBooting(timedOut: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(bootstrapAileKocuReminders());
      unawaited(ForceUpdateService.instance.check());
      Future<void>.delayed(const Duration(seconds: 2), () {
        unawaited(ForceUpdateService.instance.check());
      });
    });
    try {
      unawaited(LocaleController.instance.ensureLoaded());
      unawaited(ContentTranslator.instance.ensureLoaded());
      unawaited(AdminCatalogExtras.instance.ensureLoaded());
      _authSub =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          if (!mounted) return;
          setState(() {
            _needsPasswordReset = true;
            _user = null;
            _booting = false;
          });
          return;
        }
        final session = data.session;
        if (session == null) {
          if (mounted) {
            setState(() {
              _user = null;
              _needsPasswordReset = false;
            });
          }
          return;
        }
        if (_needsPasswordReset) return;
        // Token yenileme / metadata güncellemesi sırasında tekrar finalize
        // yarışına girme — zaten oturum açıksa kullanıcıyı düşürme.
        if (data.event == AuthChangeEvent.tokenRefreshed && _user != null) {
          return;
        }
        try {
          final pendingRole = await readPendingGoogleRole();
          final user = await withNetworkTimeout(
            finalizePendingGoogleRole(session.user),
            timeout: kBootstrapTimeout,
          );
          if (!mounted) return;
          if (user == null) {
            // Oturum varsa giriş ekranına zorla düşürme
            if (Supabase.instance.client.auth.currentSession == null) {
              setState(() => _user = null);
            }
            return;
          }
          final notice = googleAuthNotice;
          googleAuthNotice = null;
          final auth = authUserFromSupabase(
            user,
            fallbackUserType: pendingRole,
          );
          final safe =
              (auth.userType == null || auth.userType!.isEmpty) &&
                      pendingRole != null &&
                      pendingRole.isNotEmpty
                  ? auth.copyWith(userType: pendingRole)
                  : auth;
          setState(() {
            _user = safe;
            _booting = false;
            _bootTimedOut = false;
          });
          if (notice != null && notice.isNotEmpty) {
            _messengerKey.currentState
                ?.showSnackBar(SnackBar(content: Text(notice)));
          }
        } catch (e) {
          if (!mounted) return;
          // Kritik: hata olsa bile geçerli session varken _user=null yapma
          // (Google girişinden sonra "başa atma" bug'ı).
          final still = Supabase.instance.client.auth.currentSession;
          if (still == null) {
            setState(() {
              _user = null;
              _booting = false;
            });
          } else if (_user == null) {
            setState(() {
              _user = authUserFromSupabase(still.user);
              _booting = false;
              _bootTimedOut = false;
            });
          } else {
            _finishBooting();
          }
          final msg = e is StateError ? e.message : 'Google giriş başarısız.';
          _messengerKey.currentState
              ?.showSnackBar(SnackBar(content: Text(msg)));
        }
      });
    } catch (e, st) {
      debugPrint('Auth bootstrap failed: $e\n$st');
      _finishBooting();
    }
    unawaited(_bootstrapAuth());
  }

  bool _urlIndicatesPasswordRecovery() {
    return _supabaseAuthParams()['type'] == 'recovery';
  }

  Map<String, String> _supabaseAuthParams() {
    final uri = kIsWeb ? Uri.base : Uri();
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    return params;
  }

  bool _urlHasSupabaseAuthCallback() {
    if (!kIsWeb) return false;
    final params = _supabaseAuthParams();
    return params.containsKey('access_token') ||
        params.containsKey('code') ||
        params['type'] == 'recovery' ||
        params.containsKey('error');
  }

  Future<void> _bootstrapAuth() async {
    try {
      await withNetworkTimeout(
        _bootstrapAuthImpl(),
        timeout: kBootstrapTimeout,
        message: 'Oturum doğrulama zaman aşımına uğradı.',
      );
    } catch (e, st) {
      debugPrint('Auth bootstrap timeout/error: $e\n$st');
    } finally {
      _finishBooting(timedOut: _booting);
    }
  }

  Future<void> _bootstrapAuthImpl() async {
    if (kIsWeb && _urlHasSupabaseAuthCallback()) {
      try {
        await withNetworkTimeout(
          Supabase.instance.client.auth.getSessionFromUrl(Uri.base),
        );
        await Future<void>.delayed(Duration.zero);
        if (_needsPasswordReset) return;
      } on AuthException catch (e) {
        debugPrint('Web auth URL failed: ${e.message}');
      } catch (e, st) {
        debugPrint('Web auth URL failed: $e\n$st');
      }
    }

    if (GoogleAuthService.pendingPasswordRecovery ||
        _urlIndicatesPasswordRecovery()) {
      GoogleAuthService.pendingPasswordRecovery = false;
      if (mounted) {
        setState(() {
          _needsPasswordReset = true;
          _user = null;
          _booting = false;
          _bootTimedOut = false;
        });
      }
      return;
    }
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (_needsPasswordReset) return;
    try {
      // Firebase redirect dönüşü (popup engellendiğinde)
      final pendingBefore = await readPendingGoogleRole();
      final redirected = await withNetworkTimeout(
        GoogleAuthService.completeRedirectIfAny(),
        timeout: kBootstrapTimeout,
      );
      if (redirected?.user != null) {
        final user = await finalizePendingGoogleRole(redirected!.user!);
        if (mounted) {
          final notice = googleAuthNotice;
          googleAuthNotice = null;
          final auth = user == null
              ? null
              : authUserFromSupabase(
                  user,
                  fallbackUserType: pendingBefore,
                );
          final safe = auth == null
              ? null
              : ((auth.userType == null || auth.userType!.isEmpty) &&
                      pendingBefore != null)
                  ? auth.copyWith(userType: pendingBefore)
                  : auth;
          setState(() {
            _user = safe;
            _booting = false;
            _bootTimedOut = false;
          });
          if (notice != null && notice.isNotEmpty) {
            _messengerKey.currentState
                ?.showSnackBar(SnackBar(content: Text(notice)));
          }
        }
        return;
      }
    } catch (e) {
      debugPrint('Google redirect restore: $e');
      // Redirect yok / başarısız → normal oturum kontrolüne devam
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        setState(() {
          _booting = false;
          _bootTimedOut = false;
        });
      }
      return;
    }
    try {
      final pendingRole = await readPendingGoogleRole();
      final user = await withNetworkTimeout(
        finalizePendingGoogleRole(session.user),
        timeout: kBootstrapTimeout,
      );
      if (mounted) {
        final notice = googleAuthNotice;
        googleAuthNotice = null;
        final auth = user == null
            ? null
            : authUserFromSupabase(user, fallbackUserType: pendingRole);
        final safe = auth == null
            ? null
            : ((auth.userType == null || auth.userType!.isEmpty) &&
                    pendingRole != null)
                ? auth.copyWith(userType: pendingRole)
                : auth;
        setState(() {
          _user = safe;
          _booting = false;
          _bootTimedOut = false;
        });
        if (notice != null && notice.isNotEmpty) {
          _messengerKey.currentState
              ?.showSnackBar(SnackBar(content: Text(notice)));
        }
      }
    } catch (_) {
      if (mounted) {
        final still = Supabase.instance.client.auth.currentSession;
        final pendingRole = await readPendingGoogleRole();
        setState(() {
          _user = still == null
              ? null
              : authUserFromSupabase(
                  still.user,
                  fallbackUserType: pendingRole,
                );
          _booting = false;
          _bootTimedOut = false;
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
    _bootWatchdog?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _retryBootstrap() {
    setState(() {
      _booting = true;
      _bootTimedOut = false;
    });
    _bootWatchdog?.cancel();
    _bootWatchdog = Timer(kBootstrapTimeout, () {
      if (_booting) _finishBooting(timedOut: true);
    });
    unawaited(_bootstrapAuth());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        ContentTranslator.instance,
      ]),
      builder: (context, _) {
        final lang = LocaleController.instance.lang;
        return MaterialApp(
          title: 'EngelsizClub',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          locale: lang.locale,
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
          builder: (context, child) {
            return Directionality(
              textDirection:
                  lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: ForceUpdateGate(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: _booting
              ? Scaffold(
                  body: LoadingErrorView(
                    loading: true,
                    loadingMessage: 'Uygulama hazırlanıyor…',
                  ),
                )
              : _needsPasswordReset
                  ? _NewPasswordScreen(
                      onDone: () async {
                        final u = Supabase.instance.client.auth.currentUser;
                        if (!mounted) return;
                        setState(() {
                          _needsPasswordReset = false;
                          _user = u == null ? null : authUserFromSupabase(u);
                        });
                      },
                      onCancel: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        setState(() {
                          _needsPasswordReset = false;
                          _user = null;
                        });
                      },
                    )
                  : _user == null
                      ? AuthScreen(
                          bootTimedOut: _bootTimedOut,
                          onRetryBootstrap: _retryBootstrap,
                          onLogin: (u) async {
                            if (!mounted) return;
                            // Safari'de SharedPreferences takılırsa giriş hiç olmasın diye
                            // önce misafir/üye ekranına geç, limitleri arka planda yaz.
                            setState(() {
                              _user = u;
                              _bootTimedOut = false;
                            });
                            try {
                              if (u.isGuest) {
                                await GuestLimitStore.resetTimedTabsForGuestSession()
                                    .timeout(const Duration(seconds: 2));
                              } else {
                                await GuestLimitStore.clearAll()
                                    .timeout(const Duration(seconds: 2));
                              }
                            } catch (_) {}
                          },
                        )
                      : MainShell(
                          user: _user!,
                          onLogout: _logout,
                          onUserChanged: (u) => setState(() => _user = u),
                          onRequireLogin: () => setState(() => _user = null),
                        ),
        );
      },
    );
  }
}

const _uzmanlikAlanlari = [
  'Fizyoterapist',
  'Ergoterapist',
  'Dil ve Konuşma Terapisti',
  'Özel Eğitim Öğretmeni',
  'Gölge Öğretmen',
  'Çocuk Psikologu',
  'Çocuk Psikiyatristi',
  'Nörolog',
  'Bakıcı',
];

/// Şifre sıfırlama e-postasındaki link sonrası yeni parola belirleme.
class _NewPasswordScreen extends StatefulWidget {
  const _NewPasswordScreen({
    required this.onDone,
    required this.onCancel,
  });

  final Future<void> Function() onDone;
  final Future<void> Function() onCancel;

  @override
  State<_NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<_NewPasswordScreen> {
  final _sifre = TextEditingController();
  final _sifre2 = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _sifre.dispose();
    _sifre2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p1 = _sifre.text;
    final p2 = _sifre2.text;
    if (p1.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Şifre en az 6 karakter olmalı.')),
      );
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Şifreler eşleşmiyor.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: p1),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Şifreniz güncellendi.')),
      );
      await widget.onDone();
    } catch (e) {
      if (!mounted) return;
      final msg = e is AuthException
          ? e.message
          : 'Şifre güncellenemedi. Link süresi dolmuş olabilir.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const L10nText(
                    'Yeni şifre belirle',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const L10nText(
                    'E-postadaki bağlantı ile geldiniz. Hesabınız için yeni bir şifre girin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _sifre,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: S.auto('Yeni şifre'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sifre2,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: S.auto('Yeni şifre (tekrar)'),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const L10nText(
                              'Şifreyi kaydet',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => widget.onCancel(),
                    child: const L10nText('Vazgeç'),
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

/// Birebir Flutter port of Figma Make `AuthScreen`.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.onLogin,
    this.bootTimedOut = false,
    this.onRetryBootstrap,
  });

  final void Function(AuthUser user)? onLogin;
  final bool bootTimedOut;
  final VoidCallback? onRetryBootstrap;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// splash | signin | loading | verify_email
  String _step = 'splash';
  String _authTab = 'giris'; // giris | kayit

  String _girisEmail = '';
  String _girisSifre = '';
  String? _girisHesapTip; // aile | uzman | bakici
  bool _girisLoading = false;

  /// İlk yüklemede hesap türü + Google giriş tanıtımı
  static const _authTourDoneKey = 'auth_login_tour_v1';
  final _roleTourKey = GlobalKey();
  final _googleTourKey = GlobalKey();
  bool _authTourStarted = false;
  bool _authTourActive = false;

  String _kayitAd = '';
  String _kayitEmail = '';
  String _kayitSifre = '';
  String _kayitSifre2 = '';
  String? _kayitTip; // aile | uzman | bakici — seçilmeden form/Google açılmaz
  String? _kayitUzmanlik;
  bool _kayitSozlesme = false;
  bool _kayitLoading = false;

  /// E-posta doğrulama (kayıt sonrası)
  String _verifyEmail = '';
  String? _verifyTip;
  String _verifyCode = '';
  bool _verifyLoading = false;
  bool _resendLoading = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _maybeStartAuthTour() async {
    if (!mounted || _authTourStarted || _step != 'signin') return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_authTourDoneKey) == true) return;
    _authTourStarted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || _step != 'signin') return;
    setState(() {
      _authTab = 'giris';
      _authTourActive = true;
      _girisHesapTip ??= 'aile';
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    ShowcaseView.get().startShowCase([
      _roleTourKey,
      _googleTourKey,
    ]);
  }

  Future<void> _finishAuthTour() async {
    if (mounted) setState(() => _authTourActive = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authTourDoneKey, true);
  }

  void _skipAuthTour() {
    ShowcaseView.get().dismiss();
    unawaited(_finishAuthTour());
  }

  void _goToSignIn() {
    setState(() => _step = 'signin');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeStartAuthTour());
    });
  }

  String _authErrorMessage(Object error) {
    final raw = error is AuthException
        ? error.message
        : error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'E-posta henüz doğrulanmamış. Gelen kutunuzdaki kodu girin.';
    }
    if (lower.contains('token has expired') ||
        lower.contains('otp_expired') ||
        lower.contains('expired')) {
      return 'Kodun süresi dolmuş. Yeni kod gönderin.';
    }
    if (lower.contains('invalid') &&
        (lower.contains('token') || lower.contains('otp'))) {
      return 'Doğrulama kodu hatalı. Tekrar deneyin.';
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
    if (lower.contains('email rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('email address not authorized')) {
      return 'Şu an e-posta ile üyelik geçici olarak kısıtlı '
          '(sunucu e-posta kotası). Lütfen Google ile üye olun '
          'veya 30–60 dk sonra tekrar deneyin.';
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
      final res = await withNetworkTimeout(
        Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        ),
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
        final msg = e.toString().toLowerCase();
        if (msg.contains('email not confirmed') ||
            msg.contains('email_not_confirmed')) {
          setState(() {
            _verifyEmail = email;
            _verifyTip = _girisHesapTip;
            _verifyCode = '';
            _step = 'verify_email';
          });
          unawaited(_resendVerifyCode());
          _snack('E-posta henüz doğrulanmamış. Yeni kod gönderildi.');
        } else {
          setState(() => _step = 'signin');
          _snack(_authErrorMessage(e));
        }
      }
    } finally {
      if (mounted) setState(() => _girisLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _girisEmail.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const L10nText('Parolamı unuttum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const L10nText(
                'Şifre sıfırlama bağlantısını göndereceğimiz e-posta adresinizi girin.',
                style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: S.auto('E-posta adresiniz'),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const L10nText('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(emailCtrl.text.trim()),
              child: const L10nText('Gönder'),
            ),
          ],
        );
      },
    );
    emailCtrl.dispose();
    if (email == null) return;
    if (email.isEmpty || !email.contains('@')) {
      _snack('Geçerli bir e-posta adresi girin.');
      return;
    }
    try {
      await withNetworkTimeout(
        Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          // Web: oturum URL’den yakalanır. Mobil: uygulama deep link’ine döner.
          redirectTo: kIsWeb
              ? Uri.base.origin
              : GoogleAuthService.mobileRedirect,
        ),
      );
      _snack(
        'Sıfırlama bağlantısı gönderildi. E-postanızı kontrol edin '
        '(Spam klasörüne de bakın).',
      );
    } catch (e) {
      _snack(_authErrorMessage(e));
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

      // Android/iOS: sadece tarayıcı OAuth — Firebase/Google Play SHA kullanma
      final res = await GoogleAuthService.signIn();
      final user = res?.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _step = 'signin');
          if (!kIsWeb) {
            _snack(
              'Tarayıcı açıldı. Google ile giriş yapın; uygulama kendiliğinden açılacak.',
            );
          }
        }
        return;
      }

      final finalized = await withNetworkTimeout(
        finalizePendingGoogleRole(user),
      );
      if (finalized == null) {
        throw StateError('Google oturumu tamamlanamadı.');
      }
      final notice = googleAuthNotice;
      googleAuthNotice = null;
      final authUser = authUserFromSupabase(
        finalized,
        fallbackUserType: role,
      );
      // Rol metadata bazen gecikir — yerel rolü her zaman kullan
      final safeUser = authUser.userType == null || authUser.userType!.isEmpty
          ? authUser.copyWith(userType: role)
          : authUser;
      widget.onLogin?.call(safeUser);
      _snack(notice ?? 'Hoş geldin, ${safeUser.name}!');
      if (mounted) setState(() => _step = 'signin');
    } on GoogleAuthRedirecting {
      // Redirect sonrası sayfa yenilenecek; pending rol SharedPreferences’ta
      if (mounted) {
        setState(() => _step = 'loading');
        _snack('Google’a yönlendiriliyorsunuz…');
      }
      return;
    } catch (e) {
      // Redirect değilse pending temizle; aksi halde dönüşte rol kaybolur
      if (e is! GoogleAuthRedirecting) {
        // Session varken silme — auth listener rolü yazar
        final still = Supabase.instance.client.auth.currentSession;
        if (still == null) {
          await clearPendingGoogleRole();
        }
      }
      final still = Supabase.instance.client.auth.currentSession;
      if (still != null) {
        final authUser = authUserFromSupabase(
          still.user,
          fallbackUserType: role,
        );
        final safeUser =
            authUser.userType == null || authUser.userType!.isEmpty
                ? authUser.copyWith(userType: role)
                : authUser;
        widget.onLogin?.call(safeUser);
        if (mounted) {
          setState(() => _step = 'signin');
          _snack(_googleErrorMessage(e));
        }
        return;
      }
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_googleErrorMessage(e));
      }
    } finally {
      if (mounted && _step != 'loading') {
        setState(() {
          _girisLoading = false;
          _kayitLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple(String? role) async {
    if (!AppleAuthService.isAvailable) return;
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
      final res = await AppleAuthService.signIn();
      final user = res?.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _step = 'signin');
          _snack('Apple ile giriş iptal edildi.');
        }
        return;
      }

      final finalized = await withNetworkTimeout(
        finalizePendingGoogleRole(user),
      );
      if (finalized == null) {
        throw StateError('Apple oturumu tamamlanamadı.');
      }
      final notice = googleAuthNotice;
      googleAuthNotice = null;
      final authUser = authUserFromSupabase(
        finalized,
        fallbackUserType: role,
      );
      final safeUser = authUser.userType == null || authUser.userType!.isEmpty
          ? authUser.copyWith(userType: role)
          : authUser;
      widget.onLogin?.call(safeUser);
      _snack(notice ?? 'Hoş geldin, ${safeUser.name}!');
      if (mounted) setState(() => _step = 'signin');
    } catch (e) {
      final still = Supabase.instance.client.auth.currentSession;
      if (still != null) {
        final authUser = authUserFromSupabase(
          still.user,
          fallbackUserType: role,
        );
        final safeUser =
            authUser.userType == null || authUser.userType!.isEmpty
                ? authUser.copyWith(userType: role)
                : authUser;
        widget.onLogin?.call(safeUser);
        if (mounted) {
          setState(() => _step = 'signin');
          _snack(_appleErrorMessage(e));
        }
        return;
      }
      await clearPendingGoogleRole();
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_appleErrorMessage(e));
      }
    } finally {
      if (mounted && _step != 'loading') {
        setState(() {
          _girisLoading = false;
          _kayitLoading = false;
        });
      }
    }
  }

  String _appleErrorMessage(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return 'Apple ile giriş iptal edildi.';
      }
    }
    final raw = error is AuthException
        ? error.message
        : (error is StateError ? error.message : error.toString());
    final lower = raw.toLowerCase();
    if (lower.contains('provider') || lower.contains('audience')) {
      return 'Apple girişi yapılandırılmamış. Supabase → Authentication → '
          'Providers → Apple’ı açın.';
    }
    if (lower.contains('signup') && lower.contains('disabled')) {
      return 'Yeni Apple üyelikleri kapalı. Supabase → Authentication → '
          'Settings: “Allow new users to sign up” açın.';
    }
    return 'Apple ile giriş başarısız: $raw';
  }

  String _googleErrorMessage(Object error) {
    final raw = error is AuthException
        ? error.message
        : (error is firebase_auth.FirebaseAuthException
            ? (error.message ?? error.code)
            : error.toString());
    final lower = raw.toLowerCase();
    if (lower.contains('signup') &&
        (lower.contains('disabled') || lower.contains('not allowed'))) {
      return 'Yeni Google üyelikleri kapalı. Supabase Dashboard → '
          'Authentication → Settings: “Allow new users to sign up” açın.';
    }
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
    if (lower.contains('invalid_app_id') ||
        lower.contains('app_not_authorized') ||
        lower.contains('package certificate hash') ||
        lower.contains('developer_error') ||
        lower.contains('10:') ||
        RegExp(r'\b10\b').hasMatch(lower) && lower.contains('exception')) {
      return 'Google giriş yapılandırması eksik. Tekrar deneyin; '
          'gerekirse tarayıcı ile giriş açılacak.';
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
      _snack(
        'Devam etmek için Kullanım Koşulları, Gizlilik Politikası ve '
        'Sorumluluk Reddi’ni onaylayın.',
      );
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
      final res = await withNetworkTimeout(
        Supabase.instance.client.auth.signUp(
          email: email,
          password: _kayitSifre,
          emailRedirectTo: kIsWeb ? Uri.base.origin : null,
          data: {
            'name': name,
            'user_type': tip,
            if (tip == 'uzman' && _kayitUzmanlik != null)
              'uzmanlik': _kayitUzmanlik,
            if (tip == 'bakici') 'uzmanlik': 'Bakıcı',
            'welcome_credits': kMemberStartKredi,
          },
        ),
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

      final hediyeKredi = startingKrediFor(email, userType: tip);

      // Confirm email AÇIK → session null, mail gitti → kod ekranı
      // Confirm email KAPALI → session var → doğrudan giriş (eski davranış)
      if (res.session != null) {
        final authUser = authUserFromSupabase(
          user,
          fallbackUserType: tip,
        );
        widget.onLogin?.call(authUser);
        _snack(
          hediyeKredi > 0
              ? 'Hoş geldin ${authUser.name}! $hediyeKredi hediye puan hesabına tanımlandı.'
              : 'Hoş geldin ${authUser.name}! Aile rolünde $kMemberStartKredi hediye puan hesabına tanımlandı; ilan paylaşabilir, 2. el ilanlarda ücretsiz iletişim kurabilirsiniz.',
        );
        if (mounted) setState(() => _step = 'signin');
        return;
      }

      if (!mounted) return;
      setState(() {
        _verifyEmail = email;
        _verifyTip = tip;
        _verifyCode = '';
        _girisEmail = email;
        _girisHesapTip = tip;
        _step = 'verify_email';
      });
      _snack(
        hediyeKredi > 0
            ? 'Doğrulama kodu $email adresine gönderildi. '
                'Kodu girince $hediyeKredi hediye puan hesabınızda olacak.'
            : 'Doğrulama kodu $email adresine gönderildi. '
                'Kodu girdikten sonra giriş yapabilirsiniz.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _step = 'signin');
        _snack(_authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _kayitLoading = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final email = _verifyEmail.trim();
    final token = _verifyCode.trim().replaceAll(RegExp(r'\s+'), '');
    if (email.isEmpty) {
      _snack('E-posta bulunamadı. Kayıt formuna dönün.');
      return;
    }
    if (token.length < 6) {
      _snack('E-postadaki 6 haneli doğrulama kodunu girin.');
      return;
    }
    setState(() => _verifyLoading = true);
    try {
      AuthResponse res;
      try {
        res = await withNetworkTimeout(
          Supabase.instance.client.auth.verifyOTP(
            type: OtpType.signup,
            email: email,
            token: token,
          ),
        );
      } catch (_) {
        res = await withNetworkTimeout(
          Supabase.instance.client.auth.verifyOTP(
            type: OtpType.email,
            email: email,
            token: token,
          ),
        );
      }
      final user = res.user;
      if (user == null || res.session == null) {
        throw const AuthException('Doğrulama başarısız. Kodu kontrol edin.');
      }
      final tip = _verifyTip;
      final authUser = authUserFromSupabase(
        user,
        fallbackUserType: tip,
      );
      widget.onLogin?.call(authUser);
      final hediyeKredi = startingKrediFor(email, userType: tip);
      _snack(
        hediyeKredi > 0
            ? 'E-posta doğrulandı. Hoş geldin ${authUser.name}! '
                '$hediyeKredi hediye puan hesabına tanımlandı.'
            : 'E-posta doğrulandı. Hoş geldin ${authUser.name}!',
      );
      if (mounted) {
        setState(() {
          _step = 'signin';
          _verifyCode = '';
        });
      }
    } catch (e) {
      if (mounted) _snack(_authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _verifyLoading = false);
    }
  }

  Future<void> _resendVerifyCode() async {
    final email = _verifyEmail.trim();
    if (email.isEmpty) return;
    setState(() => _resendLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        _snack('Yeni doğrulama kodu gönderildi. Gelen kutunuzu kontrol edin.');
      }
    } catch (e) {
      if (mounted) _snack(_authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  void _backFromVerify() {
    setState(() {
      _step = 'signin';
      _authTab = 'giris';
      _girisEmail = _verifyEmail;
      _verifyCode = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Masaüstünde telefon çerçevesi yok — arka plan tam sayfa; form ortalanır.
    return ShowCaseWidget(
      onFinish: () {
        unawaited(_finishAuthTour());
      },
      onComplete: (index, _) {
        // Rol adımından sonra Google vurgusu için örnek rol seçili kalsın
        if (index == 0 && _girisHesapTip == null && mounted) {
          setState(() => _girisHesapTip = 'aile');
        }
      },
      builder: (context) => Scaffold(
        body: ColoredBox(
          color: MetoColors.background,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    if (widget.bootTimedOut)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Material(
                          color: MetoColors.muted,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const L10nText(
                                  'Sunucuya bağlanırken gecikme yaşandı. '
                                  'Misafir olarak devam edebilir veya tekrar deneyebilirsiniz.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MetoColors.foreground,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (widget.onRetryBootstrap != null)
                                      TextButton(
                                        onPressed: widget.onRetryBootstrap,
                                        child: const L10nText('Tekrar dene'),
                                      ),
                                    const Spacer(),
                                    FilledButton(
                                      onPressed: () =>
                                          widget.onLogin?.call(AuthUser.guest),
                                      child: const L10nText('Misafir devam'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: switch (_step) {
                        'splash' => _SplashStep(
                            onStart: _goToSignIn,
                            onGuest: () =>
                                widget.onLogin?.call(AuthUser.guest),
                          ),
                        'loading' => _LoadingStep(
                            onCancel: () {
                              setState(() {
                                _step = 'signin';
                                _girisLoading = false;
                                _kayitLoading = false;
                              });
                            },
                          ),
                        'verify_email' => _VerifyEmailStep(
                            email: _verifyEmail,
                            code: _verifyCode,
                            loading: _verifyLoading,
                            resendLoading: _resendLoading,
                            onCode: (v) => setState(() => _verifyCode = v),
                            onVerify: _verifyEmailCode,
                            onResend: _resendVerifyCode,
                            onBack: _backFromVerify,
                          ),
                        _ => _SignInStep(
                            authTab: _authTab,
                            onTab: (t) => setState(() => _authTab = t),
                            girisHesapTip: _girisHesapTip,
                            onGirisHesapTip: (v) =>
                                setState(() => _girisHesapTip = v),
                            girisEmail: _girisEmail,
                            girisSifre: _girisSifre,
                            girisLoading: _girisLoading,
                            onGirisEmail: (v) =>
                                setState(() => _girisEmail = v),
                            onGirisSifre: (v) =>
                                setState(() => _girisSifre = v),
                            onSignIn: _signIn,
                            onForgotPassword: _forgotPassword,
                            onGoogleSignIn: _signInWithGoogle,
                            onAppleSignIn: _signInWithApple,
                            onGuest: () =>
                                widget.onLogin?.call(AuthUser.guest),
                            roleTourKey: _roleTourKey,
                            googleTourKey: _googleTourKey,
                            showTourFinger: _authTourActive,
                            onSkipTour: _skipAuthTour,
                            kayitAd: _kayitAd,
                            kayitEmail: _kayitEmail,
                            kayitSifre: _kayitSifre,
                            kayitSifre2: _kayitSifre2,
                            kayitTip: _kayitTip,
                            kayitUzmanlik: _kayitUzmanlik,
                            kayitSozlesme: _kayitSozlesme,
                            kayitLoading: _kayitLoading,
                            onKayitAd: (v) => setState(() => _kayitAd = v),
                            onKayitEmail: (v) =>
                                setState(() => _kayitEmail = v),
                            onKayitSifre: (v) =>
                                setState(() => _kayitSifre = v),
                            onKayitSifre2: (v) =>
                                setState(() => _kayitSifre2 = v),
                            onKayitTip: (v) => setState(() => _kayitTip = v),
                            onKayitUzmanlik: (v) =>
                                setState(() => _kayitUzmanlik = v),
                            onKayitSozlesme: () => setState(
                                () => _kayitSozlesme = !_kayitSozlesme),
                            onCreateAccount: _createAccount,
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── E-posta doğrulama (kayıt sonrası OTP) ───────────────────────────────────

class _VerifyEmailStep extends StatelessWidget {
  const _VerifyEmailStep({
    required this.email,
    required this.code,
    required this.loading,
    required this.resendLoading,
    required this.onCode,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  final String email;
  final String code;
  final bool loading;
  final bool resendLoading;
  final ValueChanged<String> onCode;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: loading ? null : onBack,
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const L10nText('Geri'),
              style: TextButton.styleFrom(
                foregroundColor: MetoColors.primary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const L10nText(
            '✉️',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          L10nText(
            'E-posta doğrulama',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          L10nText(
            'Hesabınıza girmeden önce e-postanıza gelen 6 haneli kodu girin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: MetoColors.mutedFg,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: MetoColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: onCode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 8,
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: S.auto('••••••'),
              hintStyle: GoogleFonts.nunito(
                letterSpacing: 6,
                color: MetoColors.mutedFg,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: MetoColors.card,
            ),
            onSubmitted: (_) => onVerify(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: loading ? null : onVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : L10nText(
                      'Doğrula ve devam et',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: (loading || resendLoading) ? null : onResend,
            child: resendLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : L10nText(
                    'Kodu tekrar gönder',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: MetoColors.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          L10nText(
            'Kod gelmediyse spam/gereksiz klasörünü kontrol edin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Splash (Başlayalım) ─────────────────────────────────────────────────────

class _SplashStep extends StatelessWidget {
  const _SplashStep({required this.onStart, required this.onGuest});

  final VoidCallback onStart;
  final VoidCallback onGuest;

  static const _features = [
    ('📚', 'Bilgi Kütüphanesi', 'Aileler için bilgilendirme içerikleri'),
    ('🗺️', 'Yakınımdaki Merkezler', 'Terapi merkezi ve uzman bul'),
    ('🗣️', 'AAC İletişim Kartları', 'Görsel iletişim desteği'),
    ('⚖️', 'Yasal Haklar & Destek', 'Devlet yardımlarına kolayca ulaş'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomGap = _webBottomTapInset(context);
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
            padding: EdgeInsets.fromLTRB(24, 32, 24, 16 + bottomGap),
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
              const SizedBox(height: 8),
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
                  child: const L10nText('Başlayalım'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetoColors.primary,
                    backgroundColor: MetoColors.card,
                    side: const BorderSide(color: MetoColors.primary, width: 1.5),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const L10nText('Üye olmadan keşfet'),
                ),
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
    required this.girisLoading,
    required this.onGirisEmail,
    required this.onGirisSifre,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    required this.onGuest,
    required this.roleTourKey,
    required this.googleTourKey,
    required this.showTourFinger,
    required this.onSkipTour,
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
  final VoidCallback onForgotPassword;
  final ValueChanged<String?> onGoogleSignIn;
  final ValueChanged<String?> onAppleSignIn;
  final VoidCallback onGuest;
  final GlobalKey roleTourKey;
  final GlobalKey googleTourKey;
  final bool showTourFinger;
  final VoidCallback onSkipTour;

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
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: L10nText(
            'v1.0.21',
            style: TextStyle(
              fontSize: 11,
              color: MetoColors.mutedFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + _webBottomTapInset(context),
            ),
            child: authTab == 'giris' ? _buildGiris(context) : _buildKayit(context),
          ),
        ),
      ],
    );
  }

  Widget _buildGiris(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const L10nText(
          'Hesap Türü',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 6),
        Showcase(
          key: roleTourKey,
          title: 'Hesap türünü seç',
          description:
              'Girişten önce Aile, Uzman veya Bakıcı seçmelisin. '
              'Rol seçmeden Google veya e-posta ile giriş yapılamaz.',
          targetBorderRadius: BorderRadius.circular(14),
          tooltipActions: [
            TooltipActionButton(
              type: TooltipDefaultActionType.skip,
              name: 'Geç',
              onTap: onSkipTour,
            ),
          ],
          child: Row(
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
        ),
        const SizedBox(height: 16),
        if (AppleAuthService.isAvailable) ...[
          _AppleSignInButton(
            onPressed: () {
              if (girisHesapTip == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: L10nText(
                      'Apple ile devam etmek için önce Aile, Uzman veya Bakıcı seçin.',
                    ),
                  ),
                );
                return;
              }
              if (girisLoading) return;
              onAppleSignIn(girisHesapTip);
            },
          ),
          const SizedBox(height: 10),
        ],
        Showcase(
          key: googleTourKey,
          title: 'Google ile giriş',
          description:
              'Üyeliğini hızlıca başlatmak için buraya dokun ve Google '
              'hesabınla devam et.',
          targetBorderRadius: BorderRadius.circular(10),
          tooltipActions: [
            TooltipActionButton(
              type: TooltipDefaultActionType.skip,
              name: 'Geç',
              onTap: onSkipTour,
            ),
          ],
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _GoogleSignInButton(
                enabled: !girisLoading && girisHesapTip != null,
                label: girisHesapTip == null
                    ? 'Google ile giriş (önce hesap türü seçin)'
                    : 'Google ile ${_roleLabel(girisHesapTip)} olarak giriş',
                onPressed: () => onGoogleSignIn(girisHesapTip),
              ),
              if (showTourFinger)
                const Positioned(
                  right: 18,
                  top: -6,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: 48,
                      color: MetoColors.primary,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Color(0x66000000),
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (girisHesapTip == null) ...[
          const SizedBox(height: 10),
          const L10nText(
            'Sosyal giriş için önce Aile, Uzman veya Bakıcı seçin.',
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: girisLoading ? null : onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const L10nText(
                'Parolamı unuttum?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                  : const L10nText('E-posta ile Giriş Yap'),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onGuest,
              style: OutlinedButton.styleFrom(
                foregroundColor: MetoColors.primary,
                backgroundColor: MetoColors.card,
                side: const BorderSide(color: MetoColors.primary),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const L10nText(
                'Üye olmadan keşfet',
                style: TextStyle(
                  color: MetoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKayit(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const L10nText(
          'Yeni hesap oluşturun',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 12),
        const L10nText(
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
        if (kayitTip == null) ...[
          const L10nText(
            'Üye olmak için önce Aile, Uzman veya Bakıcı seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ] else ...[
        if (kayitTip == 'uzman' || kayitTip == 'bakici') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MetoColors.selectedBg,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: MetoColors.primary.withValues(alpha: 0.25)),
            ),
            child: L10nText(
              '🎁 Hoş geldin hediyesi: hesabınıza $kWelcomeKredi ücretsiz puan tanımlanır.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MetoColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 12),
        _KayitLegalCheckbox(
          accepted: kayitSozlesme,
          onToggle: onKayitSozlesme,
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
                hint: const L10nText(
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
                    L10nText(
                      'Kişisel verileriniz güvende',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    L10nText(
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
                      L10nText('Hesap Oluşturuluyor…'),
                    ],
                  )
                : const L10nText('Hesap Oluştur'),
          ),
        ),
        const SizedBox(height: 12),
        const _OrDivider(label: 'veya'),
        const SizedBox(height: 12),
        if (AppleAuthService.isAvailable) ...[
          _AppleSignInButton(
            onPressed: () {
              if (!kayitSozlesme) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: L10nText(
                      'Apple ile devam etmek için Kullanım Koşulları, '
                      'Gizlilik Politikası ve Sorumluluk Reddi’ni onaylayın.',
                    ),
                  ),
                );
                return;
              }
              if (kayitTip == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: L10nText('Önce hesap türünü seçin.'),
                  ),
                );
                return;
              }
              if (kayitLoading) return;
              onAppleSignIn(kayitTip);
            },
          ),
          const SizedBox(height: 10),
        ],
        _GoogleSignInButton(
          enabled: !kayitLoading && kayitTip != null && kayitSozlesme,
          label: !kayitSozlesme
              ? 'Google ile üye ol (önce koşulları onaylayın)'
              : 'Google ile ${_roleLabel(kayitTip)} olarak üye ol',
          onPressed: () {
            if (!kayitSozlesme) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: L10nText(
                    'Google ile devam etmek için Kullanım Koşulları, '
                    'Gizlilik Politikası ve Sorumluluk Reddi’ni onaylayın.',
                  ),
                ),
              );
              return;
            }
            onGoogleSignIn(kayitTip);
          },
        ),
        ],
      ],
    );
  }
}

// ─── Kayıt yasal onay ────────────────────────────────────────────────────────

class _KayitLegalCheckbox extends StatelessWidget {
  const _KayitLegalCheckbox({
    required this.accepted,
    required this.onToggle,
  });

  final bool accepted;
  final VoidCallback onToggle;

  static const _linkStyle = TextStyle(
    color: MetoColors.primary,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1.45,
    decoration: TextDecoration.underline,
    decorationColor: MetoColors.primary,
  );

  static const _baseStyle = TextStyle(
    fontSize: 12,
    color: MetoColors.mutedFg,
    height: 1.45,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: accepted ? MetoColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accepted ? MetoColors.primary : MetoColors.mutedFg,
                width: 2,
              ),
            ),
            child: accepted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: _baseStyle,
              children: [
                const TextSpan(text: ''),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () =>
                        LegalDocumentPage.open(context, LegalDocKind.terms),
                    child: const Text('Kullanım Koşulları', style: _linkStyle),
                  ),
                ),
                const TextSpan(text: ', '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () =>
                        LegalDocumentPage.open(context, LegalDocKind.privacy),
                    child: const Text('Gizlilik Politikası', style: _linkStyle),
                  ),
                ),
                const TextSpan(text: ' ve '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => LegalDocumentPage.open(
                      context,
                      LegalDocKind.disclaimer,
                    ),
                    child: const Text('Sorumluluk Reddi Beyanı', style: _linkStyle),
                  ),
                ),
                const TextSpan(text: '’nı okudum, onaylıyorum. Uygunsuz içeriğe sıfır tolerans uygulanır.'),
              ],
            ),
          ),
        ),
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

class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: SignInWithAppleButton(
        onPressed: onPressed,
        style: SignInWithAppleButtonStyle.black,
        height: 48,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _LoadingStep extends StatefulWidget {
  const _LoadingStep({this.onCancel});

  final VoidCallback? onCancel;

  @override
  State<_LoadingStep> createState() => _LoadingStepState();
}

class _LoadingStepState extends State<_LoadingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _slowTimer;
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _slowTimer = Timer(kNetworkTimeout, () {
      if (mounted) setState(() => _showCancel = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
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
          L10nText(
            _showCancel ? 'Bağlantı bekleniyor…' : 'Giriş yapılıyor…',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          L10nText(
            _showCancel
                ? 'Sunucu yanıt vermiyor. Biraz daha bekleyin veya iptal edin.'
                : 'Hesabınız doğrulanıyor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg),
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
          if (_showCancel && widget.onCancel != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: widget.onCancel,
              child: const L10nText('İptal et ve geri dön'),
            ),
          ],
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
                  L10nText(
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
