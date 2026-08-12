import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../medical_disclaimer_store.dart';
import '../meto_theme.dart';

/// Yeşil bilgilendirme kartı. [dismissKey] verilirse kapatılır ve
/// SharedPreferences’te saklanır (bir daha gösterilmez).
class MedicalInfoCard extends StatefulWidget {
  const MedicalInfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    this.margin = EdgeInsets.zero,
    this.dismissKey,
    this.dismissLabel = 'Bir daha gösterme',
  });

  final String title;
  final String body;
  final IconData icon;
  final EdgeInsetsGeometry margin;

  /// Boş değilse kapatma / bir daha gösterme gösterilir; kapatınca kaydedilir.
  final String? dismissKey;
  final String dismissLabel;

  @override
  State<MedicalInfoCard> createState() => _MedicalInfoCardState();
}

class _MedicalInfoCardState extends State<MedicalInfoCard> {
  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = widget.dismissKey;
    if (key == null || key.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final gone = await isInfoCardDismissed(key);
    if (!mounted) return;
    setState(() {
      _dismissed = gone;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    final key = widget.dismissKey;
    if (key == null || key.isEmpty) return;
    setState(() => _dismissed = true);
    await dismissInfoCard(key);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed) return const SizedBox.shrink();

    final canDismiss =
        widget.dismissKey != null && widget.dismissKey!.isNotEmpty;

    return Container(
      margin: widget.margin,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: MetoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(widget.icon, size: 20, color: MetoColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.body,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDismiss)
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: MetoColors.mutedFg,
                  ),
                ),
            ],
          ),
          if (canDismiss) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _dismiss,
                style: TextButton.styleFrom(
                  foregroundColor: MetoColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  widget.dismissLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
