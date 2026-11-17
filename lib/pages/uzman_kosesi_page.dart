import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_config.dart';
import '../app_sections_store.dart';
import '../data/centers_data.dart';
import '../data/turkish_cities_data.dart';
import '../kredi_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../uzman_kosesi/expert_billing_store.dart';
import '../uzman_kosesi/expert_cv_models.dart';
import '../uzman_kosesi/expert_cv_store.dart';
import '../uzman_kosesi/kurum_is_ilan_models.dart';
import '../uzman_kosesi/kurum_is_ilan_store.dart';
import '../uzman_kosesi/uzman_kose_bolum.dart';
import '../uzman_kosesi/uzman_kosesi_notify.dart';
import '../uzman_kosesi_profiles_store.dart';
import '../widgets/catalog_media.dart';
import '../widgets/guest_gate.dart';
import 'uzman_kosesi_cv_detail_page.dart';
import 'uzman_kosesi_cv_form_page.dart';
import 'uzman_kosesi_kurum_ilan_detail_page.dart';
import 'uzman_kosesi_kurum_ilan_form_page.dart';

/// Ana sayfa kartından açılan ayrı Uzman Köşesi sayfası (Forum/Topluluk değil).
class UzmanKosesPage extends StatefulWidget {
  const UzmanKosesPage({
    super.key,
    required this.userEmail,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  static Future<void> open(
    BuildContext context, {
    required String userEmail,
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UzmanKosesPage(
          userEmail: userEmail,
          isGuest: isGuest,
          onRequireLogin: onRequireLogin,
        ),
      ),
    );
  }

  @override
  State<UzmanKosesPage> createState() => _UzmanKosesPageState();
}

class _UzmanKosesPageState extends State<UzmanKosesPage> {
  AppSection _section = kDefaultUzmanKosesSection;
  List<UzmanKosesProfil> _profiles = const [];
  List<KurumIsIlani> _jobs = const [];
  List<MeslekGrubu> _gruplar = const [];
  bool _loadingProfiles = true;
  String _bolumFilter = kUzmanKoseBolumSaglik;
  String _meslekFilter = '';
  String _ilFilter = '';
  String _ilceFilter = '';
  int? _notifyBusyId;
  bool _bakiyeUyardi = false;
  bool _deletingMine = false;

  @override
  void initState() {
    super.initState();
    final cached = cachedUzmanKoses;
    if (cached != null) _section = cached;
    final cachedProfiles = cachedUzmanKosesProfiles;
    if (cachedProfiles != null) {
      _profiles = List<UzmanKosesProfil>.from(cachedProfiles);
      _loadingProfiles = false;
    }
    final cachedJobs = cachedKurumIsIlanlari;
    if (cachedJobs != null) {
      _jobs = List<KurumIsIlani>.from(cachedJobs);
    }
    _load(force: !hasFreshUzmanKosesCache);
    _loadProfiles(force: !hasFreshUzmanKosesProfilesCache);
  }

  Future<void> _load({bool force = false}) async {
    final row = await loadUzmanKosesSection(forceRefresh: force);
    if (!mounted) return;
    setState(() => _section = row);
  }

  Future<void> _loadProfiles({bool force = false}) async {
    await yenileUzmanKosesAylikUcret();
    final list = await loadUzmanKosesProfiles(forceRefresh: true);
    final jobs = await loadKurumIsIlanlari(forceRefresh: true);
    final gruplar = await loadMeslekGruplari();
    if (!mounted) return;
    setState(() {
      _profiles = list;
      _jobs = jobs;
      _gruplar = gruplar;
      _loadingProfiles = false;
    });
    if (_bakiyeUyardi || widget.isGuest || widget.userEmail.trim().isEmpty) {
      return;
    }
    _bakiyeUyardi = true;
    await uyarUzmanKartBakiyesi(context, userEmail: widget.userEmail);
  }

  bool get _canCreate {
    String? type;
    try {
      type = currentAuthUserType();
    } catch (_) {}
    return canCreateUzmanKosesProfil(
      isGuest: widget.isGuest,
      userEmail: widget.userEmail,
      userType: type,
    );
  }

