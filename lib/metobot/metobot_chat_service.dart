import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'metobot_cost.dart';
import 'metobot_routes.dart';

class MetoBotReply {
  const MetoBotReply({
    this.reply,
    this.threadId,
    this.error,
    this.code,
    this.suggestedRoutes = const [],
  });

  final String? reply;
  final String? threadId;
  final String? error;
  final String? code;
  final List<MetoBotSuggestedRoute> suggestedRoutes;

  bool get ok => (reply ?? '').trim().isNotEmpty;
}

class MetoBotChatService {
  MetoBotChatService._();
  static final MetoBotChatService instance = MetoBotChatService._();

  static const _countKey = 'metobot_daily_count';
  static const _dateKey = 'metobot_daily_date';
  static const _timeout = Duration(seconds: 36);

  MetoBotLimits? _cachedLimits;

  String _todayStamp() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  Future<MetoBotLimits> loadLimits() async {
    if (_cachedLimits != null) return _cachedLimits!;
    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'metobot_limits')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      final parsed = MetoBotLimits.fromSettings(row?['value']);
      _cachedLimits = parsed;
      return parsed;
    } catch (_) {
      return MetoBotLimits.defaults;
    }
  }

  Future<int> todayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dateKey) != _todayStamp()) return 0;
      return prefs.getInt(_countKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> incrementToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stamp = _todayStamp();
      final current =
          prefs.getString(_dateKey) == stamp ? (prefs.getInt(_countKey) ?? 0) : 0;
      await prefs.setString(_dateKey, stamp);
      await prefs.setInt(_countKey, current + 1);
    } catch (_) {}
  }

  Future<(String?, List<MetoBotTurn>)> loadLatestThread() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return (null, const <MetoBotTurn>[]);
    try {
      final thread = await Supabase.instance.client
          .from('metobot_threads')
          .select('id')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final id = thread?['id']?.toString();
      if (id == null || id.isEmpty) return (null, const <MetoBotTurn>[]);
      final rows = await Supabase.instance.client
          .from('metobot_messages')
          .select('role, content')
          .eq('thread_id', id)
          .order('created_at')
          .timeout(const Duration(seconds: 8));
      final list = <MetoBotTurn>[];
      for (final row in rows as List) {
        if (row is! Map) continue;
        final role = row['role']?.toString() ?? '';
        final content = row['content']?.toString() ?? '';
        if (content.trim().isEmpty) continue;
        if (role != 'user' && role != 'assistant') continue;
        list.add(MetoBotTurn(role: role, content: content));
      }
      return (id, list);
    } catch (e) {
      debugPrint('metobot load: $e');
      return (null, const <MetoBotTurn>[]);
    }
  }

  Future<MetoBotReply> send({
    required List<MetoBotTurn> messages,
    String? threadId,
    required int lastN,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const MetoBotReply(
        error: 'Giriş gerekli.',
        code: 'auth',
      );
    }
    final payload = metoBotLastN(messages, lastN);
    if (payload.isEmpty || payload.last.role != 'user') {
      return const MetoBotReply(error: 'Mesaj boş.', code: 'empty');
    }
    try {
      final res = await Supabase.instance.client.functions
          .invoke(
            'metobot-chat',
            body: {
              'messages': [
                for (final m in payload) m.toJson(),
              ],
              if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
            },
          )
          .timeout(_timeout);
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) {
        map = data.map((k, v) => MapEntry(k.toString(), v));
      }
      if (res.status >= 200 && res.status < 300) {
        final reply = map?['reply']?.toString().trim() ?? '';
        if (reply.isEmpty) {
          final mapped = metoBotMapInvokeError(
            status: res.status,
            details: map,
            fallbackCode: 'upstream',
          );
          return MetoBotReply(error: mapped.message, code: mapped.code);
        }
        return MetoBotReply(
          reply: reply,
          threadId: map?['threadId']?.toString(),
          suggestedRoutes: parseMetoBotSuggestedRoutes(map?['suggestedRoutes']),
        );
      }
      final mapped = metoBotMapInvokeError(
        status: res.status,
        details: map,
      );
      return MetoBotReply(error: mapped.message, code: mapped.code);
    } on FunctionException catch (e) {
      final mapped = metoBotMapInvokeError(
        status: e.status,
        details: e.details,
      );
      return MetoBotReply(error: mapped.message, code: mapped.code);
    } catch (e) {
      debugPrint('metobot send: $e');
      final mapped = metoBotMapInvokeError(fallbackCode: 'network');
      return MetoBotReply(error: mapped.message, code: mapped.code);
    }
  }
}
