import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../data/ilanlar_data.dart';
import '../kullanici_profil_store.dart';
import '../l10n/l10n_text.dart';
import '../uzman_kosesi/expert_cv_models.dart';
import '../uzman_kosesi/expert_cv_store.dart';
import '../uzman_kosesi/expert_profile_views_store.dart';
import '../uzman_kosesi/expert_reviews_store.dart';
import '../uzman_kosesi_profiles_store.dart';
import '../widgets/catalog_media.dart';
import '../widgets/guest_gate.dart';
import 'ilanlar_page.dart';
import 'uzman_kosesi_cv_form_page.dart';

class _Tp {
  static const bg = Color(0xFFF2F6F3);
  static const hero = Color(0xFF0F3D2E);
  static const accent = Color(0xFF0F6B4B);
  static const mint = Color(0xFFE3F1EA);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF4A6A5B);
  static const ink = Color(0xFF0F2A20);
  static const line = Color(0xFFDCE7E0);
  static const star = Color(0xFFE2A318);
  static const starOff = Color(0xFFD5E4DB);
}

class UzmanKosesCvDetailPage extends StatefulWidget {
  const UzmanKosesCvDetailPage({
    super.key,
    this.profileId,
    this.ownerId,
    this.ownerEmail,
    this.listing,
    this.userEmail = '',
    this.isGuest = false,
    this.onRequireLogin,
    this.preview,
    this.previewAsOwner = false,
    this.previewViewCount = 0,
    this.previewReviews = const [],
  });

  final int? profileId;
  final String? ownerId;
  final String? ownerEmail;
  final UzmanKosesProfil? listing;
  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;
  /// Test / tasarım önizlemesi. Doluysa ağ çağrısı yapılmaz.
  final ExpertCvProfile? preview;
  final bool previewAsOwner;
  final int previewViewCount;
  final List<ExpertReview> previewReviews;

  static Future<void> open(
    BuildContext context, {
    int? profileId,
    String? ownerId,
    String? ownerEmail,
    UzmanKosesProfil? listing,
    String userEmail = '',
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UzmanKosesCvDetailPage(
          profileId: profileId,
          ownerId: ownerId,
          ownerEmail: ownerEmail,
          listing: listing,
          userEmail: userEmail,
          isGuest: isGuest,
          onRequireLogin: onRequireLogin,
        ),
      ),
    );
  }

  @override
  State<UzmanKosesCvDetailPage> createState() => _UzmanKosesCvDetailPageState();
}

