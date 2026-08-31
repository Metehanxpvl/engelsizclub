import 'dart:async';

/// Default network timeout for Supabase / HTTP calls.
const kNetworkTimeout = Duration(seconds: 10);

/// App launch auth/session restore timeout.
const kBootstrapTimeout = Duration(seconds: 10);

/// Single-row ilan detail (photos). List feed has no client timeout.
const kIlanlarTimeout = Duration(seconds: 20);

/// Last-resort hang guard for the metadata list only — never the tab UI.
const kIlanListHangGuard = Duration(seconds: 90);

/// Soft copy when the list HTTP call is slow or fails. Not a hard tab failure.
const kIlanListSlowMessage = 'Bağlantı yavaş — tekrar dene';

class NetworkTimeoutException implements Exception {
  NetworkTimeoutException([this.message = 'İstek zaman aşımına uğradı.']);

  final String message;

  @override
  String toString() => message;
}

/// Runs [future] with an explicit timeout; throws [NetworkTimeoutException].
Future<T> withNetworkTimeout<T>(
  Future<T> future, {
  Duration timeout = kNetworkTimeout,
  String? message,
}) {
  return future.timeout(
    timeout,
    onTimeout: () => throw NetworkTimeoutException(
      message ??
          'Bağlantı yavaş veya yanıt vermiyor. Lütfen tekrar deneyin.',
    ),
  );
}

/// Timeouts and transient network failures — not auth / RLS / permission.
bool isRetryableNetworkError(Object error) {
  if (error is NetworkTimeoutException || error is TimeoutException) {
    return true;
  }
  final msg = error.toString().toLowerCase();
  if (msg.contains('401') ||
      msg.contains('403') ||
      msg.contains('42501') ||
      msg.contains('row-level security') ||
      msg.contains('not authorized') ||
      msg.contains('unauthorized') ||
      msg.contains('permission denied') ||
      msg.contains('jwt')) {
    return false;
  }
  return msg.contains('timeout') ||
      msg.contains('timed out') ||
      msg.contains('zaman aşımı') ||
      msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('failed host lookup') ||
      msg.contains('network') ||
      msg.contains('clientexception') ||
      msg.contains('502') ||
      msg.contains('503') ||
      msg.contains('504');
}

/// Runs [action] with [timeout], retrying 1–2 times on transient errors.
///
/// [maxAttempts] includes the first try (3 = 1 try + 2 retries).
/// [onRetry] is called with the failed attempt number (1-based) before waiting.
Future<T> withNetworkRetry<T>(
  Future<T> Function() action, {
  Duration timeout = kNetworkTimeout,
  int maxAttempts = 3,
  String? message,
  void Function(int attempt)? onRetry,
}) async {
  assert(maxAttempts >= 1);
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await withNetworkTimeout(
        action(),
        timeout: timeout,
        message: message,
      );
    } catch (e) {
      lastError = e;
      final canRetry = attempt < maxAttempts && isRetryableNetworkError(e);
      if (!canRetry) rethrow;
      onRetry?.call(attempt);
      final backoffMs = 400 * (1 << (attempt - 1));
      await Future<void>.delayed(Duration(milliseconds: backoffMs));
    }
  }
  throw lastError!;
}
