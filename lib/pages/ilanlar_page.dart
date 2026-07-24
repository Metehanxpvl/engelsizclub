import 'dart:math';

import 'package:flutter/material.dart';

import '../data/ilanlar_data.dart';
import '../meto_theme.dart';

/// MetoCare `IlanlarTab` — Flutter portu.
class IlanlarPage extends StatefulWidget {
  const IlanlarPage({
    super.key,
    required this.userKredi,
    required this.onKrediHarca,
    this.onUnreadChange,
    this.onOpenKrediYukle,
  });

  final int userKredi;
  final VoidCallback onKrediHarca;
  final ValueChanged<int>? onUnreadChange;
  final VoidCallback? onOpenKrediYukle;

  @override
  State<IlanlarPage> createState() => _IlanlarPageState();
}

class _ActiveSohbet {
  _ActiveSohbet({
    required this.kisi,
    required this.lastMsg,
    required this.lastTime,
    this.unread = 0,
  });

  final SohbetKisi kisi;
  String lastMsg;
  String lastTime;
  int unread;
}

class _IlanlarPageState extends State<IlanlarPage> {
  IlanKategori _kategori = IlanKategori.uzmanlar;
  bool _showVerForm = false;
  double _kmFilter = 500;

  UzmanIlani? _selectedUzman;
  BakiciIlani? _selectedBakici;
  ({IlanPoster poster, String ctaLabel})? _selectedPoster;
  SohbetKisi? _pendingSohbet;
  final _activeSohbetler = <_ActiveSohbet>[];

  int get _totalUnread =>
      _activeSohbetler.fold<int>(0, (s, c) => s + c.unread);

  void _reportUnread() => widget.onUnreadChange?.call(_totalUnread);

  List<UzmanIlani> get _filteredUzman =>
      uzmanIlanlar.where((u) => (uzmanKm[u.id] ?? 50) <= _kmFilter).toList();

  List<BakiciIlani> get _filteredBakici =>
      bakiciIlanlar.where((b) => (bakiciKm[b.id] ?? 50) <= _kmFilter).toList();

  String _nowTime() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openTeklif(SohbetKisi kisi) {
    setState(() => _pendingSohbet = kisi);
    _showKrediModal(onUnlocked: () {
      if (_pendingSohbet == null) return;
      final k = _pendingSohbet!;
      setState(() {
        _pendingSohbet = null;
        if (!_activeSohbetler.any((c) => c.kisi.ad == k.ad)) {
          _activeSohbetler.add(_ActiveSohbet(
            kisi: k,
            lastMsg: 'Teklif kabul edildi',
            lastTime: _nowTime(),
          ));
        }
      });
      _reportUnread();
      _openSohbet(k);
    });
  }

