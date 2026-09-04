import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/avm_cover_lookup.dart';
import '../gezi_kampanya_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'gezi_kampanya_feed_card.dart';

/// Admin: bekleyen / reddedilen kullanıcı önerileri.
class EtkinlikPendingSheet extends StatelessWidget {
  const EtkinlikPendingSheet({
    super.key,
    required this.items,
    required this.adminEmail,
    required this.avmCovers,
    required this.onChanged,
  });

  final List<KampanyaItem> items;
  final String adminEmail;
  final AvmCoverIndex avmCovers;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final pending = items.where(isEtkinlikPending).toList();
    final rejected = items.where(isEtkinlikRejected).toList();
    return Container(
      decoration: const BoxDecoration(
        color: MetoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
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
              const SizedBox(height: 14),
              L10nText(
                'Onay bekleyen etkinlikler',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: L10nText(
                          'Bekleyen öneri yok.',
                          style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final item in pending)
                            _PendingTile(
                              item: item,
                              adminEmail: adminEmail,
                              avmCovers: avmCovers,
                              onChanged: onChanged,
                            ),
                          if (rejected.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                              child: L10nText(
                                'Reddedilenler',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ),
                            for (final item in rejected)
                              _PendingTile(
                                item: item,
                                adminEmail: adminEmail,
                                avmCovers: avmCovers,
                                onChanged: onChanged,
                                rejected: true,
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.item,
    required this.adminEmail,
    required this.avmCovers,
    required this.onChanged,
    this.rejected = false,
  });

  final KampanyaItem item;
  final String adminEmail;
  final AvmCoverIndex avmCovers;
  final Future<void> Function() onChanged;
  final bool rejected;

  Future<void> _approve(BuildContext context) async {
    try {
      await approveEtkinlik(id: item.id, adminEmail: adminEmail);
      await onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Etkinlik onaylandı.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Öneriyi reddet?'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Kısa gerekçe (isteğe bağlı)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const L10nText('Reddet'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null) return;
    try {
      await rejectEtkinlik(
        id: item.id,
        adminEmail: adminEmail,
        reason: reason,
      );
      await onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Öneri reddedildi.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GeziKampanyaFeedCard(
            imageUrl: item.imageUrl,
            title: item.title,
            description: item.cardDescription,
            locationLabel: item.avmName.trim(),
            venueLabel: item.avmName.trim(),
            whenLabel: item.eventWhenLabel,
            timeLabel: item.eventTimeLabel,
            brandedCover: true,
            coverPlaceholderLabel: item.avmName.trim(),
            avmCoverUrl: avmCovers.urlFor(city: item.city, avmName: item.avmName),
            coverVariantSeed: item.id,
            statusBadge: rejected
                ? (item.rejectionReason.trim().isEmpty
                    ? 'Reddedildi'
                    : 'Reddedildi: ${item.rejectionReason.trim()}')
                : 'Onay bekliyor',
          ),
          if (!rejected)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _approve(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                      ),
                      child: const L10nText('Onayla'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const L10nText('Reddet'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
