import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_config.dart';
import '../../meto_theme.dart';
import '../../services/harita_google_kota.dart';

/// Admin: Engelsiz Haritalar Google arama sayacı, aylık sınır, aç/kapa.
class HaritaKontrolScreen extends StatefulWidget {
  const HaritaKontrolScreen({super.key, required this.adminEmail});

  final String? adminEmail;

  static Future<void> open(BuildContext context, {String? adminEmail}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HaritaKontrolScreen(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<HaritaKontrolScreen> createState() => _HaritaKontrolScreenState();
}

class _HaritaKontrolScreenState extends State<HaritaKontrolScreen> {
  HaritaGoogleDurum? _durum;
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  String? _hata;
  final _limit = TextEditingController();

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    if (_isAdmin) {
      _yukle();
    } else {
      _yukleniyor = false;
      _hata = 'Bu sayfa yalnızca yöneticiler içindir.';
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final d = await HaritaGoogleKota.durum();
      if (!mounted) return;
      setState(() {
        _durum = d;
        _limit.text = '${d.aylikLimit}';
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e'.replaceFirst('Bad state: ', '');
        _yukleniyor = false;
      });
    }
  }

  Future<void> _kaydet({bool? googleAcik, int? aylikLimit}) async {
    setState(() => _kaydediliyor = true);
    try {
      await HaritaGoogleKota.ayarKaydet(
        googleAcik: googleAcik,
        aylikLimit: aylikLimit,
      );
      await _yukle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'.replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          'Harita kontrol',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yukleniyor || !_isAdmin ? null : _yukle,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_hata!, textAlign: TextAlign.center),
                  ),
                )
              : _icerik(_durum!),
    );
  }

  Widget _kart({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MetoColors.border),
        ),
        child: child,
      );

  Widget _icerik(HaritaGoogleDurum d) {
    final oran = d.aylikLimit <= 0 ? 1.0 : (d.buAy / d.aylikLimit).clamp(0.0, 1.0);
    final doldu = d.aylikLimit > 0 && d.buAy >= d.aylikLimit;
    final renk = doldu
        ? Colors.red.shade700
        : (oran >= 0.8 ? Colors.orange.shade700 : MetoColors.primary);
    final googleCalisiyor = d.googleAcik && !doldu;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _kart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu ay Google sorgusu',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${d.buAy} / ${d.aylikLimit}',
                style: GoogleFonts.nunito(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: renk,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: oran,
                  minHeight: 10,
                  color: renk,
                  backgroundColor: MetoColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                googleCalisiyor
                    ? 'Arama: Google + OpenStreetMap. Sayaç her ayın 1\'inde sıfırlanır.'
                    : doldu
                        ? 'Aylık sınır doldu: ay sonuna kadar sadece OpenStreetMap kullanılıyor.'
                        : 'Google kapalı: sadece OpenStreetMap kullanılıyor.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _kart(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: d.googleAcik,
            activeColor: MetoColors.primary,
            onChanged: _kaydediliyor ? null : (v) => _kaydet(googleAcik: v),
            title: Text(
              'Google ile arama',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              d.googleAcik
                  ? 'Açık · kapatırsan sadece OpenStreetMap kullanılır'
                  : 'Kapalı · sadece OpenStreetMap kullanılıyor',
              style: GoogleFonts.nunito(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _kart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aylık sınır',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Ücretsiz hak içinde kalmak için 4500 önerilir.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _limit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: MetoColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                    ),
                    onPressed: _kaydediliyor
                        ? null
                        : () {
                            final v = int.tryParse(_limit.text.trim());
                            if (v == null || v < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Geçerli bir sayı girin.'),
                                ),
                              );
                              return;
                            }
                            _kaydet(aylikLimit: v);
                          },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
