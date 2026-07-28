import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cards_data.dart';
import '../meto_theme.dart';
import '../services/app_catalog_service.dart';
import '../services/catalog_adapters.dart';
import '../widgets/catalog_media.dart';

/// Klavye tuşu gibi kısa titreşim (cihaz destekliyorsa).
void _kartHaptic() {
  HapticFeedback.selectionClick();
  HapticFeedback.lightImpact();
}

/// Figma Make `KartlarTab` — Flutter port with edit mode, custom cards, TTS.
class KartlarPage extends StatefulWidget {
  const KartlarPage({super.key});

  @override
  State<KartlarPage> createState() => _KartlarPageState();
}

class _KartlarPageState extends State<KartlarPage> {
  NeedCard? _activeCard;
  String _activeCategory = 'tümü';
  bool _editMode = false;
  NeedCard? _editingCard;
  bool _addingNew = false;
  List<NeedCard> _customCards = [];
  Map<int, Map<String, dynamic>> _overrides = {};
  bool _loaded = false;

  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPersisted();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final customRaw = prefs.getString(kCustomCardsPrefsKey);
      if (customRaw != null && customRaw.isNotEmpty) {
        final list = jsonDecode(customRaw) as List<dynamic>;
        _customCards = list
            .map((e) => NeedCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      _customCards = [];
    }
    try {
      final ovrRaw = prefs.getString(kCardOverridesPrefsKey);
      if (ovrRaw != null && ovrRaw.isNotEmpty) {
        final map = jsonDecode(ovrRaw) as Map<String, dynamic>;
        _overrides = {
          for (final e in map.entries)
            int.parse(e.key): Map<String, dynamic>.from(e.value as Map),
        };
      }
    } catch (_) {
      _overrides = {};
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveCustomCards(List<NeedCard> cards) async {
    setState(() => _customCards = cards);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kCustomCardsPrefsKey,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _saveOverrides(Map<int, Map<String, dynamic>> ovr) async {
    setState(() => _overrides = ovr);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kCardOverridesPrefsKey,
      jsonEncode({for (final e in ovr.entries) '${e.key}': e.value}),
    );
  }

  List<NeedCard> get _allCards {
    final builtIn = CatalogAdapters.needCards().map((c) {
      final ovr = _overrides[c.id];
      return ovr != null ? c.applyOverride(ovr) : c;
    });
    return [...builtIn, ..._customCards];
  }

  List<NeedCard> get _filtered {
    if (_activeCategory == 'tümü') return _allCards;
    if (_activeCategory == 'ozel') return _customCards;
    return _allCards.where((c) => c.category == _activeCategory).toList();
  }

  Future<void> _speakCard(NeedCard card) async {
    await _tts.stop();
    await _tts.speak(card.label);
  }

  void _openEdit(NeedCard card, {bool isNew = false}) {
    setState(() {
      _editingCard = card;
      _addingNew = isNew;
      _activeCard = null;
    });
  }

  Future<void> _onSaveEdit(NeedCard draft) async {
    if (draft.label.trim().isEmpty) return;
    if (_addingNew) {
      final newCard = draft.copyWith(
        id: DateTime.now().millisecondsSinceEpoch,
        isCustom: true,
      );
      await _saveCustomCards([..._customCards, newCard]);
    } else if (draft.isCustom) {
      await _saveCustomCards(
        _customCards.map((c) => c.id == draft.id ? draft : c).toList(),
      );
    } else {
      final next = Map<int, Map<String, dynamic>>.from(_overrides);
      next[draft.id] = draft.toOverrideJson();
      await _saveOverrides(next);
    }
    if (mounted) {
      setState(() {
        _editingCard = null;
        _addingNew = false;
      });
    }
  }

  Future<void> _onDeleteEdit(NeedCard card) async {
    if (card.isCustom) {
      await _saveCustomCards(
          _customCards.where((c) => c.id != card.id).toList());
    } else {
      final next = Map<int, Map<String, dynamic>>.from(_overrides);
      next.remove(card.id);
      await _saveOverrides(next);
    }
    if (mounted) {
      setState(() {
        _editingCard = null;
        _addingNew = false;
      });
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ColoredBox(
        color: MetoColors.background,
        child:
            Center(child: CircularProgressIndicator(color: MetoColors.primary)),
      );
    }

    return ListenableBuilder(
      listenable: AppCatalogService.instance,
      builder: (context, _) => Stack(
      children: [
        ColoredBox(
          color: MetoColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'İletişim Kartları',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _editMode
                                ? 'Düzenleme modu — bir karta dokunarak özelleştir'
                                : 'Karta dokunarak sesli okut',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _editMode ? MetoColors.primary : MetoColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() {
                          _editMode = !_editMode;
                          _activeCard = null;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _editMode ? Icons.close : Icons.edit_outlined,
                                size: 13,
                                color: _editMode
                                    ? Colors.white
                                    : MetoColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _editMode ? 'Bitti' : 'Düzenle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _editMode
                                      ? Colors.white
                                      : MetoColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: kCardCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = kCardCategories[i];
                    final active = _activeCategory == cat.id;
                    return _CategoryChip(
                      label: cat.label,
                      active: active,
                      onTap: () => setState(() => _activeCategory = cat.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filtered.length + (_editMode ? 1 : 0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, i) {
                        if (_editMode && i == _filtered.length) {
                          return _AddCardTile(
                            onTap: () {
                              _openEdit(
                                const NeedCard(
                                  id: 0,
                                  label: '',
                                  emoji: '⭐',
                                  color: Color(0xFF1A6B4A),
                                  bg: Color(0xFFE8F5EE),
                                  category: 'ozel',
                                  isCustom: true,
                                ),
                                isNew: true,
                              );
                            },
                          );
                        }
                        final card = _filtered[i];
                        return _CardTile(
                          card: card,
                          editMode: _editMode,
                          onTap: () {
                            if (_editMode) {
                              _openEdit(card);
                            } else {
                              _kartHaptic();
                              setState(() => _activeCard = card);
                              _speakCard(card);
                            }
                          },
                        );
                      },
                    ),
                    if (!_editMode) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MetoColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MetoColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.volume_up_outlined,
                                  size: 16,
                                  color: MetoColors.primary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Sesli Okuma',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Karta dokunduğunuzda tam ekran açılır ve Türkçe sesli okuma başlar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: MetoColors.mutedFg,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MetoColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: MetoColors.primary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: MetoColors.primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Kartları Kişiselleştir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: MetoColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MetoColors.mutedFg,
                                  height: 1.45,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sağ üstteki ',
                                  ),
                                  TextSpan(
                                    text: 'Düzenle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' butonuna basarak kartlara fotoğraf ekleyebilir, yazıyı değiştirebilir veya yeni kartlar oluşturabilirsiniz.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_activeCard != null && !_editMode)
          _CardOverlay(
            card: _activeCard!,
            onClose: () => setState(() => _activeCard = null),
            onSpeak: () => _speakCard(_activeCard!),
          ),
        if (_editingCard != null)
          _EditCardSheet(
            card: _editingCard!,
            isNew: _addingNew,
            onClose: () => setState(() {
              _editingCard = null;
              _addingNew = false;
            }),
            onSave: _onSaveEdit,
            onDelete: _addingNew ? null : () => _onDeleteEdit(_editingCard!),
          ),
      ],
    ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}

Widget? _cardPhotoWidget(String? photo,
    {required double size, BorderRadius? radius}) {
  if (photo == null || photo.isEmpty) return null;
  final src = photo.trim();
  final lower = src.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/')) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(12),
      child: CatalogImage(
        source: src,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
  final bytes = decodeCardPhoto(photo);
  if (bytes == null) return null;
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(12),
    child: Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

Uint8List? decodeCardPhoto(String photo) {
  try {
    var data = photo;
    if (data.contains(',')) {
      data = data.split(',').last;
    }
    return Uint8List.fromList(base64Decode(data));
  } catch (_) {
    return null;
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.onTap,
    required this.editMode,
  });

  final NeedCard card;
  final VoidCallback onTap;
  final bool editMode;

  @override
  Widget build(BuildContext context) {
    final photo = _cardPhotoWidget(card.photo, size: 56);

    return Material(
      color: card.bg,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: card.color, width: 3),
          ),
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (photo != null)
                    photo
                  else
                    Text(card.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  Text(
                    card.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: card.color,
                    ),
                  ),
                  if (card.isCustom)
                    Text(
                      'özel',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: card.color.withValues(alpha: 0.60),
                      ),
                    ),
                ],
              ),
              if (editMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: card.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F9F4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: MetoColors.primary),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 24, color: MetoColors.primary),
                SizedBox(height: 4),
                Text(
                  'Yeni Kart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.primary,
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CardOverlay extends StatefulWidget {
  const _CardOverlay({
    required this.card,
    required this.onClose,
    required this.onSpeak,
  });

  final NeedCard card;
  final VoidCallback onClose;
  final VoidCallback onSpeak;

  @override
  State<_CardOverlay> createState() => _CardOverlayState();
}

class _CardOverlayState extends State<_CardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _pulse());
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _pulse() async {
    _kartHaptic();
    if (!mounted) return;
    await _shake.forward(from: 0);
  }

  void _onVisualTap() {
    _pulse();
    widget.onSpeak();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width - 32).clamp(280.0, 440.0);
    final visualSize = (cardWidth * 0.62).clamp(180.0, 280.0);
    final photo = _cardPhotoWidget(
      card.photo,
      size: visualSize,
      radius: BorderRadius.circular(20),
    );

    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      child: SafeArea(
        child: Center(
          child: Container(
            width: cardWidth,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            decoration: BoxDecoration(
              color: card.bg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: card.color, width: 6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -28,
                  right: -12,
                  child: Material(
                    color: card.color,
                    elevation: 4,
                    shadowColor: Colors.black38,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: widget.onClose,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) {
                        final t = _shake.value;
                        final dx = (1 - t) *
                            6 *
                            ((t * 10).floor().isEven ? 1 : -1) *
                            (t < 1 ? (1 - t) : 0);
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onVisualTap,
                          borderRadius: BorderRadius.circular(20),
                          child: photo ??
                              Text(
                                card.emoji,
                                style: TextStyle(fontSize: visualSize * 0.55),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      card.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: card.color,
                        height: 1.15,
                      ),
                    ),
                    if (card.desc != null && card.desc!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        card.desc!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: card.color.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Material(
                      color: card.color,
                      borderRadius: BorderRadius.circular(999),
                      elevation: 4,
                      shadowColor: card.color.withValues(alpha: 0.4),
                      child: InkWell(
                        onTap: () {
                          _kartHaptic();
                          widget.onSpeak();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.volume_up,
                                size: 22,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Sesli Oku',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kapatmak için X işaretine bas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: card.color.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditCardSheet extends StatefulWidget {
  const _EditCardSheet({
    required this.card,
    required this.isNew,
    required this.onClose,
    required this.onSave,
    this.onDelete,
  });

  final NeedCard card;
  final bool isNew;
  final VoidCallback onClose;
  final Future<void> Function(NeedCard draft) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_EditCardSheet> createState() => _EditCardSheetState();
}

class _EditCardSheetState extends State<_EditCardSheet> {
  late NeedCard _draft;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _draft = widget.card;
    _labelCtrl = TextEditingController(text: _draft.label);
    _descCtrl = TextEditingController(text: _draft.desc ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = file.mimeType ?? 'image/jpeg';
    setState(() {
      _draft = _draft.copyWith(photo: 'data:$mime;base64,$b64');
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _draft.label.trim().isNotEmpty;
    final photoBytes =
        _draft.photo != null ? decodeCardPhoto(_draft.photo!) : null;

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: MetoColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isNew ? 'Yeni Kart Ekle' : 'Kartı Düzenle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                        ),
                        Material(
                          color: MetoColors.muted,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: widget.onClose,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                size: 15,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: MetoColors.border),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Fotoğraf (isteğe bağlı)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              height: 128,
                              decoration: BoxDecoration(
                                color: _draft.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _draft.color,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: photoBytes != null
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          photoBytes,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: Material(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              onTap: () => setState(() {
                                                _draft = _draft.copyWith(
                                                  clearPhoto: true,
                                                );
                                              }),
                                              customBorder:
                                                  const CircleBorder(),
                                              child: const Padding(
                                                padding: EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 12,
                                                  color: Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _draft.emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fotoğraf ekle',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _draft.color,
                                          ),
                                        ),
                                        const Text(
                                          'Galeriden seç',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: MetoColors.mutedFg,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'İfade (Kart yazısı)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _labelCtrl,
                            onChanged: (v) => setState(() {
                              _draft = _draft.copyWith(label: v);
                            }),
                            decoration: InputDecoration(
                              hintText: 'Örn: Elma, Salıncak, Dede...',
                              filled: true,
                              fillColor: MetoColors.muted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MetoColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Açıklama (isteğe bağlı)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _descCtrl,
                            onChanged: (v) => setState(() {
                              _draft = _draft.copyWith(
                                desc: v,
                                clearDesc: v.isEmpty,
                              );
                            }),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Bu kartın ne anlama geldiğini yazın...',
                              filled: true,
                              fillColor: MetoColors.muted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: MetoColors.foreground,
                            ),
                          ),
                          if (photoBytes == null) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Simge',
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
                                for (final em in kCardEmojis)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _draft = _draft.copyWith(emoji: em);
                                    }),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _draft.emoji == em
                                            ? _draft.color.withValues(
                                                alpha: 0.20,
                                              )
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _draft.emoji == em
                                              ? _draft.color
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        em,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Renk',
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
                              for (final p in kCardPalette)
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _draft = _draft.copyWith(
                                      color: p.color,
                                      bg: p.bg,
                                    );
                                  }),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: p.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorToHex(_draft.color) ==
                                                colorToHex(p.color)
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 4,
                                      ),
                                      boxShadow: colorToHex(_draft.color) ==
                                              colorToHex(p.color)
                                          ? [
                                              BoxShadow(
                                                color: p.color,
                                                spreadRadius: 3,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Kategori',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final catId = kCardEditCategories.any(
                                (c) => c.id == _draft.category,
                              )
                                  ? _draft.category
                                  : 'ozel';
                              return DropdownButtonFormField<String>(
                                key: ValueKey(catId),
                                initialValue: catId,
                                items: [
                                  for (final c in kCardEditCategories)
                                    DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.label),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _draft = _draft.copyWith(category: v);
                                  });
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: MetoColors.muted,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: MetoColors.foreground,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Önizleme',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              width: 96,
                              constraints: const BoxConstraints(minHeight: 90),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _draft.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _draft.color,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (photoBytes != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        photoBytes,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Text(
                                      _draft.emoji,
                                      style: const TextStyle(fontSize: 36),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _draft.label.trim().isEmpty
                                        ? 'İfade'
                                        : _draft.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      color: _draft.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Material(
                            color: canSave
                                ? _draft.color
                                : _draft.color.withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap:
                                  canSave ? () => widget.onSave(_draft) : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Text(
                                  widget.isNew
                                      ? 'Kartı Ekle'
                                      : 'Değişiklikleri Kaydet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.onDelete != null) ...[
                            const SizedBox(height: 8),
                            Material(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: widget.onDelete,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    widget.card.isCustom
                                        ? 'Kartı Sil'
                                        : 'Özelleştirmeyi Sıfırla',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
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
      ),
    );
  }
}
