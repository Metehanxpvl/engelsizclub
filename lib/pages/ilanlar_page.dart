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

/// MetoCare `IlanlarTab` — Flutter portu.
class IlanlarPage extends StatefulWidget {
  const IlanlarPage({
    super.key,
    required this.userKredi,
    required this.onKrediHarca,
    this.userEmail = '',
    this.userName = 'Siz',
    this.onUnreadChange,
    this.onOpenKrediYukle,
    this.onIlanlarChanged,
  });

  final int userKredi;
  final VoidCallback onKrediHarca;
  final String userEmail;
  final String userName;
  final ValueChanged<int>? onUnreadChange;
  final VoidCallback? onOpenKrediYukle;
  final VoidCallback? onIlanlarChanged;

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
  IlanKategori _kategori = IlanKategori.uzmanlar;
  bool _showVerForm = false;
  double _kmFilter = 500;
  bool _loadingFeed = true;
  List<FavoriIlanRef> _favoriler = const [];

  UzmanIlani? _selectedUzman;
  BakiciIlani? _selectedBakici;
  IkincielIlani? _selectedIkinciel;
  ({IlanPoster poster, String ctaLabel, String peerEmail, int? ilanId, bool free})?
      _selectedPoster;
  SohbetKisi? _pendingSohbet;
  final _activeSohbetler = <_ActiveSohbet>[];
  Set<int> _teklifVerilenIlanlar = {};

  int get _totalUnread => _activeSohbetler.fold<int>(0, (s, c) => s + c.unread);

  void _reportUnread() => widget.onUnreadChange?.call(_totalUnread);

  bool _teklifVerildiMi(int? ilanId) =>
      ilanId != null && _teklifVerilenIlanlar.contains(ilanId);

