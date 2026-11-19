import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../data/rights_data.dart';
import '../hak/hak_dosyasi.dart';
import '../hak/hak_dosyasi_admin_sheet.dart';
import '../hak/hak_kural.dart';
import '../hak/hak_takip_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../metobot/metobot_chat_service.dart';
import '../metobot/metobot_cost.dart';
import '../widgets/guest_gate.dart';
import 'uzman_kosesi_page.dart';

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

int? _gunSayisiFromSure(String sure) {
  final m = RegExp(r'(\d+)\s*gün', caseSensitive: false).firstMatch(sure);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String _uygunlukLabel(HakUygunluk? u) {
  switch (u) {
    case HakUygunluk.buyukIhtimalle:
      return 'Büyük ihtimalle hakkınız var';
    case HakUygunluk.sartlaraBagli:
      return 'Şartlara bağlı, kontrol edin';
    case HakUygunluk.uygunDegil:
      return 'Uygun görünmüyor';
    case null:
      return '';
  }
}

Color _uygunlukColor(HakUygunluk? u) {
  switch (u) {
    case HakUygunluk.buyukIhtimalle:
      return const Color(0xFF15803D);
    case HakUygunluk.sartlaraBagli:
      return const Color(0xFFA16207);
    case HakUygunluk.uygunDegil:
      return const Color(0xFF6B7280);
    case null:
      return MetoColors.mutedFg;
  }
}

String hakDosyasiPlainText(HakDosyasi d, RightItem item) {
  final buf = StringBuffer();
  buf.writeln(item.title);
  if (item.amount.trim().isNotEmpty) buf.writeln(item.amount);
  if (d.ozet.trim().isNotEmpty) {
    buf.writeln('Özet: ${d.ozet}');
  } else if (item.desc.trim().isNotEmpty) {
    buf.writeln(item.desc);
  }
  if (d.kimler.isNotEmpty) {
    buf.writeln('Kimler:');
    for (final k in d.kimler) {
      buf.writeln('- ${k.metin}');
    }
  }
  if (d.kimlerAlamaz.isNotEmpty) {
    buf.writeln('Kimler alamaz:');
    for (final s in d.kimlerAlamaz) {
      buf.writeln('- $s');
    }
  }
  if (d.adimlar.isNotEmpty) {
    buf.writeln('Adımlar:');
    for (var i = 0; i < d.adimlar.length; i++) {
      final a = d.adimlar[i];
      buf.writeln('${i + 1}. ${a.baslik}: ${a.aciklama}');
    }
  } else if (item.steps.isNotEmpty) {
    buf.writeln('Adımlar:');
    for (var i = 0; i < item.steps.length; i++) {
      buf.writeln('${i + 1}. ${item.steps[i]}');
    }
  }
  if (d.belgeler.isNotEmpty) {
    buf.writeln('Belgeler:');
    for (final b in d.belgeler) {
      buf.writeln('- ${b.ad} (Nereden: ${b.nereden})');
    }
  }
  if (d.sure.trim().isNotEmpty) buf.writeln('Süre: ${d.sure}');
  if (d.sonrasi.trim().isNotEmpty) buf.writeln('Sonrası: ${d.sonrasi}');
  if (d.retSebepleri.isNotEmpty) {
    buf.writeln('Ret sebepleri:');
    for (final s in d.retSebepleri) {
      buf.writeln('- $s');
    }
  }
  if (!d.itiraz.bos) {
    buf.writeln('İtiraz: ${d.itiraz.yol} ${d.itiraz.sure}'.trim());
  }
  if (d.hakKaybi.isNotEmpty) {
    buf.writeln('Hak kaybı:');
    for (final s in d.hakKaybi) {
      buf.writeln('- $s');
    }
  }
  if (d.birlikte.isNotEmpty) {
    buf.writeln('Birlikte:');
    for (final s in d.birlikte) {
      buf.writeln('- $s');
    }
  }
  if (d.sss.isNotEmpty) {
    buf.writeln('SSS:');
    for (final s in d.sss) {
      buf.writeln('S: ${s.soru}');
      buf.writeln('C: ${s.cevap}');
    }
  }
  if (d.iletisim.isNotEmpty) {
    buf.writeln('İletişim:');
    for (final i in d.iletisim) {
      buf.writeln('- ${i.ad} ${i.telefon ?? ''} ${i.link ?? ''}'.trim());
    }
  }
  if (d.kaynaklar.isNotEmpty) {
    buf.writeln('Kaynaklar:');
    for (final k in d.kaynaklar) {
      buf.writeln('- ${k.ad}: ${k.url}');
    }
  }
  return buf.toString().trim();
}

/// Hak dosyası detay sayfası.
class HakDosyasiPage extends StatefulWidget {
  const HakDosyasiPage({super.key, required this.item});

  final RightItem item;

  static Future<void> open(BuildContext context, RightItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HakDosyasiPage(item: item),
      ),
    );
  }

  @override
  State<HakDosyasiPage> createState() => _HakDosyasiPageState();
}