  UzmanKosesProfil? get _mine =>
      myUzmanKosesProfil(_profiles, email: widget.userEmail);

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  bool get _hasYerFilter =>
      _ilFilter.trim().isNotEmpty || _ilceFilter.trim().isNotEmpty;

  bool get _hasListFilter =>
      _meslekFilter.trim().isNotEmpty || _hasYerFilter;

  List<String> get _ilSecenekleri {
    final seen = <String>{};
    final out = <String>[''];
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty || !seen.add(uzmanKosesNormYer(t))) return;
      out.add(t);
    }

    for (final name in kCityNames) {
      add(name);
    }
    for (final p in _profiles) {
      add(p.il);
    }
    for (final j in _jobs) {
      add(j.il);
    }
    return out;
  }

  List<String> get _ilceSecenekleri {
    final seen = <String>{};
    final out = <String>[''];
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty || t == kAllIlceler || !seen.add(uzmanKosesNormYer(t))) {
        return;
      }
      out.add(t);
    }

    if (_ilFilter.trim().isEmpty) return out;
    final catalog = kTurkishCities[_ilFilter]?.ilceler;
    if (catalog != null) {
      for (final name in catalog) {
        add(name);
      }
    }
    for (final p in _profiles) {
      if (uzmanKosesMatchesYer(p, il: _ilFilter)) add(p.ilce);
    }
    for (final j in _jobs) {
      if (uzmanKosesNormYer(j.il) == uzmanKosesNormYer(_ilFilter)) {
        add(j.ilce);
      }
    }
    return out;
  }

  List<String> get _meslekSecenekleri {
    final listed = uzmanKosesFiltreMeslekleri(
      grupEtiketleri: [for (final g in _gruplar) g.etiket],
      extra: [
        ...uzmanKosesListedMeslekler(_profiles),
        for (final j in _jobs) j.arananMeslek,
      ],
    );
    if (_meslekFilter.trim().isEmpty) return listed;
    if (listed.any(
      (m) => uzmanKosesNormYer(m) == uzmanKosesNormYer(_meslekFilter),
    )) {
      return listed;
    }
    return [_meslekFilter.trim(), ...listed];
  }

  List<KurumIsIlani> get _visibleJobs => kurumIsIlanlariFiltrele(
        _jobs,
        meslek: _meslekFilter,
        il: _ilFilter,
        ilce: _ilceFilter,
      );

  List<UzmanKosesProfil> get _visibleSaglik => uzmanKosesBolumProfilleri(
        _profiles,
        kUzmanKoseBolumSaglik,
        meslek: _meslekFilter,
        il: _ilFilter,
        ilce: _ilceFilter,
      );

  List<UzmanKosesProfil> get _visibleBakim => uzmanKosesBolumProfilleri(
        _profiles,
        kUzmanKoseBolumBakim,
        meslek: _meslekFilter,
        il: _ilFilter,
        ilce: _ilceFilter,
      );

  List<UzmanKosesProfil> get _visibleEv => uzmanKosesBolumProfilleri(
        _profiles,
        kUzmanKoseBolumEv,
        meslek: _meslekFilter,
        il: _ilFilter,
        ilce: _ilceFilter,
      );

  void _clearListFilters() {
    setState(() {
      _meslekFilter = '';
      _ilFilter = '';
      _ilceFilter = '';
    });
  }

  Future<void> _openForm() async {
    if (widget.isGuest || widget.userEmail.trim().isEmpty) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Profil oluşturmak için giriş yapın veya üye olun.',
      );
      return;
    }
    if (!_canCreate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Uzman Profilleri Köşesi profili Destek Veren rolünde oluşturulur. '
            'Menü → Hesap rolü bölümünden Destek Veren’e geçin.',
          ),
        ),
      );
      return;
    }
    final saved = await UzmanKosesCvFormPage.open(
      context,
      userEmail: widget.userEmail,
    );
    if (saved && mounted) await _loadProfiles(force: true);
  }

  Future<void> _openKurumForm() async {
    if (widget.isGuest || widget.userEmail.trim().isEmpty) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'İş ilanı yayınlamak için giriş yapın veya üye olun.',
      );
      return;
    }
    final saved = await UzmanKosesKurumIlanFormPage.open(
      context,
      userEmail: widget.userEmail,
    );
    if (saved && mounted) await _loadProfiles(force: true);
  }

  Future<void> _deleteMine() async {
    if (_mine == null || _deletingMine) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText(kUzmanIlanimiSil),
        content: const L10nText(kUzmanIlanSilOnay),
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
            child: const L10nText(kUzmanIlanimiSil),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingMine = true);
    try {
      await deleteMyExpertProfile();
      if (!mounted) return;
      await _loadProfiles(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('İlanınız silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'İlan silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _deletingMine = false);
    }
  }

  Future<void> _notifyProfile(UzmanKosesProfil p) async {
    if (!_isAdmin || _notifyBusyId != null) return;
    final title = uzmanProfilYayinBildirimBaslik(p);
    final body = uzmanProfilYayinBildirimMetni(p);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Kullanıcılara bildir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.35)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const L10nText('Gönder'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _notifyBusyId = p.id);
    try {
      final n = await notifyUzmanProfilYayinlandi(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0
                ? 'Bildirim gönderildi ($n kullanıcı).'
                : 'Push bildirimi gönderildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _notifyBusyId = null);
    }
  }

  Widget _bolumKutusu(String bolum) {
    final on = _bolumFilter == bolum;
    final label = kUzmanKoseBolumBasliklari[bolum] ?? bolum;
    return Material(
      color: on ? MetoColors.selectedBg : MetoColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _bolumFilter = bolum),
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? MetoColors.primary : MetoColors.border,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: on ? MetoColors.primary : MetoColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ustYayinlaButonlari() {
    final showProfil = _mine == null;
    return Row(
      children: [
        if (showProfil) ...[
          Expanded(
            child: _ilanYayinlaKutusu(
              label: 'Uzman profili oluştur',
              icon: Icons.person_add_alt_1,
              onTap: _openForm,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _ilanYayinlaKutusu(
            label: 'Kurum iş ilanı yayınla',
            icon: Icons.work_outline,
            onTap: _openKurumForm,
          ),
        ),
      ],
    );
  }

  Widget _ilanYayinlaKutusu({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: MetoColors.primary,
      elevation: 3,
      shadowColor: MetoColors.primaryDark.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bolumFiltreleri() {
    return Column(
      children: [
        for (var r = 0; r < kUzmanKoseBolumSirasi.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _bolumKutusu(kUzmanKoseBolumSirasi[r])),
              const SizedBox(width: 8),
              Expanded(
                child: r + 1 < kUzmanKoseBolumSirasi.length
                    ? _bolumKutusu(kUzmanKoseBolumSirasi[r + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _profileSection(List<UzmanKosesProfil> profiles) {
    if (profiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: L10nText(
          _hasListFilter
              ? 'Bu filtreyle uzman bulunamadı.'
              : 'Henüz uzman profili yok',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
      );
    }
    return _ProfileGrid(
      profiles: profiles,
      showAdd: false,
      showNotify: _isAdmin,
      notifyBusyId: _notifyBusyId,
      onAdd: _openForm,
      onNotify: _notifyProfile,
      onOpen: (p) async {
        await UzmanKosesCvDetailPage.open(
          context,
          ownerId: p.ownerId,
          ownerEmail: p.ownerEmail,
          listing: p,
          userEmail: widget.userEmail,
          isGuest: widget.isGuest,
          onRequireLogin: widget.onRequireLogin,
        );
        if (mounted) await _loadProfiles(force: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var title = _section.title.trim().isEmpty
        ? kDefaultUzmanKosesTitle
        : _section.title.trim();
    if (title == 'Uzman Köşesi') title = kDefaultUzmanKosesTitle;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_mine != null)
            TextButton.icon(
              onPressed: _deletingMine ? null : _deleteMine,
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB42318),
              ),
              label: const L10nText(
                kUzmanIlanimiSil,
                style: TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loadingProfiles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            _ustYayinlaButonlari(),
            const SizedBox(height: 14),
            _bolumFiltreleri(),
            const SizedBox(height: 12),
            _YerDropdown(
              value: _meslekSecenekleri.contains(_meslekFilter)
                  ? _meslekFilter
                  : '',
              items: ['', ..._meslekSecenekleri],
              allLabel: 'Tüm meslekler',
              title: 'Meslek ara',
              onChanged: (v) => setState(() => _meslekFilter = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _YerDropdown(
                    value: _ilSecenekleri.contains(_ilFilter) ? _ilFilter : '',
                    items: _ilSecenekleri,
                    allLabel: 'Tüm iller',
                    title: 'İl ara',
                    onChanged: (v) => setState(() {
                      _ilFilter = v;
                      _ilceFilter = '';
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _YerDropdown(
                    value: _ilceSecenekleri.contains(_ilceFilter)
                        ? _ilceFilter
                        : '',
                    items: _ilceSecenekleri,
                    allLabel: 'Tüm ilçeler',
                    title: 'İlçe ara',
                    enabled: _ilFilter.trim().isNotEmpty,
                    onChanged: (v) => setState(() => _ilceFilter = v),
                  ),
                ),
              ],
            ),
            if (_hasListFilter)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearListFilters,
                  child: const L10nText('Filtreleri temizle'),
                ),
              )
            else
              const SizedBox(height: 10),
            if (_mine != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deletingMine ? null : _deleteMine,
                  icon: _deletingMine
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: const L10nText(kUzmanIlanimiSil),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFB42318)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_bolumFilter == kUzmanKoseBolumKurum) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: L10nText(
                  'Klinik veya merkez, aradığı uzmanı buradan yayınlar.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                    height: 1.35,
                  ),
                ),
              ),
              _JobList(
                jobs: _visibleJobs,
                showAdd: false,
                emptyLabel: _hasListFilter
                    ? 'Bu filtreyle kurum iş ilanı yok.'
                    : 'Henüz kurum iş ilanı yok',
                onAdd: _openKurumForm,
                onOpen: (j) async {
                  final changed = await UzmanKosesKurumIlanDetailPage.open(
                    context,
                    ilan: j,
                    userEmail: widget.userEmail,
                    isGuest: widget.isGuest,
                    onRequireLogin: widget.onRequireLogin,
                  );
                  if (changed && mounted) await _loadProfiles(force: true);
                },
              ),
            ] else
              _profileSection(switch (_bolumFilter) {
                kUzmanKoseBolumBakim => _visibleBakim,
                kUzmanKoseBolumEv => _visibleEv,
                _ => _visibleSaglik,
              }),
          ],
        ],
      ),
    );
  }
}

class _YerDropdown extends StatelessWidget {
  const _YerDropdown({
    required this.value,
    required this.items,
    required this.allLabel,
    required this.onChanged,
    this.title,
    this.enabled = true,
  });

  final String value;
  final List<String> items;
  final String allLabel;
  final String? title;
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AranirSecimSheet(
        title: title ?? allLabel,
        allLabel: allLabel,
        value: value,
        items: items,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value.trim().isEmpty ? allLabel : value;
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MetoColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enabled ? MetoColors.foreground : MetoColors.mutedFg,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: enabled ? MetoColors.mutedFg : MetoColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AranirSecimSheet extends StatefulWidget {
  const _AranirSecimSheet({
    required this.title,
    required this.allLabel,
    required this.value,
    required this.items,
  });

  final String title;
  final String allLabel;
  final String value;
  final List<String> items;

  @override
  State<_AranirSecimSheet> createState() => _AranirSecimSheetState();
}

class _AranirSecimSheetState extends State<_AranirSecimSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final q = _ctrl.text;
    final out = <String>[];
    for (final item in widget.items) {
      if (item.isEmpty) continue;
      if (uzmanKosesMetinIcerir(item, q)) out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    final visible = _visible;
    return SizedBox(
      height: h,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
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
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: widget.title,
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: MetoColors.background,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MetoColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MetoColors.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              title: Text(
                widget.allLabel,
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              trailing: widget.value.isEmpty
                  ? const Icon(Icons.check, color: MetoColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: L10nText('Eşleşen seçenek yok'),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) {
                        final item = visible[i];
                        final selected =
                            uzmanKosesNormYer(item) == uzmanKosesNormYer(widget.value);
                        return ListTile(
                          dense: true,
                          title: Text(
                            item,
                            style: GoogleFonts.nunito(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check,
                                  color: MetoColors.primary,
                                  size: 18,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({
    required this.jobs,
    required this.showAdd,
    required this.emptyLabel,
    required this.onAdd,
    required this.onOpen,
  });

  final List<KurumIsIlani> jobs;
  final bool showAdd;
  final String emptyLabel;
  final VoidCallback onAdd;
  final ValueChanged<KurumIsIlani> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAdd) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.work_outline),
              label: const L10nText('İş ilanı yayınla'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (jobs.isEmpty)
          L10nText(
            emptyLabel,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          )
        else
          for (final j in jobs) ...[
            _JobTile(ilan: j, onOpen: () => onOpen(j)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.ilan, required this.onOpen});

  final KurumIsIlani ilan;
  final VoidCallback onOpen;

  static const _height = 140.0;
  static const _inset = 8.0;
  static const _photoRadius = 12.0;

  Widget _coverPhoto({required double size}) {
    if (ilan.photoUrl.trim().isEmpty) {
      return ColoredBox(
        color: MetoColors.primary.withValues(alpha: 0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              ilan.arananMeslek,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: MetoColors.primary,
              ),
            ),
          ),
        ),
      );
    }
    return CatalogImage(
      source: ilan.photoUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    const photoSize = _height - _inset * 2;
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.primary, width: 1.5),
          ),
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_photoRadius),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: photoSize,
                      height: photoSize,
                      child: _coverPhoto(size: photoSize),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ilan.kurumAdi,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ilan.arananMeslek,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: MetoColors.primary,
                          ),
                        ),
                        if (ilan.yerLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ilan.yerLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({
    required this.profiles,
    required this.showAdd,
    required this.onAdd,
    required this.onOpen,
    this.showNotify = false,
    this.notifyBusyId,
    this.onNotify,
  });

  final List<UzmanKosesProfil> profiles;
  final bool showAdd;
  final bool showNotify;
  final int? notifyBusyId;
  final VoidCallback onAdd;
  final ValueChanged<UzmanKosesProfil> onOpen;
  final ValueChanged<UzmanKosesProfil>? onNotify;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const tileH = 120.0;
        const fullH = 140.0;
        final w = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final cardW = ((w - gap) / 2).floorToDouble().clamp(80.0, w);

        Widget halfTile(UzmanKosesProfil p) => SizedBox(
              width: cardW,
              child: _ProfileTile(
                profile: p,
                width: cardW,
                height: tileH,
                fullRow: false,
                showNotify: showNotify,
                notifyBusy: notifyBusyId == p.id,
                onNotify: onNotify == null ? null : () => onNotify!(p),
                onOpen: () => onOpen(p),
              ),
            );
        Widget fullTile(UzmanKosesProfil p) => SizedBox(
              width: w,
              child: _ProfileTile(
                profile: p,
                width: w,
                height: fullH,
                fullRow: true,
                showNotify: showNotify,
                notifyBusy: notifyBusyId == p.id,
                onNotify: onNotify == null ? null : () => onNotify!(p),
                onOpen: () => onOpen(p),
              ),
            );

        final items = <({int span, Widget child})>[
          if (showAdd)
            (
              span: 1,
              child: SizedBox(
                width: cardW,
                child: _AddProfileTile(
                  width: cardW,
                  height: tileH,
                  onTap: onAdd,
                ),
              ),
            ),
          for (final p in profiles)
            p.tamSatir
                ? (span: 2, child: fullTile(p))
                : (span: 1, child: halfTile(p)),
        ];

        final rows = <Widget>[];
        var i = 0;
        while (i < items.length) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 16));
          final cur = items[i];
          if (cur.span >= 2) {
            rows.add(cur.child);
            i += 1;
            continue;
          }
          final next =
              i + 1 < items.length && items[i + 1].span == 1 ? items[i + 1] : null;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cur.child,
                const SizedBox(width: gap),
                if (next != null) next.child else SizedBox(width: cardW),
              ],
            ),
          );
          i += next != null ? 2 : 1;
        }
        return Column(children: rows);
      },
    );
  }
}

