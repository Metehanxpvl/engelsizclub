import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/duyuru_data.dart';
import '../duyuru_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/broadcast_push_service.dart';

/// Ana sayfa: Güncel Duyurular altı — adminin yayınladığı «Bunu biliyor musunuz?»
class DidYouKnowCorner extends StatefulWidget {
  const DidYouKnowCorner({super.key, required this.userEmail});

  final String userEmail;

  @override
  State<DidYouKnowCorner> createState() => _DidYouKnowCornerState();
}

class _DidYouKnowCornerState extends State<DidYouKnowCorner> {
  List<DuyuruItem> _items = const [];

  @override
  void initState() {
    super.initState();
    final cached = cachedDuyurular;
    if (cached != null) {
      _items = didYouKnowForHome(cached);
    }
    _reload();
  }

  Future<void> _reload() async {
    final all = await loadDuyurular(viewerEmail: widget.userEmail);
    if (!mounted) return;
    setState(() => _items = didYouKnowForHome(all));
  }

  void _open(DuyuruItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText(kDidYouKnowTitle),
        content: SingleChildScrollView(
          child: Text(
            item.body.trim(),
            style: GoogleFonts.nunito(height: 1.45, fontSize: 15),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const L10nText('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final latest = _items.first;
    final rest = _items.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _open(latest),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetoColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MetoColors.selectedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('💡', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kDidYouKnowTitle,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latest.body.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          height: 1.4,
                          color: MetoColors.foreground,
                        ),
                      ),
                      if (rest > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '+$rest önceki paylaşım',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
