import 'package:flutter/material.dart';

import '../meto_theme.dart';
import '../user_safety_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';

/// Şikayet + engelle bottom sheet.
Future<void> showUserSafetySheet(
  BuildContext context, {
  required String targetEmail,
  String targetDisplayName = '',
  String contextLabel = 'genel',
  String contentType = '',
  String contentId = '',
  VoidCallback? onBlocked,
  VoidCallback? onReported,
}) async {
  final email = targetEmail.trim().toLowerCase();
  final hasUser = email.contains('@');
  final hasContent =
      contentType.trim().isNotEmpty && contentId.trim().isNotEmpty;
  if (!hasUser && !hasContent) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: L10nText('Bu içerik şikayet edilemez.')),
    );
    return;
  }

  if (hasUser) await loadBlockedEmails();
  if (!context.mounted) return;
  final alreadyBlocked = hasUser && isBlockedEmail(email);
  final label = targetDisplayName.trim().isNotEmpty
      ? targetDisplayName.trim()
      : (hasUser ? email.split('@').first : 'İçerik');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _UserSafetySheetBody(
      targetEmail: hasUser ? email : '',
      targetDisplayName: label,
      contextLabel: contextLabel,
      contentType: contentType,
      contentId: contentId,
      initiallyBlocked: alreadyBlocked,
      allowBlock: hasUser,
      onBlocked: onBlocked,
      onReported: onReported,
    ),
  );
}

class _UserSafetySheetBody extends StatefulWidget {
  const _UserSafetySheetBody({
    required this.targetEmail,
    required this.targetDisplayName,
    required this.contextLabel,
    required this.initiallyBlocked,
    this.contentType = '',
    this.contentId = '',
    this.allowBlock = true,
    this.onBlocked,
    this.onReported,
  });

  final String targetEmail;
  final String targetDisplayName;
  final String contextLabel;
  final String contentType;
  final String contentId;
  final bool initiallyBlocked;
  final bool allowBlock;
  final VoidCallback? onBlocked;
  final VoidCallback? onReported;

  @override
  State<_UserSafetySheetBody> createState() => _UserSafetySheetBodyState();
}

class _UserSafetySheetBodyState extends State<_UserSafetySheetBody> {
  String? _reason;
  final _detail = TextEditingController();
  bool _busy = false;
  late bool _blocked;

  @override
  void initState() {
    super.initState();
    _blocked = widget.initiallyBlocked;
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _report() async {
    if (_reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Şikayet nedeni seçin.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await reportUser(
        targetEmail: widget.targetEmail,
        reason: _reason!,
        context: widget.contextLabel,
        detail: _detail.text,
        targetDisplayName: widget.targetDisplayName,
        contentType: widget.contentType,
        contentId: widget.contentId,
      );
      if (!mounted) return;
      widget.onReported?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Şikayetiniz alındı. Teşekkürler.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('user_reports') ||
                    e.toString().contains('schema cache')
                ? 'Şikayet tablosu henüz yok. user_blocks_reports.sql çalıştırın.'
                : 'Şikayet gönderilemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleBlock() async {
    setState(() => _busy = true);
    try {
      if (_blocked) {
        await unblockUser(widget.targetEmail);
        if (!mounted) return;
        setState(() {
          _blocked = false;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: L10nText('${widget.targetDisplayName} engeli kaldırıldı.'),
          ),
        );
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const L10nText('Kullanıcıyı engelle'),
            content: L10nText(
              '${widget.targetDisplayName} engellenecek. Mesajları ve sohbetleri gizlenecek. İstediğiniz zaman engeli kaldırabilirsiniz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const L10nText('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
                child: const L10nText('Engelle'),
              ),
            ],
          ),
        );
        if (ok != true) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        await blockUser(widget.targetEmail);
        if (!mounted) return;
        widget.onBlocked?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: L10nText('${widget.targetDisplayName} engellendi.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('user_blocks') ||
                    e.toString().contains('schema cache')
                ? 'Engel tablosu henüz yok. user_blocks_reports.sql çalıştırın.'
                : 'İşlem başarısız: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.targetDisplayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          const L10nText(
            'Hakaret, taciz veya uygunsuz davranış için şikayet edin veya engelleyin.',
            style: TextStyle(fontSize: 13, color: MetoColors.mutedFg, height: 1.35),
          ),
          const SizedBox(height: 16),
          const L10nText(
            'Şikayet nedeni',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in kReportReasons)
                ChoiceChip(
                  label: Text(r, style: const TextStyle(fontSize: 12)),
                  selected: _reason == r,
                  onSelected: _busy
                      ? null
                      : (sel) => setState(() => _reason = sel ? r : null),
                  selectedColor: MetoColors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _reason == r
                        ? MetoColors.primary
                        : MetoColors.foreground,
                    fontWeight:
                        _reason == r ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detail,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: S.auto('İsteğe bağlı detay…'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _report,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const L10nText('Şikayet et'),
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.allowBlock)
            OutlinedButton.icon(
              onPressed: _busy ? null : _toggleBlock,
              icon: Icon(
                _blocked ? Icons.lock_open_outlined : Icons.block,
                size: 18,
                color: const Color(0xFFEF4444),
              ),
              label: Text(
                _blocked ? 'Engeli kaldır' : 'Engelle',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
