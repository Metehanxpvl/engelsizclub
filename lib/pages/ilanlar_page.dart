import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../bildirim_store.dart';
import '../catalog_category_store.dart';
import '../data/ilanlar_data.dart';
import '../data/location_models.dart';
import '../ilan_store.dart';
import '../content_moderation.dart';
import '../content_view_store.dart';
import '../kredi_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../meto_theme.dart';
import '../utils/async_timeout.dart';
import '../presence_store.dart';
import '../services/app_catalog_service.dart';
import '../services/catalog_adapters.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../sohbet_store.dart';
import '../teklif_store.dart';
import '../user_cloud_store.dart';
import '../widgets/location_picker.dart';
import '../widgets/photo_gallery_lightbox.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_safety_sheet.dart';
import '../widgets/guest_gate.dart';
import '../widgets/loading_error_view.dart';
import '../widgets/ugc_terms_gate.dart';
import '../l10n/l10n_text.dart';
import '../utils/price_format.dart';

String ikincielAltDisplayLabel(String category) {
  final alt = ikincielAltKategoriOf(
    category,
    extras: CatalogAdapters.ikincielCustomAlts(),
  );
  if (alt == kIkincielAltMedikal) return S.t('ilan_alt_medikal');
  if (alt == kIkincielAltDiger) return S.t('ilan_alt_diger');
  return alt;
}

/// MetoCare `IlanlarTab` — Flutter portu.
class IlanlarPage extends StatefulWidget {
  const IlanlarPage({
    super.key,
    required this.userKredi,
    required this.onKrediHarca,
    this.userEmail = '',
    this.userName = 'Siz',
    this.userType = 'aile',
    this.profilFoto,
    this.isGuest = false,
    this.onRequireLogin,
    this.onUnreadChange,
    this.onOpenKrediYukle,
    this.onIlanlarChanged,
    this.openIlanKind,
    this.openIlanId,
    this.openIlanToken = 0,
    this.openEditIlanKind,
    this.openEditIlanId,
    this.openEditIlanToken = 0,
  });

  final int userKredi;
  final Future<bool> Function() onKrediHarca;
  final String userEmail;
  final String userName;
  /// aile | uzman | bakici
  final String userType;
  /// data:image… profil fotoğrafı
  final String? profilFoto;
  final bool isGuest;
  final VoidCallback? onRequireLogin;
  final ValueChanged<int>? onUnreadChange;
  final VoidCallback? onOpenKrediYukle;
  final VoidCallback? onIlanlarChanged;

  /// Profil / favorilerden açılacak ilan (kind: uzman|bakici|ikinciel).
  final String? openIlanKind;
  final int? openIlanId;
  final int openIlanToken;

  /// İlanlarım’dan düzenleme (kind: uzman|bakici|ikinciel).
  final String? openEditIlanKind;
  final int? openEditIlanId;
  final int openEditIlanToken;

  @override
  State<IlanlarPage> createState() => IlanlarPageState();
}

class _ActiveSohbet {
  _ActiveSohbet({
    required this.kisi,
    required this.lastMsg,
    required this.lastTime,
  });

  SohbetKisi kisi;
  String lastMsg;
  String lastTime;
  int unread = 0;
}

class IlanlarPageState extends State<IlanlarPage> {
  /// Sistem geri: form / detay katmanlarını sırayla kapatır.
  bool consumeBack() {
    if (_selectedPoster != null) {
      setState(() => _selectedPoster = null);
      return true;
    }
    if (_selectedUzman != null ||
        _selectedBakici != null ||
        _selectedIkinciel != null) {
      setState(() {
        _selectedUzman = null;
        _selectedBakici = null;
        _selectedIkinciel = null;
      });
      return true;
    }
    if (_showVerForm) {
      setState(() {
        _showVerForm = false;
        _editDraft = null;
      });
      return true;
    }
    return false;
  }

  static const _pageSize = 10;

  IlanKategori _kategori = IlanKategori.uzmanlar;
  bool _showVerForm = false;
  _IlanEditDraft? _editDraft;
  double _kmFilter = 500;
  /// Ana konum filtresi — varsayılan: dil ülkesinin tümü
  late LocationData _filterLoc = LocationData(
    countryCode: countryCodeForLang(LocaleController.instance.lang),
  );
  /// 2. el ürün durumu: Tümü | Sıfır | Az Kullanılmış | İyi | Kötü
  String _ikincielDurumFilter = 'Tümü';
  /// Uzman sekmesi: Tümü | Uzman Arıyorum | İş Arıyorum
  String _uzmanTipFilter = 'Tümü';
  /// Uzman sekmesi uzmanlık filtresi
  String _uzmanlikFilter = 'Tümü';
  /// 'Tümü' | Medikal Malzemeler | Diğer (canonical TR keys)
  String _ikincielAltFilter = 'Tümü';
  int _listPage = 0;
  bool _loadingFeed = !hasRuntimeIlanlar;
  bool _loadingMore = false;
  bool _feedRetrying = false;
  String? _feedError;

  bool get _feedHasRuntimeIlanlar =>
      runtimeUzmanIlanlar.isNotEmpty ||
      runtimeBakiciIlanlar.isNotEmpty ||
      runtimeIkincielIlanlar.isNotEmpty;

  List<FavoriIlanRef> _favoriler = const [];

  /// Aile / profesyonel ayrımı yalnız role göre (admin aile seçince puan fiyatı görmesin).
  bool get _isAileRole {
    final t = widget.userType.trim().toLowerCase();
    return t != 'uzman' && t != 'bakici';
  }

  String get _normalizedRole {
    final t = widget.userType.trim().toLowerCase();
    if (t == 'uzman' || t == 'bakici' || t == 'aile') return t;
    return 'aile';
  }

  /// Yalnızca aile (ve admin) ilan paylaşabilir.
  bool get _canPostListing =>
      !widget.isGuest && (_isAdmin || _normalizedRole == 'aile');

  bool get _profNeedsRoleSwitchToPost =>
      !widget.isGuest &&
      !_isAdmin &&
      (_normalizedRole == 'uzman' || _normalizedRole == 'bakici');

