import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../data/ilanlar_data.dart';
import '../kullanici_profil_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../uzman_kosesi/expert_cv_models.dart';
import '../uzman_kosesi/kurum_is_ilan_models.dart';
import '../uzman_kosesi/kurum_is_ilan_store.dart';
import '../widgets/catalog_media.dart';
import '../widgets/guest_gate.dart';
import '../widgets/photo_gallery_lightbox.dart';
import 'ilanlar_page.dart';
import 'uzman_kosesi_kurum_ilan_form_page.dart';

class UzmanKosesKurumIlanDetailPage extends StatefulWidget {
  const UzmanKosesKurumIlanDetailPage({
    super.key,
    required this.ilan,
    this.userEmail = '',
    this.isGuest = false,
    this.onRequireLogin,
  });

  final KurumIsIlani ilan;
  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  static Future<bool> open(
    BuildContext context, {
    required KurumIsIlani ilan,
    String userEmail = '',
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UzmanKosesKurumIlanDetailPage(
          ilan: ilan,
          userEmail: userEmail,
          isGuest: isGuest,
          onRequireLogin: onRequireLogin,
        ),
      ),
    );
    return changed == true;
  }

  @override
  State<UzmanKosesKurumIlanDetailPage> createState() =>
      _UzmanKosesKurumIlanDetailPageState();
}

class _UzmanKosesKurumIlanDetailPageState
    extends State<UzmanKosesKurumIlanDetailPage> {
  late KurumIsIlani _ilan;
  bool _busy = false;

  String get _myEmail {
    final fromWidget = widget.userEmail.trim().toLowerCase();
    if (fromWidget.isNotEmpty) return fromWidget;
    try {
      return (Supabase.instance.client.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
    } catch (_) {
      return '';
    }
  }

  bool get _isOwner {
    final mail = _myEmail;
    return mail.isNotEmpty && mail == _ilan.ownerEmail;
  }

  bool get _isAdmin => isAppAdmin(_myEmail) || isAppAdmin(widget.userEmail);

  @override
  void initState() {
    super.initState();
    _ilan = widget.ilan;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_ilan.id <= 0) return;
    final row = await loadKurumIsIlani(_ilan.id);
    if (!mounted || row == null) return;
    setState(() => _ilan = row);
  }

  Future<bool> _ensureLoggedIn() async {
    if (_myEmail.isNotEmpty && !widget.isGuest) return true;
    if (widget.onRequireLogin != null) {
      return ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin!,
      );
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: L10nText('Bu işlem için giriş yapın.')),
    );
    return false;
  }

  Future<void> _openMesaj() async {
    if (!await _ensureLoggedIn()) return;
    final peer = _ilan.ownerEmail.trim().toLowerCase();
    if (peer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bu ilanla mesaj açılamadı.')),
      );
      return;
    }
    if (peer == _myEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Kendi ilanınıza mesaj gönderemezsiniz.'),
        ),
      );
      return;
    }
    var myName = '';
    try {
      myName = (await loadKullaniciProfil(_myEmail)).adSoyad.trim();
    } catch (_) {}
    if (!mounted) return;
    final ad = _ilan.kurumAdi.trim().isEmpty ? 'Kurum' : _ilan.kurumAdi.trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: SohbetKisi(
            ad: ad,
            avatar: contactAvatarLetter(ad),
            avatarColor: MetoColors.primary,
            isOnline: false,
            peerEmail: peer,
            ilanTitle: _ilan.arananMeslek,
          ),
          myEmail: _myEmail,
          myDisplayName: myName,
        ),
      ),
    );
  }

  Future<void> _openRandevu() async {
    final raw = _ilan.telefon.trim();
    if (uzmanTelAranabilir(raw)) {
      final uri = Uri.parse('tel:${uzmanTelDigits(raw)}');
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: L10nText('Ara: $raw')),
          );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: L10nText('Ara: $raw')),
        );
      }
      return;
    }
    await _openMesaj();
  }

  Future<void> _edit() async {
    final saved = await UzmanKosesKurumIlanFormPage.open(
      context,
      userEmail: widget.userEmail,
      existing: _ilan,
    );
    if (saved && mounted) {
      await _refresh();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(_isAdmin && !_isOwner ? 'İlanı sil (Admin)' : 'İlanı sil'),
        content: const L10nText('Bu kurum iş ilanı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await deleteKurumIsIlani(_ilan.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is StateError ? e.message : 'İlan silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: L10nText(
          'Kurum iş ilanı',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isOwner)
            TextButton(
              onPressed: _busy ? null : _edit,
              child: const L10nText('Düzenle'),
            ),
          if (_isOwner || _isAdmin)
            IconButton(
              tooltip: 'Sil',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_ilan.photoUrl.trim().isNotEmpty) ...[
            GestureDetector(
              onTap: () => openFillPhotoOverlay(
                context,
                source: _ilan.photoUrl,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CatalogImage(
                  source: _ilan.photoUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            _ilan.arananMeslek,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ilan.kurumAdi,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MetoColors.primary,
            ),
          ),
          if (_ilan.yerLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _ilan.yerLabel,
                style: const TextStyle(color: MetoColors.mutedFg),
              ),
            ),
          if (_ilan.adres.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: MetoColors.mutedFg,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _ilan.adres.trim(),
                      style: const TextStyle(
                        color: MetoColors.foreground,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_ilan.calismaSekli.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _ilan.calismaSekli)
                  Chip(label: Text(s), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(_ilan.aciklama, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 24),
          if (_isAdmin && !_isOwner) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _openMesaj,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const L10nText('İlan sahibine mesaj'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const L10nText('İlanı kaldır'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
                side: const BorderSide(color: Color(0xFFB42318)),
              ),
            ),
          ] else if (!_isOwner) ...[
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _openMesaj,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetoColors.primary,
                        side: const BorderSide(
                          color: MetoColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const L10nText('Mesaj gönder'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _openRandevu,
                      style: FilledButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const L10nText('Randevu talep et'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
