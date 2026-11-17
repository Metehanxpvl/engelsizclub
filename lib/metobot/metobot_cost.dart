import 'metobot_routes.dart';

class MetoBotLimits {
  const MetoBotLimits({
    required this.dailyUserMessages,
    required this.maxOutputTokens,
    required this.lastN,
  });

  static const defaults = MetoBotLimits(
    dailyUserMessages: 40,
    maxOutputTokens: 512,
    lastN: 12,
  );

  final int dailyUserMessages;
  final int maxOutputTokens;
  final int lastN;

  static int _positive(Object? raw, int fallback) {
    if (raw is num && raw.isFinite && raw > 0) return raw.round();
    if (raw is String) {
      final n = num.tryParse(raw.trim());
      if (n != null && n.isFinite && n > 0) return n.round();
    }
    return fallback;
  }

  static MetoBotLimits fromSettings(Object? value) {
    try {
      if (value == null) return defaults;
      if (value is num || value is String) {
        return MetoBotLimits(
          dailyUserMessages: _positive(value, defaults.dailyUserMessages),
          maxOutputTokens: defaults.maxOutputTokens,
          lastN: defaults.lastN,
        );
      }
      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        return MetoBotLimits(
          dailyUserMessages: _positive(
            map['dailyUserMessages'] ?? map['daily_user_messages'],
            defaults.dailyUserMessages,
          ),
          maxOutputTokens: _positive(
            map['maxOutputTokens'] ?? map['max_output_tokens'],
            defaults.maxOutputTokens,
          ).clamp(1, 1024),
          lastN: _positive(
            map['lastN'] ?? map['last_n'],
            defaults.lastN,
          ).clamp(1, 20),
        );
      }
    } catch (_) {}
    return defaults;
  }
}

class MetoBotTurn {
  const MetoBotTurn({
    required this.role,
    required this.content,
    this.routes = const [],
  });

  final String role;
  final String content;
  final List<MetoBotSuggestedRoute> routes;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

enum MetoBotSendBlock { empty, busy, debounce, duplicate, dailyCap }

MetoBotSendBlock? metoBotSendBlock({
  required String text,
  required bool inFlight,
  required DateTime now,
  DateTime? lastAttemptAt,
  String? lastSentText,
  DateTime? lastSentAt,
  required int todayCount,
  required int dailyCap,
}) {
  if (inFlight) return MetoBotSendBlock.busy;
  if (text.trim().isEmpty) return MetoBotSendBlock.empty;
  if (lastAttemptAt != null &&
      now.difference(lastAttemptAt).inMilliseconds < 800) {
    return MetoBotSendBlock.debounce;
  }
  if (lastSentText != null &&
      lastSentText == text.trim() &&
      lastSentAt != null &&
      now.difference(lastSentAt).inMilliseconds < 10000) {
    return MetoBotSendBlock.duplicate;
  }
  if (todayCount >= dailyCap) return MetoBotSendBlock.dailyCap;
  return null;
}

const kMetoBotOffline =
    'Şu an bağlanamadı. Biraz sonra deneyin.';
const kMetoBotDailyCap =
    'Bugünkü mesaj sınırına ulaşıldı. Yarın tekrar deneyin.';
const kMetoBotAuth =
    'MetoBot için giriş yapmanız veya üye olmanız gerekiyor.';
const kMetoBotServer =
    'Sunucu hatası oluştu. Biraz sonra tekrar deneyin.';
const kMetoBotQuota =
    'Model kotası doldu. Biraz sonra tekrar deneyin.';

({String code, String message}) metoBotMapInvokeError({
  int? status,
  Object? details,
  String? fallbackCode,
}) {
  Map<String, dynamic>? map;
  if (details is Map) {
    map = details.map((k, v) => MapEntry(k.toString(), v));
  }
  final code = (map?['code'] ?? fallbackCode ?? '').toString().trim();
  final lower = code.toLowerCase();
  final raw = (map?['error'] ?? map?['message'] ?? '').toString().trim();
  final rawLower = raw.toLowerCase();

  if (lower == 'daily_cap') {
    return (code: 'daily_cap', message: kMetoBotDailyCap);
  }
  if (lower == 'auth' || status == 401) {
    return (code: 'auth', message: kMetoBotAuth);
  }
  if (lower == 'empty') {
    return (code: 'empty', message: 'Mesaj boş.');
  }
  if (lower == 'quota' ||
      rawLower.contains('kota') ||
      rawLower.contains('quota') ||
      rawLower.contains('resource_exhausted')) {
    return (code: 'quota', message: kMetoBotQuota);
  }
  if (lower == 'rate_limit' || (status == 429 && lower != 'daily_cap')) {
    return (
      code: 'rate_limit',
      message: raw.isNotEmpty ? raw : 'Biraz bekleyip tekrar deneyin.',
    );
  }

  final missingFn = status == 404 ||
      lower == 'not_found' ||
      rawLower.contains('not found') ||
      rawLower.contains('function was not found');
  if (missingFn) {
    return (code: 'offline', message: kMetoBotOffline);
  }
  if (status == 500 ||
      status == 502 ||
      status == 503 ||
      status == 504 ||
      lower == 'upstream' ||
      lower == 'config') {
    return (
      code: lower.isEmpty ? 'upstream' : lower,
      message: kMetoBotServer,
    );
  }
  if (lower == 'network' || lower == 'offline') {
    return (code: 'offline', message: kMetoBotOffline);
  }
  if (raw.isNotEmpty) {
    return (code: lower.isEmpty ? 'error' : lower, message: raw);
  }
  return (code: 'offline', message: kMetoBotOffline);
}

List<MetoBotTurn> metoBotLastN(List<MetoBotTurn> messages, int n) {
  final cap = n <= 0 ? MetoBotLimits.defaults.lastN : n;
  final cleaned = [
    for (final m in messages)
      if (m.content.trim().isNotEmpty)
        MetoBotTurn(
          role: m.role,
          content: m.content.trim().length > 1500
              ? m.content.trim().substring(0, 1500)
              : m.content.trim(),
        ),
  ];
  if (cleaned.length <= cap) return cleaned;
  return cleaned.sublist(cleaned.length - cap);
}