  void _showRoleSwitchToPostWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'İlan paylaşmak için hesap rolünüzü Aile olarak değiştirmeniz gerekir. '
          'Menü → Hesap rolü bölümünden rolünüzü değiştirebilirsiniz.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  String _uzmanListingCategory(int? ilanId) {
    if (ilanId == null) return kIlanCatUzmanAriyorum;
    for (final u in runtimeUzmanIlanlar) {
      if (u.id == ilanId) return u.category;
    }
    if (CatalogAdapters.showDemoIlanlar()) {
      for (final u in uzmanIlanlar) {
        if (u.id == ilanId) return u.category;
      }
    }
    return kIlanCatUzmanAriyorum;
  }

  /// Aile: yalnızca 2. el · Uzman/bakıcı: uzman ve bakıcı ilanları (1 puan).
  bool _canOfferOn(String kind, {int? ilanId}) {
    if (_isAdmin) return true;
    if (widget.isGuest) return false;
    return canOfferOnIlan(
      kind: kind,
      userType: _normalizedRole,
      email: widget.userEmail,
      listingCategory: _uzmanListingCategory(ilanId),
    );
  }

  String _offerBlockedMessage(String kind) {
    if (kind == 'ikinciel') {
      return '2. el ilanlarına teklif vermek için giriş yapın.';
    }
    if (_normalizedRole == 'aile') {
      return 'Uzman ve bakıcı ilanlarına teklif vermek için Menü → Hesap rolü '
          'bölümünden Uzman veya Bakıcı rolüne geçin. 2. el ilanlarına aile '
          'rolüyle ücretsiz iletişim kurabilirsiniz.';
    }
    return 'Uzman ve bakıcı ilanlarına yalnızca Uzman veya Bakıcı rolü teklif '
        'verebilir (1 puan).';
  }

  bool _canReviewOn(String kind, {int? ilanId}) =>
      !widget.isGuest && _canOfferOn(kind, ilanId: ilanId);

  UzmanIlani? _selectedUzman;
  BakiciIlani? _selectedBakici;
  IkincielIlani? _selectedIkinciel;
  ({
    IlanPoster poster,
    String ctaLabel,
    String peerEmail,
    int? ilanId,
    String ilanTitle,
    bool free,
    String kind,
  })? _selectedPoster;
  SohbetKisi? _pendingSohbet;
  final _activeSohbetler = <_ActiveSohbet>[];
  Set<int> _teklifVerilenIlanlar = {};
  /// Peş peşe tıklamada çift bildirim / çift kredi engeli
  final Set<int> _teklifInFlight = {};
  bool _freeTeklifBusy = false;

  int get _totalUnread => _activeSohbetler.fold<int>(0, (s, c) => s + c.unread);

  void _reportUnread() => widget.onUnreadChange?.call(_totalUnread);

  bool _teklifVerildiMi(int? ilanId) =>
      ilanId != null && _teklifVerilenIlanlar.contains(ilanId);

  int? _lastViewRecordedIlanId;

  void _syncOpenedIlanView() {
    final id = _selectedUzman?.id ?? _selectedBakici?.id ?? _selectedIkinciel?.id;
    if (id == null) {
      _lastViewRecordedIlanId = null;
      return;
    }
    if (_lastViewRecordedIlanId == id) return;
    _lastViewRecordedIlanId = id;
    unawaited(() async {
      final n = await recordIlanView(id);
      if (!mounted || n < 0) return;
      setState(() {
        if (_selectedUzman?.id == id) {
          _selectedUzman = _selectedUzman!.copyWith(views: n);
        }
        if (_selectedBakici?.id == id) {
          _selectedBakici = _selectedBakici!.copyWith(views: n);
        }
        if (_selectedIkinciel?.id == id) {
          _selectedIkinciel = _selectedIkinciel!.copyWith(views: n);
        }
      });
    }());
  }

  bool _teklifKilitliMi(int? ilanId) =>
      ilanId != null &&
      (_teklifVerilenIlanlar.contains(ilanId) ||
          _teklifInFlight.contains(ilanId));

  void _teklifKilitle(int? ilanId) {
    if (ilanId == null) return;
    _teklifInFlight.add(ilanId);
    _teklifVerilenIlanlar = {..._teklifVerilenIlanlar, ilanId};
  }

  void _teklifKilitAc(int? ilanId, {bool revertOffered = false}) {
    if (ilanId == null) return;
    _teklifInFlight.remove(ilanId);
    if (revertOffered) {
      _teklifVerilenIlanlar = {..._teklifVerilenIlanlar}..remove(ilanId);
    }
  }

  SohbetKisi _kisiFromPoster({
    required IlanPoster poster,
    required int ilanId,
    String? ilanTitle,
  }) {
    final peer = (ilanOwnerById[ilanId] ?? '').trim().toLowerCase();
    final listingName = poster.fullName.trim().isNotEmpty
        ? poster.fullName.trim()
        : poster.name.trim();
    final ad = chatPeerLabel(peer, listingName: listingName);
    return SohbetKisi(
      ad: ad,
      avatar: poster.avatar.trim().isNotEmpty
          ? poster.avatar
          : contactAvatarLetter(ad),
      avatarColor: poster.avatarColor,
      isOnline: false,
      sonGorus: peer.isEmpty ? 'Örnek / demo ilan' : null,
      peerEmail: peer,
      ilanId: ilanId,
      ilanTitle: ilanTitle,
    );
  }

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  bool _isIlanOwner(int id) {
    final me = widget.userEmail.trim().toLowerCase();
    return me.isNotEmpty && (ilanOwnerById[id] ?? '') == me;
  }

  bool _canDeleteIlan(int id) => _isAdmin || _isIlanOwner(id);

  Future<void> _deleteIlan({
    required String kind,
    required int id,
    required String title,
  }) async {
    if (!_canDeleteIlan(id)) return;
    final asAdmin = _isAdmin && !_isIlanOwner(id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asAdmin ? 'İlanı sil (Admin)' : 'İlanı sil'),
        content: L10nText('"$title" ilanını kalıcı silmek istiyor musunuz?'),
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
      await deleteUserIlan(
        email: widget.userEmail,
        kind: kind,
        id: id,
      );
      if (!mounted) return;
      setState(() {
        _selectedUzman = null;
        _selectedBakici = null;
        _selectedIkinciel = null;
      });
      widget.onIlanlarChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(asAdmin ? 'İlan admin tarafından silindi' : 'İlan silindi'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('policy') || e.toString().contains('42501')
                ? 'Silme yetkisi yok.'
                : 'Silinemedi: $e',
          ),
        ),
      );
    }
  }

  String _ilanKindLabel(String kind) => switch (kind) {
        'uzman' => S.t('ilan_tab_uzman'),
        'bakici' => S.t('ilan_tab_bakici'),
        'ikinciel' => S.t('ilan_tab_ikinciel'),
        _ => kind,
      };

  IlanKategori _kategoriOfKind(String kind) => switch (kind) {
        'uzman' => IlanKategori.uzmanlar,
        'bakici' => IlanKategori.bakici,
        _ => IlanKategori.ikinciel,
      };

  Future<void> _changeIlanCategory({
    required String kind,
    required int id,
    required String title,
    String? ikincielCategory,
    String? uzmanlik,
  }) async {
    if (!_isAdmin) return;

    var selectedKind = kind;
    var selectedAlt = ikincielAltKategoriOf(
      ikincielCategory ?? kIkincielAltDiger,
      extras: CatalogAdapters.ikincielCustomAlts(),
    );
    var selectedUzmanlik = (uzmanlik ?? '').trim();
    final uzmanOpts = CatalogAdapters.uzmanlikSecenekleri();
    if (selectedUzmanlik.isEmpty || !uzmanOpts.contains(selectedUzmanlik)) {
      selectedUzmanlik = uzmanOpts.first;
    }

    final result = await showDialog<({String kind, String alt, String uzmanlik})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const L10nText('Kategori değiştir (Admin)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"$title"',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kind == 'ikinciel'
                          ? 'Şu an: ${_ilanKindLabel(kind)} · ${ikincielAltDisplayLabel(ikincielCategory ?? '')}'
                          : 'Şu an: ${_ilanKindLabel(kind)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const L10nText(
                      'Yeni kategori',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in [
                          ('uzman', S.t('ilan_tab_uzman')),
                          ('bakici', S.t('ilan_tab_bakici')),
                          ('ikinciel', S.t('ilan_tab_ikinciel')),
                        ])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: selectedKind == opt.$1,
                            onSelected: (_) =>
                                setLocal(() => selectedKind = opt.$1),
                          ),
                      ],
                    ),
                    if (selectedKind == 'ikinciel') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: L10nText(
                              'Alt kategori',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Yeni alt kategori ekle',
                            onPressed: () async {
                              final name = await promptAdminNewOption(
                                context: ctx,
                                title: 'Yeni 2. el alt kategori',
                                hint: 'Örn. Ortez / protez',
                              );
                              if (name == null || !ctx.mounted) return;
                              final result = await upsertCatalogOption(
                                scope: 'ikinciel',
                                label: name,
                                icon: '📦',
                              );
                              if (!ctx.mounted) return;
                              setLocal(() => selectedAlt = name);
                              showCatalogUpsertSnackBar(
                                ctx,
                                result,
                                successText: '"$name" alt kategorilere eklendi',
                              );
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF7C3AED),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final alt
                              in CatalogAdapters.ikincielAltKategoriler())
                            ChoiceChip(
                              label: Text(ikincielAltDisplayLabel(alt)),
                              selected: selectedAlt == alt,
                              onSelected: (_) =>
                                  setLocal(() => selectedAlt = alt),
                            ),
                        ],
                      ),
                    ],
                    if (selectedKind == 'uzman') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: L10nText(
                              'Uzmanlık',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Yeni uzmanlık ekle',
                            onPressed: () async {
                              final name = await promptAdminNewOption(
                                context: ctx,
                                title: 'Yeni uzmanlık alanı',
                                hint: 'Örn. Müzik terapisti',
                              );
                              if (name == null || !ctx.mounted) return;
                              final result = await upsertCatalogOption(
                                scope: 'uzmanlik',
                                label: name,
                                icon: '👤',
                              );
                              if (!ctx.mounted) return;
                              setLocal(() => selectedUzmanlik = name);
                              showCatalogUpsertSnackBar(
                                ctx,
                                result,
                                successText: '"$name" uzmanlık alanlarına eklendi',
                              );
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF7C3AED),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedUzmanlik),
                        initialValue: () {
                          final opts = CatalogAdapters.uzmanlikSecenekleri();
                          return opts.contains(selectedUzmanlik)
                              ? selectedUzmanlik
                              : opts.first;
                        }(),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: MetoColors.card,
                          isDense: true,
                        ),
                        items: [
                          for (final u in CatalogAdapters.uzmanlikSecenekleri())
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setLocal(() => selectedUzmanlik = v);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const L10nText('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, (
                    kind: selectedKind,
                    alt: selectedAlt,
                    uzmanlik: selectedUzmanlik,
                  )),
                  child: const L10nText('Taşı'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;

    final sameKind = result.kind == kind;
    final sameAlt = result.kind != 'ikinciel' ||
        ikincielAltKategoriOf(ikincielCategory ?? kIkincielAltDiger) ==
            result.alt;
    final sameUzman = result.kind != 'uzman' ||
        (kind == 'uzman' && (uzmanlik ?? '').trim() == result.uzmanlik);
    if (sameKind && sameAlt && sameUzman) return;

    try {
      await adminChangeIlanKind(
        id: id,
        toKind: result.kind,
        ikincielCategory: result.alt,
        uzmanlik: result.uzmanlik,
      );
      if (!mounted) return;
      setState(() {
        _selectedUzman = null;
        _selectedBakici = null;
        _selectedIkinciel = null;
        _kategori = _kategoriOfKind(result.kind);
        // Alt kategori filtresini taşıma sonrası değiştirme — diğer ilanlar kaybolmasın
      });
      await _refreshFeed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'İlan "${_ilanKindLabel(result.kind)}" kategorisine taşındı',
          ),
        ),
      );
      _openListingByKindId(result.kind, id);
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _ilanEditDeleteActions({
    required int id,
    required String kind,
    required String title,
    required VoidCallback onEdit,
    String? ikincielCategory,
    String? uzmanlik,
  }) {
    final canEdit = _isIlanOwner(id);
    final canDelete = _canDeleteIlan(id);
    final canMove = _isAdmin;
    if (!canEdit && !canDelete && !canMove) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          IconButton(
            tooltip: S.auto('Satıldı olarak işaretle'),
            onPressed: () => _markSoldIlan(kind: kind, id: id, title: title),
            icon: const Icon(
              Icons.sell_outlined,
              size: 18,
              color: Color(0xFFCA8A04),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (canEdit)
          IconButton(
            tooltip: S.auto('Düzenle'),
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: MetoColors.primary,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (canMove)
          IconButton(
            tooltip: 'Admin: kategori değiştir',
            onPressed: () => _changeIlanCategory(
              kind: kind,
              id: id,
              title: title,
              ikincielCategory: ikincielCategory,
              uzmanlik: uzmanlik,
            ),
            icon: const Icon(
              Icons.drive_file_move_outline,
              size: 18,
              color: Color(0xFF7C3AED),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (canDelete)
          IconButton(
            tooltip: _isAdmin && !canEdit ? 'Admin: sil' : 'Sil',
            onPressed: () => _deleteIlan(kind: kind, id: id, title: title),
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFEF4444),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  Future<void> _markSoldIlan({
    required String kind,
    required int id,
    required String title,
  }) async {
    if (!_isIlanOwner(id) && !_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Satıldığını onaylıyor musunuz?'),
        content: L10nText(
          '"$title" ilanı satıldı olarak işaretlenecek ve yayından kalkacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCA8A04),
            ),
            child: const L10nText('Evet, satıldı'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await markIlanSold(
        email: widget.userEmail,
        kind: kind,
        id: id,
      );
      if (!mounted) return;
      setState(() {
        _selectedUzman = null;
        _selectedBakici = null;
        _selectedIkinciel = null;
      });
      widget.onIlanlarChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('İlan satıldı olarak işaretlendi ve yayından kaldırıldı')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('İşlem başarısız: $e')),
      );
    }
  }

  Future<bool> _ensureIlanPhotos(int id) async {
    final ok = await hydrateIlanDetail(id);
    if (ok || !mounted) return ok;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: L10nText('İlan detayı yüklenemedi. Tekrar deneyin.'),
      ),
    );
    return false;
  }

  /// Card on screen with no image yet: pull its photo in the background.
  void _ensureCardPhoto(int id, List<IlanPhoto> photos) {
    if (photos.any((p) => p.hasImage)) return;
    unawaited(hydrateFeedCardPhoto(id));
  }

  Future<void> _hydrateSelectedDetail(int id) async {
    final ok = await hydrateIlanDetail(id);
    if (!ok || !mounted) return;
    setState(() {
      if (_selectedUzman?.id == id) {
        for (final i in runtimeUzmanIlanlar) {
          if (i.id == id) {
            _selectedUzman = i;
            break;
          }
        }
      }
      if (_selectedBakici?.id == id) {
        for (final i in runtimeBakiciIlanlar) {
          if (i.id == id) {
            _selectedBakici = i;
            break;
          }
        }
      }
      if (_selectedIkinciel?.id == id) {
        for (final i in runtimeIkincielIlanlar) {
          if (i.id == id) {
            _selectedIkinciel = i;
            break;
          }
        }
      }
    });
  }

  Future<void> _openEditUzman(UzmanIlani ilan) async {
    if (!await _ensureIlanPhotos(ilan.id) || !mounted) return;
    var fresh = ilan;
    for (final i in runtimeUzmanIlanlar) {
      if (i.id == ilan.id) {
        fresh = i;
        break;
      }
    }
    setState(() {
      _editDraft = _IlanEditDraft(
        id: fresh.id,
        kind: 'uzman',
        title: fresh.title,
        city: fresh.city,
        district: fresh.district,
        countryCode: fresh.countryCode,
        note: fresh.note == '—' ? '' : fresh.note,
        budgetOrPrice: fresh.budget,
        uzmanlik: fresh.uzmanlik,
        category: fresh.category,
        photos: List<IlanPhoto>.from(fresh.photos),
      );
      _showVerForm = true;
    });
  }

  Future<void> _openEditBakici(BakiciIlani ilan) async {
    if (!await _ensureIlanPhotos(ilan.id) || !mounted) return;
    var fresh = ilan;
    for (final i in runtimeBakiciIlanlar) {
      if (i.id == ilan.id) {
        fresh = i;
        break;
      }
    }
    setState(() {
      _editDraft = _IlanEditDraft(
        id: fresh.id,
        kind: 'bakici',
        title: fresh.title,
        city: fresh.city,
        district: fresh.district,
        countryCode: fresh.countryCode,
        note: fresh.note == '—' ? '' : fresh.note,
        budgetOrPrice: fresh.budget,
        photos: List<IlanPhoto>.from(fresh.photos),
      );
      _showVerForm = true;
    });
  }

  Future<void> _openEditIkinciel(IkincielIlani ilan) async {
    if (!await _ensureIlanPhotos(ilan.id) || !mounted) return;
    var fresh = ilan;
    for (final i in runtimeIkincielIlanlar) {
      if (i.id == ilan.id) {
        fresh = i;
        break;
      }
    }
    setState(() {
      _editDraft = _IlanEditDraft(
        id: fresh.id,
        kind: 'ikinciel',
        title: fresh.title,
        city: fresh.city,
        district: fresh.district,
        countryCode: fresh.countryCode,
        note: fresh.note == '—' ? '' : fresh.note,
        budgetOrPrice: fresh.price,
        condition: fresh.condition,
        category: ikincielAltKategoriOf(fresh.category),
        photos: List<IlanPhoto>.from(fresh.photos),
      );
      _showVerForm = true;
    });
  }

  Future<void> _tryOpenEditIlan() async {
    final kind = widget.openEditIlanKind?.trim().toLowerCase();
    final id = widget.openEditIlanId;
    if (kind == null || kind.isEmpty || id == null || id <= 0) return;
    await ensureIlanLoaded(id);
    if (!mounted) return;
    switch (kind) {
      case 'uzman':
        for (final i in runtimeUzmanIlanlar) {
          if (i.id == id) {
            _openEditUzman(i);
            return;
          }
        }
        break;
      case 'bakici':
        for (final i in runtimeBakiciIlanlar) {
          if (i.id == id) {
            _openEditBakici(i);
            return;
          }
        }
        break;
      case 'ikinciel':
        for (final i in runtimeIkincielIlanlar) {
          if (i.id == id) {
            _openEditIkinciel(i);
            return;
          }
        }
        break;
    }
  }

  Future<void> _syncSohbetListesi() async {
    final me = widget.userEmail.trim().toLowerCase();
    if (me.isEmpty) return;
    final ozets = await loadSohbetOzetleri(me);
    if (!mounted || ozets.isEmpty) return;
    final names = await loadUserDisplayNamesByEmail(ozets.map((o) => o.peerEmail));
    if (!mounted) return;
    setState(() {
      for (final o in ozets) {
        final existing = _activeSohbetler
            .where((c) =>
                c.kisi.peerEmail.toLowerCase() == o.peerEmail.toLowerCase())
            .firstOrNull;
        final time =
            '${o.lastTime.toLocal().hour.toString().padLeft(2, '0')}:${o.lastTime.toLocal().minute.toString().padLeft(2, '0')}';
        final peerKey = o.peerEmail.trim().toLowerCase();
        final label = chatPeerLabel(
          o.peerEmail,
          profileName: names[peerKey],
          listingName: posterFullNameForOwner(o.peerEmail),
        );
        if (existing != null) {
          existing.lastMsg = scrubEmailsInText(o.lastMsg);
          existing.lastTime = time;
          existing.kisi = SohbetKisi(
            ad: label,
            avatar: contactAvatarLetter(label),
            avatarColor: existing.kisi.avatarColor,
            isOnline: existing.kisi.isOnline,
            sonGorus: existing.kisi.sonGorus,
            peerEmail: existing.kisi.peerEmail,
            ilanId: existing.kisi.ilanId,
            ilanTitle: existing.kisi.ilanTitle,
          );
        } else {
          _activeSohbetler.add(_ActiveSohbet(
            kisi: SohbetKisi(
              ad: label,
              avatar: contactAvatarLetter(label),
              avatarColor: MetoColors.primary,
              isOnline: false,
              peerEmail: o.peerEmail,
            ),
            lastMsg: scrubEmailsInText(o.lastMsg),
            lastTime: time,
          ));
        }
      }
    });
    _reportUnread();
  }

  @override
  void initState() {
    super.initState();
    ilanlarFeedRevision.addListener(_onIlanlarFeedRevision);
    _refreshFeed().then((_) async {
      if (!mounted) return;
      await _tryOpenPendingIlan();
      if (!mounted) return;
      await _tryOpenEditIlan();
    });
  }

  void _onIlanlarFeedRevision() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ilanlarFeedRevision.removeListener(_onIlanlarFeedRevision);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IlanlarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openIlanToken != oldWidget.openIlanToken) {
      unawaited(_tryOpenPendingIlan());
    }
    if (widget.openEditIlanToken != oldWidget.openEditIlanToken) {
      unawaited(_tryOpenEditIlan());
    }
  }

  Future<void> _tryOpenPendingIlan() async {
    final kind = widget.openIlanKind?.trim().toLowerCase();
    final id = widget.openIlanId;
    if (kind == null || kind.isEmpty || id == null || id <= 0) return;
    if (!ilanExistsInRuntime(id)) {
      await ensureIlanLoaded(id);
      if (!mounted) return;
    } else {
      await hydrateIlanDetail(id);
      if (!mounted) return;
    }
    _openListingByKindId(kind, id);
  }

  void _openListingByKindId(String kind, int id) {
    switch (kind) {
      case 'uzman':
        UzmanIlani? found;
        for (final i in runtimeUzmanIlanlar) {
          if (i.id == id) {
            found = i;
            break;
          }
        }
        if (found == null) return;
        setState(() {
          _showVerForm = false;
          _kategori = IlanKategori.uzmanlar;
          _selectedBakici = null;
          _selectedIkinciel = null;
          _selectedPoster = null;
          _selectedUzman = found;
        });
      case 'bakici':
        BakiciIlani? found;
        for (final i in runtimeBakiciIlanlar) {
          if (i.id == id) {
            found = i;
            break;
          }
        }
        if (found == null) return;
        setState(() {
          _showVerForm = false;
          _kategori = IlanKategori.bakici;
          _selectedUzman = null;
          _selectedIkinciel = null;
          _selectedPoster = null;
          _selectedBakici = found;
        });
      case 'ikinciel':
        IkincielIlani? found;
        for (final i in runtimeIkincielIlanlar) {
          if (i.id == id) {
            found = i;
            break;
          }
        }
        if (found == null) return;
        setState(() {
          _showVerForm = false;
          _kategori = IlanKategori.ikinciel;
          _selectedUzman = null;
          _selectedBakici = null;
          _selectedPoster = null;
          _selectedIkinciel = found;
        });
    }
  }

  Future<void> _refreshFeed() async {
    if (!_feedHasRuntimeIlanlar) {
      await warmIlanlarFromCache(widget.userEmail);
    }
    if (!mounted) return;
    setState(() {
      _loadingFeed = true;
      _feedRetrying = false;
      _feedError = null;
    });
    try {
      final ok = await loadAllIlanlar(preferEmail: widget.userEmail);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _feedError = kIlanListSlowMessage;
          _loadingFeed = false;
          _feedRetrying = false;
        });
      } else {
        setState(() {
          _loadingFeed = false;
          _feedRetrying = false;
          _feedError = null;
        });
      }
      try {
        await enrichRuntimeIlanAvatars(
          ownEmail: widget.userEmail,
          ownPhoto: widget.profilFoto,
        );
      } catch (_) {}
      if (widget.userEmail.trim().isNotEmpty) {
        try {
          final cloud = await loadUserCloudProfile(widget.userEmail);
          if (mounted) setState(() => _favoriler = cloud.favorites);
        } catch (_) {}
        try {
          final teklifler = await loadTeklifVerilenIlanlar(widget.userEmail);
          if (mounted) setState(() => _teklifVerilenIlanlar = teklifler);
        } catch (_) {}
      }
      if (!mounted) return;
      try {
        await _syncSohbetListesi();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedError = kIlanListSlowMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFeed = false;
          _feedRetrying = false;
        });
      }
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_loadingMore || _loadingFeed || !ilanlarHasMore) return;
    setState(() => _loadingMore = true);
    try {
      final ok = await loadMoreIlanlar(preferEmail: widget.userEmail);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kIlanListSlowMessage)),
        );
      } else {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kIlanListSlowMessage)),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _isFav(String kind, int id) =>
      _favoriler.any((f) => f.kind == kind && f.id == id);

  Future<void> _toggleFav(FavoriIlanRef ref) async {
    if (widget.isGuest || widget.userEmail.trim().isEmpty) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Favoriye eklemek için giriş yapmanız veya üye olmanız gerekiyor.',
      );
      return;
    }
    final adding = !_isFav(ref.kind, ref.id);
    final next = adding
        ? [..._favoriler, ref]
        : _favoriler.where((f) => f.key != ref.key).toList();
    setState(() => _favoriler = next);
    try {
      await upsertUserCloudProfile(email: widget.userEmail, favorites: next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adding ? 'Favorilere eklendi ❤️' : 'Favorilerden çıkarıldı',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favoriler = adding
            ? _favoriler.where((f) => f.key != ref.key).toList()
            : [..._favoriler, ref];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Favori kaydedilemedi. Tekrar deneyin.')),
      );
    }
  }

  Widget _favButton(FavoriIlanRef ref) {
    final on = _isFav(ref.kind, ref.id);
    return IconButton(
      tooltip: on ? 'Favoriden çıkar' : 'Kaydet',
      visualDensity: VisualDensity.compact,
      onPressed: () => _toggleFav(ref),
      icon: Icon(
        on ? Icons.favorite : Icons.favorite_border,
        size: 18,
        color: on ? const Color(0xFFDC2626) : MetoColors.mutedFg,
      ),
    );
  }

  static String _normLoc(String s) => s
      .toLowerCase()
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _matchesLoc(String city, String district, {String countryCode = 'TR'}) {
    final f = _filterLoc;
    // Konumdan bağımsız
    if (f.countryCode.isEmpty) return true;
    final code = countryCode.trim().isEmpty ? 'TR' : countryCode.trim().toUpperCase();
    if (code != f.countryCode.toUpperCase()) return false;
    // Tüm ülke
    if (f.state.isEmpty) return true;
    if (_normLoc(city) != _normLoc(f.state)) return false;
    if (f.city.isEmpty) return true;
    return _normLoc(district) == _normLoc(f.city);
  }

  List<UzmanIlani> get _filteredUzman {
    final demo = CatalogAdapters.showDemoIlanlar() ? uzmanIlanlar : const <UzmanIlani>[];
    return [...runtimeUzmanIlanlar, ...demo]
        .where((u) {
          if (!_matchesLoc(u.city, u.district, countryCode: u.countryCode)) {
            return false;
          }
          if ((uzmanKm[u.id] ?? 50) > _kmFilter) return false;
          if (_uzmanlikFilter != 'Tümü' && u.uzmanlik != _uzmanlikFilter) {
            return false;
          }
          if (_uzmanTipFilter != 'Tümü' && u.category != _uzmanTipFilter) {
            return false;
          }
          return true;
        })
        .toList();
  }

  List<BakiciIlani> get _filteredBakici {
    final demo = CatalogAdapters.showDemoIlanlar() ? bakiciIlanlar : const <BakiciIlani>[];
    return [...runtimeBakiciIlanlar, ...demo]
        .where((b) =>
            _matchesLoc(b.city, b.district, countryCode: b.countryCode) &&
            (bakiciKm[b.id] ?? 50) <= _kmFilter)
        .toList();
  }

  List<IkincielIlani> get _baseIkinciel {
    final demo =
        CatalogAdapters.showDemoIlanlar() ? ikincielIlanlar : const <IkincielIlani>[];
    return [...runtimeIkincielIlanlar, ...demo]
        .where((i) => _matchesLoc(i.city, i.district, countryCode: i.countryCode))
        .toList();
  }

  List<IkincielIlani> get _allIkinciel {
    return _baseIkinciel
        .where((i) =>
            _matchesIkincielDurum(i.condition) &&
            _matchesIkincielAlt(i.category))
        .toList();
  }

  bool _matchesIkincielAlt(String category) {
    if (_ikincielAltFilter == 'Tümü') return true;
    return ikincielAltKategoriOf(
          category,
          extras: CatalogAdapters.ikincielCustomAlts(),
        ) ==
        _ikincielAltFilter;
  }

  bool _matchesIkincielDurum(String condition) {
    if (_ikincielDurumFilter == 'Tümü') return true;
    final c = condition
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return switch (_ikincielDurumFilter) {
      'Sıfır' => c.contains('sifir'),
      'Az Kullanılmış' => c.contains('az kullan'),
      'İyi' => c == 'iyi' || c.startsWith('iyi ') || c.contains('cok iyi'),
      'Kötü' => c.contains('kotu'),
      _ => true,
    };
  }

  String _nowTime() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openTeklif(SohbetKisi kisi, {bool free = false, String kind = 'uzman'}) {
    if (widget.isGuest) {
      unawaited(ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Teklif vermek için giriş yapmanız veya üye olmanız gerekiyor.',
      ));
      return;
    }
    final me = widget.userEmail.trim().toLowerCase();
    if (kisi.peerEmail.isNotEmpty &&
        kisi.peerEmail.toLowerCase() == me) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Kendi ilanınıza teklif veremezsiniz')),
      );
      return;
    }
    if (kisi.peerEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText(
            'Bu örnek bir ilandır. Gerçek kullanıcı ilanına teklif vererek sohbet edebilirsiniz.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    // Daha önce teklif verildiyse / gönderiliyor ise kredi alma — doğrudan sohbet
    if (_teklifKilitliMi(kisi.ilanId)) {
      _openSohbet(kisi);
      return;
    }
    // 2. el: ücretsiz teklif / iletişim
    if (free || kind == 'ikinciel') {
      if (!_canOfferOn(kind, ilanId: kisi.ilanId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_offerBlockedMessage(kind)),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      _completeFreeTeklif(
        kisi,
        kind: kind,
        listingCategory: _uzmanListingCategory(kisi.ilanId),
      );
      return;
    }
    if (!_canOfferOn(kind, ilanId: kisi.ilanId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_offerBlockedMessage(kind)),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    // Optimistic kilit — modal açılırken peş peşe tıklamayı kes
    setState(() {
      _pendingSohbet = kisi;
      _teklifKilitle(kisi.ilanId);
    });
    _showKrediModal(
      onSpendAsync: () async {
        final k = _pendingSohbet;
        if (k == null) return false;
        if (widget.userKredi <= 0) return false;
        // Önce mesaj + bildirim; yalnızca ilk teklifte kredi düş.
        final newlySent = await notifyIlanSahibiTeklif(
          ownerEmail: k.peerEmail,
          actorName: widget.userName,
          ilanId: k.ilanId,
          ilanTitle: k.ilanTitle,
          kind: kind,
          listingCategory: _uzmanListingCategory(k.ilanId),
          userType: _normalizedRole,
        );
        if (k.ilanId != null) {
          await markTeklifVerildi(
            email: widget.userEmail,
            ilanId: k.ilanId!,
          );
        }
        if (!newlySent) {
          // Zaten bildirilmiş — tekrar puan alma
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: L10nText('Bu ilana zaten teklif verdiniz · sohbet açılıyor'),
              ),
            );
          }
          return true;
        }
        final spent = await widget.onKrediHarca();
        if (!spent) return false;
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: L10nText(
              '${k.ad} adlı ilan sahibine teklif bildirimi gönderildi · 1 puan harcandı',
            ),
          ),
        );
        return true;
      },
      onUnlocked: () {
        if (_pendingSohbet == null) return;
        final k = _pendingSohbet!;
        setState(() {
          _pendingSohbet = null;
          _teklifKilitAc(k.ilanId);
          if (k.ilanId != null) {
            _teklifVerilenIlanlar = {..._teklifVerilenIlanlar, k.ilanId!};
          }
          if (!_activeSohbetler.any((c) =>
              c.kisi.peerEmail.toLowerCase() == k.peerEmail.toLowerCase())) {
            _activeSohbetler.add(_ActiveSohbet(
              kisi: k,
              lastMsg: 'Teklif gönderildi',
              lastTime: _nowTime(),
            ));
          }
        });
        _reportUnread();
        _openSohbet(k);
      },
      onDismissed: () {
        if (!mounted || _pendingSohbet == null) return;
        // Vazgeçildi — kilidi geri al
        setState(() {
          final id = _pendingSohbet!.ilanId;
          _pendingSohbet = null;
          _teklifKilitAc(id, revertOffered: true);
        });
      },
    );
  }

  Future<void> _completeFreeTeklif(
    SohbetKisi k, {
    String kind = 'ikinciel',
    String listingCategory = kIlanCatUzmanAriyorum,
  }) async {
    if (_freeTeklifBusy || _teklifKilitliMi(k.ilanId)) {
      _openSohbet(k);
      return;
    }
    setState(() {
      _freeTeklifBusy = true;
      _teklifKilitle(k.ilanId);
    });
    try {
      final newlySent = await notifyIlanSahibiTeklif(
        ownerEmail: k.peerEmail,
        actorName: widget.userName,
        ilanId: k.ilanId,
        ilanTitle: k.ilanTitle,
        kind: kind,
        listingCategory: listingCategory,
        userType: _normalizedRole,
      );
      if (k.ilanId != null) {
        await markTeklifVerildi(email: widget.userEmail, ilanId: k.ilanId!);
      }
      if (!mounted) return;
      setState(() {
        _teklifKilitAc(k.ilanId);
        if (k.ilanId != null) {
          _teklifVerilenIlanlar = {..._teklifVerilenIlanlar, k.ilanId!};
        }
        if (!_activeSohbetler.any((c) =>
            c.kisi.peerEmail.toLowerCase() == k.peerEmail.toLowerCase())) {
          _activeSohbetler.add(_ActiveSohbet(
            kisi: k,
            lastMsg: 'Teklif gönderildi',
            lastTime: _nowTime(),
          ));
        }
      });
      _reportUnread();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newlySent
                ? '2. el teklif ücretsiz — sohbet açılıyor'
                : 'Bu ilana zaten teklif verdiniz · sohbet açılıyor',
          ),
        ),
      );
      _openSohbet(k);
    } catch (e) {
      if (!mounted) return;
      setState(() => _teklifKilitAc(k.ilanId, revertOffered: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('42501') ||
                    e.toString().toLowerCase().contains('row-level security')
                ? 'Teklif iletilemedi. Çıkış yapıp tekrar giriş yapın ve yeniden deneyin.'
                : e.toString().contains('bildirimler') ||
                        e.toString().contains('sohbet_mesajlari') ||
                        e.toString().contains('schema cache')
                    ? 'Teklif iletilemedi. Çıkış yapıp tekrar giriş yapın ve yeniden deneyin.'
                    : 'Teklif iletilemedi: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _freeTeklifBusy = false);
    }
  }

  void _openSohbet(SohbetKisi kisi) {
    setState(() {
      for (final c in _activeSohbetler) {
        if (c.kisi.peerEmail.toLowerCase() == kisi.peerEmail.toLowerCase() ||
            c.kisi.ad == kisi.ad) {
          c.unread = 0;
        }
      }
    });
    _reportUnread();
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: kisi,
          myEmail: widget.userEmail,
          myDisplayName: widget.userName,
          onNewMessage: (text) {
            setState(() {
              final existing = _activeSohbetler
                  .where((c) =>
                      c.kisi.peerEmail.toLowerCase() ==
                      kisi.peerEmail.toLowerCase())
                  .firstOrNull;
              if (existing != null) {
                existing.lastMsg = scrubEmailsInText(text);
                existing.lastTime = _nowTime();
              } else {
                _activeSohbetler.add(_ActiveSohbet(
                  kisi: kisi,
                  lastMsg: scrubEmailsInText(text),
                  lastTime: _nowTime(),
                ));
              }
            });
            _reportUnread();
          },
        ),
      ),
    )
        .then((_) {
      if (!mounted) return;
      _syncSohbetListesi();
    });
  }

  void _showKrediModal({
    VoidCallback? onUnlocked,
    Future<bool> Function()? onSpendAsync,
    VoidCallback? onDismissed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _KrediSheet(
        credits: widget.userKredi,
        onSpend: () async {
          if (onSpendAsync != null) return onSpendAsync();
          if (widget.userKredi <= 0) return false;
          return widget.onKrediHarca();
        },
        onUnlocked: () {
          Navigator.pop(ctx);
          onUnlocked?.call();
        },
        onClose: () => Navigator.pop(ctx),
      ),
    ).whenComplete(() {
      onDismissed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncOpenedIlanView();
    if (_showVerForm) {
      final editing = _editDraft != null;
      if (!editing && !_canPostListing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _showVerForm = false);
          if (_profNeedsRoleSwitchToPost) {
            _showRoleSwitchToPostWarning();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('İlan paylaşmak için Aile rolü gerekir.'),
              ),
            );
          }
        });
        return const SizedBox.shrink();
      }
      return _YeniIlanForm(
        userName: widget.userName,
        userEmail: widget.userEmail,
        userType: widget.userType,
        profilFoto: widget.profilFoto,
        editDraft: _editDraft,
        onBack: () => setState(() {
          _showVerForm = false;
          _editDraft = null;
        }),
        onPublished: (kategori) async {
          setState(() {
            _showVerForm = false;
            _editDraft = null;
            _kategori = kategori;
          });
          final messenger = ScaffoldMessenger.of(context);
          await _refreshFeed();
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                editing ? 'İlan güncellendi ✅' : 'İlanınız yayınlandı ✅',
              ),
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        ColoredBox(
          color: MetoColors.background,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(),
              if (_loadingFeed) const LinearProgressIndicator(minHeight: 2),
              if (_loadingFeed && _feedRetrying)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: L10nText(
                    'Yeniden deneniyor…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
              if (_feedError != null && _feedHasRuntimeIlanlar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 20,
                            color: MetoColors.mutedFg,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _feedError!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MetoColors.foreground,
                                height: 1.35,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadingFeed ? null : _refreshFeed,
                            child: const L10nText('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _buildCategoryTabs(),
              // Teklif puanı / ₺69 sadece uzman & bakıcı — aile rolünde asla.
              if (_normalizedRole == 'uzman' || _normalizedRole == 'bakici')
                _buildCreditBar(),
              _buildLocationFilter(),
              if (_kategori != IlanKategori.ikinciel) _buildKmFilter(),
              if (_kategori == IlanKategori.uzmanlar) ...[
                _buildUzmanTipFilter(),
                _buildUzmanlikFilter(),
              ],
              if (_kategori == IlanKategori.ikinciel) ...[
                _buildIkincielAltFilter(),
                _buildIkincielDurumFilter(),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    if (_loadingFeed && !_feedHasRuntimeIlanlar)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: LoadingErrorView(
                          loading: true,
                          loadingMessage: _feedRetrying
                              ? 'Yeniden deneniyor…'
                              : 'İlanlar yükleniyor…',
                        ),
                      )
                    else if (_feedError != null && !_feedHasRuntimeIlanlar)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: LoadingErrorView(
                          error: _feedError,
                          onRetry: _refreshFeed,
                        ),
                      )
                    else ...[
                      if (_kategori == IlanKategori.uzmanlar)
                        ..._pageSlice(_filteredUzman).map(_buildUzmanCard),
                      if (_kategori == IlanKategori.bakici)
                        ..._pageSlice(_filteredBakici).map(_buildBakiciCard),
                      if (_kategori == IlanKategori.ikinciel)
                        ..._pageSlice(_allIkinciel).map(_buildIkincielCard),
                      const SizedBox(height: 8),
                      _buildListPager(_currentListLength),
                      if (ilanlarHasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: (_loadingFeed || _loadingMore)
                              ? const L10nText(
                                  'Kalan ilanlar yükleniyor…',
                                  textAlign: TextAlign.center,
                                )
                              : TextButton(
                                  onPressed: _loadMoreFeed,
                                  child: const L10nText('Daha fazla ilan'),
                                ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_selectedBakici != null)
          _BakiciDrawer(
            ilan: _selectedBakici!,
            alreadyOffered: _teklifVerildiMi(_selectedBakici!.id),
            ctaLabel: _paidCtaLabel('bakici', _selectedBakici!.id),
            allowOffer: _canOfferOn('bakici', ilanId: _selectedBakici!.id),
            canWriteReview: _canReviewOn('bakici', ilanId: _selectedBakici!.id),
            onClose: () => setState(() => _selectedBakici = null),
            onEdit: _isIlanOwner(_selectedBakici!.id)
                ? () {
                    final ilan = _selectedBakici!;
                    setState(() => _selectedBakici = null);
                    _openEditBakici(ilan);
                  }
                : null,
            onDelete: _canDeleteIlan(_selectedBakici!.id)
                ? () => _deleteIlan(
                      kind: 'bakici',
                      id: _selectedBakici!.id,
                      title: _selectedBakici!.title,
                    )
                : null,
            onChangeCategory: _isAdmin
                ? () => _changeIlanCategory(
                      kind: 'bakici',
                      id: _selectedBakici!.id,
                      title: _selectedBakici!.title,
                    )
                : null,
            onProfile: () {
              final ilan = _selectedBakici!;
              setState(() {
                _selectedBakici = null;
                _selectedPoster = (
                  poster: ilan.poster,
                  ctaLabel: _paidCtaLabel('bakici', ilan.id),
                  peerEmail: ilanOwnerById[ilan.id] ?? '',
                  ilanId: ilan.id,
                  ilanTitle: ilan.title,
                  free: false,
                  kind: 'bakici',
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedBakici!;
              setState(() => _selectedBakici = null);
              _openTeklif(
                _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                kind: 'bakici',
              );
            },
          ),
        if (_selectedIkinciel != null)
          _IkincielDrawer(
            ilan: _selectedIkinciel!,
            alreadyOffered: _teklifVerildiMi(_selectedIkinciel!.id),
            onClose: () => setState(() => _selectedIkinciel = null),
            onEdit: _isIlanOwner(_selectedIkinciel!.id)
                ? () {
                    final ilan = _selectedIkinciel!;
                    setState(() => _selectedIkinciel = null);
                    _openEditIkinciel(ilan);
                  }
                : null,
            onDelete: _canDeleteIlan(_selectedIkinciel!.id)
                ? () => _deleteIlan(
                      kind: 'ikinciel',
                      id: _selectedIkinciel!.id,
                      title: _selectedIkinciel!.title,
                    )
                : null,
            onChangeCategory: _isAdmin
                ? () => _changeIlanCategory(
                      kind: 'ikinciel',
                      id: _selectedIkinciel!.id,
                      title: _selectedIkinciel!.title,
                      ikincielCategory: _selectedIkinciel!.category,
                    )
                : null,
            onProfile: () {
              final ilan = _selectedIkinciel!;
              setState(() {
                _selectedIkinciel = null;
                _selectedPoster = (
                  poster: ilan.poster,
                  ctaLabel: _teklifVerildiMi(ilan.id)
                      ? 'Teklif Verildi — Mesaja Git'
                      : 'Ücretsiz İletişim',
                  peerEmail: ilanOwnerById[ilan.id] ?? '',
                  ilanId: ilan.id,
                  ilanTitle: ilan.title,
                  free: true,
                  kind: 'ikinciel',
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedIkinciel!;
              setState(() => _selectedIkinciel = null);
              _openTeklif(
                _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                free: true,
                kind: 'ikinciel',
              );
            },
          ),
        if (_selectedUzman != null)
          _UzmanDrawer(
            ilan: _selectedUzman!,
            alreadyOffered: _teklifVerildiMi(_selectedUzman!.id),
            ctaLabel: _paidCtaLabel('uzman', _selectedUzman!.id),
            allowOffer: _canOfferOn('uzman', ilanId: _selectedUzman!.id),
            canWriteReview: _canReviewOn('uzman', ilanId: _selectedUzman!.id),
            onClose: () => setState(() => _selectedUzman = null),
            onEdit: _isIlanOwner(_selectedUzman!.id)
                ? () {
                    final ilan = _selectedUzman!;
                    setState(() => _selectedUzman = null);
                    _openEditUzman(ilan);
                  }
                : null,
            onDelete: _canDeleteIlan(_selectedUzman!.id)
                ? () => _deleteIlan(
                      kind: 'uzman',
                      id: _selectedUzman!.id,
                      title: _selectedUzman!.title,
                    )
                : null,
            onChangeCategory: _isAdmin
                ? () => _changeIlanCategory(
                      kind: 'uzman',
                      id: _selectedUzman!.id,
                      title: _selectedUzman!.title,
                      uzmanlik: _selectedUzman!.uzmanlik,
                    )
                : null,
            onProfile: () {
              final ilan = _selectedUzman!;
              setState(() {
                _selectedUzman = null;
                _selectedPoster = (
                  poster: ilan.poster,
                  ctaLabel: _paidCtaLabel('uzman', ilan.id),
                  peerEmail: ilanOwnerById[ilan.id] ?? '',
                  ilanId: ilan.id,
                  ilanTitle: ilan.title,
                  free: false,
                  kind: 'uzman',
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedUzman!;
              setState(() => _selectedUzman = null);
              _openTeklif(
                _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                kind: 'uzman',
              );
            },
          ),
        // Profil en üstte — satıcıya basınca diğer panellerin altında kalmasın.
        if (_selectedPoster != null)
          _ProfilDrawer(
            poster: _selectedPoster!.poster,
            ctaLabel: _teklifVerildiMi(_selectedPoster!.ilanId)
                ? 'Teklif Verildi — Mesaja Git'
                : _selectedPoster!.ctaLabel,
            alreadyOffered: _teklifVerildiMi(_selectedPoster!.ilanId),
            allowOffer: _canOfferOn(
              _selectedPoster!.kind,
              ilanId: _selectedPoster!.ilanId,
            ),
            canWriteReview: _canReviewOn(
              _selectedPoster!.kind,
              ilanId: _selectedPoster!.ilanId,
            ),
            onClose: () => setState(() => _selectedPoster = null),
            onKrediTap: () {
              final p = _selectedPoster!.poster;
              final peer = _selectedPoster!.peerEmail;
              final id = _selectedPoster!.ilanId;
              final title = _selectedPoster!.ilanTitle;
              final free = _selectedPoster!.free;
              final kind = _selectedPoster!.kind;
              setState(() => _selectedPoster = null);
              _openTeklif(
                id != null
                    ? _kisiFromPoster(
                        poster: p,
                        ilanId: id,
                        ilanTitle: title,
                      )
                    : SohbetKisi(
                        ad: chatPeerLabel(
                          peer,
                          listingName: p.fullName.trim().isNotEmpty
                              ? p.fullName
                              : p.name,
                        ),
                        avatar: p.avatar,
                        avatarColor: p.avatarColor,
                        isOnline: false,
                        peerEmail: peer,
                        ilanTitle: title,
                      ),
                free: free,
                kind: kind,
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText(
                  'İlanlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                L10nText(
                  'Uzman / bakıcı-temizlik arayan ilanlar · 2. el',
                  style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ],
            ),
          ),
          if (_totalUnread > 0) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  L10nText(
                    '$_totalUnread yeni',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_canPostListing || _profNeedsRoleSwitchToPost)
            FilledButton.icon(
              onPressed: () async {
                if (widget.isGuest) {
                  await ensureMemberAccess(
                    context,
                    isGuest: true,
                    onRequireLogin: widget.onRequireLogin ?? () {},
                    message:
                        'İlan vermek için giriş yapmanız veya üye olmanız gerekiyor.',
                  );
                  return;
                }
                if (_profNeedsRoleSwitchToPost) {
                  _showRoleSwitchToPostWarning();
                  return;
                }
                setState(() => _showVerForm = true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const L10nText(
                'İlan Ver',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = [
      (IlanKategori.uzmanlar, S.t('ilan_tab_uzman'), '🏃', _filteredUzman.length),
      (
        IlanKategori.bakici,
        S.t('ilan_tab_bakici'),
        '🤝',
        _filteredBakici.length,
      ),
      (IlanKategori.ikinciel, S.t('ilan_tab_ikinciel'), '♻️', _baseIkinciel.length),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: tabs.map((t) {
          final selected = _kategori == t.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: selected ? MetoColors.selectedBg : MetoColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected ? MetoColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    _kategori = t.$1;
                    _listPage = 0;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(t.$3, style: const TextStyle(fontSize: 20)),
                        Text(
                          t.$2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? MetoColors.primary
                                : MetoColors.mutedFg,
                          ),
                        ),
                        Text(
                          S.n('ilan_count', {'n': '${t.$4}'}),
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? MetoColors.primary
                                : const Color(0xFFB0A899),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCreditBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText(
                  '${widget.userKredi} puanınız var',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const L10nText(
                  '1 puan = 1 teklif = ₺69,90',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => widget.onOpenKrediYukle?.call(),
            style: TextButton.styleFrom(
              backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
              foregroundColor: MetoColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const L10nText(
              'Satın Al',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: LocationCascadePicker(
        value: _filterLoc,
        showAnywhereOption: true,
        requireFullSelection: false,
        compact: true,
        onChanged: (loc) => setState(() {
          _filterLoc = loc;
          _listPage = 0;
        }),
      ),
    );
  }

  int get _currentListLength {
    return switch (_kategori) {
      IlanKategori.uzmanlar => _filteredUzman.length,
      IlanKategori.bakici => _filteredBakici.length,
      IlanKategori.ikinciel => _allIkinciel.length,
    };
  }

  List<T> _pageSlice<T>(List<T> items) {
    if (items.isEmpty) return const [];
    final pageCount = (items.length / _pageSize).ceil().clamp(1, 9999);
    final page = _listPage.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  Widget _buildListPager(int total) {
    if (total <= _pageSize) {
      if (total == 0) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: L10nText(
            'Bu filtrede ilan yok',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: L10nText(
          '$total ilan',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
        ),
      );
    }
    final pageCount = (total / _pageSize).ceil();
    final page = _listPage.clamp(0, pageCount - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        children: [
          L10nText(
            'Sayfa ${page + 1} / $pageCount · $total ilan',
            style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < pageCount; i++)
                Material(
                  color: i == page ? MetoColors.primary : MetoColors.muted,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _listPage = i),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: L10nText(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: i == page ? Colors.white : MetoColors.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKmFilter() {
    final label = _kmFilter >= 500 ? 'Tümü' : '${_kmFilter.toInt()} km';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 13, color: MetoColors.primary),
          const SizedBox(width: 4),
          const L10nText(
            'Mesafe',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: MetoColors.primary,
                inactiveTrackColor: MetoColors.muted,
                thumbColor: MetoColors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: MetoColors.primary.withValues(alpha: 0.12),
              ),
              child: Slider(
                min: 5,
                max: 500,
                divisions: 99,
                value: _kmFilter,
                onChanged: (v) => setState(() {
                  _kmFilter = v;
                  _listPage = 0;
                }),
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: MetoColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static const _uzmanTipFiltreleri = <String>[
    'Tümü',
    kIlanCatUzmanAriyorum,
    kIlanCatIsAriyorum,
  ];

  Widget _buildChipFilterRow({
    required String title,
    required List<String> options,
    required String active,
    required ValueChanged<String> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final label = options[i];
                      final isActive = active == label;
                      final shown = label == 'Tümü' ? S.t('ilan_alt_all') : label;
                      return Material(
                        color: isActive ? MetoColors.primary : MetoColors.muted,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: () => setState(() {
                            onSelected(label);
                            _listPage = 0;
                          }),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              shown,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : MetoColors.mutedFg,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUzmanTipFilter() {
    return _buildChipFilterRow(
      title: 'İlan türü',
      options: _uzmanTipFiltreleri,
      active: _uzmanTipFilter,
      onSelected: (v) => _uzmanTipFilter = v,
    );
  }

  Widget _buildUzmanlikFilter() {
    final opts = <String>[
      'Tümü',
      ...CatalogAdapters.uzmanlikSecenekleri(),
    ];
    return _buildChipFilterRow(
      title: 'Uzmanlık',
      options: opts,
      active: _uzmanlikFilter,
      onSelected: (v) => _uzmanlikFilter = v,
    );
  }

  static const _ikincielDurumFiltreleri = <String>[
    'Tümü',
    'Sıfır',
    'Az Kullanılmış',
    'İyi',
    'Kötü',
  ];

  String _ikincielAltLabel(String key) => switch (key) {
        'Tümü' => S.t('ilan_alt_all'),
        kIkincielAltMedikal => S.t('ilan_alt_medikal'),
        kIkincielAltDiger => S.t('ilan_alt_diger'),
        _ => key,
      };

  Widget _buildIkincielAltFilter() {
    final keys = <String>[
      'Tümü',
      ...CatalogAdapters.ikincielAltKategoriler(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.t('ilan_ikinciel_alt'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < keys.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final key = keys[i];
                      final active = _ikincielAltFilter == key;
                      return Material(
                        color: active ? MetoColors.primary : MetoColors.muted,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: () => setState(() {
                            _ikincielAltFilter = key;
                            _listPage = 0;
                          }),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              _ikincielAltLabel(key),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : MetoColors.mutedFg,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIkincielDurumFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.t('ilan_condition'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _ikincielDurumFiltreleri.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final label = _ikincielDurumFiltreleri[i];
                      final active = _ikincielDurumFilter == label;
                      final shown = label == 'Tümü'
                          ? S.t('ilan_alt_all')
                          : label;
                      return Material(
                        color: active ? MetoColors.primary : MetoColors.muted,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: () => setState(() {
                            _ikincielDurumFilter = label;
                            _listPage = 0;
                          }),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              shown,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : MetoColors.mutedFg,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paidActionLabel(String kind, int? ilanId) {
    if (_teklifVerildiMi(ilanId)) return 'Teklif Verildi';
    if (!_canOfferOn(kind, ilanId: ilanId)) {
      return kind == 'ikinciel' ? 'Giriş gerekli' : 'Rol gerekli';
    }
    if (kind == 'ikinciel') return 'İletişim';
    return 'Teklif Ver';
  }

  String _paidCtaLabel(String kind, int? ilanId) {
    if (_teklifVerildiMi(ilanId)) return 'Teklif Verildi — Mesaja Git';
    if (!_canOfferOn(kind, ilanId: ilanId)) {
      if (kind == 'ikinciel') return 'İletişim için giriş yapın';
      if (_normalizedRole == 'aile') {
        return 'Teklif için Uzman/Bakıcı rolü';
      }
      return 'Teklif için Uzman/Bakıcı rolü';
    }
    if (kind == 'ikinciel') return 'Ücretsiz İletişim';
    return '1 Puan Harca — Teklif Ver';
  }

  Widget _buildUzmanCard(UzmanIlani ilan) {
    _ensureCardPhoto(ilan.id, ilan.photos);
    final renk = uzmanRenkFor(ilan.uzmanlik);
    final avgR = avgRating(ilan.poster.reviews);
    final km = uzmanKm[ilan.id];
    void openDetail() {
      setState(() {
        _selectedPoster = null;
        _selectedUzman = ilan;
      });
      unawaited(_hydrateSelectedDetail(ilan.id));
    }
    void openPoster() => setState(() {
          _selectedUzman = null;
          _selectedBakici = null;
          _selectedIkinciel = null;
          _selectedPoster = (
            poster: ilan.poster,
            ctaLabel: _paidCtaLabel('uzman', ilan.id),
            peerEmail: ilanOwnerById[ilan.id] ?? '',
            ilanId: ilan.id,
            ilanTitle: ilan.title,
            free: false,
            kind: 'uzman',
          );
        });

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ilan.photos.isNotEmpty)
            _PhotoStrip(
              photos: ilan.photos,
              emoji: renk.emoji,
            ),
          InkWell(
            onTap: openDetail,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarButton(
                  label: ilan.poster.publicListingAvatar,
                  color: ilan.poster.avatarColor,
                  onTap: openPoster,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (ilan.urgent)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 4),
                                  child: Icon(Icons.auto_awesome,
                                      size: 14, color: Colors.red),
                                ),
                              Expanded(
                                child: L10nText(
                                  ilan.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Badge(
                                text: '${renk.emoji} ${ilan.uzmanlik}',
                                bg: renk.bg,
                                fg: renk.color,
                              ),
                              if (isIlanIsAriyorum(ilan.category))
                                const _Badge(
                                  text: '💼 İş Arıyorum',
                                  bg: Color(0xFFE0F2FE),
                                  fg: Color(0xFF0369A1),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openPoster,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: L10nText(
                        ilan.poster.publicListingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                    StarRow(rating: avgR, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      avgR.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    L10nText(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const L10nText(
                      'Profil',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up,
                        size: 18, color: MetoColors.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(items: [
            '📍 ${ilan.district}, ${ilan.city}',
            '📅 ${ilan.frequency}',
            '👁 ${ilanViewLabel(ilan.views)}',
            if (km != null) '📍 $km km uzakta',
          ]),
          const SizedBox(height: 8),
          _Chip(text: ilan.tani),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: openDetail,
            child: L10nText(
              ilan.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.budget,
            subtitle: '${ilan.offers} teklif · ${ilan.posted}',
            leadingActions: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _favButton(FavoriIlanRef(
                  kind: 'uzman',
                  id: ilan.id,
                  title: ilan.title,
                  konum:
                      '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                  fiyat: ilan.budget,
                )),
                _ilanEditDeleteActions(
                  id: ilan.id,
                  kind: 'uzman',
                  title: ilan.title,
                  uzmanlik: ilan.uzmanlik,
                  onEdit: () => _openEditUzman(ilan),
                ),
              ],
            ),
            onProfile: openDetail,
            onAction: _canOfferOn('uzman', ilanId: ilan.id) ||
                    _teklifVerildiMi(ilan.id)
                ? () => _openTeklif(
                      _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                      kind: 'uzman',
                    )
                : null,
            actionLabel: _canOfferOn('uzman', ilanId: ilan.id) ||
                    _teklifVerildiMi(ilan.id)
                ? _paidActionLabel('uzman', ilan.id)
                : 'Teklif için Uzman/Bakıcı rolü',
            alreadyOffered: _teklifVerildiMi(ilan.id),
            profileLabel: 'Detay',
          ),
        ],
      ),
    );
  }

  Widget _buildBakiciCard(BakiciIlani ilan) {
    _ensureCardPhoto(ilan.id, ilan.photos);
    final avgR = avgRating(ilan.poster.reviews);
    final km = bakiciKm[ilan.id];
    void openDetail() {
      setState(() {
        _selectedPoster = null;
        _selectedBakici = ilan;
      });
      unawaited(_hydrateSelectedDetail(ilan.id));
    }
    void openPoster() => setState(() {
          _selectedUzman = null;
          _selectedBakici = null;
          _selectedIkinciel = null;
          _selectedPoster = (
            poster: ilan.poster,
            ctaLabel: _paidCtaLabel('bakici', ilan.id),
            peerEmail: ilanOwnerById[ilan.id] ?? '',
            ilanId: ilan.id,
            ilanTitle: ilan.title,
            free: false,
            kind: 'bakici',
          );
        });

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ilan.photos.isNotEmpty)
            _PhotoStrip(
              photos: ilan.photos,
              emoji: '🤝',
            ),
          InkWell(
            onTap: openDetail,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarButton(
                  label: ilan.poster.publicListingAvatar,
                  color: ilan.poster.avatarColor,
                  onTap: openPoster,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (ilan.urgent)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 4),
                                  child: Icon(Icons.auto_awesome,
                                      size: 14, color: Colors.red),
                                ),
                              Expanded(
                                child: L10nText(
                                  ilan.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const _Badge(
                            text: '🤝 Bakıcı/Temizlik Görevlisi Aranıyor',
                            bg: Color(0xFFEFF6FF),
                            fg: Color(0xFF1D4ED8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openPoster,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: L10nText(
                        ilan.poster.publicListingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                    StarRow(rating: avgR, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      avgR.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    L10nText(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const L10nText(
                      'Profil',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up,
                        size: 18, color: MetoColors.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(items: [
            '📍 ${ilan.district}, ${ilan.city}',
            '👁 ${ilanViewLabel(ilan.views)}',
            if (km != null) '📍 $km km uzakta',
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(text: ilan.tani),
              _Chip(text: ilan.age),
            ],
          ),
          const SizedBox(height: 8),
          L10nText('📅 ${ilan.hours}',
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: openDetail,
            child: L10nText(
              ilan.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.budget,
            subtitle: ilan.posted,
            leadingActions: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _favButton(FavoriIlanRef(
                  kind: 'bakici',
                  id: ilan.id,
                  title: ilan.title,
                  konum:
                      '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                  fiyat: ilan.budget,
                )),
                _ilanEditDeleteActions(
                  id: ilan.id,
                  kind: 'bakici',
                  title: ilan.title,
                  onEdit: () => _openEditBakici(ilan),
                ),
              ],
            ),
            onProfile: openDetail,
            onAction: _canOfferOn('bakici', ilanId: ilan.id) ||
                    _teklifVerildiMi(ilan.id)
                ? () => _openTeklif(
                      _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                      kind: 'bakici',
                    )
                : null,
            actionLabel: _canOfferOn('bakici', ilanId: ilan.id) ||
                    _teklifVerildiMi(ilan.id)
                ? _paidActionLabel('bakici', ilan.id)
                : null,
            alreadyOffered: _teklifVerildiMi(ilan.id),
            profileLabel: 'Detay',
          ),
        ],
      ),
    );
  }

  Widget _buildIkincielCard(IkincielIlani ilan) {
    _ensureCardPhoto(ilan.id, ilan.photos);
    final avgR = avgRating(ilan.poster.reviews);
    void openDetail() {
      setState(() => _selectedIkinciel = ilan);
      unawaited(_hydrateSelectedDetail(ilan.id));
    }
    void openPoster() {
      setState(() {
        _selectedIkinciel = null;
        _selectedPoster = (
          poster: ilan.poster,
          ctaLabel: _teklifVerildiMi(ilan.id)
              ? 'Teklif Verildi — Mesaja Git'
              : 'Ücretsiz İletişim',
          peerEmail: ilanOwnerById[ilan.id] ?? '',
          ilanId: ilan.id,
          ilanTitle: ilan.title,
          free: true,
          kind: 'ikinciel',
        );
      });
    }

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ilan.photos.isNotEmpty)
            _PhotoStrip(
              photos: ilan.photos,
              emoji: ilan.emoji,
            ),
          InkWell(
            onTap: openDetail,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      L10nText(
                        ilan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      L10nText(
                        '${ilan.brand} · ${ikincielAltDisplayLabel(ilan.category)}',
                        style: const TextStyle(
                            fontSize: 12, color: MetoColors.mutedFg),
                      ),
                    ],
                  ),
                ),
                _Badge(
                  text: ilan.condition,
                  bg: ikincielDurumRenk(ilan.condition).bg,
                  fg: ikincielDurumRenk(ilan.condition).fg,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openPoster,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  children: [
                    _SmallAvatar(
                        label: ilan.poster.publicListingAvatar,
                        color: ilan.poster.avatarColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: L10nText(
                        ilan.poster.publicListingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                    StarRow(rating: avgR, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      avgR.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    L10nText(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const L10nText(
                      'Profil',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up,
                        size: 18, color: MetoColors.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(items: [
            '📍 ${ilan.district}, ${ilan.city}',
            '👁 ${ilanViewLabel(ilan.views)}',
            ilan.posted,
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: openDetail,
            child: L10nText(
              ilan.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.price,
            subtitle: ilan.originalPrice,
            subtitleStrike: true,
            priceLarge: true,
            leadingActions: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _favButton(FavoriIlanRef(
                  kind: 'ikinciel',
                  id: ilan.id,
                  title: ilan.title,
                  konum:
                      '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                  fiyat: ilan.price,
                )),
                _ilanEditDeleteActions(
                  id: ilan.id,
                  kind: 'ikinciel',
                  title: ilan.title,
                  ikincielCategory: ilan.category,
                  onEdit: () => _openEditIkinciel(ilan),
                ),
              ],
            ),
            onProfile: openDetail,
            onAction: () => _openTeklif(
                  _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                  free: true,
                  kind: 'ikinciel',
                ),
            actionLabel: _teklifVerildiMi(ilan.id)
                ? 'Teklif Verildi'
                : 'İletişim',
            alreadyOffered: _teklifVerildiMi(ilan.id),
            profileLabel: 'Detay',
          ),
        ],
      ),
    );
  }

}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(
          Icons.star,
          size: size,
          color: filled ? MetoColors.accentGold : const Color(0xFFE5E0D8),
        );
      }),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.reviews});

  final List<IlanReview> reviews;

  @override
  Widget build(BuildContext context) {
    final counts = [5, 4, 3, 2, 1].map((s) {
      return (star: s, count: reviews.where((r) => r.rating == s).length);
    }).toList();
    final peak =
        counts.map((c) => c.count).fold<int>(0, (a, b) => a > b ? a : b);
    final maxCount = peak == 0 ? 1 : peak;

    return Column(
      children: counts.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                child: L10nText(
                  '${c.star}',
                  textAlign: TextAlign.right,
                  style:
                      const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ),
              const Icon(Icons.star, size: 10, color: MetoColors.accentGold),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: c.count / maxCount,
                    minHeight: 6,
                    backgroundColor: MetoColors.muted,
                    color: MetoColors.accentGold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                child: L10nText(
                  '${c.count}',
                  style:
                      const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _IlanCard extends StatelessWidget {
  const _IlanCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget face;
    if (isAvatarImageSource(label)) {
      face = UserAvatar(
        avatar: label,
        color: color,
        radius: 22,
        fallbackName: label,
      );
    } else {
      face = Container(
        alignment: Alignment.center,
        color: color,
        child: Text(
          avatarInitialsFallback(label),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 44, height: 44, child: face),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      avatar: label,
      color: color,
      radius: 12,
      fallbackName: label,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: MetoColors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
      ),
    );
  }
}

class _OwnerViewsBanner extends StatelessWidget {
  const _OwnerViewsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF047857)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count <= 0
                  ? 'İlanını henüz kimse görüntülemedi'
                  : 'İlanını ${ilanViewLabel(count).toLowerCase()}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        final primary = item.contains('km uzakta');
        return Text(
          item,
          style: TextStyle(
            fontSize: 12,
            color: primary ? MetoColors.primary : MetoColors.mutedFg,
            fontWeight: primary ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.price,
    required this.subtitle,
    required this.onProfile,
    this.onAction,
    this.actionLabel,
    this.subtitleStrike = false,
    this.priceLarge = false,
    this.alreadyOffered = false,
    this.profileLabel = 'Profil',
    this.leadingActions,
  });

  final String price;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool subtitleStrike;
  final bool priceLarge;
  final bool alreadyOffered;
  final String profileLabel;
  final Widget? leadingActions;

  @override
  Widget build(BuildContext context) {
    final showAction = onAction != null && actionLabel != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (leadingActions != null) ...[
              leadingActions!,
              const SizedBox(width: 4),
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: onProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: MetoColors.foreground,
                side: const BorderSide(color: MetoColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(profileLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            if (showAction) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: alreadyOffered
                      ? const Color(0xFF15803D)
                      : MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  alreadyOffered
                      ? Icons.check_circle
                      : Icons.monetization_on,
                  size: 14,
                ),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          formatPriceTl(price),
          style: TextStyle(
            fontSize: priceLarge ? 16 : 12,
            fontWeight: FontWeight.w800,
            color: priceLarge ? MetoColors.primary : MetoColors.foreground,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: MetoColors.mutedFg,
            decoration: subtitleStrike ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

ImageProvider? _ilanPhotoProvider(IlanPhoto photo) =>
    galleryImageProvider(photo.dataUrl);

List<ImageProvider> _ilanGalleryImages(List<IlanPhoto> photos) {
  return [
    for (final p in photos)
      if (_ilanPhotoProvider(p) != null) _ilanPhotoProvider(p)!,
  ];
}

void _openIlanPhotoGallery(
  BuildContext context,
  List<IlanPhoto> photos, {
  int index = 0,
}) {
  final gallery = _ilanGalleryImages(photos);
  if (gallery.isEmpty) return;
  final safe = index.clamp(0, photos.length - 1);
  var gi = 0;
  for (var k = 0; k < safe; k++) {
    if (photos[k].hasImage) gi++;
  }
  openPhotoGallery(
    context,
    images: gallery,
    initialIndex: photos[safe].hasImage ? gi : 0,
  );
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.emoji,
  });

  final List<IlanPhoto> photos;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final height = photos.length == 1 ? 220.0 : 180.0;
    final gallery = _ilanGalleryImages(photos);
    final glyph = emoji.trim().isEmpty ? '📦' : emoji;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: height,
        child: Row(
          children: photos.asMap().entries.map((e) {
            final i = e.key;
            final photo = e.value;
            return Expanded(
              child: GestureDetector(
                onTap: gallery.isEmpty
                    ? null
                    : () => _openIlanPhotoGallery(
                          context,
                          photos,
                          index: i,
                        ),
                child: Container(
                  height: height,
                  margin:
                      EdgeInsets.only(right: i < photos.length - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: photo.swatchColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: photo.hasImage
                      ? FillPhoto(
                          source: photo.dataUrl,
                          placeholder: Text(
                            glyph,
                            style: TextStyle(
                              fontSize: photos.length == 1 ? 48 : 32,
                              color: Colors.black.withValues(alpha: 0.85),
                            ),
                          ),
                        )
                      : Text(
                          glyph,
                          style: TextStyle(
                            fontSize: photos.length == 1 ? 48 : 32,
                            color: Colors.black.withValues(alpha: 0.85),
                          ),
                        ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Kredi modal ─────────────────────────────────────────────────────────────

class _KrediSheet extends StatefulWidget {
  const _KrediSheet({
    required this.credits,
    required this.onSpend,
    required this.onUnlocked,
    required this.onClose,
  });

  final int credits;
  final Future<bool> Function() onSpend;
  final VoidCallback onUnlocked;
  final VoidCallback onClose;

  @override
  State<_KrediSheet> createState() => _KrediSheetState();
}

class _KrediSheetState extends State<_KrediSheet> {
  bool _unlocked = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return _SheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF16A34A), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      L10nText('Teklif Gönderildi!',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      L10nText('1 puan harcandı · Sohbet hazır',
                          style: TextStyle(
                              fontSize: 12, color: MetoColors.mutedFg)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: MetoColors.muted,
                  borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  _InfoLine(
                      icon: Icons.message, text: 'Karşı taraf bilgilendirildi'),
                  SizedBox(height: 8),
                  _InfoLine(
                      icon: Icons.chat_bubble_outline,
                      text: 'Sohbeti başlatmak için devam edin'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onUnlocked,
              style: _primaryBtn,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const L10nText('Sohbete Git',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    L10nText('İletişim Bilgisini Aç',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    L10nText('1 puan harcayarak iletişim bilgisine ulaş',
                        style:
                            TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on,
                        size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    L10nText('${widget.credits} puan',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText('Açıldığında ne görürsünüz:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                _InfoLine(icon: Icons.phone, text: 'Telefon numarası'),
                _InfoLine(icon: Icons.email_outlined, text: 'E-posta adresi'),
                _InfoLine(
                    icon: Icons.location_on_outlined,
                    text: 'Kesin adres / semt'),
                _InfoLine(
                    icon: Icons.calendar_today, text: 'Uygun saat bilgisi'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.credits > 0 && !_busy
                ? () async {
                    setState(() => _busy = true);
                    try {
                      final ok = await widget.onSpend();
                      if (!mounted) return;
                      if (ok) {
                        setState(() {
                          _unlocked = true;
                          _busy = false;
                        });
                      } else {
                        setState(() => _busy = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: L10nText(
                              'Teklif gönderilemedi. Tekrar deneyin.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().contains('42501') ||
                                    e.toString().toLowerCase().contains('row-level security')
                                ? 'Teklif iletilemedi. Çıkış yapıp tekrar giriş yapın ve yeniden deneyin.'
                                : e.toString().contains('bildirimler') ||
                                        e.toString().contains('sohbet_mesajlari') ||
                                        e.toString().contains('schema cache')
                                    ? 'Teklif iletilemedi. Çıkış yapıp tekrar giriş yapın ve yeniden deneyin.'
                                    : 'Teklif iletilemedi: $e',
                          ),
                        ),
                      );
                    }
                  }
                : null,
            style: _primaryBtn,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.monetization_on, size: 20),
            label: Text(
              _busy ? 'Gönderiliyor…' : '1 Puan Harca — Teklif Ver',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          TextButton(
              onPressed: _busy ? null : widget.onClose,
              child: const L10nText('Vazgeç',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: MetoColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

final _primaryBtn = FilledButton.styleFrom(
  backgroundColor: MetoColors.primary,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(999)),
          ),
          child,
        ],
      ),
    );
  }
}

class _DrawerShell extends StatefulWidget {
  const _DrawerShell(
      {required this.onClose, required this.footer, required this.child});
  final VoidCallback onClose;
  final Widget footer;
  final Widget child;

  @override
  State<_DrawerShell> createState() => _DrawerShellState();
}

class _DrawerShellState extends State<_DrawerShell> {
  double _dragY = 0;

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    final next = (_dragY + d.delta.dy).clamp(0.0, 600.0);
    if (next != _dragY) setState(() => _dragY = next);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final shouldClose =
        _dragY > 120 || (d.primaryVelocity != null && d.primaryVelocity! > 700);
    if (shouldClose) {
      widget.onClose();
      return;
    }
    setState(() => _dragY = 0);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final dim = (1 - (_dragY / 320).clamp(0.0, 0.65));
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.54 * dim),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: GestureDetector(
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: maxH),
                    decoration: const BoxDecoration(
                      color: MetoColors.card,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: _onVerticalDragUpdate,
                          onVerticalDragEnd: _onVerticalDragEnd,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                            child: Row(
                              children: [
                                const Spacer(),
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: MetoColors.muted,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      tooltip: S.auto('Kapat'),
                                      onPressed: widget.onClose,
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Flexible(
                            child: SingleChildScrollView(child: widget.child)),
                        widget.footer,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.label,
    required this.onTap,
    this.color,
    this.alreadyOffered = false,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool alreadyOffered;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: MetoColors.border))),
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        style: _primaryBtn.copyWith(
            backgroundColor: WidgetStatePropertyAll(
                !enabled
                    ? MetoColors.mutedFg
                    : alreadyOffered
                        ? const Color(0xFF15803D)
                        : (color ?? MetoColors.primary))),
        icon: Icon(
          !enabled
              ? Icons.block
              : alreadyOffered
                  ? Icons.check_circle
                  : Icons.monetization_on,
          size: 18,
        ),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.reviews,
    required this.yorumYaz,
    required this.submitted,
    required this.myRating,
    required this.myText,
    required this.onToggleYorum,
    required this.onRating,
    required this.onSubmit,
    this.canWrite = true,
  });

  final List<IlanReview> reviews;
  final bool yorumYaz;
  final bool submitted;
  final int myRating;
  final TextEditingController myText;
  final VoidCallback onToggleYorum;
  final ValueChanged<int> onRating;
  final VoidCallback onSubmit;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const L10nText('Yorumlar',
                style: TextStyle(fontWeight: FontWeight.w800)),
            if (canWrite && !yorumYaz && !submitted)
              TextButton(
                  onPressed: onToggleYorum,
                  child: const L10nText('+ Yorum Yaz',
                      style: TextStyle(fontWeight: FontWeight.w800))),
            if (!canWrite)
              const L10nText('Bu ilana rolünüzle yorum yazılamaz',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg)),
            if (submitted)
              const L10nText('✓ Yorumunuz eklendi',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A))),
          ],
        ),
        if (canWrite && yorumYaz) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const L10nText('Puanınız',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Row(
                  children: List.generate(5, (i) {
                    final s = i + 1;
                    return IconButton(
                      onPressed: () => onRating(s),
                      icon: Icon(Icons.star,
                          size: 28,
                          color: s <= myRating
                              ? MetoColors.accentGold
                              : const Color(0xFFE5E0D8)),
                    );
                  }),
                ),
                TextField(
                  controller: myText,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: S.auto('Deneyiminizi paylaşın...'),
                    filled: true,
                    fillColor: MetoColors.card,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                          onPressed: onSubmit,
                          child: const L10nText('Gönder',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: onToggleYorum, child: const L10nText('İptal')),
                  ],
                ),
              ],
            ),
          ),
        ],
        ...reviews.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetoColors.muted.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SmallAvatar(label: r.avatar, color: r.avatarColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r.author,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                            StarRow(rating: r.rating.toDouble(), size: 10),
                          ],
                        ),
                        Text(r.text,
                            style: const TextStyle(fontSize: 12, height: 1.4)),
                        Text(r.date,
                            style: const TextStyle(
                                fontSize: 10, color: MetoColors.mutedFg)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _ProfilDrawer extends StatefulWidget {
  const _ProfilDrawer({
    required this.poster,
    required this.ctaLabel,
    required this.onClose,
    required this.onKrediTap,
    this.alreadyOffered = false,
    this.allowOffer = true,
    this.canWriteReview = true,
  });
  final IlanPoster poster;
  final String ctaLabel;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final bool alreadyOffered;
  final bool allowOffer;
  final bool canWriteReview;
  @override
  State<_ProfilDrawer> createState() => _ProfilDrawerState();
}

class _ProfilDrawerState extends State<_ProfilDrawer> {
  late List<IlanReview> _reviews = List.of(widget.poster.reviews);
  bool _yorumYaz = false;
  int _myRating = 0;
  final _myText = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _myText.dispose();
    super.dispose();
  }

  double get _avg =>
      _reviews.isEmpty ? widget.poster.rating : avgRating(_reviews);

  @override
  Widget build(BuildContext context) {
    final offerOk = widget.allowOffer || widget.alreadyOffered;
    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: offerOk
            ? widget.ctaLabel
            : 'Bu ilan için rolünüz uygun değil',
        alreadyOffered: widget.alreadyOffered,
        enabled: offerOk,
        onTap: () {
          widget.onClose();
          widget.onKrediTap();
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarButton(
                    label: widget.poster.publicListingAvatar,
                    color: widget.poster.avatarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      L10nText(widget.poster.publicListingLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Row(children: [
                        StarRow(rating: _avg, size: 13),
                        const SizedBox(width: 4),
                        L10nText(
                            '${_avg.toStringAsFixed(1)} (${_reviews.length} uzman yorumu)',
                            style: const TextStyle(fontSize: 12)),
                      ]),
                      Wrap(
                          spacing: 4,
                          children: widget.poster.tags
                              .map((t) => _Chip(text: t))
                              .toList()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.poster.bio,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            _RatingBreakdown(reviews: _reviews),
            const SizedBox(height: 16),
            _ReviewSection(
              reviews: _reviews,
              yorumYaz: _yorumYaz,
              submitted: _submitted,
              myRating: _myRating,
              myText: _myText,
              canWrite: widget.canWriteReview,
              onToggleYorum: () => setState(() => _yorumYaz = !_yorumYaz),
              onRating: (r) => setState(() => _myRating = r),
              onSubmit: () {
                if (_myRating == 0 || _myText.text.trim().isEmpty) return;
                final text = _myText.text.trim();
                final rating = _myRating;
                setState(() {
                  _reviews.insert(
                      0,
                      IlanReview(
                        author: 'Sen',
                        avatar: 'BN',
                        avatarColor: MetoColors.primary,
                        rating: rating,
                        date: 'Az önce',
                        text: text,
                      ));
                  _submitted = true;
                  _yorumYaz = false;
                  _myText.clear();
                  _myRating = 0;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _UzmanDrawer extends StatefulWidget {
  const _UzmanDrawer({
    required this.ilan,
    required this.onClose,
    required this.onKrediTap,
    required this.onProfile,
    this.alreadyOffered = false,
    this.ctaLabel = '1 Puan Harca — Teklif Ver',
    this.onEdit,
    this.onDelete,
    this.onChangeCategory,
    this.allowOffer = true,
    this.canWriteReview = true,
  });
  final UzmanIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  final String ctaLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCategory;
  final bool allowOffer;
  final bool canWriteReview;
  @override
  State<_UzmanDrawer> createState() => _UzmanDrawerState();
}

class _UzmanDrawerState extends State<_UzmanDrawer> {
  int _tab = 0;
  int _photoIndex = 0;
  late List<IlanReview> _reviews = List.of(widget.ilan.poster.reviews);
  bool _yorumYaz = false;
  int _myRating = 0;
  final _myText = TextEditingController();

  @override
  void dispose() {
    _myText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renk = uzmanRenkFor(widget.ilan.uzmanlik);
    final cv = posterCvFor(widget.ilan.poster);
    final avgR = avgRating(_reviews);
    final ilan = widget.ilan;
    final photos = ilan.photos;
    final offerOk = widget.allowOffer || widget.alreadyOffered;

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.alreadyOffered
            ? 'Teklif Verildi — Mesaja Git'
            : (offerOk
                ? widget.ctaLabel
                : 'Bu ilan için rolünüz uygun değil'),
        color: renk.color,
        alreadyOffered: widget.alreadyOffered,
        enabled: offerOk,
        onTap: () {
          widget.onClose();
          widget.onKrediTap();
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Builder(builder: (context) {
                    final idx = _photoIndex.clamp(0, photos.length - 1);
                    final current = photos[idx];
                    return GestureDetector(
                      onTap: () => _openIlanPhotoGallery(
                        context,
                        photos,
                        index: idx,
                      ),
                      child: Container(
                        color: current.swatchColor,
                        alignment: Alignment.center,
                        child: current.hasImage
                            ? FillPhoto(
                                source: current.dataUrl,
                                placeholder: Text(renk.emoji,
                                    style: const TextStyle(fontSize: 64)),
                              )
                            : Text(renk.emoji,
                                style: const TextStyle(fontSize: 64)),
                      ),
                    );
                  }),
                ),
              ),
              if (photos.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = photos[i];
                      final selected = i == _photoIndex.clamp(0, photos.length - 1);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _photoIndex = i);
                          _openIlanPhotoGallery(context, photos, index: i);
                        },
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(
                            color: p.swatchColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? MetoColors.primary
                                  : MetoColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: p.hasImage
                              ? FillPhoto(source: p.dataUrl)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: L10nText(
                    ilan.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    tooltip: S.auto('Düzenle'),
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: MetoColors.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onChangeCategory != null)
                  IconButton(
                    tooltip: 'Admin: kategori değiştir',
                    onPressed: widget.onChangeCategory,
                    icon: const Icon(
                      Icons.drive_file_move_outline,
                      size: 20,
                      color: Color(0xFF7C3AED),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: S.auto('Sil'),
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _Badge(
              text: '${renk.emoji} ${ilan.uzmanlik}',
              bg: renk.bg,
              fg: renk.color,
            ),
            const SizedBox(height: 10),
            Text(
              formatPriceTl(ilan.budget),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: renk.color,
              ),
            ),
            const SizedBox(height: 10),
            _MetaRow(items: [
              '📍 ${ilan.district}, ${ilan.city}',
              '📅 ${ilan.frequency}',
              '👁 ${ilanViewLabel(ilan.views)}',
              ilan.posted,
            ]),
            if (widget.onEdit != null) ...[
              const SizedBox(height: 10),
              _OwnerViewsBanner(count: ilan.views),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(text: ilan.tani),
                _Chip(text: ilan.age),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const L10nText(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  L10nText(
                    ilan.note,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MetoColors.mutedFg,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  _AvatarButton(
                    label: ilan.poster.publicListingAvatar,
                    color: ilan.poster.avatarColor,
                    onTap: widget.onProfile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          ilan.poster.publicListingLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: MetoColors.primary,
                          ),
                        ),
                        Row(children: [
                          StarRow(rating: avgR, size: 12),
                          L10nText(
                            ' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]),
                        const L10nText(
                          'İlan sahibi profilini gör',
                          style: TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_up,
                      color: MetoColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _TabBtn(
                        label: '👤 Profil',
                        selected: _tab == 0,
                        color: renk.color,
                        onTap: () => setState(() => _tab = 0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _TabBtn(
                        label: '📄 Özgeçmiş',
                        selected: _tab == 1,
                        color: renk.color,
                        onTap: () => setState(() => _tab = 1))),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              Wrap(
                  spacing: 8,
                  children: widget.ilan.poster.tags
                      .map((t) => _Badge(text: t, bg: renk.bg, fg: renk.color))
                      .toList()),
              const SizedBox(height: 12),
              Text(widget.ilan.poster.bio,
                  style: const TextStyle(
                      fontSize: 14, color: MetoColors.mutedFg, height: 1.5)),
              const SizedBox(height: 16),
              _RatingBreakdown(reviews: _reviews),
              const SizedBox(height: 12),
              _ReviewSection(
                reviews: _reviews,
                yorumYaz: _yorumYaz,
                submitted: false,
                myRating: _myRating,
                myText: _myText,
                canWrite: widget.canWriteReview,
                onToggleYorum: () => setState(() => _yorumYaz = !_yorumYaz),
                onRating: (r) => setState(() => _myRating = r),
                onSubmit: () {
                if (_myRating == 0 || _myText.text.trim().isEmpty) return;
                final text = _myText.text.trim();
                final rating = _myRating;
                final owner =
                    (ilanOwnerById[widget.ilan.id] ?? '').trim().toLowerCase();
                setState(() {
                  _reviews.insert(
                      0,
                      IlanReview(
                          author: 'Sen',
                          avatar: 'BN',
                          avatarColor: MetoColors.primary,
                          rating: rating,
                          date: 'Az önce',
                          text: text));
                  _yorumYaz = false;
                  _myText.clear();
                  _myRating = 0;
                });
                if (owner.isNotEmpty) {
                  unawaited(notifyIlanYorum(
                    ownerEmail: owner,
                    actorName: 'Bir kullanıcı',
                    ilanTitle: widget.ilan.title,
                    reviewText: text,
                    ilanId: widget.ilan.id,
                    rating: rating,
                  ));
                }
              },
              ),
            ] else ...[
              ..._cvSection(cv, color: renk.color),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BakiciDrawer extends StatefulWidget {
  const _BakiciDrawer({
    required this.ilan,
    required this.onClose,
    required this.onKrediTap,
    required this.onProfile,
    this.alreadyOffered = false,
    this.ctaLabel = '1 Puan Harca — Teklif Ver & Sohbet Aç',
    this.onEdit,
    this.onDelete,
    this.onChangeCategory,
    this.allowOffer = true,
    this.canWriteReview = true,
  });
  final BakiciIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  final String ctaLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCategory;
  final bool allowOffer;
  final bool canWriteReview;
  @override
  State<_BakiciDrawer> createState() => _BakiciDrawerState();
}

class _BakiciDrawerState extends State<_BakiciDrawer> {
  int _tab = 0;
  int _photoIndex = 0;
  late List<IlanReview> _reviews = List.of(widget.ilan.poster.reviews);
  bool _yorumYaz = false;
  int _myRating = 0;
  final _myText = TextEditingController();

  @override
  void dispose() {
    _myText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cv = posterCvFor(widget.ilan.poster);
    final avgR = avgRating(_reviews);
    final ilan = widget.ilan;
    final photos = ilan.photos;
    final offerOk = widget.allowOffer || widget.alreadyOffered;

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.alreadyOffered
            ? 'Teklif Verildi — Mesaja Git'
            : (offerOk ? widget.ctaLabel : 'Bu ilan için rolünüz uygun değil'),
        alreadyOffered: widget.alreadyOffered,
        enabled: offerOk,
        onTap: () {
          widget.onClose();
          widget.onKrediTap();
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Builder(builder: (context) {
                    final idx = _photoIndex.clamp(0, photos.length - 1);
                    final current = photos[idx];
                    return GestureDetector(
                      onTap: () => _openIlanPhotoGallery(
                        context,
                        photos,
                        index: idx,
                      ),
                      child: Container(
                        color: current.swatchColor,
                        alignment: Alignment.center,
                        child: current.hasImage
                            ? FillPhoto(
                                source: current.dataUrl,
                                placeholder: const L10nText('🤝',
                                    style: TextStyle(fontSize: 64)),
                              )
                            : const L10nText('🤝',
                                style: TextStyle(fontSize: 64)),
                      ),
                    );
                  }),
                ),
              ),
              if (photos.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = photos[i];
                      final selected =
                          i == _photoIndex.clamp(0, photos.length - 1);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _photoIndex = i);
                          _openIlanPhotoGallery(context, photos, index: i);
                        },
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(
                            color: p.swatchColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? MetoColors.primary
                                  : MetoColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: p.hasImage
                              ? FillPhoto(source: p.dataUrl)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: L10nText(
                    ilan.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    tooltip: S.auto('Düzenle'),
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: MetoColors.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onChangeCategory != null)
                  IconButton(
                    tooltip: 'Admin: kategori değiştir',
                    onPressed: widget.onChangeCategory,
                    icon: const Icon(
                      Icons.drive_file_move_outline,
                      size: 20,
                      color: Color(0xFF7C3AED),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: S.auto('Sil'),
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const _Badge(
              text: '🤝 Bakıcı/Temizlik Görevlisi Aranıyor',
              bg: Color(0xFFEFF6FF),
              fg: Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 10),
            Text(
              formatPriceTl(ilan.budget),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: MetoColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            _MetaRow(items: [
              '📍 ${ilan.district}, ${ilan.city}',
              '📅 ${ilan.hours}',
              '👁 ${ilanViewLabel(ilan.views)}',
              ilan.posted,
            ]),
            if (widget.onEdit != null) ...[
              const SizedBox(height: 10),
              _OwnerViewsBanner(count: ilan.views),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(text: ilan.tani),
                _Chip(text: ilan.age),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const L10nText(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  L10nText(
                    ilan.note,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MetoColors.mutedFg,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  _AvatarButton(
                    label: ilan.poster.publicListingAvatar,
                    color: ilan.poster.avatarColor,
                    onTap: widget.onProfile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          ilan.poster.publicListingLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: MetoColors.primary,
                          ),
                        ),
                        Row(children: [
                          StarRow(rating: avgR, size: 12),
                          L10nText(
                            ' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]),
                        const L10nText(
                          'İlan sahibi profilini gör',
                          style: TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_up,
                      color: MetoColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _TabBtn(
                        label: '👤 Profil',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _TabBtn(
                        label: '📄 Özgeçmiş',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1))),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              Wrap(
                  spacing: 8,
                  children: widget.ilan.poster.tags
                      .map((t) => _Chip(text: t))
                      .toList()),
              const SizedBox(height: 12),
              Text(widget.ilan.poster.bio,
                  style: const TextStyle(
                      fontSize: 14, color: MetoColors.mutedFg, height: 1.5)),
              const SizedBox(height: 16),
              _RatingBreakdown(reviews: _reviews),
              const SizedBox(height: 12),
              _ReviewSection(
                reviews: _reviews,
                yorumYaz: _yorumYaz,
                submitted: false,
                myRating: _myRating,
                myText: _myText,
                canWrite: widget.canWriteReview,
                onToggleYorum: () => setState(() => _yorumYaz = !_yorumYaz),
                onRating: (r) => setState(() => _myRating = r),
                onSubmit: () {
                if (_myRating == 0 || _myText.text.trim().isEmpty) return;
                final text = _myText.text.trim();
                final rating = _myRating;
                final owner =
                    (ilanOwnerById[widget.ilan.id] ?? '').trim().toLowerCase();
                setState(() {
                  _reviews.insert(
                      0,
                      IlanReview(
                          author: 'Sen',
                          avatar: 'BN',
                          avatarColor: MetoColors.primary,
                          rating: rating,
                          date: 'Az önce',
                          text: text));
                  _yorumYaz = false;
                  _myText.clear();
                  _myRating = 0;
                });
                if (owner.isNotEmpty) {
                  unawaited(notifyIlanYorum(
                    ownerEmail: owner,
                    actorName: 'Bir kullanıcı',
                    ilanTitle: widget.ilan.title,
                    reviewText: text,
                    ilanId: widget.ilan.id,
                    rating: rating,
                  ));
                }
              },
              ),
            ] else ...[
              ..._cvSection(cv),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _IkincielDrawer extends StatefulWidget {
  const _IkincielDrawer({
    required this.ilan,
    required this.onClose,
    required this.onKrediTap,
    required this.onProfile,
    this.alreadyOffered = false,
    this.onEdit,
    this.onDelete,
    this.onChangeCategory,
  });

  final IkincielIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCategory;

  @override
  State<_IkincielDrawer> createState() => _IkincielDrawerState();
}

class _IkincielDrawerState extends State<_IkincielDrawer> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ilan = widget.ilan;
    final photos = ilan.photos.isEmpty
        ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
        : ilan.photos;
    final idx = _photoIndex.clamp(0, photos.length - 1);
    final current = photos[idx];

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.alreadyOffered
            ? 'Teklif Verildi — Mesaja Git'
            : 'Ücretsiz İletişim',
        alreadyOffered: widget.alreadyOffered,
        onTap: () {
          widget.onClose();
          widget.onKrediTap();
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: GestureDetector(
                  onTap: () => _openIlanPhotoGallery(
                    context,
                    photos,
                    index: idx,
                  ),
                  child: Container(
                    color: current.swatchColor,
                    alignment: Alignment.center,
                    child: current.hasImage
                        ? FillPhoto(
                            source: current.dataUrl,
                            placeholder: Text(ilan.emoji,
                                style: const TextStyle(fontSize: 64)),
                          )
                        : Text(ilan.emoji,
                            style: const TextStyle(fontSize: 64)),
                  ),
                ),
              ),
            ),
            if (photos.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final p = photos[i];
                    final selected = i == idx;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _photoIndex = i);
                        _openIlanPhotoGallery(context, photos, index: i);
                      },
                      child: Container(
                        width: 56,
                        decoration: BoxDecoration(
                          color: p.swatchColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? MetoColors.primary
                                : MetoColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: p.hasImage
                            ? FillPhoto(source: p.dataUrl)
                            : Text(ilan.emoji,
                                style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: L10nText(
                    ilan.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (widget.onEdit != null)
                  IconButton(
                    tooltip: S.auto('Düzenle'),
                    onPressed: widget.onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: MetoColors.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onChangeCategory != null)
                  IconButton(
                    tooltip: 'Admin: kategori değiştir',
                    onPressed: widget.onChangeCategory,
                    icon: const Icon(
                      Icons.drive_file_move_outline,
                      size: 20,
                      color: Color(0xFF7C3AED),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: S.auto('Sil'),
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                _Badge(
                  text: ilan.condition,
                  bg: ikincielDurumRenk(ilan.condition).bg,
                  fg: ikincielDurumRenk(ilan.condition).fg,
                ),
              ],
            ),
            const SizedBox(height: 4),
            L10nText(
              '${ilan.brand} · ${ikincielAltDisplayLabel(ilan.category)}',
              style: const TextStyle(fontSize: 13, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 10),
            Text(
              formatPriceTl(ilan.price),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: MetoColors.primary,
              ),
            ),
            if (ilan.originalPrice.trim().isNotEmpty)
              Text(
                formatPriceTl(ilan.originalPrice),
                style: const TextStyle(
                  fontSize: 13,
                  color: MetoColors.mutedFg,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            const SizedBox(height: 12),
            _MetaRow(items: [
              '📍 ${ilan.district}, ${ilan.city}',
              '👁 ${ilanViewLabel(ilan.views)}',
              ilan.posted,
            ]),
            if (widget.onEdit != null) ...[
              const SizedBox(height: 10),
              _OwnerViewsBanner(count: ilan.views),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const L10nText(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  L10nText(
                    ilan.note,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MetoColors.mutedFg,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  _SmallAvatar(
                    label: ilan.poster.publicListingAvatar,
                    color: ilan.poster.avatarColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          ilan.poster.publicListingLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const L10nText(
                          'Satıcı profilini gör',
                          style: TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: MetoColors.mutedFg),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? MetoColors.primary;
    return Material(
      color: selected ? c : MetoColors.muted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : MetoColors.mutedFg)),
          ),
        ),
      ),
    );
  }
}

class _CvBlock extends StatelessWidget {
  const _CvBlock({required this.title, required this.body, this.color});
  final String title;
  final String body;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color ?? MetoColors.primary)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 12, color: MetoColors.mutedFg, height: 1.5)),
        ],
      ),
    );
  }
}

List<Widget> _cvSection(PosterCv cv, {Color? color}) {
  if (!cv.hasContent) {
    return const [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Özgeçmiş henüz doldurulmamış.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
          ),
        ),
      ),
    ];
  }

  final blocks = <Widget>[];
  if (cv.egitimText.isNotEmpty) {
    blocks.add(_CvBlock(
      title: '📚 Eğitim',
      body: cv.egitimText,
      color: color,
    ));
  }
  if (cv.deneyimText.isNotEmpty) {
    blocks.add(_CvBlock(
      title: '💼 Deneyim',
      body: cv.deneyimText,
      color: color,
    ));
  }
  if (cv.sertifikalarText.isNotEmpty) {
    blocks.add(_CvBlock(
      title: '🛡 Sertifikalar',
      body: cv.sertifikalarText,
      color: color,
    ));
  }
  if (cv.hakkimda.trim().isNotEmpty) {
    blocks.add(_CvBlock(
      title: 'Hakkında',
      body: cv.hakkimda.trim(),
      color: color,
    ));
  }
  return blocks;
}

class SohbetPage extends StatefulWidget {
  const SohbetPage({
    super.key,
    required this.kisi,
    required this.myEmail,
    this.myDisplayName = '',
    this.sohbetKey,
    this.onNewMessage,
  });

  final SohbetKisi kisi;
  final String myEmail;
  /// Karşı tarafa bildirimde gösterilecek ad (e-posta değil).
  final String myDisplayName;
  /// Admin moderasyonunda gerçek sohbet anahtarı (iki başka kullanıcı).
  final String? sohbetKey;
  final ValueChanged<String>? onNewMessage;

  @override
  State<SohbetPage> createState() => _SohbetPageState();
}

class _SohbetPageState extends State<SohbetPage> {
  final _messages = <SohbetMesaj>[];
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool _peerOnline = false;
  String? _error;
  Timer? _poll;
  RealtimeChannel? _realtime;
  late String _headerName;

  String get _me => widget.myEmail.trim().toLowerCase();
  String get _peer => widget.kisi.peerEmail.trim().toLowerCase();
  bool get _isAdmin => isAppAdmin(_me);
  String get _key {
    final override = widget.sohbetKey?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return sohbetKeyFor(_me, _peer);
  }

  bool get _isParticipant {
    final parts = _key.split('|');
    return parts.any((p) => p.trim().toLowerCase() == _me);
  }

  bool get _canSend => _isParticipant && _peer.isNotEmpty && !_peer.contains('↔');

  @override
  void initState() {
    super.initState();
    _peerOnline = widget.kisi.isOnline;
    _headerName = chatPeerLabel(
      widget.kisi.peerEmail,
      listingName: widget.kisi.ad,
    );
    _load(initial: true);
    unawaited(_refreshPeerOnline());
    unawaited(_resolvePeerName());
    unawaited(touchMyPresence());
    if (_key.isNotEmpty) {
      _realtime = subscribeSohbetMesajlari(
        sohbetKey: _key,
        onChange: () {
          if (mounted) unawaited(_load());
        },
      );
    }
    // Presence + Realtime yedek
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_refreshPeerOnline());
      unawaited(touchMyPresence());
    });
  }

  Future<void> _resolvePeerName() async {
    if (_peer.isEmpty || !_peer.contains('@')) return;
    final names = await loadUserDisplayNamesByEmail([_peer]);
    final next = chatPeerLabel(
      _peer,
      profileName: names[_peer],
      listingName: widget.kisi.ad,
    );
    if (!mounted || next == _headerName) return;
    setState(() => _headerName = next);
  }

  Future<void> _refreshPeerOnline() async {
    if (_peer.isEmpty || !_peer.contains('@')) {
      if (mounted && _peerOnline) setState(() => _peerOnline = false);
      return;
    }
    final online = await isEmailOnline(_peer);
    if (!mounted || online == _peerOnline) return;
    setState(() => _peerOnline = online);
  }

  Future<void> _markIncomingRead() async {
    if (!_canSend) return;
    await markSohbetMesajlariOkundu(_key);
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(unsubscribeRealtime(_realtime));
    _realtime = null;
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_key.isEmpty || (!_isParticipant && !_isAdmin)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Karşı taraf gerçek bir kullanıcı değil (örnek ilan).';
        });
      }
      return;
    }
    if (!_isAdmin && (_peer.isEmpty || _me.isEmpty)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Karşı taraf gerçek bir kullanıcı değil (örnek ilan).';
        });
      }
      return;
    }
    try {
      final list = await loadSohbetMesajlari(_key);
      if (!mounted) return;
      final grew = list.length > _messages.length;
      final hasUnreadIncoming =
          list.any((m) => m.receiverEmail == _me && !m.isRead);
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
        _error = null;
      });
      if (initial || hasUnreadIncoming) {
        await _markIncomingRead();
      }
      if (initial || grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('sohbet_mesajlari') ||
                e.toString().contains('PGRST')
            ? 'Sohbet tablosu yok. Supabase’de sohbet_mesajlari.sql çalıştırın.'
            : 'Mesajlar yüklenemedi';
      });
    }
  }

  Future<void> _gonder() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _sending || !_canSend) return;
    setState(() => _sending = true);
    try {
      final msg = await sendSohbetMesaj(peerEmail: _peer, body: text);
      // Mesaj kaydı başarılıysa karşı tarafa uygulama içi bildirim.
      try {
        await notifySohbetMesaj(
          peerEmail: _peer,
          messageBody: text,
          actorName: widget.myDisplayName,
          ilanId: widget.kisi.ilanId,
        );
      } catch (_) {
        // Mesaj gitti; bildirim tablosu yoksa sessiz geç
      }
      if (!mounted) return;
      _draft.clear();
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
        }
        _sending = false;
      });
      widget.onNewMessage?.call(text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('sohbet_mesajlari') ||
                    e.toString().contains('schema cache')
                ? 'Sohbet tablosu henüz yok. sohbet_mesajlari.sql çalıştırın.'
                : 'Gönderilemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _silMesaj(SohbetMesaj m) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Mesajı sil'),
        content: const L10nText('Bu mesaj kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await deleteSohbetMesaj(m.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((x) => x.id == m.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Mesaj silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('policy') || e.toString().contains('42501')
                ? 'Silme yetkisi yok. Supabase’de sohbet_mesajlari_delete.sql çalıştırın.'
                : 'Silinemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _silSohbet() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Sohbeti sil'),
        content: L10nText(
          '$_headerName ile olan tüm mesajlar silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const L10nText('Tümünü sil'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await deleteSohbet(_key);
      if (!mounted) return;
      setState(() => _messages.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Sohbet silindi')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('policy') || e.toString().contains('42501')
                ? 'Silme yetkisi yok. Supabase’de sohbet_mesajlari_delete.sql çalıştırın.'
                : 'Sohbet silinemedi: $e',
          ),
        ),
      );
    }
  }

  void _mesajMenu(SohbetMesaj m, bool ben) {
    final canDelete = ben || _isAdmin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                scrubEmailsInText(m.body),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: MetoColors.mutedFg),
              ),
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: Text(
                  _isAdmin && !ben ? 'Mesajı sil (Admin)' : 'Mesajı sil',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _silMesaj(m);
                },
              )
            else
              const Padding(
                padding: EdgeInsets.all(20),
                child: L10nText(
                  'Karşı tarafın mesajını silemezsiniz. Tüm sohbeti silmek için üstteki menüyü kullanın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0.5,
        title: Row(
          children: [
            Stack(
              children: [
                _SmallAvatar(
                    label: widget.kisi.avatar, color: widget.kisi.avatarColor),
                Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: _peerOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: MetoColors.card, width: 2)))),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_headerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    _peer.isEmpty
                        ? 'Örnek ilan'
                        : (_peerOnline ? 'Çevrimiçi' : 'Çevrimdışı'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _peerOnline
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_peer.isNotEmpty && _peer.contains('@'))
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'sil') {
                  _silSohbet();
                } else if (v == 'guvenlik') {
                  showUserSafetySheet(
                    context,
                    targetEmail: _peer,
                    targetDisplayName: _headerName,
                    contextLabel: 'sohbet',
                    onBlocked: () {
                      if (mounted) Navigator.of(context).maybePop();
                    },
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'guvenlik',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 20),
                      SizedBox(width: 8),
                      L10nText('Şikayet / Engelle'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sil',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 8),
                      L10nText('Sohbeti sil',
                          style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: MetoColors.primary))
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: MetoColors.muted.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(
                              _isAdmin && !_isParticipant
                                  ? 'Admin moderasyon · basılı tutarak mesaj silin'
                                  : _peer.isEmpty
                                      ? 'Örnek ilan — bot cevap kapalı'
                                      : 'Gerçek sohbet · basılı tutarak mesaj silin',
                              style: const TextStyle(
                                  fontSize: 10, color: MetoColors.mutedFg)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFB45309))),
                      ],
                      const SizedBox(height: 12),
                      if (_messages.isEmpty && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _isAdmin && !_isParticipant
                                ? 'Bu sohbette henüz mesaj yok.'
                                : 'Henüz mesaj yok. İlk mesajı siz yazın — karşı taraf kendi hesabından görür.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: MetoColors.mutedFg),
                          ),
                        ),
                      ..._messages.map((m) {
                        final ben = m.senderEmail == _me;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: ben
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!ben) ...[
                                _SmallAvatar(
                                    label: widget.kisi.avatar,
                                    color: widget.kisi.avatarColor),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: GestureDetector(
                                  onLongPress: () => _mesajMenu(m, ben),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: ben
                                          ? MetoColors.primary
                                          : MetoColors.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: ben
                                          ? null
                                          : Border.all(color: MetoColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(scrubEmailsInText(m.body),
                                            style: TextStyle(
                                                color: ben
                                                    ? Colors.white
                                                    : MetoColors.foreground)),
                                        Text(m.timeLabel,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: ben
                                                    ? Colors.white70
                                                    : MetoColors.mutedFg)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
          Container(
            color: MetoColors.card,
            child: SafeArea(
              top: false,
              // Klavye açıkken SafeArea alt padding'i ekleme (çift boşluk)
              bottom: !keyboardOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: !_canSend
                    ? Text(
                        _isAdmin
                            ? 'Admin: mesajları basılı tutarak silebilirsiniz (gönderim kapalı).'
                            : 'Bu sohbette mesaj gönderilemez.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MetoColors.mutedFg,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _draft,
                              enabled: true,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: S.auto('Mesaj yaz…'),
                                filled: true,
                                fillColor: MetoColors.muted,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              onTap: () {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!_scroll.hasClients) return;
                                  _scroll.animateTo(
                                    _scroll.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sending ? null : _gonder,
                            style: IconButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IlanEditDraft {
  const _IlanEditDraft({
    required this.id,
    required this.kind,
    required this.title,
    required this.city,
    required this.district,
    required this.note,
    required this.budgetOrPrice,
    this.countryCode = 'TR',
    this.uzmanlik = 'Uzman',
    this.condition = 'İyi',
    this.category = kIkincielAltDiger,
    this.photos = const [],
  });

  final int id;
  final String kind;
  final String title;
  final String city;
  final String district;
  final String countryCode;
  final String note;
  final String budgetOrPrice;
  final String uzmanlik;
  final String condition;
  final String category;
  final List<IlanPhoto> photos;
}

class _YeniIlanForm extends StatefulWidget {
  const _YeniIlanForm({
    required this.onBack,
    required this.onPublished,
    this.userName = 'Siz',
    this.userEmail = '',
    this.userType = 'aile',
    this.profilFoto,
    this.editDraft,
  });
  final VoidCallback onBack;
  final ValueChanged<IlanKategori> onPublished;
  final String userName;
  final String userEmail;
  final String userType;
  final String? profilFoto;
  final _IlanEditDraft? editDraft;
  @override
  State<_YeniIlanForm> createState() => _YeniIlanFormState();
}

class _YeniIlanFormState extends State<_YeniIlanForm> {
  String _formKategori = 'Uzman Arıyorum';
  String _formUzmanlik = CatalogAdapters.uzmanlikSecenekleri().first;
  String _formCondition = 'İyi';
  String _formAltKategori = kIkincielAltMedikal;
  final List<IlanPhoto> _formPhotos = [];
  /// Anlık önizleme (URL açılmasa bile formda görünsün).
  final List<Uint8List?> _formPhotoBytes = [];
  final _formBaslik = TextEditingController();
  final _formButce = TextEditingController();
  final _formAciklama = TextEditingController();
  String _aciklamaUyari = '';
  String _baslikUyari = '';
  late LocationData _formLoc = LocationData(
    countryCode: countryCodeForLang(LocaleController.instance.lang),
  );
  bool _pickingPhoto = false;

  bool get _isAdmin => isAppAdmin(widget.userEmail);
  bool get _canPostListing =>
      _isAdmin || normalizedUserType(widget.userType) == 'aile';
  bool get _profNeedsRoleSwitch =>
      !_isAdmin && isProfUserType(widget.userType);
  bool get _isEditing => widget.editDraft != null;
  String get _formKind => CatalogAdapters.ilanKindForFormValue(_formKategori);
  bool get _isIkinciel => _formKind == 'ikinciel';
  bool get _isUzmanArama => _formKind == 'uzman';
  bool get _isBakiciArama => _formKind == 'bakici';
  bool get _isUzmanOrBakici => _isUzmanArama || _isBakiciArama;
  /// Uzman / bakıcı: en fazla 2; 2. el: en fazla 4.
  int get _maxPhotos =>
      _isUzmanOrBakici ? kUzmanBakiciMaxPhotos : 4;
  bool get _showPhotoPicker => _isIkinciel || _isUzmanOrBakici;

  @override
  void initState() {
    super.initState();
    final d = widget.editDraft;
    if (d == null) return;
    _formKategori = switch (d.kind) {
      'bakici' => 'Bakıcı/Temizlik Görevlisi Arıyorum',
      'ikinciel' => '2. El Alet',
      _ => isIlanIsAriyorum(d.category)
          ? kIlanCatIsAriyorum
          : 'Uzman Arıyorum',
    };
    _formBaslik.text = d.title;
    _formButce.text = priceInputDigits(d.budgetOrPrice);
    _formAciklama.text = d.note;
    _formLoc = LocationData.fromLegacy(
      city: d.city,
      district: d.district,
      countryCode: d.countryCode,
    );
    if (d.uzmanlik.isNotEmpty) {
      final opts = CatalogAdapters.uzmanlikSecenekleri();
      _formUzmanlik = opts.contains(d.uzmanlik) ? d.uzmanlik : opts.first;
    }
    if (kIkincielDurumSecenekleri.contains(d.condition)) {
      _formCondition = d.condition;
    } else if (d.condition.trim().isNotEmpty) {
      // Eski değerleri en yakın seçeneğe eşle
      final lower = d.condition.trim().toLowerCase();
      if (lower.contains('sıfır') || lower.contains('sifir')) {
        _formCondition = 'Sıfır ürün';
      } else if (lower.contains('az')) {
        _formCondition = 'Az kullanılmış';
      } else if (lower.contains('kötü') || lower.contains('kotu')) {
        _formCondition = 'Kötü';
      } else if (lower.contains('çok')) {
        _formCondition = 'İyi';
      } else {
        _formCondition = 'İyi';
      }
    }
    _formAltKategori = ikincielAltKategoriOf(
      d.category,
      extras: CatalogAdapters.ikincielCustomAlts(),
    );
    _formPhotos.addAll(d.photos);
    _formPhotoBytes.addAll(List<Uint8List?>.filled(d.photos.length, null));
  }

  @override
  void dispose() {
    _formBaslik.dispose();
    _formButce.dispose();
    _formAciklama.dispose();
    super.dispose();
  }

  bool _publishing = false;

  Future<void> _publish() async {
    if (_publishing) return;
    if (_pickingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: L10nText('Fotoğraf yükleniyor, lütfen biraz bekleyin.')),
      );
      return;
    }
    // Optimistic önizleme / yarım kalmış yükleme kontrolü
    final pending = _formPhotos.any((p) => !p.hasImage);
    if (pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: L10nText(
                'Fotoğraf henüz yüklenmedi. Birkaç saniye bekleyip tekrar deneyin.')),
      );
      return;
    }

    final baslik = scrubIlanListingText(_formBaslik.text.trim());
    final butce = formatPriceTl(_formButce.text.trim());
    final aciklama = scrubIlanListingText(_formAciklama.text.trim());
    final loc = _formLoc;
    final cityName = loc.legacyCity;
    final districtName = loc.legacyDistrict;

    final eksik = <String>[];
    if (baslik.isEmpty) eksik.add('Başlık');
    if (loc.countryCode.isEmpty) eksik.add('Ülke');
    if (cityName.isEmpty) eksik.add('Bölge / İl');
    if (districtName.isEmpty) eksik.add('Şehir / İlçe');
    if (butce.isEmpty) {
      eksik.add(_isIkinciel ? 'Fiyat' : 'Bütçe');
    }
    if (eksik.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Lütfen doldurun: ${eksik.join(', ')}')),
      );
      return;
    }

    final name =
        widget.userName.trim().isEmpty ? 'Siz' : widget.userName.trim();
    final photo = (widget.profilFoto ?? '').trim();
    final avatar = isAvatarImageSource(photo)
        ? photo
        : listingPublicAvatar('', displayName: name);
    final note = aciklama.isEmpty ? '—' : aciklama;
    final email = widget.userEmail.trim();
    final edit = widget.editDraft;

    if (edit == null && !_canPostListing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profNeedsRoleSwitch
                ? 'İlan paylaşmak için hesap rolünüzü Aile olarak değiştirmeniz gerekir. '
                    'Menü → Hesap rolü bölümünden rolünüzü değiştirebilirsiniz.'
                : 'İlan paylaşmak için Aile rolü gerekir.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (edit == null && !await ensureUgcTermsAccepted(context)) return;
    if (!mounted) return;
    if (containsBlockedContent('$baslik\n$note')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText(blockedContentMessage())),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      late final IlanKategori kategori;
      switch (_formKind) {
        case 'uzman':
          kategori = IlanKategori.uzmanlar;
          if (edit != null) {
            await updateIlanInCloud(
              id: edit.id,
              kind: 'uzman',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              budget: butce,
              uzmanlik: _formUzmanlik,
              category: _formKategori,
              photos: List<IlanPhoto>.from(
                _formPhotos.take(kUzmanBakiciMaxPhotos),
              ),
              ownerEmail: email,
            );
          } else {
            await publishIlanToCloud(
              kind: 'uzman',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              budget: butce,
              uzmanlik: _formUzmanlik,
              category: _formKategori,
              photos: List<IlanPhoto>.from(
                _formPhotos.take(kUzmanBakiciMaxPhotos),
              ),
              posterName: name,
              posterAvatar: avatar,
              ownerEmail: email,
            );
          }
          break;
        case 'bakici':
          kategori = IlanKategori.bakici;
          if (edit != null) {
            await updateIlanInCloud(
              id: edit.id,
              kind: 'bakici',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              budget: butce,
              photos: List<IlanPhoto>.from(
                _formPhotos.take(kUzmanBakiciMaxPhotos),
              ),
              ownerEmail: email,
            );
          } else {
            await publishIlanToCloud(
              kind: 'bakici',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              budget: butce,
              photos: List<IlanPhoto>.from(
                _formPhotos.take(kUzmanBakiciMaxPhotos),
              ),
              posterName: name,
              posterAvatar: avatar,
              ownerEmail: email,
            );
          }
          break;
        default:
          kategori = IlanKategori.ikinciel;
          if (edit != null) {
            await updateIlanInCloud(
              id: edit.id,
              kind: 'ikinciel',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              price: butce,
              condition: _formCondition,
              category: _formAltKategori,
              photos: _formPhotos.isEmpty
                  ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
                  : List<IlanPhoto>.from(_formPhotos),
              ownerEmail: email,
            );
          } else {
            await publishIlanToCloud(
              kind: 'ikinciel',
              title: baslik,
              city: cityName,
              district: districtName,
              location: loc,
              note: note,
              price: butce,
              condition: _formCondition,
              category: _formAltKategori,
              photos: _formPhotos.isEmpty
                  ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
                  : List<IlanPhoto>.from(_formPhotos),
              posterName: name,
              posterAvatar: avatar,
              ownerEmail: email,
            );
          }
      }
      if (!mounted) return;
      widget.onPublished(kategori);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (edit != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('ilanlar_update_own') || msg.contains('yetki')
                  ? 'Güncelleme yetkisi yok. Supabase’de ilanlar_update_own.sql çalıştırın.'
                  : 'İlan güncellenemedi: $e',
            ),
          ),
        );
      } else if (msg.contains('LOCAL_ILAN_SAVED:')) {
        // Yerel kayıt oldu; yine de yayınlandı say.
        widget.onPublished(
          _isUzmanArama
              ? IlanKategori.uzmanlar
              : _isBakiciArama
                  ? IlanKategori.bakici
                  : IlanKategori.ikinciel,
        );
        final detail = msg.contains('LOCAL_ILAN_SAVED:')
            ? msg.split('LOCAL_ILAN_SAVED:').last.replaceFirst('StateError: ', '')
            : formatIlanCloudError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(detail),
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (msg.contains('yetki hatası') ||
          msg.contains('Aile rol') ||
          msg.contains('ilanlar_ensure') ||
          msg.contains('şeması güncel') ||
          msg.contains('buluta kaydedilemedi')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatIlanCloudError(e)),
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (lower.contains('quota') ||
          lower.contains('ön bellek') ||
          lower.contains('localstorage') ||
          lower.contains('exceeded')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: L10nText(
              'Tarayıcı önbelleği dolu. Daha az/küçük fotoğrafla tekrar deneyin '
              'veya site verilerini temizleyip yenileyin.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: L10nText('İlan yayınlanamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _scrubListingField(TextEditingController controller, void Function(String) setWarning) {
    final val = controller.text;
    final cleaned = scrubIlanListingText(val);
    if (cleaned != val) {
      setWarning(
        'İletişim bilgileri (telefon/e-posta/link) ilanda görünmez — '
        'iletişim yalnızca uygulama üzerinden kurulur.',
      );
      controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    } else {
      setWarning('');
    }
  }

  void _handleAciklama(String val) {
    _scrubListingField(_formAciklama, (w) => setState(() => _aciklamaUyari = w));
  }

  void _handleBaslik(String val) {
    _scrubListingField(_formBaslik, (w) => setState(() => _baslikUyari = w));
  }

  ImageProvider? _formPhotoProviderAt(int index) {
    if (index >= 0 &&
        index < _formPhotoBytes.length &&
        _formPhotoBytes[index] != null &&
        _formPhotoBytes[index]!.isNotEmpty) {
      return MemoryImage(_formPhotoBytes[index]!);
    }
    if (index >= 0 && index < _formPhotos.length) {
      return _ilanPhotoProvider(_formPhotos[index]);
    }
    return null;
  }

  Future<void> _pickProductPhoto() async {
    if (_formPhotos.length >= _maxPhotos || _pickingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  _isIkinciel ? 'Ürün fotoğrafı ekle' : 'İlan fotoğrafı ekle',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: MetoColors.primary),
                title: const L10nText('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: MetoColors.primary),
                title: const L10nText('Kamerayla çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const L10nText('Vazgeç'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }

      final optimized = await ImageOptimizeService.forListing(raw);
      // Önce anlık önizleme (R2 beklemeden görünsün)
      if (!mounted) return;
      final previewIndex = _formPhotos.length;
      setState(() {
        _formPhotos.add(const IlanPhoto.swatch(Color(0xFFDCE8F5)));
        _formPhotoBytes.add(optimized.bytes);
      });

      final publicUrl = await R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: optimized.fileName,
        contentType: optimized.contentType,
      );

      if (!mounted) return;
      setState(() {
        if (previewIndex < _formPhotos.length) {
          _formPhotos[previewIndex] = IlanPhoto.data(publicUrl);
        }
      });
    } catch (e) {
      // Yükleme başarısızsa geçici önizlemeyi geri al
      if (mounted &&
          _formPhotoBytes.isNotEmpty &&
          _formPhotos.isNotEmpty &&
          (_formPhotos.last.dataUrl == null ||
              !(_formPhotos.last.dataUrl!.startsWith('http') ||
                  _formPhotos.last.dataUrl!.startsWith('data:')))) {
        setState(() {
          _formPhotos.removeLast();
          _formPhotoBytes.removeLast();
        });
      }
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Bad state: ', '');
      final msg = raw.toLowerCase();
      final friendly = msg.contains('giriş')
          ? 'Fotoğraf yüklemek için giriş yapın.'
          : (msg.contains('ilan_photos_storage') || msg.contains('bucket'))
              ? raw
              : (msg.contains('8 mb') ||
                      msg.contains('büyük') ||
                      msg.contains('boş') ||
                      msg.contains('okunamadı') ||
                      msg.contains('sıkıştır') ||
                      msg.contains('yüklen') ||
                      msg.contains('depolama'))
                  ? raw
                  : 'Fotoğraf eklenemedi. Galeri/kamera iznini ve interneti kontrol edin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Widget _adminAddBtn({
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    if (!_isAdmin) return const SizedBox.shrink();
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _adminRemoveBtn({
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    if (!_isAdmin) return const SizedBox.shrink();
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _adminCatalogBtns({
    required String addTooltip,
    required VoidCallback onAdd,
    required String removeTooltip,
    required VoidCallback onRemove,
  }) {
    if (!_isAdmin) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _adminRemoveBtn(tooltip: removeTooltip, onPressed: onRemove),
        _adminAddBtn(tooltip: addTooltip, onPressed: onAdd),
      ],
    );
  }

  Future<void> _removeCatalogOptionFlow({
    required String scope,
    required String title,
    required String successPrefix,
    void Function(String removed)? onRemoved,
  }) async {
    if (deletableCatalogOptions(scope).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinecek özel seçenek yok.')),
      );
      return;
    }
    final picked = await promptAdminRemoveOption(
      context: context,
      scope: scope,
      title: title,
    );
    if (picked == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçeneği kaldır'),
        content: Text(
          '"${picked.label}" listeden kaldırılsın mı?\n\n'
          'Sabit seçenekler silinemez. Mevcut ilanlar etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await deleteCatalogOption(
        scope: scope,
        label: picked.label,
        id: picked.id,
      );
      if (!mounted) return;
      setState(() => onRemoved?.call(picked.label));
      showCatalogDeleteSnackBar(
        context,
        result,
        successText: '$successPrefix "${picked.label}" kaldırıldı',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : '$e')),
      );
    }
  }

  Future<void> _removeIlanKategoriOption() async {
    await _removeCatalogOptionFlow(
      scope: 'ilan',
      title: 'Kaldırılacak ilan kategorisi',
      successPrefix: 'İlan kategorisi',
      onRemoved: (removed) {
        if (_formKategori.trim().toLowerCase() != removed.toLowerCase()) {
          return;
        }
        _formKategori = 'Uzman Arıyorum';
        _formPhotos.clear();
        _formPhotoBytes.clear();
      },
    );
  }

  Future<void> _removeUzmanlikOption() async {
    final opts = CatalogAdapters.uzmanlikSecenekleri();
    await _removeCatalogOptionFlow(
      scope: 'uzmanlik',
      title: 'Kaldırılacak uzmanlık alanı',
      successPrefix: 'Uzmanlık alanı',
      onRemoved: (removed) {
        if (_formUzmanlik.trim().toLowerCase() != removed.toLowerCase()) {
          return;
        }
        _formUzmanlik = opts.isNotEmpty ? opts.first : 'Fizyoterapist';
      },
    );
  }

  Future<void> _removeIkincielAltOption() async {
    final opts = CatalogAdapters.ikincielAltKategoriler();
    await _removeCatalogOptionFlow(
      scope: 'ikinciel',
      title: 'Kaldırılacak alt kategori',
      successPrefix: 'Alt kategori',
      onRemoved: (removed) {
        if (_formAltKategori.trim().toLowerCase() != removed.toLowerCase()) {
          return;
        }
        _formAltKategori = opts.isNotEmpty ? opts.first : kIkincielAltDiger;
      },
    );
  }

  Future<void> _addUzmanlikOption() async {
    final name = await promptAdminNewOption(
      context: context,
      title: 'Yeni uzmanlık alanı',
      hint: 'Örn. Müzik terapisti',
    );
    if (name == null || !mounted) return;
    final result = await upsertCatalogOption(
      scope: 'uzmanlik',
      label: name,
      icon: '👤',
    );
    if (!mounted) return;
    setState(() => _formUzmanlik = name);
    showCatalogUpsertSnackBar(
      context,
      result,
      successText: '"$name" uzmanlık alanlarına eklendi',
    );
  }

  Future<void> _addIlanKategoriOption() async {
    final added = await promptAdminNewIlanKategori(context);
    if (added == null || !mounted) return;
    final result = await upsertCatalogOption(
      scope: 'ilan',
      label: added.label,
      icon: added.kind == 'ikinciel'
          ? '♻️'
          : added.kind == 'bakici'
              ? '🤝'
              : '🏃',
      meta: {'kind': added.kind},
    );
    if (added.kind == 'ikinciel') {
      await upsertCatalogOption(
        scope: 'ikinciel',
        label: added.label,
        icon: '📦',
      );
    }
    if (!mounted) return;
    setState(() {
      _formKategori = added.label;
      _formPhotos.clear();
      _formPhotoBytes.clear();
      if (added.kind == 'ikinciel') {
        _formAltKategori = added.label;
      }
    });
    showCatalogUpsertSnackBar(
      context,
      result,
      successText: '"${added.label}" ilan kategorilerine eklendi',
    );
  }

  Future<void> _addIkincielAltOption() async {
    final name = await promptAdminNewOption(
      context: context,
      title: 'Yeni 2. el alt kategori',
      hint: 'Örn. Ortez / protez',
    );
    if (name == null || !mounted) return;
    final result = await upsertCatalogOption(
      scope: 'ikinciel',
      label: name,
      icon: '📦',
    );
    if (!mounted) return;
    setState(() => _formAltKategori = name);
    showCatalogUpsertSnackBar(
      context,
      result,
      successText: '"$name" alt kategorilere eklendi',
    );
  }

  Widget _formField(
    String label,
    String hint,
    TextEditingController c, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    ValueChanged<String>? onChanged,
    String? warning,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          TextField(
              controller: c,
              onChanged: onChanged,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                  hintText: hint,
                  suffixText: suffixText,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: MetoColors.card)),
          if (warning != null && warning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              warning,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppCatalogService.instance,
      builder: (context, _) {
        final kategoriOpts = CatalogAdapters.ilanFormKategorileri();
        final kategoriValues = {for (final o in kategoriOpts) o.value};
        final kategoriValue = kategoriValues.contains(_formKategori)
            ? _formKategori
            : 'Uzman Arıyorum';
        final uzmanOpts = CatalogAdapters.uzmanlikSecenekleri();
        final uzmanValue = uzmanOpts.contains(_formUzmanlik)
            ? _formUzmanlik
            : uzmanOpts.first;
        final ikincielAlts = CatalogAdapters.ikincielAltKategoriler();
        return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
              Text(
                _isEditing ? 'İlanı Düzenle' : 'Yeni İlan Ver',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: L10nText(
                  'İLAN KATEGORİSİ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ),
              _adminCatalogBtns(
                addTooltip: 'Yeni kategori ekle',
                onAdd: _addIlanKategoriOption,
                removeTooltip: 'Kategori kaldır',
                onRemove: _removeIlanKategoriOption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kategoriValue,
            isExpanded: true,
            decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: MetoColors.card),
            items: [
              for (final o in kategoriOpts)
                DropdownMenuItem(
                  value: o.value,
                  child: Text(
                    o.builtin
                        ? switch (o.value) {
                            kIlanCatIsAriyorum => 'İş Arıyorum',
                            _ => switch (o.kind) {
                                'uzman' => S.t('ilan_cat_uzman'),
                                'bakici' => S.t('ilan_cat_bakici'),
                                _ => S.t('ilan_cat_ikinciel'),
                              },
                          }
                        : o.value,
                  ),
                ),
            ],
            onChanged: _isEditing
                ? null
                : (v) => setState(() {
                      _formKategori = v!;
                      _formPhotos.clear();
                      _formPhotoBytes.clear();
                    }),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              _isIkinciel
                  ? '2. el ilanını aile hesabıyla paylaşırsınız. Diğer aileler ücretsiz iletişime geçebilir; uzman ve bakıcılar 1 puan harcayarak teklif verebilir.'
                  : _isBakiciArama
                      ? 'Bu ilan “bakıcı/temizlik görevlisi arıyorum” ilanıdır. Aile rolü teklif veremez; bakıcılar ve uzmanlar 1 puan harcayarak teklif verir.'
                      : 'Uzman arıyorum ilanınız Uzman Ara sekmesinde listelenir. Aile rolü teklif veremez; uzman ve bakıcılar 1 puan harcayarak teklif verir.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1D4ED8),
                height: 1.35,
              ),
            ),
          ),
          if (_isUzmanArama) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: L10nText(
                    'UZMANLIK ALANI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
                _adminCatalogBtns(
                  addTooltip: 'Yeni uzmanlık ekle',
                  onAdd: _addUzmanlikOption,
                  removeTooltip: 'Uzmanlık kaldır',
                  onRemove: _removeUzmanlikOption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: uzmanValue,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: MetoColors.card,
              ),
              items: uzmanOpts
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _formUzmanlik = v!),
            ),
          ],
          const SizedBox(height: 16),
          _formField(
            'Başlık',
            'İlanınıza kısa bir başlık',
            _formBaslik,
            onChanged: _handleBaslik,
            warning: _baslikUyari,
          ),
          LocationCascadePicker(
            value: _formLoc,
            requireFullSelection: true,
            showAnywhereOption: false,
            onChanged: (loc) => setState(() => _formLoc = loc),
          ),
          const SizedBox(height: 16),
          _formField(
            _isIkinciel ? 'Fiyat' : 'Bütçe',
            _isIkinciel ? '2000' : '300',
            _formButce,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            suffixText: 'TL',
          ),
          if (_isIkinciel) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.t('ilan_ikinciel_alt').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
                _adminCatalogBtns(
                  addTooltip: 'Yeni alt kategori ekle',
                  onAdd: _addIkincielAltOption,
                  removeTooltip: 'Alt kategori kaldır',
                  onRemove: _removeIkincielAltOption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in ikincielAlts)
                  ChoiceChip(
                    label: Text(ikincielAltDisplayLabel(opt)),
                    selected: _formAltKategori == opt,
                    onSelected: (_) =>
                        setState(() => _formAltKategori = opt),
                    selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _formAltKategori == opt
                          ? MetoColors.primary
                          : MetoColors.mutedFg,
                    ),
                    side: BorderSide(
                      color: _formAltKategori == opt
                          ? MetoColors.primary
                          : MetoColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              S.t('ilan_condition').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in kIkincielDurumSecenekleri)
                  ChoiceChip(
                    label: Text(opt),
                    selected: _formCondition == opt,
                    onSelected: (_) => setState(() => _formCondition = opt),
                    selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _formCondition == opt
                          ? MetoColors.primary
                          : MetoColors.mutedFg,
                    ),
                    side: BorderSide(
                      color: _formCondition == opt
                          ? MetoColors.primary
                          : MetoColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_showPhotoPicker) ...[
            Text(
                _isIkinciel ? 'ÜRÜN FOTOĞRAFLARI' : 'FOTOĞRAFLAR',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _isUzmanOrBakici
                    ? 'En fazla $kUzmanBakiciMaxPhotos fotoğraf ekleyebilirsiniz. İlk fotoğraf kapak olur.'
                    : 'En fazla $_maxPhotos fotoğraf ekleyebilirsiniz. İlk fotoğraf kapak olur.',
                style: const TextStyle(
                    fontSize: 12, color: MetoColors.mutedFg),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._formPhotos.asMap().entries.map((e) {
                  final provider = _formPhotoProviderAt(e.key);
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: e.value.swatchColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MetoColors.border),
                          image: provider == null
                              ? null
                              : DecorationImage(
                                  image: provider,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: provider != null
                            ? null
                            : const Center(
                                child: Icon(Icons.image_outlined,
                                    color: MetoColors.mutedFg),
                              ),
                      ),
                      if (e.key == 0)
                        const Positioned(
                            left: 4,
                            bottom: 4,
                            child: L10nText('Kapak',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700))),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _formPhotos.removeAt(e.key);
                            if (e.key < _formPhotoBytes.length) {
                              _formPhotoBytes.removeAt(e.key);
                            }
                          }),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_formPhotos.length < _maxPhotos)
                  InkWell(
                    onTap: _pickingPhoto ? null : _pickProductPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MetoColors.muted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetoColors.border),
                      ),
                      child: _pickingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MetoColors.primary,
                                ),
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined),
                                SizedBox(height: 4),
                                L10nText('Ekle',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700))
                              ]),
                    ),
                  ),
              ],
            ),
            if (_formPhotos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _isIkinciel
                      ? 'Galeri veya kameradan ürün fotoğrafı ekleyin — satış hızlanır'
                      : 'İsteğe bağlı: galeri veya kameradan en fazla $kUzmanBakiciMaxPhotos fotoğraf ekleyin',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFD97706)),
                ),
              ),
            const SizedBox(height: 16),
          ],
          const L10nText('AÇIKLAMA',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          TextField(
            controller: _formAciklama,
            maxLines: 4,
            onChanged: _handleAciklama,
            decoration: InputDecoration(
              hintText: S.auto('Detaylı bilgi, tercihleriniz... (telefon/e-posta yazmayın)'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: MetoColors.card,
            ),
          ),
          if (_aciklamaUyari.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A))),
              child: Text(_aciklamaUyari,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: MetoColors.primary),
                SizedBox(width: 8),
                Expanded(
                    child: L10nText(
                        'Telefon, e-posta ve adres bilgileri otomatik olarak engellenir. İletişim yalnızca puan sistemi üzerinden kurulur.',
                        style: TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                            height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              style: _primaryBtn,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _publishing
                    ? (_isEditing ? 'Kaydediliyor…' : 'Yayınlanıyor…')
                    : (_isEditing
                        ? 'Değişiklikleri Kaydet'
                        : 'İlanı Yayınla — Ücretsiz'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
