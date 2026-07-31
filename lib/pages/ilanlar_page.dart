import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../bildirim_store.dart';
import '../data/centers_data.dart' show kAllIlceler;
import '../data/ilanlar_data.dart';
import '../data/turkish_cities_data.dart';
import '../ilan_store.dart';
import '../meto_theme.dart';
import '../presence_store.dart';
import '../services/catalog_adapters.dart';
import '../sohbet_store.dart';
import '../teklif_store.dart';
import '../user_cloud_store.dart';
import '../widgets/photo_gallery_lightbox.dart';
import '../widgets/user_avatar.dart';

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
  State<IlanlarPage> createState() => _IlanlarPageState();
}

class _ActiveSohbet {
  _ActiveSohbet({
    required this.kisi,
    required this.lastMsg,
    required this.lastTime,
  });

  final SohbetKisi kisi;
  String lastMsg;
  String lastTime;
  int unread = 0;
}

class _IlanlarPageState extends State<IlanlarPage> {
  static const _kAllIller = 'Tümü';
  static const _pageSize = 10;

  IlanKategori _kategori = IlanKategori.uzmanlar;
  bool _showVerForm = false;
  _IlanEditDraft? _editDraft;
  double _kmFilter = 500;
  String _filterIl = _kAllIller;
  String _filterIlce = kAllIlceler;
  int _listPage = 0;
  bool _loadingFeed = true;
  List<FavoriIlanRef> _favoriler = const [];

  bool get _isAileRole {
    final t = widget.userType.trim().toLowerCase();
    return t != 'uzman' && t != 'bakici' && !isAppAdmin(widget.userEmail);
  }

  String get _normalizedRole {
    final t = widget.userType.trim().toLowerCase();
    if (t == 'uzman' || t == 'bakici' || t == 'aile') return t;
    return 'aile';
  }

  /// 2. el: her rol serbest. Uzman/bakıcı ilanları: sadece uzman veya bakıcı.
  bool _canOfferOn(String kind) {
    if (_isAdmin) return true;
    switch (kind) {
      case 'ikinciel':
        return true;
      case 'uzman':
      case 'bakici':
        return _normalizedRole == 'uzman' || _normalizedRole == 'bakici';
      default:
        return false;
    }
  }

