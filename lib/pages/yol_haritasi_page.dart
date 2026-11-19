import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../medical_disclaimer_store.dart';
import '../meto_theme.dart';
import '../yol_haritasi/yol_haritasi_data.dart';
import '../yol_haritasi/yol_haritasi_store.dart';

const _kYolHaritasiSorumlulukKabul = 'info_dismiss_yol_haritasi_v1';

const _sorumlulukMetni =
    'Bu yol haritası yalnızca genel bilgilendirme amacıyla hazırlanmıştır. '
    'Tıbbi tavsiye, tanı veya tedavi yerine geçmez.\n\n'
    'Her çocuğun ihtiyacı farklıdır; hangi doktora gidileceğine ve hangi '
    'terapilerin uygulanacağına çocuğunuzu muayene eden hekim ve uzmanlar '
    'karar verir. Haklar ve resmî süreçlere ilişkin bilgiler değişebilir; '
    'güncel bilgi için ilgili kurumlara (hastane, RAM, Aile ve Sosyal '
    'Hizmetler Bakanlığı) başvurunuz.\n\n'
    'Engelsiz Club, bu içeriğe dayanılarak alınan kararlardan sorumlu '
    'tutulamaz.';

/// "Tanı aldık, şimdi ne yapmalı?" — kişiye özel yol haritası.
class YolHaritasiPage {
  YolHaritasiPage._();

  static const routePath = '/yol-haritasi';

  static Future<void> open(BuildContext context) async {
    final email =
        Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';

    final kabul = await isInfoCardDismissed(_kYolHaritasiSorumlulukKabul);
    if (!kabul && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Önemli bilgilendirme',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Text(
              _sorumlulukMetni,
              style: GoogleFonts.nunito(fontSize: 14, height: 1.45),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                await dismissInfoCard(_kYolHaritasiSorumlulukKabul);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              style:
                  FilledButton.styleFrom(backgroundColor: MetoColors.primary),
              child: const Text('Okudum, anladım'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YolHaritasiScreen(userEmail: email),
        settings: const RouteSettings(name: routePath),
      ),
    );
  }
}

class YolHaritasiScreen extends StatefulWidget {
  const YolHaritasiScreen({super.key, required this.userEmail});

  final String userEmail;

  @override
  State<YolHaritasiScreen> createState() => _YolHaritasiScreenState();
}

class _YolHaritasiScreenState extends State<YolHaritasiScreen> {
  YolKayit? _kayit;
  bool _sihirbaz = true;

  // Sihirbaz taslağı
  String? _taslakTani;
  String _taniArama = '';
  final Map<String, bool> _taslakCevaplar = {};
  String? _hata;