class _UzmanKosesCvDetailPageState extends State<UzmanKosesCvDetailPage> {
  ExpertCvProfile? _p;
  Map<String, String> _files = const {};
  bool _loading = true;
  bool _canSeeFiles = false;
  int _viewCount = 0;
  List<ExpertReview> _reviews = const [];
  int _myRating = 0;
  bool _savingReview = false;
  bool _deleting = false;
  final _myText = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preview != null) {
      _p = widget.preview;
      _viewCount = widget.previewViewCount;
      _reviews = widget.previewReviews;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _myText.dispose();
    super.dispose();
  }

  String get _myEmail {
    try {
      final auth = (Supabase.instance.client.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      if (auth.isNotEmpty) return auth;
    } catch (_) {}
    return widget.userEmail.trim().toLowerCase();
  }

  bool get _isAdmin =>
      isAppAdmin(_myEmail) || isAppAdmin(widget.userEmail);

  bool get _isOwner {
    if (widget.previewAsOwner) return true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final uid = user?.id ?? '';
      final email = (user?.email ?? '').trim().toLowerCase();
      if (uid.isNotEmpty && uid == (_p?.ownerId ?? widget.ownerId ?? '')) {
        return true;
      }
      if (email.isNotEmpty &&
          email ==
              (_p?.ownerEmail ?? widget.ownerEmail ?? '')
                  .trim()
                  .toLowerCase()) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _load() async {
    ExpertCvProfile? p;
    if (widget.profileId != null) {
      p = await loadExpertProfileById(widget.profileId!);
    }
    p ??= await loadPublicExpertProfile(
      ownerId: widget.ownerId ?? widget.listing?.ownerId ?? '',
      ownerEmail: widget.ownerEmail ?? widget.listing?.ownerEmail ?? '',
    );
    p = _mergeListing(p, widget.listing);
    Map<String, String> files = const {};
    var canSee = false;
    var views = 0;
    var reviews = const <ExpertReview>[];
    if (p != null) {
      canSee = _maySeeFiles(p);
      if (canSee && p.id > 0) files = await loadExpertFiles(p.id);
      if (p.id > 0) reviews = await loadExpertReviews(p.id);
    }
    if (!mounted) return;
    final ownerNow = p != null && _isOwnerOf(p);
    if (p != null && p.id > 0) {
      if (ownerNow) {
        views = await loadExpertProfileViewCount(p.id);
      } else {
        await recordExpertProfileView(p.id);
      }
    }
    if (!mounted) return;
    final mine = reviews.where((r) => r.authorEmail == _myEmail).toList();
    setState(() {
      _p = p;
      _files = files;
      _canSeeFiles = canSee;
      _viewCount = views;
      _reviews = reviews;
      _loading = false;
      if (mine.isNotEmpty) {
        _myRating = mine.first.rating;
        if (_myText.text.trim().isEmpty) _myText.text = mine.first.body;
      }
    });
  }

  bool _isOwnerOf(ExpertCvProfile p) {
    if (widget.previewAsOwner) return true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final uid = user?.id ?? '';
      final email = (user?.email ?? '').trim().toLowerCase();
      if (uid.isNotEmpty && uid == p.ownerId) return true;
      if (email.isNotEmpty &&
          email == p.ownerEmail.trim().toLowerCase()) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  ExpertCvProfile? _mergeListing(
    ExpertCvProfile? cv,
    UzmanKosesProfil? listing,
  ) {
    if (listing == null) return cv;
    if (cv == null) {
      return ExpertCvProfile(
        ownerId: listing.ownerId,
        ownerEmail: listing.ownerEmail,
        fullName: listing.fullName,
        photoUrl: listing.photoUrl,
        meslekEtiket: listing.meslek,
        ustGrup: listing.ustGrup,
        il: listing.il,
        ilce: listing.ilce,
        countryCode: listing.countryCode,
        deneyimYili: listing.deneyimYili,
        dogrulandi: listing.dogrulandi,
        status: 'published',
      );
    }
    return cv.withMeslek(
      etiket: listing.meslek,
      ustGrup: listing.ustGrup,
    );
  }

  bool _maySeeFiles(ExpertCvProfile p) {
    if (isAppAdmin(widget.userEmail) || isAppAdmin(_myEmail)) return true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = (user?.email ?? '').trim().toLowerCase();
      if (isAppAdmin(email)) return true;
      if (user?.id != null && user!.id == p.ownerId) return true;
    } catch (_) {}
    return false;
  }

  Future<void> _editMine() async {
    final email = _myEmail;
    if (email.isEmpty) return;
    final saved = await UzmanKosesCvFormPage.open(context, userEmail: email);
    if (saved == true && mounted) {
      await _load();
      if (_p == null && mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteMine() async {
    if (widget.preview != null || _deleting) return;
    final adminRemove = _isAdmin && !_isOwner;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(adminRemove ? 'Profili kaldır (Admin)' : kUzmanIlanSil),
        content: L10nText(
          adminRemove
              ? 'Bu uzman profili kaldırılacak. İlan sahibine gerekirse mesaj atabilirsiniz.'
              : kUzmanIlanSilOnay,
        ),
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
            child: const L10nText(kUzmanIlanSil),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      if (adminRemove) {
        final oid = (_p?.ownerId ?? widget.ownerId ?? widget.listing?.ownerId ?? '')
            .trim();
        await deleteExpertProfileAsAdmin(ownerId: oid);
      } else {
        await deleteMyExpertProfile();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final msg = e is StateError ? e.message : 'İlan silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
    final p = _p;
    if (p == null || !mounted) return;
    final peer = p.ownerEmail.trim().toLowerCase();
    if (peer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bu uzmanla mesaj açılamadı.')),
      );
      return;
    }
    if (peer == _myEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Kendi profilinize mesaj gönderemezsiniz.'),
        ),
      );
      return;
    }
    final me = _myEmail;
    var myName = '';
    try {
      myName = (await loadKullaniciProfil(me)).adSoyad.trim();
    } catch (_) {}
    if (!mounted) return;
    final ad = p.fullName.trim().isEmpty ? 'Uzman' : p.fullName.trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: SohbetKisi(
            ad: ad,
            avatar: contactAvatarLetter(ad),
            avatarColor: _Tp.accent,
            isOnline: false,
            peerEmail: peer,
            ilanTitle: p.meslekEtiket,
          ),
          myEmail: me,
          myDisplayName: myName,
        ),
      ),
    );
  }

  Future<void> _openRandevu() async {
    final p = _p;
    if (p == null) return;
    final raw = p.cepTelefonu.trim();
    if (uzmanTelAranabilir(raw)) {
      final digits = uzmanTelDigits(raw);
      final uri = Uri.parse('tel:$digits');
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

  Future<void> _submitReview() async {
    if (!await _ensureLoggedIn()) return;
    final p = _p;
    if (p == null || p.id <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Yorum için profil henüz yayınlanmamış.')),
      );
      return;
    }
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Kendi profilinize yorum yazamazsınız.')),
      );
      return;
    }
    if (_myRating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Lütfen 1-5 yıldız seçin.')),
      );
      return;
    }
    final text = _myText.text.trim();
    if (text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Yorum en az 3 karakter olmalı.')),
      );
      return;
    }
    setState(() => _savingReview = true);
    var name = '';
    try {
      name = (await loadKullaniciProfil(_myEmail)).adSoyad.trim();
    } catch (_) {}
    try {
      final saved = await upsertExpertReview(
        profileId: p.id,
        expertOwnerId: p.ownerId,
        rating: _myRating,
        body: text,
        authorName: name,
      );
      if (!mounted) return;
      setState(() {
        _reviews = [
          saved,
          ..._reviews.where((r) => r.authorEmail != saved.authorEmail),
        ];
        _savingReview = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Yorumunuz kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingReview = false);
      final msg = e is StateError ? e.message : 'Yorum kaydedilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _deleteReview(ExpertReview r) async {
    final admin = isAppAdmin(_myEmail) || isAppAdmin(widget.userEmail);
    if (!canDeleteExpertReview(
      viewerEmail: _myEmail.isNotEmpty ? _myEmail : widget.userEmail,
      authorEmail: r.authorEmail,
    )) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(admin ? 'Yorumu sil (Admin)' : 'Yorumu sil'),
        content: const L10nText('Bu yorum kalıcı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteExpertReview(r.id);
      if (!mounted) return;
      setState(() {
        _reviews = _reviews.where((e) => e.id != r.id).toList();
        if (r.authorEmail == _myEmail) {
          _myRating = 0;
          _myText.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'Yorum silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  TextStyle _inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = _Tp.ink,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: _Tp.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _Tp.accent))
          : p == null
              ? const Center(child: L10nText('Özgeçmiş bulunamadı'))
              : Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _hero(p),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                child: Column(
                                  children: [
                                    _aboutCard(p),
                                    _workplaceCard(p),
                                    _quickGrid(p),
                                    _groupsCard(p),
                                    _expertiseCard(p),
                                    _certsCard(p),
                                    _reviewsCard(),
                                    if (_canSeeFiles) _filesNote(),
                                    const SizedBox(height: 8),
                                    if (p.isBakim)
                                      L10nText(
                                        kBakimKimlikNotu,
                                        style: _inter(
                                          size: 12,
                                          color: _Tp.muted,
                                          height: 1.35,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    L10nText(
                                      kUzmanSorumlulukReddi,
                                      style: _inter(
                                        size: 12,
                                        color: _Tp.muted,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (_isOwner) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _deleting ? null : _deleteMine,
                                          icon: const Icon(Icons.delete_outline),
                                          label: const L10nText(kUzmanIlanSil),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFB42318),
                                            side: const BorderSide(
                                              color: Color(0xFFB42318),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
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
                    if (_isOwner) _ownerBar() else _bottomBar(),
                  ],
                ),
    );
  }

  Widget _hero(ExpertCvProfile p) {
    final uzmanlik = uzmanHeroUzmanlik(p);
    final uni = p.isBakim ? '' : _fmt(p.meslekDetaylari['universite']);
    final yil = p.isBakim ? '' : _fmt(p.meslekDetaylari['mezuniyet_yili']);
    final bolum = p.isBakici ? p.mezunBolum : '';
    final badges = <({IconData icon, String label})>[
      for (final s in p.calismaSekli)
        if (s.trim().isNotEmpty)
          (icon: _calismaIcon(s), label: s.trim()),
      for (final s in p.musaitlik)
        if (s.trim().isNotEmpty)
          (icon: _musaitIcon(s), label: s.trim()),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _Tp.hero,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _circleIconBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: 'Geri',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: L10nText(
                      uzmanProfilEkranBasligi(p),
                      style: _inter(
                        size: 16,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_isOwner) ...[
                    _circleIconBtn(
                      icon: Icons.edit_outlined,
                      label: 'Düzenle',
                      onTap: _editMine,
                    ),
                    const SizedBox(width: 8),
                    _circleIconBtn(
                      icon: Icons.delete_outline,
                      label: kUzmanIlanSil,
                      onTap: _deleting ? () {} : _deleteMine,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(p),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          style: _inter(
                            size: 24,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (uzmanlik.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            uzmanlik,
                            style: _inter(
                              size: 14,
                              weight: FontWeight.w400,
                              color: const Color(0xFFD5E8DE),
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (_reviews.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _starRow(expertReviewOrtalama(_reviews), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                uzmanYildizOzeti(
                                  expertReviewOrtalama(_reviews),
                                  _reviews.length,
                                ),
                                style: _inter(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFFE4F2EA),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_isOwner) ...[
                          const SizedBox(height: 8),
                          _heroPill(
                            Icons.visibility_outlined,
                            uzmanProfilBakanOzeti(_viewCount),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (uni.isNotEmpty || yil.isNotEmpty || bolum.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (uni.isNotEmpty)
                  Text(
                    uni,
                    style: _inter(
                      size: 14,
                      weight: FontWeight.w500,
                      color: const Color(0xFFE4F2EA),
                    ),
                  ),
                if (bolum.isNotEmpty)
                  Text(
                    bolum,
                    style: _inter(
                      size: 14,
                      weight: FontWeight.w500,
                      color: const Color(0xFFE4F2EA),
                    ),
                  ),
                if (yil.isNotEmpty)
                  Text(
                    '$yil mezunu',
                    style: _inter(
                      size: 14,
                      weight: FontWeight.w400,
                      color: const Color(0xFFD5E8DE),
                    ),
                  ),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in badges) _heroPill(b.icon, b.label),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(ExpertCvProfile p) {
    final initials = uzmanBasHarfler(p.fullName);
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: p.photoUrl.trim().isNotEmpty
                ? CatalogImage(
                    source: p.photoUrl,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => _initials(initials),
                  )
                : _initials(initials),
          ),
          if (p.dogrulanmisProfil)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _Tp.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Tp.hero, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initials(String text) {
    return Container(
      width: 84,
      height: 84,
      color: _Tp.mint,
      alignment: Alignment.center,
      child: Text(
        text,
        style: _inter(size: 26, weight: FontWeight.w700, color: _Tp.accent),
      ),
    );
  }

  Widget _circleIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: _inter(
              size: 13,
              weight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickGrid(ExpertCvProfile p) {
    final items = <({IconData icon, String label, String value})>[
      for (final s in uzmanHizliBilgiler(p))
        (
          icon: _hizliIcon(s.iconHint),
          label: s.label,
          value: s.value,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final rows = <List<({IconData icon, String label, String value})>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(items.sublist(i, i + 2 > items.length ? items.length : i + 2));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _quickTile(row[0])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: row.length == 2
                          ? _quickTile(row[1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickTile(({IconData icon, String label, String value}) it) {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _Tp.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(it.icon, size: 18, color: _Tp.accent),
          ),
          const SizedBox(height: 10),
          L10nText(
            it.label,
            style: _inter(size: 12, weight: FontWeight.w500, color: _Tp.muted),
          ),
          const SizedBox(height: 2),
          Text(
            it.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _inter(size: 16, weight: FontWeight.w600, color: _Tp.ink),
          ),
        ],
      ),
    );
  }

  Future<void> _openIsYeriHarita(String addr) async {
    final q = Uri.encodeComponent(addr);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText(addr)),
      );
    }
  }

  Widget _workplaceCard(ExpertCvProfile p) {
    final addr = p.isYeriAdresi;
    if (addr.isEmpty) return const SizedBox.shrink();
    final canSee = uzmanIsYeriAdresiGorunur(
      isGuest: widget.isGuest,
      userEmail: _myEmail,
      isOwner: _isOwner,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              uzmanAdresKartBasligi(p),
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 8),
            if (canSee) ...[
              Text(
                addr,
                style: _inter(
                  size: 14,
                  weight: FontWeight.w500,
                  color: _Tp.ink,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _openIsYeriHarita(addr),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const L10nText('Haritada aç'),
                style: TextButton.styleFrom(
                  foregroundColor: _Tp.accent,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ] else ...[
              L10nText(
                kUzmanIsYeriAdresGirisNotu,
                style: _inter(size: 14, color: _Tp.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _ensureLoggedIn(),
                child: const L10nText('Giriş yap'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aboutCard(ExpertCvProfile p) {
    final tanitim = p.kisaTanitim.trim();
    final deneyim = p.isBakim
        ? (p.meslekDetaylari['deneyim_aciklama']?.toString().trim() ?? '')
        : '';
    final parts = <String>[
      if (tanitim.isNotEmpty) tanitim,
      if (deneyim.isNotEmpty && deneyim != tanitim) deneyim,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              'Hakkında',
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(
                parts[i],
                textAlign: TextAlign.justify,
                style: _inter(
                  size: 14,
                  weight: FontWeight.w400,
                  color: _Tp.ink,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupsCard(ExpertCvProfile p) {
    final tags = uzmanGrupKartEtiketleri(p);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              uzmanGrupKartBasligi(p),
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags) _pill(t, filled: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expertiseCard(ExpertCvProfile p) {
    final tags = uzmanUzmanlikKartEtiketleri(p);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              uzmanUzmanlikKartBasligi(p),
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags) _pill(t, filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _certsCard(ExpertCvProfile p) {
    final rows = uzmanSertifikaSatirlari([
      p.meslekDetaylari['belgeler'],
      p.meslekDetaylari['sertifikalar'],
      p.meslekDetaylari['egitim_sertifika'],
    ]);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              'Sertifikalar',
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _Tp.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 20,
                      color: _Tp.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].baslik,
                          style: _inter(
                            size: 15,
                            weight: FontWeight.w600,
                            color: _Tp.ink,
                          ),
                        ),
                        if (rows[i].kurum.isNotEmpty)
                          Text(
                            rows[i].kurum,
                            style: _inter(
                              size: 13,
                              weight: FontWeight.w400,
                              color: _Tp.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewsCard() {
    final avg = expertReviewOrtalama(_reviews);
    final canWrite = !_isOwner;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              'Yorumlar',
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 8),
            if (_reviews.isEmpty)
              L10nText(
                kUzmanYorumYok,
                style: _inter(size: 14, weight: FontWeight.w500, color: _Tp.muted),
              )
            else ...[
              Row(
                children: [
                  _starRow(avg, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    uzmanYildizOzeti(avg, _reviews.length),
                    style: _inter(size: 15, weight: FontWeight.w600, color: _Tp.ink),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_reviews.length})',
                    style: _inter(size: 13, color: _Tp.muted),
                  ),
                ],
              ),
            ],
            if (canWrite) ...[
              const SizedBox(height: 14),
              L10nText(
                'Puan verin (5 üzerinden)',
                style: _inter(size: 13, weight: FontWeight.w600, color: _Tp.ink),
              ),
              const SizedBox(height: 4),
              _starPick(),
              const SizedBox(height: 8),
              TextField(
                controller: _myText,
                minLines: 2,
                maxLines: 4,
                enabled: !_savingReview,
                style: _inter(size: 14, color: _Tp.ink),
                decoration: InputDecoration(
                  hintText: 'Yorumunuzu yazın…',
                  hintStyle: _inter(size: 14, color: _Tp.muted),
                  filled: true,
                  fillColor: _Tp.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _savingReview ? null : _submitReview,
                    style: FilledButton.styleFrom(
                      backgroundColor: _Tp.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: L10nText(
                      _savingReview ? 'Kaydediliyor…' : 'Yorumu gönder',
                    ),
                  ),
                ),
              ),
            ],
            if (_reviews.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in _reviews) _reviewRow(r),
            ],
          ],
        ),
      ),
    );
  }

  Widget _starRow(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? _Tp.star : _Tp.starOff,
        );
      }),
    );
  }

  Widget _starPick() {
    return Row(
      children: List.generate(5, (i) {
        final n = i + 1;
        final on = n <= _myRating;
        return Semantics(
          button: true,
          label: '$n yıldız',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _savingReview ? null : () => setState(() => _myRating = n),
            icon: Icon(
              on ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 28,
              color: on ? _Tp.star : _Tp.starOff,
            ),
          ),
        );
      }),
    );
  }

  Widget _reviewRow(ExpertReview r) {
    final canDelete = canDeleteExpertReview(
      viewerEmail: _myEmail.isNotEmpty ? _myEmail : widget.userEmail,
      authorEmail: r.authorEmail,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _Tp.mint,
            child: Text(
              contactAvatarLetter(r.authorName),
              style: _inter(size: 13, weight: FontWeight.w700, color: _Tp.accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.authorName.isEmpty ? 'Üye' : r.authorName,
                        style: _inter(
                          size: 14,
                          weight: FontWeight.w600,
                          color: _Tp.ink,
                        ),
                      ),
                    ),
                    _starRow(r.rating.toDouble(), size: 14),
                    if (canDelete)
                      IconButton(
                        tooltip: isAppAdmin(_myEmail) ||
                                isAppAdmin(widget.userEmail)
                            ? 'Yorumu sil (Admin)'
                            : 'Yorumu sil',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteReview(r),
                        icon: const Icon(Icons.close, size: 18, color: _Tp.muted),
                      ),
                  ],
                ),
                if (uzmanYorumTarih(r.createdAt).isNotEmpty)
                  Text(
                    uzmanYorumTarih(r.createdAt),
                    style: _inter(size: 12, color: _Tp.muted),
                  ),
                const SizedBox(height: 4),
                Text(
                  r.body,
                  style: _inter(size: 14, color: _Tp.ink, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filesNote() {
    if (_files.isEmpty) return const SizedBox.shrink();
    final keys = _files.keys.toList()
      ..sort((a, b) {
        const order = ['diploma', 'belge', 'kimlik_dogrulama', 'adli_sicil'];
        final ia = order.indexOf(a);
        final ib = order.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L10nText(
              'Belgeler (yalnız siz ve yöneticiler)',
              style: _inter(size: 17, weight: FontWeight.w700, color: _Tp.ink),
            ),
            const SizedBox(height: 10),
            for (final key in keys) ...[
              L10nText(
                uzmanBelgeAlaniEtiketi(key),
                style: _inter(
                  size: 13,
                  weight: FontWeight.w600,
                  color: _Tp.muted,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CatalogImage(
                  source: _files[key]!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? _Tp.hero : _Tp.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: _inter(
          size: 13,
          weight: FontWeight.w500,
          color: filled ? Colors.white : _Tp.ink,
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tp.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _ownerBar() {
    return Material(
      color: _Tp.card,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _Tp.line)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _editMine,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _Tp.accent,
                            side: const BorderSide(color: _Tp.accent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const L10nText('Düzenle'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _deleting ? null : _deleteMine,
                          icon: const Icon(Icons.delete_outline),
                          label: const L10nText(kUzmanIlanSil),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB42318),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Material(
      color: _Tp.card,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _Tp.line)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _openMesaj,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _Tp.accent,
                            side: const BorderSide(color: _Tp.accent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: _inter(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _Tp.accent,
                            ),
                          ),
                          child: L10nText(
                            _isAdmin ? 'İlan sahibine mesaj' : 'Mesaj gönder',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 48,
                        child: _isAdmin
                            ? FilledButton.icon(
                                onPressed: _deleting ? null : _deleteMine,
                                icon: const Icon(Icons.delete_outline),
                                label: const L10nText('Profili kaldır'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB42318),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: _openRandevu,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _Tp.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: _inter(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                child: L10nText(
                                  uzmanIkinciAksiyonMetni(
                                    _p ?? const ExpertCvProfile(),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _hizliIcon(String hint) {
    switch (hint) {
      case 'schedule':
        return Icons.schedule_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'access':
        return Icons.accessibility_new_outlined;
      case 'work':
        return Icons.work_outline;
      case 'pets':
        return Icons.pets_outlined;
      case 'smoke':
        return Icons.smoke_free_outlined;
      case 'clean':
        return Icons.cleaning_services_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.info_outline;
    }
  }

  IconData _calismaIcon(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('gündüz') || s.contains('gunduz')) {
      return Icons.wb_sunny_outlined;
    }
    if (s.contains('gece')) return Icons.dark_mode_outlined;
    if (s.contains('yatılı') || s.contains('yatili')) return Icons.hotel_outlined;
    if (s.contains('ev')) return Icons.home_outlined;
    if (s.contains('klinik')) return Icons.local_hospital_outlined;
    if (s.contains('online')) return Icons.videocam_outlined;
    if (s.contains('saat')) return Icons.schedule_outlined;
    return Icons.work_outline;
  }

  IconData _musaitIcon(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('sonu')) return Icons.weekend_outlined;
    if (s.contains('gece')) return Icons.dark_mode_outlined;
    if (s.contains('yatılı') || s.contains('yatili')) return Icons.hotel_outlined;
    return Icons.calendar_today_outlined;
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is bool) return v ? 'Evet' : 'Hayır';
    if (v is List) return v.map((e) => e.toString()).join(', ');
    return v.toString().trim();
  }
}
