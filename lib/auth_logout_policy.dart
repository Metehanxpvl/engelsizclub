/// Çıkış ekranındayken token yenileme / broadcast oturumu geri getirmesin.
/// Yeni giriş ve şifre sıfırlama yine işlensin.
bool blockAuthRestoreAfterLogout({
  required bool loggingOut,
  required bool isSignedInEvent,
  required bool isPasswordRecoveryEvent,
}) {
  if (!loggingOut) return false;
  if (isSignedInEvent || isPasswordRecoveryEvent) return false;
  return true;
}