  bool _canReviewOn(String kind) => _canOfferOn(kind);

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
    return SohbetKisi(
      ad: poster.revealedName,
      avatar: poster.avatar.trim().isNotEmpty
          ? poster.avatar
          : contactAvatarLetter(poster.revealedName),
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
        content: Text('"$title" ilanını kalıcı silmek istiyor musunuz?'),
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
            child: const Text('Sil'),
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

  Widget _ilanEditDeleteActions({
    required int id,
    required String kind,
    required String title,
    required VoidCallback onEdit,
  }) {
    final canEdit = _isIlanOwner(id);
    final canDelete = _canDeleteIlan(id);
    if (!canEdit && !canDelete) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          IconButton(
            tooltip: 'Satıldı olarak işaretle',
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
            tooltip: 'Düzenle',
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
        title: const Text('Satıldığını onaylıyor musunuz?'),
        content: Text(
          '"$title" ilanı satıldı olarak işaretlenecek ve yayından kalkacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCA8A04),
            ),
            child: const Text('Evet, satıldı'),
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
        const SnackBar(content: Text('İlan satıldı olarak işaretlendi ve yayından kaldırıldı')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  void _openEditUzman(UzmanIlani ilan) {
    setState(() {
      _editDraft = _IlanEditDraft(
        id: ilan.id,
        kind: 'uzman',
        title: ilan.title,
        city: ilan.city,
        district: ilan.district,
        note: ilan.note == '—' ? '' : ilan.note,
        budgetOrPrice: ilan.budget,
        uzmanlik: ilan.uzmanlik,
        photos: List<IlanPhoto>.from(ilan.photos),
      );
      _showVerForm = true;
    });
  }

  void _openEditBakici(BakiciIlani ilan) {
    setState(() {
      _editDraft = _IlanEditDraft(
        id: ilan.id,
        kind: 'bakici',
        title: ilan.title,
        city: ilan.city,
        district: ilan.district,
        note: ilan.note == '—' ? '' : ilan.note,
        budgetOrPrice: ilan.budget,
        photos: List<IlanPhoto>.from(ilan.photos),
      );
      _showVerForm = true;
    });
  }

  void _openEditIkinciel(IkincielIlani ilan) {
    setState(() {
      _editDraft = _IlanEditDraft(
        id: ilan.id,
        kind: 'ikinciel',
        title: ilan.title,
        city: ilan.city,
        district: ilan.district,
        note: ilan.note == '—' ? '' : ilan.note,
        budgetOrPrice: ilan.price,
        condition: ilan.condition,
        photos: List<IlanPhoto>.from(ilan.photos),
      );
      _showVerForm = true;
    });
  }

  void _tryOpenEditIlan() {
    final kind = widget.openEditIlanKind?.trim().toLowerCase();
    final id = widget.openEditIlanId;
    if (kind == null || kind.isEmpty || id == null || id <= 0) return;
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
    setState(() {
      for (final o in ozets) {
        final existing = _activeSohbetler
            .where((c) =>
                c.kisi.peerEmail.toLowerCase() == o.peerEmail.toLowerCase())
            .firstOrNull;
        final time =
            '${o.lastTime.toLocal().hour.toString().padLeft(2, '0')}:${o.lastTime.toLocal().minute.toString().padLeft(2, '0')}';
        if (existing != null) {
          existing.lastMsg = scrubEmailsInText(o.lastMsg);
          existing.lastTime = time;
        } else {
          final fromIlan = revealedPosterNameForOwner(o.peerEmail);
          final label = publicContactLabel(
            o.peerEmail,
            preferredName: fromIlan ?? '',
          );
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
    _refreshFeed().then((_) {
      if (!mounted) return;
      _tryOpenPendingIlan();
      _tryOpenEditIlan();
    });
  }

  @override
  void didUpdateWidget(covariant IlanlarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openIlanToken != oldWidget.openIlanToken) {
      _tryOpenPendingIlan();
    }
    if (widget.openEditIlanToken != oldWidget.openEditIlanToken) {
      _tryOpenEditIlan();
    }
  }

  void _tryOpenPendingIlan() {
    final kind = widget.openIlanKind?.trim().toLowerCase();
    final id = widget.openIlanId;
    if (kind == null || kind.isEmpty || id == null || id <= 0) return;
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
    setState(() => _loadingFeed = true);
    await loadAllIlanlar(preferEmail: widget.userEmail);
    await enrichRuntimeIlanAvatars(
      ownEmail: widget.userEmail,
      ownPhoto: widget.profilFoto,
    );
    final cloud = widget.userEmail.trim().isEmpty
        ? null
        : await loadUserCloudProfile(widget.userEmail);
    final teklifler = widget.userEmail.trim().isEmpty
        ? <int>{}
        : await loadTeklifVerilenIlanlar(widget.userEmail);
    if (!mounted) return;
    setState(() {
      _loadingFeed = false;
      if (cloud != null) _favoriler = cloud.favorites;
      _teklifVerilenIlanlar = teklifler;
    });
    widget.onIlanlarChanged?.call();
    await _syncSohbetListesi();
  }

  bool _isFav(String kind, int id) =>
      _favoriler.any((f) => f.kind == kind && f.id == id);

  Future<void> _toggleFav(FavoriIlanRef ref) async {
    if (widget.userEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favori için giriş yapın')),
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
        const SnackBar(content: Text('Favori kaydedilemedi. Tekrar deneyin.')),
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

  bool _matchesLoc(String city, String district) {
    if (_filterIl == _kAllIller) return true;
    if (_normLoc(city) != _normLoc(_filterIl)) return false;
    if (_filterIlce == kAllIlceler) return true;
    return _normLoc(district) == _normLoc(_filterIlce);
  }

  List<String> get _filterIlceOptions {
    if (_filterIl == _kAllIller) return const [kAllIlceler];
    final info = kTurkishCities[_filterIl];
    if (info == null) return const [kAllIlceler];
    return info.ilceler;
  }

  List<UzmanIlani> get _filteredUzman {
    final demo = CatalogAdapters.showDemoIlanlar() ? uzmanIlanlar : const <UzmanIlani>[];
    return [...runtimeUzmanIlanlar, ...demo]
        .where((u) =>
            _matchesLoc(u.city, u.district) &&
            (uzmanKm[u.id] ?? 50) <= _kmFilter)
        .toList();
  }

  List<BakiciIlani> get _filteredBakici {
    final demo = CatalogAdapters.showDemoIlanlar() ? bakiciIlanlar : const <BakiciIlani>[];
    return [...runtimeBakiciIlanlar, ...demo]
        .where((b) =>
            _matchesLoc(b.city, b.district) &&
            (bakiciKm[b.id] ?? 50) <= _kmFilter)
        .toList();
  }

  List<IkincielIlani> get _allIkinciel {
    final demo =
        CatalogAdapters.showDemoIlanlar() ? ikincielIlanlar : const <IkincielIlani>[];
    return [...runtimeIkincielIlanlar, ...demo]
        .where((i) => _matchesLoc(i.city, i.district))
        .toList();
  }

  String _nowTime() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openTeklif(SohbetKisi kisi, {bool free = false, String kind = 'uzman'}) {
    final me = widget.userEmail.trim().toLowerCase();
    if (kisi.peerEmail.isNotEmpty &&
        kisi.peerEmail.toLowerCase() == me) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendi ilanınıza teklif veremezsiniz')),
      );
      return;
    }
    if (kisi.peerEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
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
    // 2. el: tüm roller serbest, ücretsiz
    if (free || kind == 'ikinciel') {
      _completeFreeTeklif(kisi);
      return;
    }
    if (!_canOfferOn(kind)) {
      final msg = (kind == 'uzman' || kind == 'bakici')
          ? 'Uzman/bakıcı ilanlarına yalnızca Uzman veya Bakıcı rolü teklif verebilir. '
              '2. el ilanlarda her rol serbestçe teklif verip konuşabilir.'
          : 'Bu ilana teklif veremezsiniz.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
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
                content: Text('Bu ilana zaten teklif verdiniz · sohbet açılıyor'),
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
            content: Text(
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

  Future<void> _completeFreeTeklif(SohbetKisi k) async {
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
            e.toString().contains('bildirimler') ||
                    e.toString().contains('sohbet_mesajlari') ||
                    e.toString().contains('schema cache')
                ? 'Teklif iletilemedi. Supabase SQL dosyalarını çalıştırın.'
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
    if (_showVerForm) {
      final editing = _editDraft != null;
      return _YeniIlanForm(
        userName: widget.userName,
        userEmail: widget.userEmail,
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
              _buildCategoryTabs(),
              if (!_isAileRole) _buildCreditBar(),
              _buildLocationFilter(),
              if (_kategori != IlanKategori.ikinciel) _buildKmFilter(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    if (_kategori == IlanKategori.uzmanlar)
                      ..._pageSlice(_filteredUzman).map(_buildUzmanCard),
                    if (_kategori == IlanKategori.bakici)
                      ..._pageSlice(_filteredBakici).map(_buildBakiciCard),
                    if (_kategori == IlanKategori.ikinciel)
                      ..._pageSlice(_allIkinciel).map(_buildIkincielCard),
                    const SizedBox(height: 8),
                    _buildListPager(_currentListLength),
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
            allowOffer: _canOfferOn('bakici'),
            canWriteReview: _canReviewOn('bakici'),
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
            allowOffer: _canOfferOn('uzman'),
            canWriteReview: _canReviewOn('uzman'),
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
            allowOffer: _canOfferOn(_selectedPoster!.kind),
            canWriteReview: _canReviewOn(_selectedPoster!.kind),
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
                        ad: p.name,
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
                Text(
                  'İlanlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                Text(
                  'Uzman / bakıcı arayan ilanlar · 2. el',
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
                  Text(
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
          FilledButton.icon(
            onPressed: () => setState(() => _showVerForm = true),
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
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
      (IlanKategori.uzmanlar, 'Uzman Ara', '🏃', _filteredUzman.length),
      (IlanKategori.bakici, 'Bakıcı Ara', '🤝', _filteredBakici.length),
      (IlanKategori.ikinciel, '2. El Aletler', '♻️', _allIkinciel.length),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? MetoColors.primary
                                : MetoColors.mutedFg,
                          ),
                        ),
                        Text(
                          '${t.$4} ilan',
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
                Text(
                  '${widget.userKredi} puanınız var',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const Text(
                  '1 puan = 1 teklif = ₺49,90',
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
            child: const Text(
              'Satın Al',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    final ilceValue = _filterIl == _kAllIller
        ? kAllIlceler
        : (_filterIlceOptions.contains(_filterIlce)
            ? _filterIlce
            : kAllIlceler);
    final ilceItems = _filterIl == _kAllIller
        ? const <String>[]
        : _filterIlceOptions.where((e) => e != kAllIlceler).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _IlanlarLocDropdown(
              value: _filterIl,
              hint: 'İl',
              allValue: _kAllIller,
              items: kCityNames,
              onChanged: (v) => setState(() {
                _filterIl = v;
                _filterIlce = kAllIlceler;
                _listPage = 0;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _IlanlarLocDropdown(
              value: ilceValue,
              hint: 'İlçe',
              allValue: kAllIlceler,
              items: ilceItems,
              enabled: _filterIl != _kAllIller,
              onChanged: (v) => setState(() {
                _filterIlce = v;
                _listPage = 0;
              }),
            ),
          ),
        ],
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
          child: Text(
            'Bu filtrede ilan yok',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
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
          Text(
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
                        child: Text(
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
          const Text(
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

  String _paidActionLabel(String kind, int? ilanId) {
    if (_teklifVerildiMi(ilanId)) return 'Teklif Verildi';
    if (!_canOfferOn(kind)) return 'Rol gerekli';
    return 'Teklif Ver';
  }

  String _paidCtaLabel(String kind, int? ilanId) {
    if (_teklifVerildiMi(ilanId)) return 'Teklif Verildi — Mesaja Git';
    if (!_canOfferOn(kind)) {
      return kind == 'uzman' || kind == 'bakici'
          ? 'Teklif için Uzman/Bakıcı rolü'
          : 'Teklif verilemez';
    }
    return '1 Puan Harca — Teklif Ver';
  }

  Widget _buildUzmanCard(UzmanIlani ilan) {
    final renk = uzmanRenkFor(ilan.uzmanlik);
    final avgR = avgRating(ilan.poster.reviews);
    final km = uzmanKm[ilan.id];
    void openDetail() => setState(() {
          _selectedPoster = null;
          _selectedUzman = ilan;
        });
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
                  label: ilan.poster.avatar,
                  color: ilan.poster.avatarColor,
                  onTap: openPoster,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                            child: Text(
                              ilan.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                          _Badge(
                            text: '${renk.emoji} ${ilan.uzmanlik}',
                            bg: renk.bg,
                            fg: renk.color,
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
                      child: Text(
                        ilan.poster.name,
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
                    Text(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const Text(
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
            '👁 ${ilan.views}',
            if (km != null) '📍 $km km uzakta',
          ]),
          const SizedBox(height: 8),
          _Chip(text: ilan.tani),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: openDetail,
            child: Text(
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
                  onEdit: () => _openEditUzman(ilan),
                ),
              ],
            ),
            onProfile: openDetail,
            onAction: _canOfferOn('uzman') || _teklifVerildiMi(ilan.id)
                ? () => _openTeklif(
                      _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                      kind: 'uzman',
                    )
                : null,
            actionLabel: _canOfferOn('uzman') || _teklifVerildiMi(ilan.id)
                ? _paidActionLabel('uzman', ilan.id)
                : null,
            alreadyOffered: _teklifVerildiMi(ilan.id),
            profileLabel: 'Detay',
          ),
        ],
      ),
    );
  }

  Widget _buildBakiciCard(BakiciIlani ilan) {
    final avgR = avgRating(ilan.poster.reviews);
    final km = bakiciKm[ilan.id];
    void openDetail() => setState(() {
          _selectedPoster = null;
          _selectedBakici = ilan;
        });
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
                  label: ilan.poster.avatar,
                  color: ilan.poster.avatarColor,
                  onTap: openPoster,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                            child: Text(
                              ilan.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                          const _Badge(
                            text: '🤝 Bakıcı Aranıyor',
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
                      child: Text(
                        ilan.poster.name,
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
                    Text(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const Text(
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
            '👁 ${ilan.views}',
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
          Text('📅 ${ilan.hours}',
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: openDetail,
            child: Text(
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
            onAction: _canOfferOn('bakici') || _teklifVerildiMi(ilan.id)
                ? () => _openTeklif(
                      _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id, ilanTitle: ilan.title),
                      kind: 'bakici',
                    )
                : null,
            actionLabel: _canOfferOn('bakici') || _teklifVerildiMi(ilan.id)
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
    final avgR = avgRating(ilan.poster.reviews);
    void openDetail() => setState(() => _selectedIkinciel = ilan);
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
                      Text(
                        ilan.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      Text(
                        '${ilan.brand} · ${ilan.category}',
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
                        label: ilan.poster.avatar,
                        color: ilan.poster.avatarColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ilan.poster.name,
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
                    Text(
                      ' (${ilan.poster.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: MetoColors.mutedFg),
                    ),
                    const SizedBox(width: 6),
                    const Text(
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
            '👁 ${ilan.views}',
            ilan.posted,
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: openDetail,
            child: Text(
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
            actionLabel:
                _teklifVerildiMi(ilan.id) ? 'Teklif Verildi' : 'İletişim',
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
                child: Text(
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
                child: Text(
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
          price,
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

List<ImageProvider> _ilanGalleryImages(List<IlanPhoto> photos) {
  return [
    for (final p in photos)
      if (galleryImageProvider(p.dataUrl) != null)
        galleryImageProvider(p.dataUrl)!,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: height,
        child: Row(
          children: photos.asMap().entries.map((e) {
            final i = e.key;
            final photo = e.value;
            final bytes = _photoBytes(photo);
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
                    image: bytes == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(bytes),
                            fit: BoxFit.cover,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: bytes != null
                      ? null
                      : Text(
                          emoji,
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

  static Uint8List? _photoBytes(IlanPhoto photo) {
    if (!photo.hasImage) return null;
    try {
      var raw = photo.dataUrl!;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
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
                      Text('Teklif Gönderildi!',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('1 puan harcandı · Sohbet hazır',
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
              label: const Text('Sohbete Git',
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
                    Text('İletişim Bilgisini Aç',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('1 puan harcayarak iletişim bilgisine ulaş',
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
                    Text('${widget.credits} puan',
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
                Text('Açıldığında ne görürsünüz:',
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
                            content: Text(
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
                            e.toString().contains('bildirimler') ||
                                    e.toString().contains('sohbet_mesajlari') ||
                                    e.toString().contains('schema cache')
                                ? 'Teklif iletilemedi. Supabase SQL dosyalarını çalıştırın.'
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
              child: const Text('Vazgeç',
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
                                      tooltip: 'Kapat',
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
            const Text('Yorumlar',
                style: TextStyle(fontWeight: FontWeight.w800)),
            if (canWrite && !yorumYaz && !submitted)
              TextButton(
                  onPressed: onToggleYorum,
                  child: const Text('+ Yorum Yaz',
                      style: TextStyle(fontWeight: FontWeight.w800))),
            if (!canWrite)
              const Text('Bu ilana rolünüzle yorum yazılamaz',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg)),
            if (submitted)
              const Text('✓ Yorumunuz eklendi',
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
                const Text('Puanınız',
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
                    hintText: 'Deneyiminizi paylaşın...',
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
                          child: const Text('Gönder',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: onToggleYorum, child: const Text('İptal')),
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
                    label: widget.poster.avatar,
                    color: widget.poster.avatarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.poster.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Row(children: [
                        StarRow(rating: _avg, size: 13),
                        const SizedBox(width: 4),
                        Text(
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
                setState(() {
                  _reviews.insert(
                      0,
                      IlanReview(
                        author: 'Sen',
                        avatar: 'BN',
                        avatarColor: MetoColors.primary,
                        rating: _myRating,
                        date: 'Az önce',
                        text: _myText.text.trim(),
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

  Uint8List? _bytes(IlanPhoto photo) {
    if (!photo.hasImage) return null;
    try {
      var raw = photo.dataUrl!;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = uzmanRenkFor(widget.ilan.uzmanlik);
    final cv = uzmanCvFor(widget.ilan.uzmanlik);
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
                    final bytes = _bytes(current);
                    return GestureDetector(
                      onTap: () => _openIlanPhotoGallery(
                        context,
                        photos,
                        index: idx,
                      ),
                      child: Container(
                        color: current.swatchColor,
                        alignment: Alignment.center,
                        child: bytes != null
                            ? Image.memory(bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
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
                      final b = _bytes(p);
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
                            image: b == null
                                ? null
                                : DecorationImage(
                                    image: MemoryImage(b),
                                    fit: BoxFit.cover,
                                  ),
                          ),
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
                  child: Text(
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
                    tooltip: 'Düzenle',
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
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Sil',
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
              ilan.budget,
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
              '👁 ${ilan.views}',
              ilan.posted,
            ]),
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
                  const Text(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
                    label: ilan.poster.avatar,
                    color: ilan.poster.avatarColor,
                    onTap: widget.onProfile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ilan.poster.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: MetoColors.primary,
                          ),
                        ),
                        Row(children: [
                          StarRow(rating: avgR, size: 12),
                          Text(
                            ' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]),
                        const Text(
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
                  setState(() {
                    _reviews.insert(
                        0,
                        IlanReview(
                            author: 'Sen',
                            avatar: 'BN',
                            avatarColor: MetoColors.primary,
                            rating: _myRating,
                            date: 'Az önce',
                            text: _myText.text.trim()));
                    _yorumYaz = false;
                    _myText.clear();
                    _myRating = 0;
                  });
                },
              ),
            ] else ...[
              _CvBlock(
                  title: '📚 Eğitim',
                  color: renk.color,
                  body: '${cv.bolum}\n${cv.okul} · ${cv.mezunYil}'),
              _CvBlock(
                  title: '💼 Deneyim',
                  color: renk.color,
                  body: '${cv.deneyimYil} yıl deneyim\n${cv.deneyimAlani}'),
              _CvBlock(
                  title: '🛡 Sertifikalar',
                  color: renk.color,
                  body: cv.sertifikalar.map((s) => '✓ $s').join('\n')),
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

  Uint8List? _bytes(IlanPhoto photo) {
    if (!photo.hasImage) return null;
    try {
      var raw = photo.dataUrl!;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = bakiciCvFor(widget.ilan.poster);
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
                    final bytes = _bytes(current);
                    return GestureDetector(
                      onTap: () => _openIlanPhotoGallery(
                        context,
                        photos,
                        index: idx,
                      ),
                      child: Container(
                        color: current.swatchColor,
                        alignment: Alignment.center,
                        child: bytes != null
                            ? Image.memory(bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
                            : const Text('🤝',
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
                      final b = _bytes(p);
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
                            image: b == null
                                ? null
                                : DecorationImage(
                                    image: MemoryImage(b),
                                    fit: BoxFit.cover,
                                  ),
                          ),
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
                  child: Text(
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
                    tooltip: 'Düzenle',
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
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Sil',
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
              text: '🤝 Bakıcı Aranıyor',
              bg: Color(0xFFEFF6FF),
              fg: Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 10),
            Text(
              ilan.budget,
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
              '👁 ${ilan.views}',
              ilan.posted,
            ]),
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
                  const Text(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
                    label: ilan.poster.avatar,
                    color: ilan.poster.avatarColor,
                    onTap: widget.onProfile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ilan.poster.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: MetoColors.primary,
                          ),
                        ),
                        Row(children: [
                          StarRow(rating: avgR, size: 12),
                          Text(
                            ' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]),
                        const Text(
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
                  setState(() {
                    _reviews.insert(
                        0,
                        IlanReview(
                            author: 'Sen',
                            avatar: 'BN',
                            avatarColor: MetoColors.primary,
                            rating: _myRating,
                            date: 'Az önce',
                            text: _myText.text.trim()));
                    _yorumYaz = false;
                    _myText.clear();
                    _myRating = 0;
                  });
                },
              ),
            ] else ...[
              _CvBlock(
                  title: '📚 Eğitim',
                  body: '${cv.bolum}\n${cv.okul} · ${cv.mezunYil}'),
              _CvBlock(
                  title: '💼 Deneyim',
                  body: '${cv.deneyimYil} yıl deneyim\n${cv.deneyimAlani}'),
              _CvBlock(
                  title: '🛡 Sertifikalar',
                  body: cv.sertifikalar.map((s) => '✓ $s').join('\n')),
              _CvBlock(title: 'Hakkında', body: widget.ilan.poster.bio),
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
  });

  final IkincielIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_IkincielDrawer> createState() => _IkincielDrawerState();
}

class _IkincielDrawerState extends State<_IkincielDrawer> {
  int _photoIndex = 0;

  Uint8List? _bytes(IlanPhoto photo) {
    if (!photo.hasImage) return null;
    try {
      var raw = photo.dataUrl!;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ilan = widget.ilan;
    final photos = ilan.photos.isEmpty
        ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
        : ilan.photos;
    final idx = _photoIndex.clamp(0, photos.length - 1);
    final current = photos[idx];
    final bytes = _bytes(current);

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
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                        : Text(ilan.emoji, style: const TextStyle(fontSize: 64)),
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
                    final b = _bytes(p);
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
                          image: b == null
                              ? null
                              : DecorationImage(
                                  image: MemoryImage(b),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: b != null
                            ? null
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
                  child: Text(
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
                    tooltip: 'Düzenle',
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
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Sil',
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
            Text(
              '${ilan.brand} · ${ilan.category}',
              style: const TextStyle(fontSize: 13, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 10),
            Text(
              ilan.price,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: MetoColors.primary,
              ),
            ),
            if (ilan.originalPrice.trim().isNotEmpty)
              Text(
                ilan.originalPrice,
                style: const TextStyle(
                  fontSize: 13,
                  color: MetoColors.mutedFg,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            const SizedBox(height: 12),
            _MetaRow(items: [
              '📍 ${ilan.district}, ${ilan.city}',
              '👁 ${ilan.views}',
              ilan.posted,
            ]),
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
                  const Text(
                    'İlan açıklaması',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
                    label: ilan.poster.avatar,
                    color: ilan.poster.avatarColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ilan.poster.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
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
    _load(initial: true);
    unawaited(_refreshPeerOnline());
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
        title: const Text('Mesajı sil'),
        content: const Text('Bu mesaj kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Sil'),
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
        const SnackBar(content: Text('Mesaj silindi')),
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
        title: const Text('Sohbeti sil'),
        content: Text(
          '${widget.kisi.ad} ile olan tüm mesajlar silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Tümünü sil'),
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
        const SnackBar(content: Text('Sohbet silindi')),
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
                child: Text(
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
    return Scaffold(
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
                  Text(widget.kisi.ad,
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
          if (_peer.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'sil') _silSohbet();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'sil',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 8),
                      Text('Sohbeti sil',
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
              minimum: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _draft,
                              enabled: true,
                              decoration: InputDecoration(
                                hintText: 'Mesaj yaz…',
                                filled: true,
                                fillColor: MetoColors.muted,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (_) => _gonder(),
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
    this.uzmanlik = 'Uzman',
    this.condition = 'İyi',
    this.photos = const [],
  });

  final int id;
  final String kind;
  final String title;
  final String city;
  final String district;
  final String note;
  final String budgetOrPrice;
  final String uzmanlik;
  final String condition;
  final List<IlanPhoto> photos;
}

class _YeniIlanForm extends StatefulWidget {
  const _YeniIlanForm({
    required this.onBack,
    required this.onPublished,
    this.userName = 'Siz',
    this.userEmail = '',
    this.profilFoto,
    this.editDraft,
  });
  final VoidCallback onBack;
  final ValueChanged<IlanKategori> onPublished;
  final String userName;
  final String userEmail;
  final String? profilFoto;
  final _IlanEditDraft? editDraft;
  @override
  State<_YeniIlanForm> createState() => _YeniIlanFormState();
}

class _YeniIlanFormState extends State<_YeniIlanForm> {
  String _formKategori = 'Uzman Arıyorum';
  String _formUzmanlik = CatalogAdapters.uzmanlikSecenekleri().first;
  String _formCondition = 'İyi';
  final List<IlanPhoto> _formPhotos = [];
  final _formBaslik = TextEditingController();
  final _formButce = TextEditingController();
  final _formAciklama = TextEditingController();
  String _aciklamaUyari = '';
  String? _formIl;
  String? _formIlce;
  bool _pickingPhoto = false;

  bool get _isEditing => widget.editDraft != null;
  bool get _isIkinciel => _formKategori == '2. El Alet';
  bool get _isUzmanArama =>
      _formKategori == 'Uzman Arıyorum' || _formKategori == 'Uzman';
  bool get _isBakiciArama =>
      _formKategori == 'Bakıcı Arıyorum' || _formKategori == 'Bakıcı';
  bool get _isUzmanOrBakici => _isUzmanArama || _isBakiciArama;
  /// Uzman / bakıcı: en fazla 2; 2. el: en fazla 4.
  int get _maxPhotos =>
      _isUzmanOrBakici ? kUzmanBakiciMaxPhotos : 4;
  bool get _showPhotoPicker => _isIkinciel || _isUzmanOrBakici;

  List<String> get _ilceOptions {
    final city = _formIl;
    if (city == null) return const [];
    final info = kTurkishCities[city];
    if (info == null) return const [];
    return info.ilceler.where((i) => i != kAllIlceler).toList();
  }

  @override
  void initState() {
    super.initState();
    final d = widget.editDraft;
    if (d == null) return;
    _formKategori = switch (d.kind) {
      'bakici' => 'Bakıcı Arıyorum',
      'ikinciel' => '2. El Alet',
      _ => 'Uzman Arıyorum',
    };
    _formBaslik.text = d.title;
    _formButce.text = d.budgetOrPrice;
    _formAciklama.text = d.note;
    _formIl = d.city.isEmpty ? null : d.city;
    _formIlce = d.district.isEmpty ? null : d.district;
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
    _formPhotos.addAll(d.photos);
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
    final baslik = _formBaslik.text.trim();
    final butce = _formButce.text.trim();
    final aciklama = _formAciklama.text.trim();
    final city = _formIl;
    final district = _formIlce;

    final eksik = <String>[];
    if (baslik.isEmpty) eksik.add('Başlık');
    if (city == null || city.isEmpty) eksik.add('İl');
    if (district == null || district.isEmpty) eksik.add('İlçe');
    if (butce.isEmpty) {
      eksik.add(_isIkinciel ? 'Fiyat' : 'Bütçe');
    }
    if (eksik.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doldurun: ${eksik.join(', ')}')),
      );
      return;
    }

    final name =
        widget.userName.trim().isEmpty ? 'Siz' : widget.userName.trim();
    final photo = (widget.profilFoto ?? '').trim();
    final avatar = isAvatarImageSource(photo)
        ? photo
        : posterAvatarInitials(maskPersonDisplayName(name));
    final cityName = city!;
    final districtName = district!;
    final note = aciklama.isEmpty ? '—' : aciklama;
    final email = widget.userEmail.trim();
    final edit = widget.editDraft;

    setState(() => _publishing = true);
    try {
      late final IlanKategori kategori;
      switch (_formKategori) {
        case 'Uzman Arıyorum':
        case 'Uzman':
          kategori = IlanKategori.uzmanlar;
          if (edit != null) {
            await updateIlanInCloud(
              id: edit.id,
              kind: 'uzman',
              title: baslik,
              city: cityName,
              district: districtName,
              note: note,
              budget: butce,
              uzmanlik: _formUzmanlik,
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
              note: note,
              budget: butce,
              uzmanlik: _formUzmanlik,
              photos: List<IlanPhoto>.from(
                _formPhotos.take(kUzmanBakiciMaxPhotos),
              ),
              posterName: name,
              posterAvatar: avatar,
              ownerEmail: email,
            );
          }
          break;
        case 'Bakıcı Arıyorum':
        case 'Bakıcı':
          kategori = IlanKategori.bakici;
          if (edit != null) {
            await updateIlanInCloud(
              id: edit.id,
              kind: 'bakici',
              title: baslik,
              city: cityName,
              district: districtName,
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
              note: note,
              price: butce,
              condition: _formCondition,
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
              note: note,
              price: butce,
              condition: _formCondition,
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
      } else if (msg.contains('Ortak görünüm')) {
        // Yerel kayıt oldu; yine de yayınlandı say.
        widget.onPublished(
          _isUzmanArama
              ? IlanKategori.uzmanlar
              : _isBakiciArama
                  ? IlanKategori.bakici
                  : IlanKategori.ikinciel,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İlan kaydedildi ama henüz diğer kullanıcılara açılmadı. '
              'Supabase ilanlar tablosunu oluşturun.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (lower.contains('quota') ||
          lower.contains('ön bellek') ||
          lower.contains('localstorage') ||
          lower.contains('exceeded')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tarayıcı önbelleği dolu. Daha az/küçük fotoğrafla tekrar deneyin '
              'veya site verilerini temizleyip yenileyin.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İlan yayınlanamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _handleAciklama(String val) {
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-().]{7,}\d)');
    final emailRegex =
        RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
    var cleaned =
        val.replaceAll(phoneRegex, '***').replaceAll(emailRegex, '***');
    setState(() {
      _aciklamaUyari = cleaned != val
          ? 'İletişim bilgileri (telefon/e-posta) ilanda görünmez — puan sistemi bu bilgileri korur.'
          : '';
      _formAciklama.value = TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length));
    });
  }

  Uint8List? _decodePhoto(IlanPhoto photo) {
    if (!photo.hasImage) return null;
    try {
      var raw = photo.dataUrl!;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
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
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: MetoColors.primary),
                title: const Text('Kamerayla çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
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
      // Oranı koruyarak küçült — kırpma yok.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }
      var mime = 'image/jpeg';
      final encoded = base64Encode(bytes);
      if (encoded.length > 500000) {
        throw StateError(
          'Fotoğraf çok büyük. Daha küçük / daha az fotoğraf ekleyin.',
        );
      }
      final dataUrl = 'data:$mime;base64,$encoded';
      if (!mounted) return;
      setState(() => _formPhotos.add(IlanPhoto.data(dataUrl)));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final friendly = msg.contains('büyük') || msg.contains('boş')
          ? e.toString().replaceFirst('Bad state: ', '')
          : (msg.contains('quota') ||
                  msg.contains('ön bellek') ||
                  msg.contains('localstorage') ||
                  msg.contains('exceeded'))
              ? 'Tarayıcı önbelleği dolu. Daha az / daha küçük fotoğraf deneyin.'
              : 'Fotoğraf eklenemedi. Galeri/kamera iznini kontrol edin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Widget _formField(String label, String hint, TextEditingController c) {
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
              decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: MetoColors.card)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('İLAN KATEGORİSİ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _formKategori,
            decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: MetoColors.card),
            items: const [
              'Uzman Arıyorum',
              'Bakıcı Arıyorum',
              '2. El Alet',
            ]
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _isEditing
                ? null
                : (v) => setState(() {
                      _formKategori = v!;
                      _formPhotos.clear();
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
                  ? '2. el ürün satışı için ilan oluşturursunuz. Hesap rolünüz değişmez.'
                  : _isBakiciArama
                      ? 'Bu ilan “bakıcı arıyorum” ilanıdır. Aile hesabınız bakıcı olmaz; bakıcılar size teklif verir.'
                      : 'Bu ilan “uzman arıyorum” ilanıdır. Aile hesabınız uzman olmaz; uzmanlar size teklif verir.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1D4ED8),
                height: 1.35,
              ),
            ),
          ),
          if (_isUzmanArama) ...[
            const SizedBox(height: 16),
            const Text('UZMANLIK ALANI',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: () {
                final opts = CatalogAdapters.uzmanlikSecenekleri();
                return opts.contains(_formUzmanlik)
                    ? _formUzmanlik
                    : opts.first;
              }(),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: MetoColors.card,
              ),
              items: CatalogAdapters.uzmanlikSecenekleri()
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _formUzmanlik = v!),
            ),
          ],
          const SizedBox(height: 16),
          _formField(
              'Başlık', 'İlanınıza kısa bir başlık', _formBaslik),
          const Text('İL',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _formIl,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'İl seçin',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: MetoColors.card,
            ),
            items: kCityNames
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() {
              _formIl = v;
              _formIlce = null;
            }),
          ),
          const SizedBox(height: 16),
          const Text('İLÇE',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _formIlce,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _formIl == null ? 'Önce il seçin' : 'İlçe seçin',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: MetoColors.card,
            ),
            items: _ilceOptions
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _formIl == null
                ? null
                : (v) => setState(() => _formIlce = v),
          ),
          const SizedBox(height: 16),
          _formField(
            _isIkinciel ? 'Fiyat' : 'Bütçe',
            _isIkinciel ? '₺2.000' : '₺300–500/seans',
            _formButce,
          ),
          if (_isIkinciel) ...[
            const Text(
              'ÜRÜN DURUMU',
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
                  final bytes = _decodePhoto(e.value);
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: e.value.swatchColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MetoColors.border),
                          image: bytes == null
                              ? null
                              : DecorationImage(
                                  image: MemoryImage(bytes),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: bytes != null
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
                            child: Text('Kapak',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700))),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _formPhotos.removeAt(e.key)),
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
                                Text('Ekle',
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
          const Text('AÇIKLAMA',
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
              hintText:
                  'Detaylı bilgi, tercihleriniz... (telefon/e-posta yazmayın)',
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
                    child: Text(
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
  }
}

class _IlanlarLocDropdown extends StatelessWidget {
  const _IlanlarLocDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.enabled = true,
    this.allValue,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool enabled;
  /// Seçilince kutuda hint gösterilir (örn. "Tümü" → İl).
  final String? allValue;

  @override
  Widget build(BuildContext context) {
    final showHint = value == null ||
        value!.isEmpty ||
        (allValue != null && value == allValue);
    final safeValue = showHint
        ? null
        : (items.contains(value) ? value : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? MetoColors.background : MetoColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetoColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: enabled ? MetoColors.mutedFg : MetoColors.border,
            ),
          ),
          icon: Icon(
            Icons.expand_more,
            size: 18,
            color: enabled ? MetoColors.mutedFg : MetoColors.border,
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? MetoColors.foreground : MetoColors.mutedFg,
          ),
          dropdownColor: MetoColors.card,
          borderRadius: BorderRadius.circular(12),
          items: [
            if (allValue != null)
              DropdownMenuItem(value: allValue, child: Text('Tümü')),
            for (final item in items)
              if (item != allValue)
                DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
        ),
      ),
    );
  }
}
