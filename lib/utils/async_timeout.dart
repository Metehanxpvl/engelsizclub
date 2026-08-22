import 'dart:async';

/// Default network timeout for Supabase / HTTP calls.
const kNetworkTimeout = Duration(seconds: 10);

/// App launch auth/session restore timeout.
const kBootstrapTimeout = Duration(seconds: 10);

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

extension FutureNetworkTimeout<T> on Future<T> {
  Future<T> withNetworkTimeout({
    Duration timeout = kNetworkTimeout,
    String? message,
  }) =>
      withNetworkTimeout(this, timeout: timeout, message: message);
}