  String _taniAramaNorm(String s) => s
      .toLowerCase()
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c');

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final k = await yolKayitYukle(widget.userEmail);
    if (!mounted) return;
    setState(() {
      _kayit = k;
      _sihirbaz = !(k.haritaHazir && yolTaniBul(k.taniId) != null);
      _taslakTani = k.taniId;
      _taslakCevaplar
        ..clear()
        ..addAll(k.cevaplar);
    });
  }

  Future<void> _kaydet() async {
    final k = _kayit;
    if (k == null) return;
    await yolKayitKaydet(widget.userEmail, k);
  }

  void _haritaOlustur() {
    final tani = yolTaniBul(_taslakTani);
    if (tani == null) {
      setState(() => _hata = 'Önce tanıyı seçin');
      return;
    }
    final eksik = tani.sorular.any((s) => !_taslakCevaplar.containsKey(s.id));
    if (eksik) {
      setState(() => _hata = 'Devam etmek için tüm soruları cevaplayın');
      return;
    }

    final k = _kayit ?? YolKayit();
    if (k.taniId != tani.id) {
      k.durumlar.clear();
      k.otomatik.clear();
    } else {
      // Önceki cevaplardan gelen otomatik işaretleri kaldır.
      for (final id in k.otomatik) {
        if (k.durumlar[id] == YolDurum.gerekYok) k.durumlar.remove(id);
      }
      k.otomatik.clear();
    }
    k.taniId = tani.id;
    k.cevaplar
      ..clear()
      ..addEntries(
        tani.sorular.map((s) => MapEntry(s.id, _taslakCevaplar[s.id]!)),
      );
    for (final s in tani.sorular) {
      final liste =
          k.cevaplar[s.id] == true ? s.evetIseGerekYok : s.hayirIseGerekYok;
      for (final id in liste) {
        if (k.durumlar[id] != YolDurum.yapildi) {
          k.durumlar[id] = YolDurum.gerekYok;
          k.otomatik.add(id);
        }
      }
    }

    setState(() {
      _kayit = k;
      _sihirbaz = false;
      _hata = null;
    });
    _kaydet();
  }

  void _durumDegistir(String id, YolDurum d) {
    final k = _kayit;
    if (k == null) return;
    setState(() {
      if (k.durumlar[id] == d) {
        k.durumlar.remove(id);
      } else {
        k.durumlar[id] = d;
      }
      k.otomatik.remove(id);
    });
    _kaydet();
  }

  @override
  Widget build(BuildContext context) {
    final k = _kayit;
    final tani = yolTaniBul(k?.taniId);
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.background,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: Text(
          'Yol Haritam',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (!_sihirbaz && tani != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _sihirbaz = true;
                _taslakTani = k?.taniId;
                _taslakCevaplar
                  ..clear()
                  ..addAll(k?.cevaplar ?? {});
              }),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Cevapları değiştir'),
              style: TextButton.styleFrom(foregroundColor: MetoColors.primary),
            ),
        ],
      ),
      body: k == null
          ? const Center(child: CircularProgressIndicator())
          : (_sihirbaz || tani == null)
              ? _buildSihirbaz()
              : _buildHarita(k, tani),
    );
  }

  // ---------------------------------------------------------------- Sihirbaz

  Widget _buildSihirbaz() {
    final tani = yolTaniBul(_taslakTani);
    final q = _taniAramaNorm(_taniArama.trim());
    final filtreli = q.isEmpty
        ? yolTanilari
        : yolTanilari
            .where((t) => _taniAramaNorm(t.ad).contains(q))
            .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Tanı aldık, şimdi ne yapmalı?',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tanıyı seçin; çocuğunuz için sorulabilecek doktor ve terapileri hatırlatalım.',
          style: GoogleFonts.nunito(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 20),
        _adimBasligi('Adım 1 / 2 · Tanı'),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Tanı ara',
            hintStyle: GoogleFonts.nunito(color: MetoColors.mutedFg),
            prefixIcon: const Icon(Icons.search, color: MetoColors.mutedFg),
            filled: true,
            fillColor: MetoColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MetoColors.primary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: MetoColors.foreground,
          ),
          onChanged: (v) => setState(() => _taniArama = v),
        ),
        const SizedBox(height: 8),
        for (final t in filtreli)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            selected: _taslakTani == t.id,
            selectedTileColor: MetoColors.selectedBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            title: Text(
              t.ad,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: _taslakTani == t.id
                    ? MetoColors.primary
                    : MetoColors.foreground,
              ),
            ),
            trailing: _taslakTani == t.id
                ? const Icon(Icons.check, color: MetoColors.primary)
                : null,
            onTap: () => setState(() {
              if (_taslakTani != t.id) _taslakCevaplar.clear();
              _taslakTani = t.id;
              _hata = null;
            }),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          selected: _taslakTani == 'genetik',
          selectedTileColor: MetoColors.selectedBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Tanım listede yok',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: _taslakTani == 'genetik'
                  ? MetoColors.primary
                  : MetoColors.foreground,
            ),
          ),
          trailing: _taslakTani == 'genetik'
              ? const Icon(Icons.check, color: MetoColors.primary)
              : null,
          onTap: () => setState(() {
            if (_taslakTani != 'genetik') _taslakCevaplar.clear();
            _taslakTani = 'genetik';
            _hata = null;
          }),
        ),
        if (tani != null) ...[
          const SizedBox(height: 24),
          _adimBasligi('Adım 2 / 2 · Birkaç soru'),
          const SizedBox(height: 4),
          for (final s in tani.sorular) _soruSatiri(s),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _haritaOlustur,
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Yol haritamı oluştur',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (_hata != null) ...[
          const SizedBox(height: 8),
          Text(
            _hata!,
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.red.shade700),
          ),
        ],
        const SizedBox(height: 20),
        _altBilgi(null),
      ],
    );
  }

  Widget _adimBasligi(String t) => Text(
        t,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: MetoColors.mutedFg,
        ),
      );

  Widget _soruSatiri(YolSoru s) {
    final c = _taslakCevaplar[s.id];
    Widget secenek(String label, bool deger) => ChoiceChip(
          label: Text(label),
          selected: c == deger,
          selectedColor: MetoColors.selectedBg,
          labelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: c == deger ? MetoColors.primary : MetoColors.foreground,
          ),
          onSelected: (_) => setState(() {
            _taslakCevaplar[s.id] = deger;
            _hata = null;
          }),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MetoColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.metin,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              secenek('Evet', true),
              const SizedBox(width: 8),
              secenek('Hayır', false),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Harita

  List<YolDal> _gorunenDallar(YolKayit k, YolTani t) => t.dallar
      .where((d) => d.sadeceEvetIse == null || k.cevaplar[d.sadeceEvetIse] == true)
      .toList();

  Widget _buildHarita(YolKayit k, YolTani t) {
    final dallar = _gorunenDallar(k, t);
    var toplam = 0;
    var yapilan = 0;
    final eksikler = <String>[];
    for (final d in dallar) {
      var a = 0;
      var y = 0;
      for (final m in d.maddeler) {
        final s = k.durumlar[m.id];
        if (s == YolDurum.gerekYok) continue;
        a++;
        if (s == YolDurum.yapildi) y++;
      }
      toplam += a;
      yapilan += y;
      if (y < a) eksikler.add('${d.baslik}: ${a - y}');
    }
    final oran = toplam == 0 ? 1.0 : yapilan / toplam;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          '${t.ad} yol haritası',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Bu liste teşhis veya tedavi önerisi değildir; gözden kaçabilecek '
          'bölümleri hatırlatır. Kararları doktorunuzla birlikte verin.',
          style: GoogleFonts.nunito(fontSize: 12, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'İlerleme',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: MetoColors.mutedFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$yapilan / $toplam · %${(oran * 100).round()}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: oran,
                  minHeight: 8,
                  backgroundColor: MetoColors.muted,
                  color: MetoColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                eksikler.isEmpty
                    ? 'Tüm maddeler tamam'
                    : 'Henüz sorulmayan: ${eksikler.join(', ')}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: eksikler.isEmpty
                      ? MetoColors.primary
                      : const Color(0xFFB26A00),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _lejant(Icons.check, 'Gittik / alıyoruz'),
            const SizedBox(width: 14),
            _lejant(Icons.remove, 'Gerek görülmedi'),
            const SizedBox(width: 14),
            Text(
              'Boş = henüz sormadık',
              style:
                  GoogleFonts.nunito(fontSize: 12, color: MetoColors.mutedFg),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < dallar.length; i++)
          _dalKarti(k, dallar[i], acik: i == 0),
        const SizedBox(height: 8),
        _altBilgi(t.kaynak),
      ],
    );
  }

  Widget _lejant(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: MetoColors.mutedFg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      );

  Widget _dalKarti(YolKayit k, YolDal d, {required bool acik}) {
    var a = 0;
    var y = 0;
    for (final m in d.maddeler) {
      final s = k.durumlar[m.id];
      if (s == YolDurum.gerekYok) continue;
      a++;
      if (s == YolDurum.yapildi) y++;
    }
    final tamam = y == a;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: acik,
          leading: Icon(d.icon, color: MetoColors.primary),
          title: Text(
            d.baslik,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          subtitle: d.not == null
              ? null
              : Text(
                  d.not!,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tamam ? MetoColors.selectedBg : const Color(0xFFFFF3DC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              a == 0 ? 'Gerek görülmedi' : '$y / $a',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tamam ? MetoColors.primary : const Color(0xFF8A5300),
              ),
            ),
          ),
          children: [for (final m in d.maddeler) _maddeSatiri(k, m)],
        ),
      ),
    );
  }

  Widget _maddeSatiri(YolKayit k, YolMadde m) {
    final s = k.durumlar[m.id];
    final gerekYok = s == YolDurum.gerekYok;
    final otomatik = k.otomatik.contains(m.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MetoColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.baslik,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gerekYok
                        ? MetoColors.mutedFg
                        : MetoColors.foreground,
                    decoration: gerekYok ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  otomatik ? '${m.aciklama} · cevabınıza göre' : m.aciklama,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _durumButonu(
            icon: Icons.check,
            tooltip: 'Gittik / alıyoruz',
            secili: s == YolDurum.yapildi,
            onTap: () => _durumDegistir(m.id, YolDurum.yapildi),
          ),
          const SizedBox(width: 6),
          _durumButonu(
            icon: Icons.remove,
            tooltip: 'Doktorumuz gerek görmedi',
            secili: gerekYok,
            onTap: () => _durumDegistir(m.id, YolDurum.gerekYok),
          ),
        ],
      ),
    );
  }

  Widget _durumButonu({
    required IconData icon,
    required String tooltip,
    required bool secili,
    required VoidCallback onTap,
  }) {
    final yapildiMi = icon == Icons.check;
    final renk = yapildiMi ? MetoColors.primary : MetoColors.mutedFg;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: secili,
        label: tooltip,
        child: Material(
          color: secili
              ? (yapildiMi ? MetoColors.selectedBg : MetoColors.muted)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: secili ? renk : MetoColors.border,
                  width: secili ? 1.5 : 1,
                ),
              ),
              child: Icon(icon, size: 20, color: secili ? renk : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  Widget _altBilgi(String? kaynak) => Text(
        '${kaynak != null ? 'Kaynak: $kaynak (uyarlanmıştır). ' : ''}'
        'Bilgilendirme amaçlıdır, tıbbi tavsiye değildir. Planı doktorunuzla '
        'birlikte yapın.',
        style: GoogleFonts.nunito(fontSize: 11, color: MetoColors.mutedFg),
      );
}
