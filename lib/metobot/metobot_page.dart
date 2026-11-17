import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../widgets/guest_gate.dart';
import 'metobot_avatar.dart';
import 'metobot_chat_service.dart';
import 'metobot_cost.dart';

const _kDisclaimerKey = 'metobot_disclaimer_v1';
const _welcome =
    'Merhaba. Ben MetoBot. Engelsiz Club’da yanındayım. Nasıl yardımcı olayım?';

Future<String?> openMetoBot(
  BuildContext context, {
  bool isGuest = false,
  VoidCallback? onRequireLogin,
}) async {
  final loggedIn = Supabase.instance.client.auth.currentUser != null;
  if (isGuest || !loggedIn) {
    await ensureMemberAccess(
      context,
      isGuest: true,
      onRequireLogin: onRequireLogin ?? () {},
      message: 'MetoBot için giriş yapmanız veya üye olmanız gerekiyor.',
    );
    return null;
  }

  var accepted = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    accepted = prefs.getBool(_kDisclaimerKey) == true;
  } catch (_) {}

  if (!accepted) {
    if (!context.mounted) return null;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: L10nText(
          'Önemli bilgi',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        content: L10nText(
          'MetoBot doktor değildir, teşhis koymaz.\n\n'
          'Acil durumda 112’yi arayın. Sağlık kararları için hekiminize danışın.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: MetoColors.mutedFg,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: L10nText(
              'Vazgeç',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: MetoColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: L10nText(
              'Anladım',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDisclaimerKey, true);
    } catch (_) {}
  }

  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      settings: const RouteSettings(name: MetoBotPage.routeName),
      builder: (_) => const MetoBotPage(),
    ),
  );
}

class MetoBotPage extends StatefulWidget {
  const MetoBotPage({super.key});

  static const String routeName = '/metobot';

  @override
  State<MetoBotPage> createState() => _MetoBotPageState();
}

class _MetoBotPageState extends State<MetoBotPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <MetoBotTurn>[];

  MetoBotLimits _limits = MetoBotLimits.defaults;
  String? _threadId;
  bool _loading = true;
  bool _inFlight = false;
  int _todayCount = 0;
  DateTime? _lastAttemptAt;
  DateTime? _lastSentAt;
  String? _lastSentText;
  String? _failHint;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final service = MetoBotChatService.instance;
    final limits = await service.loadLimits();
    final today = await service.todayCount();
    final loaded = await service.loadLatestThread();
    if (!mounted) return;
    setState(() {
      _limits = limits;
      _todayCount = today;
      _threadId = loaded.$1;
      _messages
        ..clear()
        ..addAll(loaded.$2);
      _loading = false;
    });
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _snack(String source) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.auto(source)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final block = metoBotSendBlock(
      text: text,
      inFlight: _inFlight,
      now: DateTime.now(),
      lastAttemptAt: _lastAttemptAt,
      lastSentText: _lastSentText,
      lastSentAt: _lastSentAt,
      todayCount: _todayCount,
      dailyCap: _limits.dailyUserMessages,
    );
    if (block == MetoBotSendBlock.empty ||
        block == MetoBotSendBlock.debounce ||
        block == MetoBotSendBlock.busy ||
        block == MetoBotSendBlock.duplicate) {
      return;
    }
    if (block == MetoBotSendBlock.dailyCap) {
      setState(() => _failHint = kMetoBotDailyCap);
      _snack(kMetoBotDailyCap);
      return;
    }

    _lastAttemptAt = DateTime.now();
    setState(() {
      _inFlight = true;
      _failHint = null;
      _messages.add(MetoBotTurn(role: 'user', content: text));
    });
    _input.clear();
    _jumpToEnd();

    final result = await MetoBotChatService.instance.send(
      messages: _messages,
      threadId: _threadId,
      lastN: _limits.lastN,
    );
    if (!mounted) return;

    final reply = result.reply?.trim() ?? '';
    if (!result.ok || reply.isEmpty) {
      final mapped = metoBotMapInvokeError(
        details: {
          'code': result.code,
          'error': result.error,
        },
        fallbackCode: result.code ?? 'offline',
      );
      setState(() {
        _inFlight = false;
        _failHint = mapped.message;
        if (_messages.isNotEmpty &&
            _messages.last.role == 'user' &&
            _messages.last.content == text) {
          _messages.removeLast();
        }
        if (_input.text.trim().isEmpty) _input.text = text;
      });
      _snack(mapped.message);
      return;
    }

    await MetoBotChatService.instance.incrementToday();
    final today = await MetoBotChatService.instance.todayCount();
    if (!mounted) return;
    setState(() {
      _inFlight = false;
      _failHint = null;
      _todayCount = today;
      _threadId = result.threadId ?? _threadId;
      _lastSentText = text;
      _lastSentAt = DateTime.now();
      _messages.add(MetoBotTurn(
        role: 'assistant',
        content: reply,
        routes: result.suggestedRoutes,
      ));
    });
    _jumpToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_inFlight && _input.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const MetoBotAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L10nText(
                    'MetoBot',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: MetoColors.foreground,
                    ),
                  ),
                  L10nText(
                    'Yardımcı asistan',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: MetoColors.primary),
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      if (_messages.isEmpty) _welcomeBubble(),
                      for (final m in _messages) _bubble(m),
                      if (_inFlight) _typing(),
                    ],
                  ),
          ),
          Material(
            color: MetoColors.card,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (canSend) _send();
                            },
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MetoColors.foreground,
                            ),
                            decoration: InputDecoration(
                              hintText: S.auto('Mesaj yazın'),
                              hintStyle: GoogleFonts.nunito(
                                color: MetoColors.mutedFg,
                                fontWeight: FontWeight.w600,
                              ),
                              filled: true,
                              fillColor: MetoColors.muted,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: FilledButton(
                            onPressed: canSend ? _send : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                              disabledBackgroundColor: MetoColors.muted,
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: _inFlight
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: L10nText(
                        'Bugün $_todayCount / ${_limits.dailyUserMessages} mesaj',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                    ),
                    if (_failHint != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: L10nText(
                          _failHint!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB42318),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetoBotAvatar(size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: MetoColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MetoColors.border),
              ),
              child: L10nText(
                _welcome,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typing() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          const MetoBotAvatar(size: 28),
          const SizedBox(width: 8),
          L10nText(
            'Yazıyor…',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(MetoBotTurn m) {
    final mine = m.role == 'user';
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: mine ? MetoColors.primary : MetoColors.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: MetoColors.border),
      ),
      child: L10nText(
        m.content,
        style: GoogleFonts.nunito(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: mine ? Colors.white : MetoColors.foreground,
        ),
      ),
    );
    if (mine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const MetoBotAvatar(size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bubble,
                if (m.routes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hint in m.routes)
                        ActionChip(
                          onPressed: _inFlight
                              ? null
                              : () => Navigator.of(context).pop(hint.route),
                          backgroundColor: MetoColors.selectedBg,
                          side: const BorderSide(color: MetoColors.border),
                          label: L10nText(
                            hint.title,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
