import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/centers_data.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../widgets/guest_gate.dart';
import 'place_models.dart';
import 'place_store.dart';

/// Detayda erişilebilirlik özeti. Satır yalnız [PlaceStore.submitReview] ile açılır.
class PlaceAccessibilityPanel extends StatefulWidget {
  const PlaceAccessibilityPanel({
    super.key,
    required this.center,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final MetoCenter center;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<PlaceAccessibilityPanel> createState() =>
      _PlaceAccessibilityPanelState();
}

class _PlaceAccessibilityPanelState extends State<PlaceAccessibilityPanel> {
  PlaceAccessSummary _summary = const PlaceAccessSummary(reviews: []);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PlaceAccessibilityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center.id != widget.center.id ||
        oldWidget.center.googlePlaceId != widget.center.googlePlaceId) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await PlaceStore.instance.loadReviews(widget.center);
    if (!mounted) return;
    setState(() {
      _summary = PlaceAccessSummary(reviews: list);
      _loading = false;
    });
  }

  Future<void> _openForm() async {
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    if (widget.isGuest || !signedIn) {
      if (!mounted) return;
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Değerlendirmek için giriş yapın.',
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccessReviewSheet(center: widget.center),
    );
    if (saved == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const L10nText(
            'Erişilebilirlik',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_summary.isEmpty)
            const L10nText(
              'Henüz değerlendirme yok. İlk sen ol.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
                height: 1.4,
              ),
            )
          else ...[
            L10nText(
              '${_summary.count} değerlendirme',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 10),
            for (final c in kAccessCriteria)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.foreground,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7EDE4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _summary.labelFor(c.key),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _openForm,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const L10nText('Değerlendir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessReviewSheet extends StatefulWidget {
  const _AccessReviewSheet({required this.center});

  final MetoCenter center;

  @override
  State<_AccessReviewSheet> createState() => _AccessReviewSheetState();
}

class _AccessReviewSheetState extends State<_AccessReviewSheet> {
  final _note = TextEditingController();
  final _values = <String, int>{
    for (final c in kAccessCriteria) c.key: 1,
  };
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PlaceStore.instance.submitReview(
        center: widget.center,
        criteria: Map<String, int>.from(_values),
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
              const L10nText(
                'Erişilebilirlik değerlendirmesi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                widget.center.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 16),
              for (final c in kAccessCriteria) ...[
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in kAccessScale) ...[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ChoiceChip(
                            label: Center(child: Text(s.label)),
                            selected: _values[c.key] == s.value,
                            onSelected: (_) =>
                                setState(() => _values[c.key] = s.value),
                            selectedColor: const Color(0xFFC8E6D4),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (s != kAccessScale.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const L10nText('Gönder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