  SohbetKisi _kisiFromPoster({
    required IlanPoster poster,
    required int ilanId,
  }) {
    final peer = (ilanOwnerById[ilanId] ?? '').trim().toLowerCase();
    return SohbetKisi(
      ad: poster.name,
      avatar: poster.avatar,
      avatarColor: poster.avatarColor,
      isOnline: false,
      sonGorus: peer.isEmpty ? 'Örnek / demo ilan' : null,
      peerEmail: peer,
      ilanId: ilanId,
    );
  }

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  Future<void> _adminDeleteIlan({
    required String kind,
    required int id,
    required String title,
  }) async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı sil (Admin)'),
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
      setState(() {});
      widget.onIlanlarChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan admin tarafından silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('policy') || e.toString().contains('42501')
                ? 'Silme yetkisi yok. admin_moderation.sql çalıştırın.'
                : 'Silinemedi: $e',
          ),
        ),
      );
    }
  }

  Widget _adminIlanDeleteBtn({
    required String kind,
    required int id,
    required String title,
  }) {
    if (!_isAdmin) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Admin: ilanı sil',
      onPressed: () => _adminDeleteIlan(kind: kind, id: id, title: title),
      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
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
          existing.lastMsg = o.lastMsg;
          existing.lastTime = time;
        } else {
          final initials = o.peerEmail.isNotEmpty
              ? o.peerEmail.substring(0, 1).toUpperCase()
              : '?';
          _activeSohbetler.add(_ActiveSohbet(
            kisi: SohbetKisi(
              ad: o.peerEmail.split('@').first,
              avatar: initials,
              avatarColor: MetoColors.primary,
              isOnline: false,
              peerEmail: o.peerEmail,
            ),
            lastMsg: o.lastMsg,
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
    _refreshFeed();
  }

  Future<void> _refreshFeed() async {
    setState(() => _loadingFeed = true);
    await loadAllIlanlar(preferEmail: widget.userEmail);
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
    final next = _isFav(ref.kind, ref.id)
        ? _favoriler.where((f) => f.key != ref.key).toList()
        : [..._favoriler, ref];
    setState(() => _favoriler = next);
    await upsertUserCloudProfile(email: widget.userEmail, favorites: next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFav(ref.kind, ref.id)
              ? 'Favorilere eklendi ❤️'
              : 'Favorilerden çıkarıldı',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
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

  List<UzmanIlani> get _filteredUzman =>
      [...runtimeUzmanIlanlar, ...uzmanIlanlar]
          .where((u) => (uzmanKm[u.id] ?? 50) <= _kmFilter)
          .toList();

  List<BakiciIlani> get _filteredBakici =>
      [...runtimeBakiciIlanlar, ...bakiciIlanlar]
          .where((b) => (bakiciKm[b.id] ?? 50) <= _kmFilter)
          .toList();

  List<IkincielIlani> get _allIkinciel =>
      [...runtimeIkincielIlanlar, ...ikincielIlanlar];

  String _nowTime() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openTeklif(SohbetKisi kisi, {bool free = false}) {
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
    // Daha önce teklif verildiyse kredi alma — doğrudan sohbet
    if (_teklifVerildiMi(kisi.ilanId)) {
      _openSohbet(kisi);
      return;
    }
    // 2. el ürünlerde teklif ücretsiz
    if (free) {
      _completeFreeTeklif(kisi);
      return;
    }
    setState(() => _pendingSohbet = kisi);
    _showKrediModal(
      onSpendAsync: () async {
        final k = _pendingSohbet;
        if (k == null) return false;
        if (widget.userKredi <= 0) return false;
        // Önce mesaj + bildirim; başarılı olursa kredi düş.
        await notifyIlanSahibiTeklif(
          ownerEmail: k.peerEmail,
          actorName: widget.userName,
          ilanId: k.ilanId,
        );
        widget.onKrediHarca();
        if (k.ilanId != null) {
          await markTeklifVerildi(
            email: widget.userEmail,
            ilanId: k.ilanId!,
          );
          if (mounted) {
            setState(() {
              _teklifVerilenIlanlar = {..._teklifVerilenIlanlar, k.ilanId!};
            });
          }
        }
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${k.ad} adlı ilan sahibine teklif bildirimi gönderildi',
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
    );
  }

  Future<void> _completeFreeTeklif(SohbetKisi k) async {
    try {
      await notifyIlanSahibiTeklif(
        ownerEmail: k.peerEmail,
        actorName: widget.userName,
        ilanId: k.ilanId,
      );
    } catch (e) {
      if (!mounted) return;
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
      return;
    }
    if (k.ilanId != null) {
      await markTeklifVerildi(email: widget.userEmail, ilanId: k.ilanId!);
      if (mounted) {
        setState(() {
          _teklifVerilenIlanlar = {..._teklifVerilenIlanlar, k.ilanId!};
        });
      }
    }
    if (!mounted) return;
    setState(() {
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
      const SnackBar(
        content: Text('2. el teklif ücretsiz — sohbet açılıyor'),
      ),
    );
    _openSohbet(k);
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
          onNewMessage: (text) {
            setState(() {
              final existing = _activeSohbetler
                  .where((c) =>
                      c.kisi.peerEmail.toLowerCase() ==
                      kisi.peerEmail.toLowerCase())
                  .firstOrNull;
              if (existing != null) {
                existing.lastMsg = text;
                existing.lastTime = _nowTime();
              } else {
                _activeSohbetler.add(_ActiveSohbet(
                  kisi: kisi,
                  lastMsg: text,
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
          widget.onKrediHarca();
          return true;
        },
        onUnlocked: () {
          Navigator.pop(ctx);
          onUnlocked?.call();
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showVerForm) {
      return _YeniIlanForm(
        userName: widget.userName,
        userEmail: widget.userEmail,
        onBack: () => setState(() => _showVerForm = false),
        onPublished: (kategori) async {
          setState(() {
            _showVerForm = false;
            _kategori = kategori;
          });
          final messenger = ScaffoldMessenger.of(context);
          await _refreshFeed();
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('İlanınız yayınlandı ✅')),
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
              _buildCreditBar(),
              if (_kategori != IlanKategori.ikinciel) _buildKmFilter(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    if (_kategori == IlanKategori.uzmanlar)
                      ..._filteredUzman.map(_buildUzmanCard),
                    if (_kategori == IlanKategori.bakici)
                      ..._filteredBakici.map(_buildBakiciCard),
                    if (_kategori == IlanKategori.ikinciel)
                      ..._allIkinciel.map(_buildIkincielCard),
                    const SizedBox(height: 12),
                    _buildStatsFooter(),
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
            onClose: () => setState(() => _selectedBakici = null),
            onProfile: () {
              final ilan = _selectedBakici!;
              setState(() {
                _selectedBakici = null;
                _selectedPoster = (
                  poster: ilan.poster,
                  ctaLabel: _teklifVerildiMi(ilan.id)
                      ? 'Teklif Verildi — Mesaja Git'
                      : '1 Kredi Harca — Teklif Ver',
                  peerEmail: ilanOwnerById[ilan.id] ?? '',
                  ilanId: ilan.id,
                  free: false,
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedBakici!;
              setState(() => _selectedBakici = null);
              _openTeklif(_kisiFromPoster(poster: ilan.poster, ilanId: ilan.id));
            },
          ),
        if (_selectedIkinciel != null)
          _IkincielDrawer(
            ilan: _selectedIkinciel!,
            alreadyOffered: _teklifVerildiMi(_selectedIkinciel!.id),
            onClose: () => setState(() => _selectedIkinciel = null),
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
                  free: true,
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedIkinciel!;
              setState(() => _selectedIkinciel = null);
              _openTeklif(
                _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id),
                free: true,
              );
            },
          ),
        if (_selectedUzman != null)
          _UzmanDrawer(
            ilan: _selectedUzman!,
            alreadyOffered: _teklifVerildiMi(_selectedUzman!.id),
            onClose: () => setState(() => _selectedUzman = null),
            onProfile: () {
              final ilan = _selectedUzman!;
              setState(() {
                _selectedUzman = null;
                _selectedPoster = (
                  poster: ilan.poster,
                  ctaLabel: _teklifVerildiMi(ilan.id)
                      ? 'Teklif Verildi — Mesaja Git'
                      : '1 Kredi Harca — Teklif Ver',
                  peerEmail: ilanOwnerById[ilan.id] ?? '',
                  ilanId: ilan.id,
                  free: false,
                );
              });
            },
            onKrediTap: () {
              final ilan = _selectedUzman!;
              setState(() => _selectedUzman = null);
              _openTeklif(_kisiFromPoster(poster: ilan.poster, ilanId: ilan.id));
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
            onClose: () => setState(() => _selectedPoster = null),
            onKrediTap: () {
              final p = _selectedPoster!.poster;
              final peer = _selectedPoster!.peerEmail;
              final id = _selectedPoster!.ilanId;
              final free = _selectedPoster!.free;
              setState(() => _selectedPoster = null);
              _openTeklif(
                id != null
                    ? _kisiFromPoster(poster: p, ilanId: id)
                    : SohbetKisi(
                        ad: p.name,
                        avatar: p.avatar,
                        avatarColor: p.avatarColor,
                        isOnline: false,
                        peerEmail: peer,
                      ),
                free: free,
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
                  onTap: () => setState(() => _kategori = t.$1),
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
                  '${widget.userKredi} krediniz var',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const Text(
                  '1 kredi = iletişim bilgisi',
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
                onChanged: (v) => setState(() => _kmFilter = v),
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
            ctaLabel: _teklifVerildiMi(ilan.id)
                ? 'Teklif Verildi — Mesaja Git'
                : '1 Kredi Harca — Teklif Ver',
            peerEmail: ilanOwnerById[ilan.id] ?? '',
            ilanId: ilan.id,
            free: false,
          );
        });

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          _favButton(FavoriIlanRef(
                            kind: 'uzman',
                            id: ilan.id,
                            title: ilan.title,
                            konum:
                                '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                            fiyat: ilan.budget,
                          )),
                          _adminIlanDeleteBtn(
                            kind: 'uzman',
                            id: ilan.id,
                            title: ilan.title,
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
            onProfile: openDetail,
            onAction: () =>
                _openTeklif(_kisiFromPoster(poster: ilan.poster, ilanId: ilan.id)),
            actionLabel:
                _teklifVerildiMi(ilan.id) ? 'Teklif Verildi' : 'Teklif Ver',
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
            ctaLabel: _teklifVerildiMi(ilan.id)
                ? 'Teklif Verildi — Mesaja Git'
                : '1 Kredi Harca — Teklif Ver',
            peerEmail: ilanOwnerById[ilan.id] ?? '',
            ilanId: ilan.id,
            free: false,
          );
        });

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          _favButton(FavoriIlanRef(
                            kind: 'bakici',
                            id: ilan.id,
                            title: ilan.title,
                            konum:
                                '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                            fiyat: ilan.budget,
                          )),
                          _adminIlanDeleteBtn(
                            kind: 'bakici',
                            id: ilan.id,
                            title: ilan.title,
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
            onProfile: openDetail,
            onAction: () =>
                _openTeklif(_kisiFromPoster(poster: ilan.poster, ilanId: ilan.id)),
            actionLabel:
                _teklifVerildiMi(ilan.id) ? 'Teklif Verildi' : 'Teklif Ver',
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
          free: true,
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
              onTap: openDetail,
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
                _favButton(FavoriIlanRef(
                  kind: 'ikinciel',
                  id: ilan.id,
                  title: ilan.title,
                  konum:
                      '${ilan.district.isEmpty ? '' : '${ilan.district}, '}${ilan.city}',
                  fiyat: ilan.price,
                )),
                _adminIlanDeleteBtn(
                  kind: 'ikinciel',
                  id: ilan.id,
                  title: ilan.title,
                ),
                _Badge(
                  text: ilan.condition,
                  bg: const Color(0xFFF0FDF4),
                  fg: const Color(0xFF15803D),
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
            onProfile: openDetail,
            onAction: () => _openTeklif(
                  _kisiFromPoster(poster: ilan.poster, ilanId: ilan.id),
                  free: true,
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

  Widget _buildStatsFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.work_outline, size: 14, color: MetoColors.primary),
              SizedBox(width: 8),
              Text(
                'Platform İstatistikleri',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(value: '1.240', label: 'Aktif İlan'),
              _StatCell(value: '320', label: 'Uzman'),
              _StatCell(value: '94%', label: 'Eşleşme'),
            ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
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
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
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
    required this.onAction,
    required this.actionLabel,
    this.subtitleStrike = false,
    this.priceLarge = false,
    this.alreadyOffered = false,
    this.profileLabel = 'Profil',
  });

  final String price;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback onAction;
  final String actionLabel;
  final bool subtitleStrike;
  final bool priceLarge;
  final bool alreadyOffered;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: priceLarge ? 16 : 12,
                  fontWeight: FontWeight.w800,
                  color:
                      priceLarge ? MetoColors.primary : MetoColors.foreground,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                  decoration:
                      subtitleStrike ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onProfile,
          style: OutlinedButton.styleFrom(
            foregroundColor: MetoColors.foreground,
            side: const BorderSide(color: MetoColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(profileLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: alreadyOffered
                ? const Color(0xFF15803D)
                : MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(
            alreadyOffered ? Icons.check_circle : Icons.monetization_on,
            size: 14,
          ),
          label: Text(actionLabel,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.emoji,
    this.onTap,
  });

  final List<IlanPhoto> photos;
  final String emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: photos.asMap().entries.map((e) {
            final i = e.key;
            final photo = e.value;
            final bytes = _photoBytes(photo);
            return Expanded(
              child: Container(
                height: i == 0 ? 110 : 52,
                margin: EdgeInsets.only(right: i < photos.length - 1 ? 4 : 0),
                decoration: BoxDecoration(
                  color: photo.swatchColor,
                  borderRadius: BorderRadius.circular(12),
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
                          fontSize: i == 0 ? 36 : 20,
                          color:
                              Colors.black.withValues(alpha: i == 0 ? 1 : 0.5),
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

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.primary,
            ),
          ),
          Text(label,
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
        ],
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
                      Text('Teklif Gönderildi!',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('1 kredi harcandı · Sohbet hazır',
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
                    Text('1 kredi harcayarak iletişim bilgisine ulaş',
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
                    Text('${widget.credits} kredi',
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
              _busy ? 'Gönderiliyor…' : '1 Kredi Harca — Teklif Ver',
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
  });
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool alreadyOffered;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: MetoColors.border))),
      child: FilledButton.icon(
        onPressed: onTap,
        style: _primaryBtn.copyWith(
            backgroundColor: WidgetStatePropertyAll(
                alreadyOffered
                    ? const Color(0xFF15803D)
                    : (color ?? MetoColors.primary))),
        icon: Icon(
          alreadyOffered ? Icons.check_circle : Icons.monetization_on,
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
  });

  final List<IlanReview> reviews;
  final bool yorumYaz;
  final bool submitted;
  final int myRating;
  final TextEditingController myText;
  final VoidCallback onToggleYorum;
  final ValueChanged<int> onRating;
  final VoidCallback onSubmit;

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
            if (!yorumYaz && !submitted)
              TextButton(
                  onPressed: onToggleYorum,
                  child: const Text('+ Yorum Yaz',
                      style: TextStyle(fontWeight: FontWeight.w800))),
            if (submitted)
              const Text('✓ Yorumunuz eklendi',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A))),
          ],
        ),
        if (yorumYaz) ...[
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
  });
  final IlanPoster poster;
  final String ctaLabel;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final bool alreadyOffered;
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
    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.ctaLabel,
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
  });
  final UzmanIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  @override
  State<_UzmanDrawer> createState() => _UzmanDrawerState();
}

class _UzmanDrawerState extends State<_UzmanDrawer> {
  int _tab = 0;
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
    final cv = uzmanCvFor(widget.ilan.uzmanlik);
    final avgR = avgRating(_reviews);
    final ilan = widget.ilan;

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.alreadyOffered
            ? 'Teklif Verildi — Mesaja Git'
            : '1 Kredi Harca — Teklif Ver',
        color: renk.color,
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
            Text(
              ilan.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
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
  });
  final BakiciIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;
  @override
  State<_BakiciDrawer> createState() => _BakiciDrawerState();
}

class _BakiciDrawerState extends State<_BakiciDrawer> {
  int _tab = 0;
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
    final cv = bakiciCvFor(widget.ilan.poster);
    final avgR = avgRating(_reviews);
    final ilan = widget.ilan;

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.alreadyOffered
            ? 'Teklif Verildi — Mesaja Git'
            : '1 Kredi Harca — Teklif Ver & Sohbet Aç',
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
            Text(
              ilan.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
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
  });

  final IkincielIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
  final VoidCallback onProfile;
  final bool alreadyOffered;

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
                aspectRatio: 4 / 3,
                child: Container(
                  color: current.swatchColor,
                  alignment: Alignment.center,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                      : Text(ilan.emoji, style: const TextStyle(fontSize: 64)),
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
                      onTap: () => setState(() => _photoIndex = i),
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
                _Badge(
                  text: ilan.condition,
                  bg: const Color(0xFFF0FDF4),
                  fg: const Color(0xFF15803D),
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
    this.sohbetKey,
    this.onNewMessage,
  });

  final SohbetKisi kisi;
  final String myEmail;
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
          actorName: _me.split('@').first,
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
                m.body,
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
                                        Text(m.body,
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
            padding: const EdgeInsets.all(12),
            color: MetoColors.card,
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
        ],
      ),
    );
  }
}

class _YeniIlanForm extends StatefulWidget {
  const _YeniIlanForm({
    required this.onBack,
    required this.onPublished,
    this.userName = 'Siz',
    this.userEmail = '',
  });
  final VoidCallback onBack;
  final ValueChanged<IlanKategori> onPublished;
  final String userName;
  final String userEmail;
  @override
  State<_YeniIlanForm> createState() => _YeniIlanFormState();
}

class _YeniIlanFormState extends State<_YeniIlanForm> {
  String _formKategori = 'Uzman Arıyorum';
  String _formUzmanlik = CatalogAdapters.uzmanlikSecenekleri().first;
  final List<IlanPhoto> _formPhotos = [];
  final _formBaslik = TextEditingController();
  final _formButce = TextEditingController();
  final _formAciklama = TextEditingController();
  String _aciklamaUyari = '';
  String? _formIl;
  String? _formIlce;
  bool _pickingPhoto = false;

  bool get _isIkinciel => _formKategori == '2. El Alet';
  bool get _isUzmanArama =>
      _formKategori == 'Uzman Arıyorum' || _formKategori == 'Uzman';
  bool get _isBakiciArama =>
      _formKategori == 'Bakıcı Arıyorum' || _formKategori == 'Bakıcı';

  List<String> get _ilceOptions {
    final city = _formIl;
    if (city == null) return const [];
    final info = kTurkishCities[city];
    if (info == null) return const [];
    return info.ilceler.where((i) => i != kAllIlceler).toList();
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

    final name = widget.userName.trim().isEmpty ? 'Siz' : widget.userName.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final avatar = initials.isEmpty
        ? 'SZ'
        : initials.substring(0, initials.length.clamp(0, 2));
    final cityName = city!;
    final districtName = district!;
    final note = aciklama.isEmpty ? '—' : aciklama;
    final email = widget.userEmail.trim();

    setState(() => _publishing = true);
    try {
      late final IlanKategori kategori;
      switch (_formKategori) {
        case 'Uzman Arıyorum':
        case 'Uzman':
          kategori = IlanKategori.uzmanlar;
          await publishIlanToCloud(
            kind: 'uzman',
            title: baslik,
            city: cityName,
            district: districtName,
            note: note,
            budget: butce,
            uzmanlik: _formUzmanlik,
            posterName: name,
            posterAvatar: avatar,
            ownerEmail: email,
          );
          break;
        case 'Bakıcı Arıyorum':
        case 'Bakıcı':
          kategori = IlanKategori.bakici;
          await publishIlanToCloud(
            kind: 'bakici',
            title: baslik,
            city: cityName,
            district: districtName,
            note: note,
            budget: butce,
            posterName: name,
            posterAvatar: avatar,
            ownerEmail: email,
          );
          break;
        default:
          kategori = IlanKategori.ikinciel;
          await publishIlanToCloud(
            kind: 'ikinciel',
            title: baslik,
            city: cityName,
            district: districtName,
            note: note,
            price: butce,
            photos: _formPhotos.isEmpty
                ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
                : List<IlanPhoto>.from(_formPhotos),
            posterName: name,
            posterAvatar: avatar,
            ownerEmail: email,
          );
      }
      if (!mounted) return;
      widget.onPublished(kategori);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (msg.contains('Ortak görünüm')) {
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
          ? 'İletişim bilgileri (telefon/e-posta) ilanda görünmez — kredi sistemi bu bilgileri korur.'
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
    if (_formPhotos.length >= 4 || _pickingPhoto) return;
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Ürün fotoğrafı ekle',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
      // Web önbellek kotası için agresif küçültme (max ~4 foto).
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 45,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }
      var mime = 'image/jpeg';
      final encoded = base64Encode(bytes);
      if (encoded.length > 180000) {
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
              const Text('Yeni İlan Ver',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
            onChanged: (v) => setState(() {
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
            const Text('ÜRÜN FOTOĞRAFLARI',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg)),
            const SizedBox(height: 8),
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
                if (_formPhotos.length < 6)
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
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Galeri veya kameradan ürün fotoğrafı ekleyin — satış hızlanır',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
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
                        'Telefon, e-posta ve adres bilgileri otomatik olarak engellenir. İletişim yalnızca kredi sistemi üzerinden kurulur.',
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
                _publishing ? 'Yayınlanıyor…' : 'İlanı Yayınla — Ücretsiz',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
