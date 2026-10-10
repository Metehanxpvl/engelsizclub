import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../duyuru_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/broadcast_push_service.dart';

/// Admin: serbest metin → «Bunu biliyor muydunuz?» bildirimi.
class AdminDidYouKnowSheet extends StatefulWidget {
  const AdminDidYouKnowSheet({super.key, required this.adminEmail});

  final String adminEmail;

  static Future<void> open(BuildContext context, {required String adminEmail}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminDidYouKnowSheet(adminEmail: adminEmail),
    );
  }

  @override
  State<AdminDidYouKnowSheet> createState() => _AdminDidYouKnowSheetState();
}

class _AdminDidYouKnowSheetState extends State<AdminDidYouKnowSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = didYouKnowPushBody(_text.text);
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bir mesaj yazın.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await BroadcastPushService.instance.biliyorMuydunuz(
        message: message,
        adminEmail: widget.adminEmail,
      );
      if (!mounted) return;
      if (sent) {
        invalidateDuyuruCache();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: L10nText(
              'Yayınlandı. Üyeler ana sayfada görür, bildirim de gider.',
            ),
          ),
        );
      } else {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: L10nText('Bildirim gönderilemedi. Tekrar deneyin.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final preview = didYouKnowPushBody(_text.text);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              kDidYouKnowTitle,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            L10nText(
              'Ana sayfada «Bunu biliyor musunuz?» köşesinde yayınlanır. Üyeler uygulamayı açınca görür, bildirim de gider.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: MetoColors.mutedFg,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 6,
              maxLength: kDidYouKnowMaxChars,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(),
              decoration: InputDecoration(
                hintText: 'Üyelere iletmek istediğiniz mesaj…',
                filled: true,
                fillColor: MetoColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: MetoColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: MetoColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: MetoColors.primary),
                ),
              ),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MetoColors.selectedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kDidYouKnowTitle,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      style: GoogleFonts.nunito(
                        height: 1.4,
                        color: MetoColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _sending ? 'Gönderiliyor…' : 'Bildirim gönder',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