class _AddProfileTile extends StatelessWidget {
  const _AddProfileTile({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: Material(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetoColors.primary, width: 1.5),
                    color: MetoColors.primary.withValues(alpha: 0.08),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 48,
                      color: MetoColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: width,
            child: Text(
              'Profil oluştur',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: MetoColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.width,
    required this.height,
    required this.onOpen,
    this.fullRow = false,
    this.showNotify = false,
    this.notifyBusy = false,
    this.onNotify,
  });

  final UzmanKosesProfil profile;
  final double width;
  final double height;
  final VoidCallback onOpen;
  final bool fullRow;
  final bool showNotify;
  final bool notifyBusy;
  final VoidCallback? onNotify;

  Widget _coverPhoto({required double w, required double h}) {
    if (profile.photoUrl.trim().isEmpty) {
      return ColoredBox(
        color: MetoColors.primary.withValues(alpha: 0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              profile.meslek,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: MetoColors.primary,
              ),
            ),
          ),
        ),
      );
    }
    return CatalogImage(
      source: profile.photoUrl,
      fit: BoxFit.cover,
      width: w,
      height: h,
    );
  }

  List<Widget> _badges() => [
        if (showNotify && onNotify != null)
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: MetoColors.primary,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Kullanıcılara bildir',
                onPressed: notifyBusy ? null : onNotify,
                visualDensity: VisualDensity.compact,
                icon: notifyBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.campaign_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),
        if (profile.dogrulandi)
          Positioned(
            top: 6,
            right: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(
                  Icons.verified,
                  size: 16,
                  color: MetoColors.primary,
                ),
              ),
            ),
          ),
      ];

  Widget _fullRowCard() {
    const inset = 8.0;
    const photoRadius = 12.0;
    final photoSize = (height - inset * 2).clamp(72.0, height);
    return SizedBox(
      width: width,
      child: Material(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetoColors.primary, width: 1.5),
            ),
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(inset),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(photoRadius),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: photoSize,
                            height: photoSize,
                            child: _coverPhoto(w: photoSize, h: photoSize),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                profile.fullName,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: MetoColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.meslek,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  color: MetoColors.primary,
                                ),
                              ),
                              if (profile.deneyimYili != null)
                                Text(
                                  '${profile.deneyimYili} yıl deneyim',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    color: MetoColors.primary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                profile.yerLabel,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ..._badges(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (fullRow) return _fullRowCard();
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: Material(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetoColors.primary, width: 1.5),
                    color: MetoColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (profile.photoUrl.trim().isNotEmpty)
                        CatalogImage(
                          source: profile.photoUrl,
                          fit: BoxFit.cover,
                          width: width,
                          height: height,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(
                            child: Text(
                              profile.meslek,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                color: MetoColors.primary,
                              ),
                            ),
                          ),
                        ),
                      if (showNotify && onNotify != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Material(
                            color: MetoColors.primary,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Kullanıcılara bildir',
                              onPressed: notifyBusy ? null : onNotify,
                              visualDensity: VisualDensity.compact,
                              icon: notifyBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.campaign_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ),
                      if (profile.dogrulandi)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: MetoColors.primary,
                              ),
                            ),
                          ),
                        ),
                      if (profile.photoUrl.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.65),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                                child: Text(
                                  profile.meslek,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    color: Colors.white,
                                  ),
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
          const SizedBox(height: 8),
          SizedBox(
            width: width,
            child: Text(
              profile.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: MetoColors.foreground,
              ),
            ),
          ),
          if (profile.deneyimYili != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${profile.deneyimYili} yıl deneyim',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 2),
          SizedBox(
            width: width,
            child: Text(
              profile.yerLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: MetoColors.mutedFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