class _HakDosyasiPageState extends State<HakDosyasiPage> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _loading = true;
  HakDosyasi _dosya = const HakDosyasi();
  HakProfil _profil = const HakProfil();
  HakTakip _takip = const HakTakip(hakId: '');
  HakUygunluk? _uygunluk;
  final Set<String> _openSections = {'ozet', 'sartlar'};
  final Set<String> _openSss = {};

  String get _userEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  bool get _isAdmin => isAppAdmin(_userEmail);

  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    _takip = HakTakip(hakId: widget.item.id);
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _load() async {
    final dosya = hakDosyasiOf(widget.item.id) ?? const HakDosyasi();
    final profil = await hakProfilYukle();
    final takipMap = await hakTakipYukle();
    final takip = takipMap[widget.item.id] ?? HakTakip(hakId: widget.item.id);
    final u = dosya.bos
        ? null
        : uygunlukKural(dosya, cevaplarWithDerived(profil.cevaplar));
    if (!mounted) return;
    setState(() {
      _dosya = dosya;
      _profil = profil;
      _takip = takip;
      _uygunluk = u;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final parts = <String>[];
    if (_dosya.ozet.trim().isNotEmpty) {
      parts.add(_dosya.ozet);
    } else if (widget.item.desc.trim().isNotEmpty) {
      parts.add(widget.item.desc);
    }
    if (_dosya.adimlar.isNotEmpty) {
      for (var i = 0; i < _dosya.adimlar.length; i++) {
        final a = _dosya.adimlar[i];
        parts.add('${i + 1}. ${a.baslik}. ${a.aciklama}');
      }
    } else {
      for (var i = 0; i < widget.item.steps.length; i++) {
        parts.add('${i + 1}. ${widget.item.steps[i]}');
      }
    }
    final text = parts.join('\n');
    if (text.trim().isEmpty) return;
    setState(() => _speaking = true);
    await _tts.speak(text);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  Future<void> _setDurum(String durum) async {
    final now = DateTime.now();
    var basvuru = _takip.basvuruTarihi;
    var sonuc = _takip.sonucTarihi;
    var itirazSon = _takip.itirazSonTarih;

    if (durum == 'basvurdum' || durum == 'bekliyor') {
      basvuru ??= DateTime(now.year, now.month, now.day);
    }
    if (durum == 'onaylandi' || durum == 'reddedildi') {
      basvuru ??= DateTime(now.year, now.month, now.day);
      sonuc ??= DateTime(now.year, now.month, now.day);
    }
    if (durum != 'reddedildi') {
      itirazSon = null;
    } else {
      final gun = _gunSayisiFromSure(_dosya.itiraz.sure);
      if (gun != null && sonuc != null) {
        itirazSon = sonuc.add(Duration(days: gun));
      }
    }

    final next = HakTakip(
      hakId: widget.item.id,
      durum: durum,
      belgeler: _takip.belgeler,
      basvuruTarihi: basvuru,
      sonucTarihi: sonuc,
      itirazSonTarih: itirazSon,
      notlar: _takip.notlar,
    );
    await hakTakipKaydet(next);
    if (!mounted) return;
    setState(() => _takip = next);

    if (durum == 'reddedildi') {
      await _pickRetTeblig();
    }
  }

  Future<void> _pickRetTeblig() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takip.sonucTarihi ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Ret tebliğ tarihi',
    );
    if (picked == null || !mounted) return;
    final gun = _gunSayisiFromSure(_dosya.itiraz.sure);
    final itirazSon =
        gun == null ? _takip.itirazSonTarih : picked.add(Duration(days: gun));
    final next = HakTakip(
      hakId: widget.item.id,
      durum: _takip.durum,
      belgeler: _takip.belgeler,
      basvuruTarihi: _takip.basvuruTarihi,
      sonucTarihi: picked,
      itirazSonTarih: itirazSon,
      notlar: _takip.notlar,
    );
    await hakTakipKaydet(next);
    if (!mounted) return;
    setState(() => _takip = next);
  }

  Future<void> _toggleBelge(String ad, bool ok) async {
    final list = [
      for (final e in _takip.belgeler)
        if ((e['ad']?.toString() ?? '') != ad) Map<String, dynamic>.from(e),
    ];
    list.add({'ad': ad, 'ok': ok});
    final next = HakTakip(
      hakId: widget.item.id,
      durum: _takip.durum,
      belgeler: list,
      basvuruTarihi: _takip.basvuruTarihi,
      sonucTarihi: _takip.sonucTarihi,
      itirazSonTarih: _takip.itirazSonTarih,
      notlar: _takip.notlar,
    );
    await hakTakipKaydet(next);
    if (!mounted) return;
    setState(() => _takip = next);
  }

  bool _belgeOk(String ad) {
    for (final e in _takip.belgeler) {
      if (e['ad']?.toString() == ad) return e['ok'] == true;
    }
    return false;
  }

  Future<void> _openUrl(String? url) async {
    final s = (url ?? '').trim();
    if (s.isEmpty) return;
    final uri = Uri.tryParse(s);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editAdmin() async {
    final ok = await showHakDosyasiAdminSheet(
      context,
      hakId: widget.item.id,
      title: widget.item.title,
    );
    if (ok == true) await _load();
  }

  Future<void> _askMetoBot() async {
    if (_isGuest) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: () {},
        message: 'Bu hak hakkında soru sormak için giriş yapmanız gerekiyor.',
      );
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController();
    String? reply;
    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  L10nText(
                    'Bu hak hakkında soru sor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Sorunuzu yazın…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (reply != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MetoColors.muted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        reply!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: MetoColors.foreground,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final q = controller.text.trim();
                            if (q.isEmpty) return;
                            setSheet(() => busy = true);
                            final plain =
                                hakDosyasiPlainText(_dosya, widget.item);
                            final content =
                                '[Bağlam: Aşağıdaki hak dosyasına dayanarak cevap ver. Bilgi yoksa \'Bu konuda ilgili kuruma danışmanızı öneririm\' de. Hukuki tavsiye verme.]\n$plain\n\n[Soru]: $q';
                            final res = await MetoBotChatService.instance.send(
                              messages: [
                                MetoBotTurn(role: 'user', content: content),
                              ],
                              lastN: 1,
                            );
                            setSheet(() {
                              busy = false;
                              reply = res.ok
                                  ? res.reply
                                  : (res.error ?? 'Yanıt alınamadı.');
                            });
                          },
                    child: Text(busy ? 'Gönderiliyor…' : 'Gönder'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  void _openUzman() {
    UzmanKosesPage.open(
      context,
      userEmail: _userEmail,
      isGuest: _isGuest,
      viewMode: UzmanKosesViewMode.uzmanOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Hak Dosyası',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _speaking ? 'Durdur' : 'Sesli dinle',
            onPressed: _toggleSpeak,
            icon: Icon(_speaking ? Icons.stop : Icons.volume_up_outlined),
          ),
          if (_isAdmin)
            IconButton(
              tooltip: 'Dosyayı düzenle',
              onPressed: _editAdmin,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildHeader(item),
                      const SizedBox(height: 16),
                      _buildTrackingBar(),
                      const SizedBox(height: 16),
                      if (_dosya.bos) ...[
                        _fallbackBody(item),
                      ] else ...[
                        if (_dosya.ozet.trim().isNotEmpty)
                          _section(
                            id: 'ozet',
                            title: 'Özet',
                            child: L10nText(
                              _dosya.ozet,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                        if (_dosya.kimler.isNotEmpty)
                          _section(
                            id: 'sartlar',
                            title: 'Şartları sağlıyor musunuz?',
                            child: Column(
                              children: [
                                for (final k in _dosya.kimler)
                                  _criterionRow(k),
                              ],
                            ),
                          ),
                        if (_dosya.kimlerAlamaz.isNotEmpty)
                          _section(
                            id: 'alamaz',
                            title: 'Kimler alamaz?',
                            child: _bulletList(_dosya.kimlerAlamaz),
                          ),
                        if (_dosya.adimlar.isNotEmpty)
                          _section(
                            id: 'adimlar',
                            title: 'Adım adım başvuru',
                            child: Column(
                              children: [
                                for (var i = 0; i < _dosya.adimlar.length; i++)
                                  _adimRow(i + 1, _dosya.adimlar[i]),
                              ],
                            ),
                          ),
                        if (_dosya.belgeler.isNotEmpty)
                          _section(
                            id: 'belgeler',
                            title: 'Gerekli belgeler',
                            child: Column(
                              children: [
                                for (final b in _dosya.belgeler) _belgeRow(b),
                              ],
                            ),
                          ),
                        if (_dosya.sure.trim().isNotEmpty ||
                            _dosya.sonrasi.trim().isNotEmpty)
                          _section(
                            id: 'sure',
                            title: 'Ne kadar sürer, sonra ne olur?',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_dosya.sure.trim().isNotEmpty)
                                  L10nText(
                                    _dosya.sure,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: MetoColors.foreground,
                                    ),
                                  ),
                                if (_dosya.sonrasi.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  L10nText(
                                    _dosya.sonrasi,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: MetoColors.mutedFg,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (_dosya.retSebepleri.isNotEmpty ||
                            !_dosya.itiraz.bos)
                          _section(
                            id: 'ret',
                            title: 'Ret gelirse ne yapmalı?',
                            child: _retSection(),
                          ),
                        if (_dosya.hakKaybi.isNotEmpty)
                          _section(
                            id: 'kayip',
                            title: 'Hakkınızı kaybetmemek için',
                            child: _bulletList(_dosya.hakKaybi),
                          ),
                        if (_dosya.birlikte.isNotEmpty)
                          _section(
                            id: 'birlikte',
                            title: 'Birlikte alınabilir mi?',
                            child: _bulletList(_dosya.birlikte),
                          ),
                        if (_dosya.sss.isNotEmpty)
                          _section(
                            id: 'sss',
                            title: 'SSS',
                            child: Column(
                              children: [
                                for (var i = 0; i < _dosya.sss.length; i++)
                                  _sssTile(i, _dosya.sss[i]),
                              ],
                            ),
                          ),
                        if (_dosya.iletisim.isNotEmpty)
                          _section(
                            id: 'iletisim',
                            title: 'İletişim',
                            child: Column(
                              children: [
                                for (final i in _dosya.iletisim)
                                  _iletisimRow(i),
                              ],
                            ),
                          ),
                        if (_dosya.kaynaklar.isNotEmpty)
                          _section(
                            id: 'kaynaklar',
                            title: 'Kaynaklar',
                            child: Column(
                              children: [
                                for (final k in _dosya.kaynaklar)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(k.ad),
                                    subtitle: Text(k.url),
                                    trailing: const Icon(Icons.open_in_new,
                                        size: 16),
                                    onTap: () => _openUrl(k.url),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                _bottomBar(),
              ],
            ),
    );
  }

  Widget _buildHeader(RightItem item) {
    final badge = _uygunlukLabel(_uygunluk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        L10nText(
          item.title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: item.color,
          ),
        ),
        if (badge.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _uygunlukColor(_uygunluk).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _uygunlukColor(_uygunluk),
              ),
            ),
          ),
        ],
        if (_dosya.sonGuncelleme != null) ...[
          const SizedBox(height: 8),
          Text(
            'Son güncelleme: ${_fmtDate(_dosya.sonGuncelleme)}',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
        if ((_dosya.uzmanOnayi ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Uzman onaylı: ${_dosya.uzmanOnayi}',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      ],
    );
  }

  Widget _buildTrackingBar() {
    const steps = [
      ('basvurmadim', 'Başvurmadım'),
      ('basvurdum', 'Başvurdum'),
      ('bekliyor', 'Sonuç bekleniyor'),
      ('onaylandi', 'Onaylandı'),
      ('reddedildi', 'Reddedildi'),
    ];
    final itirazGun = _takip.durum == 'reddedildi' &&
            _takip.itirazSonTarih != null
        ? _takip.itirazSonTarih!.difference(DateTime.now()).inDays
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in steps)
                ChoiceChip(
                  label: Text(s.$2, style: const TextStyle(fontSize: 12)),
                  selected: _takip.durum == s.$1,
                  onSelected: (_) => _setDurum(s.$1),
                ),
            ],
          ),
          if (_takip.durum == 'reddedildi') ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickRetTeblig,
              icon: const Icon(Icons.event, size: 16),
              label: Text(
                _takip.sonucTarihi == null
                    ? 'Ret tebliğ tarihi seç'
                    : 'Ret tebliğ: ${_fmtDate(_takip.sonucTarihi)}',
              ),
            ),
            if (itirazGun != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  itirazGun >= 0
                      ? 'İtiraz için son $itirazGun gün'
                      : 'İtiraz süresi dolmuş olabilir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: itirazGun >= 0
                        ? const Color(0xFFB45309)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackBody(RightItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const L10nText(
            'Bu hakkın ayrıntılı dosyası hazırlanıyor',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...item.desc.split('\n\n').map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: L10nText(
                  p,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ),
        if (item.steps.isNotEmpty) ...[
          const SizedBox(height: 8),
          L10nText(
            'Başvuru adımları',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < item.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${item.steps[i]}'),
            ),
        ],
        if (item.where.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.where,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _section({
    required String id,
    required String title,
    required Widget child,
  }) {
    final open = _openSections.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MetoColors.border),
        ),
        child: Column(
          children: [
            Semantics(
              header: true,
              button: true,
              label: title,
              child: InkWell(
                onTap: () => setState(() {
                  if (open) {
                    _openSections.remove(id);
                  } else {
                    _openSections.add(id);
                  }
                }),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        color: MetoColors.mutedFg,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  Widget _criterionRow(HakKriter k) {
    KuralSonuc? s;
    if (k.kural != null) {
      s = degerlendir(k.kural!, _profil.cevaplar);
    }
    String mark;
    String status;
    switch (s) {
      case KuralSonuc.saglaniyor:
        mark = '✓';
        status = 'sağlanıyor';
      case KuralSonuc.saglanmiyor:
        mark = '✗';
        status = 'sağlanmıyor';
      case KuralSonuc.bilinmiyor:
        mark = '?';
        status = 'bilinmiyor';
      case null:
        mark = '•';
        status = '';
    }
    return Semantics(
      label: '${k.metin}. $status',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mark,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: mark == '✓'
                    ? const Color(0xFF15803D)
                    : mark == '✗'
                        ? const Color(0xFFDC2626)
                        : MetoColors.mutedFg,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.metin,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: MetoColors.foreground,
                    ),
                  ),
                  if (s == KuralSonuc.bilinmiyor)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sihirbazda cevaplayın'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: L10nText(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _adimRow(int n, HakAdim a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: MetoColors.primary,
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.baslik,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                if (a.aciklama.trim().isNotEmpty)
                  Text(
                    a.aciklama,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                if ((a.link ?? '').trim().isNotEmpty)
                  TextButton(
                    onPressed: () => _openUrl(a.link),
                    child: const Text('Aç'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _belgeRow(HakBelge b) {
    final ok = _belgeOk(b.ad);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: ok,
      onChanged: (v) => _toggleBelge(b.ad, v == true),
      title: Text(b.ad, style: const TextStyle(fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.nereden.trim().isNotEmpty)
            Text('Nereden: ${b.nereden}',
                style: TextStyle(fontSize: 12, color: MetoColors.mutedFg)),
          if ((b.link ?? '').trim().isNotEmpty)
            TextButton(
              onPressed: () => _openUrl(b.link),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Aç'),
            ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _retSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dosya.retSebepleri.isNotEmpty) ...[
          const Text(
            'Sık ret sebepleri',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _bulletList(_dosya.retSebepleri),
        ],
        if (_dosya.itiraz.yol.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('İtiraz yolu: ${_dosya.itiraz.yol}',
              style: const TextStyle(fontSize: 13)),
        ],
        if (_dosya.itiraz.sure.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Süre: ${_dosya.itiraz.sure}',
              style: const TextStyle(fontSize: 13)),
        ],
        if (_dosya.itiraz.dilekce.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _dosya.itiraz.dilekce),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dilekçe örneği kopyalandı')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Dilekçe örneğini kopyala'),
          ),
        ],
      ],
    );
  }

  Widget _sssTile(int i, HakSss s) {
    final id = 'sss_$i';
    final open = _openSss.contains(id);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: open,
      onExpansionChanged: (v) => setState(() {
        if (v) {
          _openSss.add(id);
        } else {
          _openSss.remove(id);
        }
      }),
      title: Text(
        s.soru,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: MetoColors.foreground,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.cevap,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: MetoColors.mutedFg,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iletisimRow(HakIletisim i) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(i.ad),
      subtitle: Text(
        [if ((i.telefon ?? '').isNotEmpty) i.telefon, if ((i.link ?? '').isNotEmpty) i.link]
            .join(' · '),
      ),
      onTap: () {
        final tel = (i.telefon ?? '').trim();
        if (tel.isNotEmpty) {
          final cleaned = tel.replaceAll(RegExp(r'[^\d+]'), '');
          _openUrl('tel:$cleaned');
        } else {
          _openUrl(i.link);
        }
      },
    );
  }

  Widget _bottomBar() {
    return Material(
      elevation: 8,
      color: MetoColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bilgilendirme amaçlıdır, hukuki tavsiye değildir. Kesin bilgi için ilgili kuruma başvurun.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _askMetoBot,
                      child: const Text('Bu hak hakkında soru sor'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _openUzman,
                      style: FilledButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                      ),
                      child: const Text('Uzmana danış'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
