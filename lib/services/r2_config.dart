/// Cloudflare R2 — compile-time dart-define only; do not put keys in source.
///
/// Required for client SigV4 PUT:
///   --dart-define=R2_ACCESS_KEY_ID=...
///   --dart-define=R2_SECRET_ACCESS_KEY=...
///   --dart-define=R2_ENDPOINT=https://ACCOUNT_ID.r2.cloudflarestorage.com
///   --dart-define=R2_BUCKET=engelsizclub-labels
///
/// Public object URL (S3 API host is not the CDN):
///   --dart-define=R2_PUBLIC_BASE_URL=https://pub-xxx.r2.dev
/// Default is the Engelsiz Club r2.dev host (public CDN, not a secret).
///
/// Optional Worker (R2 presign + POST /gemini CORS proxy):
///   --dart-define=R2_WORKER_URL=https://engelsizclub-r2.<account>.workers.dev
///   --dart-define=GEMINI_PROXY_URL=https://engelsizclub-r2.<account>.workers.dev/gemini
class R2Config {
  R2Config._();

  static const accessKeyId = String.fromEnvironment(
    'R2_ACCESS_KEY_ID',
    defaultValue: '',
  );

  static const secretAccessKey = String.fromEnvironment(
    'R2_SECRET_ACCESS_KEY',
    defaultValue: '',
  );

  static const endpoint = String.fromEnvironment(
    'R2_ENDPOINT',
    defaultValue:
        'https://22d8a199f4ecf32ed81795a03f2d3a1c.r2.cloudflarestorage.com',
  );

  static const bucket = String.fromEnvironment(
    'R2_BUCKET',
    defaultValue: 'engelsizclub-labels',
  );

  static const publicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-b37e9c19660c4a9994f5f75493eda814.r2.dev',
  );

  static const workerUrl = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: '',
  );

  static const accountId = String.fromEnvironment(
    'R2_ACCOUNT_ID',
    defaultValue: '',
  );

  static String get trimmedEndpoint =>
      endpoint.trim().replaceAll(RegExp(r'/+$'), '');

  static String get trimmedPublicBase =>
      publicBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static String get trimmedWorkerUrl =>
      workerUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static String get trimmedBucket {
    final b = bucket.trim();
    return b.isEmpty ? 'engelsizclub-labels' : b;
  }

  static bool get hasWorker => trimmedWorkerUrl.startsWith('http');

  /// Client SigV4: access + secret + S3 endpoint + bucket. No key defaults.
  static bool get hasClientSigV4 =>
      accessKeyId.trim().isNotEmpty &&
      secretAccessKey.trim().isNotEmpty &&
      trimmedEndpoint.startsWith('http') &&
      trimmedBucket.isNotEmpty;

  /// Public HTTPS URL: `{base}/{key}` (trailing/leading slashes stripped).
  static String publicObjectUrl(String objectKey) {
    final base = trimmedPublicBase;
    final key = objectKey.trim().replaceFirst(RegExp(r'^/+'), '');
    return '$base/$key';
  }
}
