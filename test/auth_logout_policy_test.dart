import 'package:engelsizclub/auth_logout_policy.dart';
import 'package:engelsizclub/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('çıkış sonrası token yenileme oturumu geri getirmez', () {
    expect(
      blockAuthRestoreAfterLogout(
        loggingOut: true,
        isSignedInEvent: false,
        isPasswordRecoveryEvent: false,
      ),
      isTrue,
    );
  });

  test('çıkış sonrası yeni giriş kabul edilir', () {
    expect(
      blockAuthRestoreAfterLogout(
        loggingOut: true,
        isSignedInEvent: true,
        isPasswordRecoveryEvent: false,
      ),
      isFalse,
    );
  });

  test('çıkış sonrası şifre sıfırlama kabul edilir', () {
    expect(
      blockAuthRestoreAfterLogout(
        loggingOut: true,
        isSignedInEvent: false,
        isPasswordRecoveryEvent: true,
      ),
      isFalse,
    );
  });

  test('çıkış yokken dinleyici kesilmez', () {
    expect(
      blockAuthRestoreAfterLogout(
        loggingOut: false,
        isSignedInEvent: false,
        isPasswordRecoveryEvent: false,
      ),
      isFalse,
    );
  });

  test('web Google picker keeps the sign-in form visible', () {
    expect(GoogleAuthService.hidesAuthFormDuringPicker(isWeb: true), isFalse);
    expect(GoogleAuthService.hidesAuthFormDuringPicker(isWeb: false), isTrue);
  });

  test('web Google sign-in reloads to recover CanvasKit gray screen', () {
    expect(
      GoogleAuthService.reloadsAfterSuccessfulWebSignIn(isWeb: true),
      isTrue,
    );
    expect(
      GoogleAuthService.reloadsAfterSuccessfulWebSignIn(isWeb: false),
      isFalse,
    );
  });
}
