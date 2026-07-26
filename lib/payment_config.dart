/// Gerçek kart tahsilatı için iyzico / PayTR / Stripe gerekir.
/// Kart numarası ve CVV uygulamada veya Supabase'de ASLA saklanmaz.
/// Para, üye işyeri anlaşmanızdaki banka hesabına (IBAN) ödeme firması tarafından yatırılır.
///
/// Anahtarları aldığınızda buraya yazın veya --dart-define ile verin:
/// flutter run --dart-define=IYZICO_API_KEY=xxx --dart-define=IYZICO_SECRET_KEY=yyy
class PaymentConfig {
  static const iyzicoApiKey = String.fromEnvironment('IYZICO_API_KEY');
  static const iyzicoSecretKey = String.fromEnvironment('IYZICO_SECRET_KEY');

  /// false iken kart formu UI gösterilir ama tahsilat yapılmaz (havale çalışır).
  static bool get kartTahsilatHazir =>
      iyzicoApiKey.isNotEmpty && iyzicoSecretKey.isNotEmpty;
}