  void _openSohbet(SohbetKisi kisi) {
    setState(() {
      for (final c in _activeSohbetler) {
        if (c.kisi.ad == kisi.ad) c.unread = 0;
      }
    });
    _reportUnread();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SohbetPage(
          kisi: kisi,
          onNewMessage: (text) {
            setState(() {
              final existing = _activeSohbetler
                  .where((c) => c.kisi.ad == kisi.ad)
                  .firstOrNull;
              if (existing != null) {
                existing.unread += 1;
                existing.lastMsg = text;
                existing.lastTime = _nowTime();
              } else {
                _activeSohbetler.add(_ActiveSohbet(
                  kisi: kisi,
                  lastMsg: text,
                  lastTime: _nowTime(),
                  unread: 1,
                ));
              }
            });
            _reportUnread();
          },
        ),
      ),
    ).then((_) {
      setState(() {
        for (final c in _activeSohbetler) {
          if (c.kisi.ad == kisi.ad) c.unread = 0;
        }
      });
      _reportUnread();
    });
  }

  void _showKrediModal({VoidCallback? onUnlocked}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _KrediSheet(
        credits: widget.userKredi,
        onSpend: () {
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
      return _YeniIlanForm(onBack: () => setState(() => _showVerForm = false));
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (_activeSohbetler.isNotEmpty) _buildMesajlarim(),
            _buildCategoryTabs(),
            _buildCreditBar(),
            if (_kategori != IlanKategori.ikinciel) _buildKmFilter(),
            Expanded(child: _buildList()),
          ],
        ),
        if (_selectedPoster != null)
          _ProfilDrawer(
            poster: _selectedPoster!.poster,
            ctaLabel: _selectedPoster!.ctaLabel,
            onClose: () => setState(() => _selectedPoster = null),
            onKrediTap: () {
              final p = _selectedPoster!.poster;
              setState(() => _selectedPoster = null);
              _openTeklif(SohbetKisi(
                ad: p.name,
                avatar: p.avatar,
                avatarColor: p.avatarColor,
                isOnline: Random().nextDouble() > 0.4,
                sonGorus: 'Son görülme: 1 saat önce',
              ));
            },
          ),
        if (_selectedBakici != null)
          _BakiciDrawer(
            ilan: _selectedBakici!,
            onClose: () => setState(() => _selectedBakici = null),
            onKrediTap: () {
              final ilan = _selectedBakici!;
              setState(() => _selectedBakici = null);
              _openTeklif(SohbetKisi(
                ad: ilan.poster.name,
                avatar: ilan.poster.avatar,
                avatarColor: ilan.poster.avatarColor,
                isOnline: Random().nextDouble() > 0.4,
                sonGorus: 'Son görülme: 2 saat önce',
              ));
            },
          ),
        if (_selectedUzman != null)
          _UzmanDrawer(
            ilan: _selectedUzman!,
            onClose: () => setState(() => _selectedUzman = null),
            onKrediTap: () {
              final ilan = _selectedUzman!;
              setState(() => _selectedUzman = null);
              _openTeklif(SohbetKisi(
                ad: ilan.poster.name,
                avatar: ilan.poster.avatar,
                avatarColor: ilan.poster.avatarColor,
                isOnline: Random().nextDouble() > 0.4,
                sonGorus: 'Son görülme: 1 saat önce',
              ));
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
                  'Uzman · Bakıcı · 2. El Malzeme',
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

  Widget _buildMesajlarim() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: MetoColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mesajlarım',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (_totalUnread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$_totalUnread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: MetoColors.border),
          for (final s in _activeSohbetler)
            InkWell(
              onTap: () => _openSohbet(s.kisi),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _SmallAvatar(
                      label: s.kisi.avatar,
                      color: s.kisi.avatarColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.kisi.ad,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          Text(
                            s.lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: s.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: s.unread > 0
                                  ? MetoColors.foreground
                                  : MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          s.lastTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        if (s.unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${s.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = [
      (IlanKategori.uzmanlar, 'Uzmanlar', '🏃', _filteredUzman.length),
      (IlanKategori.bakici, 'Bakıcı', '🤝', _filteredBakici.length),
      (IlanKategori.ikinciel, '2. El Aletler', '♻️', ikincielIlanlar.length),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: MetoColors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Maksimum Mesafe',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MetoColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MetoColors.primary,
              inactiveTrackColor: MetoColors.muted,
              thumbColor: MetoColors.primary,
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 km', style: TextStyle(fontSize: 10, color: MetoColors.mutedFg)),
              Text('500 km', style: TextStyle(fontSize: 10, color: MetoColors.mutedFg)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (_kategori == IlanKategori.uzmanlar)
          ..._filteredUzman.map(_buildUzmanCard),
        if (_kategori == IlanKategori.bakici)
          ..._filteredBakici.map(_buildBakiciCard),
        if (_kategori == IlanKategori.ikinciel)
          ...ikincielIlanlar.map(_buildIkincielCard),
        const SizedBox(height: 12),
        _buildStatsFooter(),
      ],
    );
  }

  Widget _buildUzmanCard(UzmanIlani ilan) {
    final renk = uzmanRenkFor(ilan.uzmanlik);
    final avgR = avgRating(ilan.poster.reviews);
    final km = uzmanKm[ilan.id];

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarButton(
                label: ilan.poster.avatar,
                color: ilan.poster.avatarColor,
                onTap: () => setState(() => _selectedUzman = ilan),
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
                            child: Icon(Icons.auto_awesome, size: 14, color: Colors.red),
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
                    const SizedBox(height: 4),
                    _RatingRow(
                      rating: avgR,
                      suffix: '(${ilan.poster.reviewCount} yorum)',
                      onTap: () => setState(() => _selectedUzman = ilan),
                    ),
                  ],
                ),
              ),
            ],
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
          Text(
            ilan.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.budget,
            subtitle: '${ilan.offers} teklif · ${ilan.posted}',
            onProfile: () => setState(() => _selectedUzman = ilan),
            onAction: () => _openTeklif(SohbetKisi(
              ad: ilan.poster.name,
              avatar: ilan.poster.avatar,
              avatarColor: ilan.poster.avatarColor,
              isOnline: Random().nextDouble() > 0.4,
              sonGorus: 'Son görülme: 1 saat önce',
            )),
            actionLabel: 'Teklif Ver',
          ),
        ],
      ),
    );
  }

  Widget _buildBakiciCard(BakiciIlani ilan) {
    final avgR = avgRating(ilan.poster.reviews);
    final km = bakiciKm[ilan.id];

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarButton(
                label: ilan.poster.avatar,
                color: ilan.poster.avatarColor,
                onTap: () => setState(() => _selectedBakici = ilan),
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
                            child: Icon(Icons.auto_awesome, size: 14, color: Colors.red),
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
                          text: '🤝 Bakıcı',
                          bg: Color(0xFFEFF6FF),
                          fg: Color(0xFF1D4ED8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _RatingRow(
                      rating: avgR,
                      suffix: '(${ilan.poster.reviewCount} yorum)',
                      onTap: () => setState(() => _selectedBakici = ilan),
                    ),
                  ],
                ),
              ),
            ],
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
          Text('📅 ${ilan.hours}', style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
          const SizedBox(height: 4),
          Text(
            ilan.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.budget,
            subtitle: ilan.posted,
            onProfile: () => setState(() => _selectedBakici = ilan),
            onAction: () => _openTeklif(SohbetKisi(
              ad: ilan.poster.name,
              avatar: ilan.poster.avatar,
              avatarColor: ilan.poster.avatarColor,
              isOnline: [10, 13].contains(ilan.id),
              sonGorus: 'Son görülme: 3 saat önce',
            )),
            actionLabel: 'Teklif Ver',
          ),
        ],
      ),
    );
  }

  Widget _buildIkincielCard(IkincielIlani ilan) {
    final avgR = avgRating(ilan.poster.reviews);

    return _IlanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ilan.photos.isNotEmpty) _PhotoStrip(photos: ilan.photos, emoji: ilan.emoji),
          Row(
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
                      style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                    ),
                  ],
                ),
              ),
              _Badge(
                text: ilan.condition,
                bg: const Color(0xFFF0FDF4),
                fg: const Color(0xFF15803D),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _selectedPoster = (
              poster: ilan.poster,
              ctaLabel: 'Satıcıyla İletişime Geç',
            )),
            child: Row(
              children: [
                _SmallAvatar(label: ilan.poster.avatar, color: ilan.poster.avatarColor),
                const SizedBox(width: 8),
                Text(
                  ilan.poster.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(width: 6),
                StarRow(rating: avgR, size: 10),
                const SizedBox(width: 4),
                Text(
                  avgR.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  ' (${ilan.poster.reviewCount})',
                  style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(items: [
            '📍 ${ilan.district}, ${ilan.city}',
            '👁 ${ilan.views}',
            ilan.posted,
          ]),
          const SizedBox(height: 8),
          Text(
            ilan.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.4),
          ),
          const SizedBox(height: 8),
          _CardFooter(
            price: ilan.price,
            subtitle: ilan.originalPrice,
            subtitleStrike: true,
            priceLarge: true,
            onProfile: () => setState(() => _selectedPoster = (
              poster: ilan.poster,
              ctaLabel: 'Satıcıyla İletişime Geç',
            )),
            onAction: () => _showKrediModal(),
            actionLabel: 'İletişim',
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

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.suffix,
    this.onTap,
  });

  final double rating;
  final String suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          StarRow(rating: rating, size: 11),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            ' $suffix',
            style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      ),
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
    final peak = counts.map((c) => c.count).fold<int>(0, (a, b) => a > b ? a : b);
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
                  style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
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
                  style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
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
  });

  final String price;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback onAction;
  final String actionLabel;
  final bool subtitleStrike;
  final bool priceLarge;

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
          ),
        ),
        OutlinedButton(
          onPressed: onProfile,
          style: OutlinedButton.styleFrom(
            foregroundColor: MetoColors.foreground,
            side: const BorderSide(color: MetoColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.monetization_on, size: 14),
          label: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.emoji});

  final List<Color> photos;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: photos.asMap().entries.map((e) {
          final i = e.key;
          final bg = e.value;
          return Expanded(
            child: Container(
              height: i == 0 ? 110 : 52,
              margin: EdgeInsets.only(right: i < photos.length - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: i == 0 ? 36 : 20,
                  color: Colors.black.withValues(alpha: i == 0 ? 1 : 0.5),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
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
          Text(label, style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
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
  final bool Function() onSpend;
  final VoidCallback onUnlocked;
  final VoidCallback onClose;

  @override
  State<_KrediSheet> createState() => _KrediSheetState();
}

class _KrediSheetState extends State<_KrediSheet> {
  bool _unlocked = false;

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
                  child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Teklif Gönderildi!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('1 kredi harcandı · Sohbet hazır', style: TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  _InfoLine(icon: Icons.message, text: 'Karşı taraf bilgilendirildi'),
                  SizedBox(height: 8),
                  _InfoLine(icon: Icons.chat_bubble_outline, text: 'Sohbeti başlatmak için devam edin'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onUnlocked,
              style: _primaryBtn,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Sohbete Git', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    Text('İletişim Bilgisini Aç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('1 kredi harcayarak iletişim bilgisine ulaş', style: TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text('${widget.credits} kredi', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Açıldığında ne görürsünüz:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                _InfoLine(icon: Icons.phone, text: 'Telefon numarası'),
                _InfoLine(icon: Icons.email_outlined, text: 'E-posta adresi'),
                _InfoLine(icon: Icons.location_on_outlined, text: 'Kesin adres / semt'),
                _InfoLine(icon: Icons.calendar_today, text: 'Uygun saat bilgisi'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.credits > 0 ? () { if (widget.onSpend()) setState(() => _unlocked = true); } : null,
            style: _primaryBtn,
            icon: const Icon(Icons.monetization_on, size: 20),
            label: const Text('1 Kredi Harca — Teklif Ver', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          TextButton(onPressed: widget.onClose, child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.w700))),
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
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(999)),
          ),
          child,
        ],
      ),
    );
  }
}

class _DrawerShell extends StatelessWidget {
  const _DrawerShell({required this.onClose, required this.footer, required this.child});
  final VoidCallback onClose;
  final Widget footer;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: GestureDetector(
          onTap: onClose,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
                decoration: const BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(999)),
                    ),
                    Flexible(child: SingleChildScrollView(child: child)),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: MetoColors.border))),
      child: FilledButton.icon(
        onPressed: onTap,
        style: _primaryBtn.copyWith(backgroundColor: WidgetStatePropertyAll(color ?? MetoColors.primary)),
        icon: const Icon(Icons.monetization_on, size: 18),
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
            const Text('Yorumlar', style: TextStyle(fontWeight: FontWeight.w800)),
            if (!yorumYaz && !submitted)
              TextButton(onPressed: onToggleYorum, child: const Text('+ Yorum Yaz', style: TextStyle(fontWeight: FontWeight.w800))),
            if (submitted)
              const Text('✓ Yorumunuz eklendi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
          ],
        ),
        if (yorumYaz) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Puanınız', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Row(
                  children: List.generate(5, (i) {
                    final s = i + 1;
                    return IconButton(
                      onPressed: () => onRating(s),
                      icon: Icon(Icons.star, size: 28, color: s <= myRating ? MetoColors.accentGold : const Color(0xFFE5E0D8)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(onPressed: onSubmit, child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: onToggleYorum, child: const Text('İptal')),
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
                        Text(r.author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        StarRow(rating: r.rating.toDouble(), size: 10),
                      ],
                    ),
                    Text(r.text, style: const TextStyle(fontSize: 12, height: 1.4)),
                    Text(r.date, style: const TextStyle(fontSize: 10, color: MetoColors.mutedFg)),
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
  });
  final IlanPoster poster;
  final String ctaLabel;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
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

  double get _avg => _reviews.isEmpty ? widget.poster.rating : avgRating(_reviews);

  @override
  Widget build(BuildContext context) {
    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: widget.ctaLabel,
        onTap: () { widget.onClose(); widget.onKrediTap(); },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarButton(label: widget.poster.avatar, color: widget.poster.avatarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.poster.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Row(children: [
                        StarRow(rating: _avg, size: 13),
                        const SizedBox(width: 4),
                        Text('${_avg.toStringAsFixed(1)} (${_reviews.length} uzman yorumu)', style: const TextStyle(fontSize: 12)),
                      ]),
                      Wrap(spacing: 4, children: widget.poster.tags.map((t) => _Chip(text: t)).toList()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.poster.bio, style: const TextStyle(fontSize: 14, height: 1.5)),
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
                  _reviews.insert(0, IlanReview(
                    author: 'Sen', avatar: 'BN', avatarColor: MetoColors.primary,
                    rating: _myRating, date: 'Az önce', text: _myText.text.trim(),
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
  const _UzmanDrawer({required this.ilan, required this.onClose, required this.onKrediTap});
  final UzmanIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
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
  void dispose() { _myText.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final renk = uzmanRenkFor(widget.ilan.uzmanlik);
    final cv = uzmanCvFor(widget.ilan.uzmanlik);
    final avgR = avgRating(_reviews);

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: '1 Kredi Harca — Teklif Ver',
        color: renk.color,
        onTap: () { widget.onClose(); widget.onKrediTap(); },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarButton(label: widget.ilan.poster.avatar, color: widget.ilan.poster.avatarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.ilan.poster.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      _Badge(text: '${renk.emoji} ${widget.ilan.uzmanlik}', bg: renk.bg, fg: renk.color),
                      Row(children: [
                        StarRow(rating: avgR, size: 12),
                        Text(' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)', style: const TextStyle(fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _TabBtn(label: '👤 Profil', selected: _tab == 0, color: renk.color, onTap: () => setState(() => _tab = 0))),
                const SizedBox(width: 8),
                Expanded(child: _TabBtn(label: '📄 Özgeçmiş', selected: _tab == 1, color: renk.color, onTap: () => setState(() => _tab = 1))),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              Wrap(spacing: 8, children: widget.ilan.poster.tags.map((t) => _Badge(text: t, bg: renk.bg, fg: renk.color)).toList()),
              const SizedBox(height: 12),
              Text(widget.ilan.poster.bio, style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg, height: 1.5)),
              const SizedBox(height: 16),
              _RatingBreakdown(reviews: _reviews),
              const SizedBox(height: 12),
              _ReviewSection(
                reviews: _reviews, yorumYaz: _yorumYaz, submitted: false, myRating: _myRating, myText: _myText,
                onToggleYorum: () => setState(() => _yorumYaz = !_yorumYaz),
                onRating: (r) => setState(() => _myRating = r),
                onSubmit: () {
                  if (_myRating == 0 || _myText.text.trim().isEmpty) return;
                  setState(() {
                    _reviews.insert(0, IlanReview(author: 'Sen', avatar: 'BN', avatarColor: MetoColors.primary, rating: _myRating, date: 'Az önce', text: _myText.text.trim()));
                    _yorumYaz = false; _myText.clear(); _myRating = 0;
                  });
                },
              ),
            ] else ...[
              _CvBlock(title: '📚 Eğitim', color: renk.color, body: '${cv.bolum}\n${cv.okul} · ${cv.mezunYil}'),
              _CvBlock(title: '💼 Deneyim', color: renk.color, body: '${cv.deneyimYil} yıl deneyim\n${cv.deneyimAlani}'),
              _CvBlock(title: '🛡 Sertifikalar', color: renk.color, body: cv.sertifikalar.map((s) => '✓ $s').join('\n')),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BakiciDrawer extends StatefulWidget {
  const _BakiciDrawer({required this.ilan, required this.onClose, required this.onKrediTap});
  final BakiciIlani ilan;
  final VoidCallback onClose;
  final VoidCallback onKrediTap;
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
  void dispose() { _myText.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cv = bakiciCvFor(widget.ilan.poster);
    final avgR = avgRating(_reviews);

    return _DrawerShell(
      onClose: widget.onClose,
      footer: _DrawerFooter(
        label: '1 Kredi Harca — Teklif Ver & Sohbet Aç',
        onTap: () { widget.onClose(); widget.onKrediTap(); },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarButton(label: widget.ilan.poster.avatar, color: widget.ilan.poster.avatarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.ilan.poster.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Row(children: [
                        StarRow(rating: avgR, size: 12),
                        Text(' ${avgR.toStringAsFixed(1)} (${_reviews.length} yorum)', style: const TextStyle(fontSize: 12)),
                      ]),
                      Text('${widget.ilan.city} · ${widget.ilan.district}', style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _TabBtn(label: '👤 Profil', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
                const SizedBox(width: 8),
                Expanded(child: _TabBtn(label: '📄 Özgeçmiş', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              Wrap(spacing: 8, children: widget.ilan.poster.tags.map((t) => _Chip(text: t)).toList()),
              const SizedBox(height: 12),
              Text(widget.ilan.poster.bio, style: const TextStyle(fontSize: 14, color: MetoColors.mutedFg, height: 1.5)),
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('İlan Detayları', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Text('📅 ${widget.ilan.hours}', style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                    Text('💰 ${widget.ilan.budget}', style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                    Text('🧒 ${widget.ilan.tani} · ${widget.ilan.age}', style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _RatingBreakdown(reviews: _reviews),
              const SizedBox(height: 12),
              _ReviewSection(
                reviews: _reviews, yorumYaz: _yorumYaz, submitted: false, myRating: _myRating, myText: _myText,
                onToggleYorum: () => setState(() => _yorumYaz = !_yorumYaz),
                onRating: (r) => setState(() => _myRating = r),
                onSubmit: () {
                  if (_myRating == 0 || _myText.text.trim().isEmpty) return;
                  setState(() {
                    _reviews.insert(0, IlanReview(author: 'Sen', avatar: 'BN', avatarColor: MetoColors.primary, rating: _myRating, date: 'Az önce', text: _myText.text.trim()));
                    _yorumYaz = false; _myText.clear(); _myRating = 0;
                  });
                },
              ),
            ] else ...[
              _CvBlock(title: '📚 Eğitim', body: '${cv.bolum}\n${cv.okul} · ${cv.mezunYil}'),
              _CvBlock(title: '💼 Deneyim', body: '${cv.deneyimYil} yıl deneyim\n${cv.deneyimAlani}'),
              _CvBlock(title: '🛡 Sertifikalar', body: cv.sertifikalar.map((s) => '✓ $s').join('\n')),
              _CvBlock(title: 'Hakkında', body: widget.ilan.poster.bio),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.selected, required this.onTap, this.color});
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
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : MetoColors.mutedFg)),
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
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? MetoColors.primary)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.5)),
        ],
      ),
    );
  }
}

class SohbetPage extends StatefulWidget {
  const SohbetPage({super.key, required this.kisi, this.onNewMessage});
  final SohbetKisi kisi;
  final ValueChanged<String>? onNewMessage;
  @override
  State<SohbetPage> createState() => _SohbetPageState();
}

class _SohbetPageState extends State<SohbetPage> {
  final _messages = <({String from, String text, String time})>[
    (from: 'karsi', text: 'Merhaba! İlanınızı inceledim, müsait olduğumda görüşebiliriz.', time: '10:32'),
  ];
  final _draft = TextEditingController();
  bool _karsiYaziyor = false;

  @override
  void dispose() { _draft.dispose(); super.dispose(); }

  String _now() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _gonder() {
    if (_draft.text.trim().isEmpty) return;
    final msg = _draft.text.trim();
    setState(() {
      _draft.clear();
      _messages.add((from: 'ben', text: msg, time: _now()));
      _karsiYaziyor = true;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      const yanitlar = [
        'Tabii, detayları konuşabiliriz.',
        'Uygun saatler için takvimimi paylaşabilirim.',
        'Referanslarımı da iletebilirim.',
        'Tecrübem hakkında daha fazla bilgi vermekten memnuniyet duyarım.',
      ];
      setState(() {
        _karsiYaziyor = false;
        final reply = yanitlar[Random().nextInt(yanitlar.length)];
        _messages.add((from: 'karsi', text: reply, time: _now()));
        widget.onNewMessage?.call(reply);
      });
    });
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
                _SmallAvatar(label: widget.kisi.avatar, color: widget.kisi.avatarColor),
                if (widget.kisi.isOnline)
                  Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: MetoColors.card, width: 2)))),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.kisi.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    widget.kisi.isOnline ? 'Çevrimiçi' : (widget.kisi.sonGorus ?? 'Son görülme bilinmiyor'),
                    style: TextStyle(fontSize: 12, color: widget.kisi.isOnline ? Colors.green : MetoColors.mutedFg),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.phone_outlined, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: MetoColors.muted.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
                    child: const Text('Teklif kabul edildi · Sohbet açıldı', style: TextStyle(fontSize: 10, color: MetoColors.mutedFg)),
                  ),
                ),
                const SizedBox(height: 12),
                ..._messages.map((m) {
                  final ben = m.from == 'ben';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: ben ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!ben) ...[
                          _SmallAvatar(label: widget.kisi.avatar, color: widget.kisi.avatarColor),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: ben ? MetoColors.primary : MetoColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: ben ? null : Border.all(color: MetoColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.text, style: TextStyle(color: ben ? Colors.white : MetoColors.foreground)),
                                Text(m.time, style: TextStyle(fontSize: 10, color: ben ? Colors.white70 : MetoColors.mutedFg)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_karsiYaziyor)
                  Row(
                    children: [
                      _SmallAvatar(label: widget.kisi.avatar, color: widget.kisi.avatarColor),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: MetoColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: MetoColors.border)),
                        child: const Text('...', style: TextStyle(color: MetoColors.mutedFg)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: MetoColors.card,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz…',
                      filled: true,
                      fillColor: MetoColors.muted,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _gonder(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _gonder, style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(14)), child: const Icon(Icons.send, size: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YeniIlanForm extends StatefulWidget {
  const _YeniIlanForm({required this.onBack});
  final VoidCallback onBack;
  @override
  State<_YeniIlanForm> createState() => _YeniIlanFormState();
}

class _YeniIlanFormState extends State<_YeniIlanForm> {
  String _formKategori = 'Uzman';
  final List<Color> _formPhotos = [];
  final _formAciklama = TextEditingController();
  String _aciklamaUyari = '';

  @override
  void dispose() { _formAciklama.dispose(); super.dispose(); }

  void _handleAciklama(String val) {
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-().]{7,}\d)');
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
    var cleaned = val.replaceAll(phoneRegex, '***').replaceAll(emailRegex, '***');
    setState(() {
      _aciklamaUyari = cleaned != val
          ? 'İletişim bilgileri (telefon/e-posta) ilanda görünmez — kredi sistemi bu bilgileri korur.'
          : '';
      _formAciklama.value = TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: cleaned.length));
    });
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
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
              const Text('Yeni İlan Ver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('İLAN KATEGORİSİ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _formKategori,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: MetoColors.card),
            items: ['Uzman', 'Bakıcı', '2. El Alet'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() { _formKategori = v!; _formPhotos.clear(); }),
          ),
          const SizedBox(height: 16),
          ...[
            ('Başlık', 'İlanınıza kısa bir başlık'),
            ('Şehir / İlçe', 'İstanbul / Kadıköy'),
            (_formKategori == '2. El Alet' ? 'Fiyat' : 'Bütçe', _formKategori == '2. El Alet' ? '₺2.000' : '₺300–500/seans'),
          ].map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.$1.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MetoColors.mutedFg)),
                const SizedBox(height: 8),
                TextField(decoration: InputDecoration(hintText: f.$2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: MetoColors.card)),
              ],
            ),
          )),
          if (_formKategori == '2. El Alet') ...[
            const Text('FOTOĞRAFLAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MetoColors.mutedFg)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._formPhotos.asMap().entries.map((e) => Stack(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(12), border: Border.all(color: MetoColors.border)),
                      child: const Center(child: Text('📷', style: TextStyle(fontSize: 24))),
                    ),
                    if (e.key == 0)
                      const Positioned(left: 4, bottom: 4, child: Text('Kapak', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _formPhotos.removeAt(e.key)),
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
                if (_formPhotos.length < 6)
                  InkWell(
                    onTap: () => setState(() => _formPhotos.add(formPhotoColors[_formPhotos.length % formPhotoColors.length])),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: MetoColors.muted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetoColors.border, style: BorderStyle.solid),
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add), Text('Ekle', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]),
                    ),
                  ),
              ],
            ),
            if (_formPhotos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('⚠ Fotoğraf eklemek satışı hızlandırır', style: TextStyle(fontSize: 12, color: Color(0xFFD97706))),
              ),
            const SizedBox(height: 16),
          ],
          const Text('AÇIKLAMA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MetoColors.mutedFg)),
          const SizedBox(height: 8),
          TextField(
            controller: _formAciklama,
            maxLines: 4,
            onChanged: _handleAciklama,
            decoration: InputDecoration(
              hintText: 'Detaylı bilgi, tercihleriniz... (telefon/e-posta yazmayın)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: MetoColors.card,
            ),
          ),
          if (_aciklamaUyari.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Text(_aciklamaUyari, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: MetoColors.muted, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: MetoColors.primary),
                SizedBox(width: 8),
                Expanded(child: Text('Telefon, e-posta ve adres bilgileri otomatik olarak engellenir. İletişim yalnızca kredi sistemi üzerinden kurulur.', style: TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onBack,
              style: _primaryBtn,
              icon: const Icon(Icons.add),
              label: const Text('İlanı Yayınla — Ücretsiz', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
