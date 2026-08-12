import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_colors.dart';

class _CviObj {
  const _CviObj({
    required this.asset,
    required this.label,
  });
  final String asset;
  final String label;
}

const _objs = <String, _CviObj>{
  'top-sari': _CviObj(
    asset: 'assets/cvi/find/top-sari.svg',
    label: 'Sarı top',
  ),
  'top-kirmizi': _CviObj(
    asset: 'assets/cvi/find/top-kirmizi.svg',
    label: 'Kırmızı top',
  ),
  'top-yesil': _CviObj(
    asset: 'assets/cvi/find/top-yesil.svg',
    label: 'Yeşil top',
  ),
  'araba-kirmizi': _CviObj(
    asset: 'assets/cvi/find/araba-kirmizi.svg',
    label: 'Kırmızı araba',
  ),
  'araba-sari': _CviObj(
    asset: 'assets/cvi/find/araba-sari.svg',
    label: 'Sarı araba',
  ),
  'elma-yesil': _CviObj(
    asset: 'assets/cvi/find/elma-yesil.svg',
    label: 'Yeşil elma',
  ),
  'elma-kirmizi': _CviObj(
    asset: 'assets/cvi/find/elma-kirmizi.svg',
    label: 'Kırmızı elma',
  ),
};

const _l1Pool = ['top-sari', 'araba-kirmizi', 'elma-yesil'];

const _l2Sets = <({String target, List<String> distractors})>[
  (target: 'top-sari', distractors: ['top-kirmizi', 'top-yesil']),
  (target: 'top-kirmizi', distractors: ['top-sari', 'top-yesil']),
  (target: 'araba-sari', distractors: ['araba-kirmizi', 'top-yesil']),
  (target: 'elma-kirmizi', distractors: ['elma-yesil', 'top-sari']),
  (target: 'elma-yesil', distractors: ['elma-kirmizi', 'top-kirmizi']),
];

/// CVI Görsel Egzersizleri - 2: Objeyi Bul.
class CviFindObjectPage extends StatefulWidget {
  const CviFindObjectPage({super.key});

  @override
  State<CviFindObjectPage> createState() => _CviFindObjectPageState();
}

class _CviFindObjectPageState extends State<CviFindObjectPage> {
  final _rng = Random();
  int? _level;
  bool _darkBg = true;
  bool _locked = false;
  String? _targetKey;
  List<String> _keys = const [];
  String _prompt = 'Başlamak için Seviye 1 veya Seviye 2’ye dokunun.';
  String _feedback = '';

  void _startLevel(int level) {
    setState(() {
      _level = level;
      _locked = false;
      _feedback = '';
      if (level == 1) {
        final key = _l1Pool[_rng.nextInt(_l1Pool.length)];
        _targetKey = key;
        _keys = [key];
        _prompt = '${_objs[key]!.label} — dokun';
      } else {
        final set = _l2Sets[_rng.nextInt(_l2Sets.length)];
        _targetKey = set.target;
        _keys = [set.target, ...set.distractors]..shuffle(_rng);
        _prompt = '${_objs[set.target]!.label} bul';
      }
    });
  }

  void _onPick(String key) {
    if (_locked || _targetKey == null) return;
    if (key == _targetKey) {
      setState(() {
        _feedback = 'Harika! Doğru obje.';
        _locked = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _level == null) return;
        _startLevel(_level!);
      });
    } else {
      setState(() => _feedback = 'Tekrar dene.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playBg = _darkBg ? Colors.black : Colors.white;
    final promptColor = _darkBg ? Colors.white : Colors.black87;
    final fbColor = _darkBg ? const Color(0xFF86EFAC) : CviColors.primary;

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
            'CVI’lı çocuklar için görsel dikkat egzersizi. Sade zemin, tek obje ile başlayın.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CviColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LevelBtn(
                  label: 'Seviye 1',
                  active: _level == 1,
                  onTap: () => _startLevel(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LevelBtn(
                  label: 'Seviye 2',
                  active: _level == 2,
                  onTap: () => _startLevel(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => setState(() => _darkBg = !_darkBg),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: CviColors.primary,
              side: const BorderSide(color: CviColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _darkBg ? 'Zemin: Siyah' : 'Zemin: Beyaz',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 0.85,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: playBg,
                borderRadius: BorderRadius.circular(18),
              ),
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
                  if (_keys.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Başlamak için Seviye 1 veya Seviye 2’ye dokunun.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: _darkBg ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    )
                  else if (_keys.length == 1)
                    Center(
                      child: _ObjButton(
                        obj: _objs[_keys.first]!,
                        size: 220,
                        onTap: () => _onPick(_keys.first),
                      ),
                    )
                  else
                    Align(
                      alignment: const Alignment(0, 0.15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final k in _keys)
                            _ObjButton(
                              obj: _objs[k]!,
                              size: 110,
                              onTap: () => _onPick(k),
                            ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 14,
                    child: Text(
                      _feedback,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: fbColor,
                      ),
                    ),
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
              'Önemli Tıbbi Uyarı: Bu etkinlik bilgilendirme amaçlıdır. '
              'CVI tanısı ve tedavisi sadece doktor ve görme rehabilitasyon '
              'uzmanı tarafından konulur. Bu egzersizler tıbbi tedavi yerine '
              'geçmez. Çocuğunuzun durumuna uygun olup olmadığını mutlaka '
              'doktorunuza danışın. Engelsiz Club içeriklerden doğabilecek '
              'sonuçlardan sorumlu değildir.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: const Color(0xFF44403C),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bu etkinlik CVI görsel erişim prensiplerine göre Engelsiz Club tarafından hazırlanmıştır.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: CviColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBtn extends StatelessWidget {
  const _LevelBtn({
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
        minimumSize: const Size.fromHeight(56),
        backgroundColor: CviColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: active
              ? const BorderSide(color: Color(0xFF86EFAC), width: 3)
              : BorderSide.none,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ObjButton extends StatelessWidget {
  const _ObjButton({
    required this.obj,
    required this.size,
    required this.onTap,
  });

  final _CviObj obj;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obj.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(
            obj.asset,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
