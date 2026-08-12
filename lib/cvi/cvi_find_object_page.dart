import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_colors.dart';

class _Obj {
  const _Obj({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
  final String id;
  final String name;
  final Color color;
  final IconData icon;
}

const _objects = <_Obj>[
  _Obj(id: 'top', name: 'Sarı top', color: Color(0xFFF5C518), icon: Icons.circle),
  _Obj(
    id: 'itfaiye',
    name: 'Kırmızı itfaiye arabası',
    color: Color(0xFFE53935),
    icon: Icons.fire_truck,
  ),
  _Obj(id: 'elma', name: 'Yeşil elma', color: Color(0xFF43A047), icon: Icons.apple),
  _Obj(id: 'balina', name: 'Mavi balina', color: Color(0xFF1E88E5), icon: Icons.water),
  _Obj(
    id: 'ayicik',
    name: 'Turuncu ayıcık',
    color: Color(0xFFFB8C00),
    icon: Icons.pets,
  ),
  _Obj(
    id: 'balon',
    name: 'Mor balon',
    color: Color(0xFF8E24AA),
    icon: Icons.bubble_chart,
  ),
  _Obj(
    id: 'cicek',
    name: 'Pembe çiçek',
    color: Color(0xFFEC407A),
    icon: Icons.local_florist,
  ),
  _Obj(
    id: 'kopek',
    name: 'Kahverengi köpek',
    color: Color(0xFF6D4C41),
    icon: Icons.cruelty_free,
  ),
];

String _promptFor(_Obj o) {
  const map = {
    'top': 'Sarı topu göster',
    'itfaiye': 'Kırmızı itfaiye arabasını göster',
    'elma': 'Yeşil elmayı göster',
    'balina': 'Mavi balinayı göster',
    'ayicik': 'Turuncu ayıcığı göster',
    'balon': 'Mor balonu göster',
    'cicek': 'Pembe çiçeği göster',
    'kopek': 'Kahverengi köpeği göster',
  };
  return map[o.id] ?? '${o.name} göster';
}

/// CVI Görsel Egzersizleri - 2 (3 modül, sakin akış).
class CviFindObjectPage extends StatefulWidget {
  const CviFindObjectPage({super.key});

  @override
  State<CviFindObjectPage> createState() => _CviFindObjectPageState();
}

class _CviFindObjectPageState extends State<CviFindObjectPage> {
  final _rng = Random();
  int _module = 1;
  int _idx = 0;
  int _hardLevel = 1;
  String? _targetId;
  List<_Obj> _shown = const [];
  String _prompt = '';
  String _hint = '';
  bool _locked = false;
  bool _clap = false;

  @override
  void initState() {
    super.initState();
    _applyModule(1);
  }

  void _applyModule(int m) {
    setState(() {
      _module = m;
      _locked = false;
      _clap = false;
      if (m == 1) {
        _targetId = null;
        _shown = [_objects[_idx]];
        _prompt = _objects[_idx].name;
        _hint = 'Ekranda dursun. Anne/baba objeyi göstersin. Acele yok.';
      } else if (m == 2) {
        _renderFind();
      } else {
        _renderHard();
      }
    });
  }

  void _renderFind() {
    final target = _objects[_rng.nextInt(_objects.length)];
    final others = (_objects.where((o) => o.id != target.id).toList()..shuffle(_rng))
        .take(2)
        .toList();
    _targetId = target.id;
    _shown = [target, ...others]..shuffle(_rng);
    _prompt = _promptFor(target);
    _hint = 'Üç obje ekranda kalır. Doğru olana birlikte dokunun.';
    _locked = false;
    _clap = false;
  }

  void _renderHard() {
    final item = _objects[_idx % _objects.length];
    _locked = false;
    _clap = false;
    if (_hardLevel == 1 || _hardLevel == 2) {
      _targetId = null;
      _shown = [item];
      _prompt = item.name;
      _hint = _hardLevel == 1
          ? 'Seviye 1: Siyah zemin, tek obje. Birlikte bakın.'
          : 'Seviye 2: Çizgili zemin. Obje hâlâ ekranda; stres yok.';
    } else {
      _targetId = item.id;
      final others =
          (_objects.where((o) => o.id != item.id).toList()..shuffle(_rng))
              .take(2)
              .toList();
      _shown = [item, ...others]..shuffle(_rng);
      _prompt = _promptFor(item);
      _hint = 'Seviye 3: Üç obje içinde hedefi bulun.';
    }
  }

  void _nextObject() {
    setState(() {
      _idx = (_idx + 1) % _objects.length;
      if (_module == 1) {
        _shown = [_objects[_idx]];
        _prompt = _objects[_idx].name;
      } else if (_module == 3) {
        _renderHard();
      }
    });
  }

  void _onPick(_Obj o) {
    if (_locked || _targetId == null) return;
    if (o.id == _targetId) {
      setState(() {
        _locked = true;
        _clap = true;
        _hint = 'Harika! Doğru obje.';
      });
      Future<void>.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          _clap = false;
          if (_module == 2) {
            _renderFind();
          } else if (_module == 3 && _hardLevel == 3) {
            _idx = (_idx + 1) % _objects.length;
            _renderHard();
          } else {
            _locked = false;
          }
        });
      });
    } else {
      setState(() => _hint = 'Birlikte tekrar bakalım — acele yok.');
    }
  }

  BoxDecoration get _stageDecoration {
    if (_module == 1 || (_module == 3 && _hardLevel == 1)) {
      return BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      );
    }
    if (_module == 3 && _hardLevel == 2) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF111111),
            Color(0xFF333333),
            Color(0xFF111111),
            Color(0xFF333333),
            Color(0xFF111111),
            Color(0xFF333333),
          ],
          stops: [0, 0.16, 0.33, 0.5, 0.66, 1],
        ),
      );
    }
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CviColors.border),
    );
  }

  bool get _darkText {
    if (_module == 2) return true;
    if (_module == 3 && _hardLevel == 3) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final promptColor = _darkText ? Colors.black87 : Colors.white;
    final hintColor = _darkText ? CviColors.muted : const Color(0xFFCFD8D3);

    return Scaffold(
      backgroundColor: CviColors.bg,
      appBar: AppBar(
        backgroundColor: CviColors.card,
        foregroundColor: CviColors.text,
        title: Text(
          'CVI Görsel Egzersizleri - 2',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Görsel dikkat için sakin bir oyun. Objeler ekranda kalır; anne/baba birlikte gösterir. Acele yok.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CviColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ModChip(
                label: 'Modül 1 · Tek Obje',
                active: _module == 1,
                onTap: () => _applyModule(1),
              ),
              _ModChip(
                label: 'Modül 2 · Doğruyu Bul',
                active: _module == 2,
                onTap: () => _applyModule(2),
              ),
              _ModChip(
                label: 'Modül 3 · Zorluk',
                active: _module == 3,
                onTap: () => _applyModule(3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_module == 1)
            FilledButton(
              onPressed: _nextObject,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF0F5132),
              ),
              child: Text(
                'Yeni Obje',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            )
          else if (_module == 2)
            FilledButton(
              onPressed: () => setState(_renderFind),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF0F5132),
              ),
              child: Text(
                'Yeni Soru',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            )
          else
            Row(
              children: [
                for (var lv = 1; lv <= 3; lv++) ...[
                  if (lv > 1) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _hardLevel = lv;
                        _renderHard();
                      }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor:
                            _hardLevel == lv ? CviColors.primary : Colors.white,
                        foregroundColor:
                            _hardLevel == lv ? Colors.white : CviColors.primary,
                        side: const BorderSide(color: CviColors.primary, width: 2),
                      ),
                      child: Text(
                        'Seviye $lv',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 0.88,
            child: DecoratedBox(
              decoration: _stageDecoration,
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Text(
                      _prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: promptColor,
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 48, 8, 40),
                      child: _shown.length == 1
                          ? _ObjTile(
                              obj: _shown.first,
                              big: true,
                              darkLabel: !_darkText,
                              onTap: _targetId == null
                                  ? null
                                  : () => _onPick(_shown.first),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final o in _shown)
                                  _ObjTile(
                                    obj: o,
                                    big: false,
                                    darkLabel: !_darkText,
                                    onTap: () => _onPick(o),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      _hint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hintColor,
                      ),
                    ),
                  ),
                  if (_clap)
                    Container(
                      alignment: Alignment.center,
                      color: Colors.black26,
                      child: const Text('👏', style: TextStyle(fontSize: 64)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              border: Border(
                left: BorderSide(color: Color(0xFFF59E0B), width: 4),
              ),
            ),
            child: Text(
              'Önemli Tıbbi Uyarı: Bu etkinlikler bilgilendirme amaçlıdır. '
              'CVI tanısı ve tedavisi sadece doktor tarafından yapılır. '
              'Bu egzersizler tıbbi tedavi yerine geçmez. Uygulamadan önce '
              'doktorunuza danışın. Engelsiz Club içeriklerden doğabilecek '
              'sonuçlardan sorumlu değildir.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Color(0xFF44403C),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu etkinlik CVI görsel erişim prensiplerine göre Engelsiz Club tarafından hazırlanmıştır.',
            style: GoogleFonts.nunito(fontSize: 12, color: CviColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ModChip extends StatelessWidget {
  const _ModChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: CviColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: active
            ? const BorderSide(color: Color(0xFF86EFAC), width: 3)
            : BorderSide.none,
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _ObjTile extends StatelessWidget {
  const _ObjTile({
    required this.obj,
    required this.big,
    required this.darkLabel,
    this.onTap,
  });
  final _Obj obj;
  final bool big;
  final bool darkLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = big ? 200.0 : 100.0;
    return Semantics(
      button: onTap != null,
      label: obj.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: obj.color,
                  shape: big && obj.id == 'top'
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: obj.id == 'top'
                      ? null
                      : BorderRadius.circular(big ? 28 : 18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  obj.icon,
                  size: big ? 72 : 40,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                obj.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: big ? 13 : 11,
                  fontWeight: FontWeight.w800,
                  color: darkLabel ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
