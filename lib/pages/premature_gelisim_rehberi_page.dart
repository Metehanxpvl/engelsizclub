import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../meto_theme.dart';
import '../widgets/youtube_embed.dart';

/// Pathways.org preemie kaynaklarından ilham — özgün TR metin.
/// Web URL: /bilgi-kutuphanesi/premature-bebek
class PrematureGelisimRehberiPage extends StatelessWidget {
  const PrematureGelisimRehberiPage({super.key});

  static const youtubeVideoId = 'zQfuBFwVZ5E';
  static const routePath = '/bilgi-kutuphanesi/premature-bebek';

  /// Web’de SEO sayfasına git; mobilde uygulama içi sayfa.
  static Future<void> open(BuildContext context) async {
    if (kIsWeb) {
      final uri = Uri.parse(routePath);
      final ok = await launchUrl(
        uri,
        webOnlyWindowName: '_self',
      );
      if (ok) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrematureGelisimRehberiPage(),
        settings: const RouteSettings(name: routePath),
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
        title: Text(
          'Prematüre Bebek',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Prematüre Bebek Gelişim Rehberi',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: MetoColors.foreground,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Erken doğum, aileyi bir anda bambaşka bir ritme sokabilir. '
            'Yalnız değilsin; birçok anne-baba aynı kaygıları taşıyor. '
            'Bu sayfa, gelişimi “düzeltilmiş yaş” penceresinden okumana '
            'yardımcı olmak için hazırlandı — yumuşak bir üslupla, baskı kurmadan.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          Text(
            'Düzeltilmiş yaş, bebeğin takvimdeki yaşı değil; beklenen doğum '
            'tarihine göre hesaplanan gelişim yaşıdır. Örneğin 6 hafta erken '
            'geldiyse, 3 aylıkken gelişim olarak kabaca 1,5 aylık gibi düşünülür. '
            'Arkadaşların bebekleriyle kıyas yaparken bu farkı hatırlamak '
            'gereksiz paniği azaltır. Yine de her çocuk kendine özgüdür; '
            'kararları birlikte çocuk doktorunla verirsin.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 28),
          _sectionTitle('Bölüm 1 — 0–3 Ay: Baş Kontrolü ve Tummy Time'),
          Text(
            'Bu dönemde hedef “mükemmel pozisyon” değil; kısa, güvenli '
            'yüzüstü uyanık sürelerdir. Boyun ve omuz kasları yavaş yavaş '
            'güçlenir. Sesini duyunca bakışlarını çevirmesi veya kısa süre '
            'başını kaldırmaya çalışması yeterince güzel bir başlangıçtır.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Göğüste Tummy Time',
            'Uyanıkken seni yarı yaslanarak oturt; bebeği göğsüne yüzüstü koy. '
            '1–2 dakika yeter. Ağlarsa kaldır; başka bir saatte dene.',
          ),
          const SizedBox(height: 8),
          _activityCard(
            'Kucakta yüzüstü taşıma',
            'Bebeği karnı aşağıda, kolunun üzerinde güvenli şekilde taşı '
            '(başını destekle). Doktorun izin vermediyse zorlama.',
          ),
          const SizedBox(height: 28),
          _sectionTitle('Bölüm 2 — 4–6 Ay: Dönme ve Oturma'),
          Text(
            'Kaslar olgunlaştıkça yanlara dönme, destekli oturma ve ellere '
            'uzanma görünür. Desteksiz oturma henüz yoksa yastıklarla desteklemek '
            'tamam — “hemen otursun” baskısı gerekmez.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Oyuncakla uzanma',
            'Sırt üstündeyken sevdiği oyuncağı biraz uzağa tut; uzanmasını bekle. '
            '2–3 dakikalık turlar yeterlidir.',
          ),
          const SizedBox(height: 8),
          _activityCard(
            'Destekli oturma çemberi',
            'Bacakların arasında oturt; belini destekle. Karşında sen ol, '
            'kısa süre şarkı söyle; yorulunca bırak.',
          ),
          const SizedBox(height: 28),
          _sectionTitle('Bölüm 3 — 7–12 Ay: Emekleme ve Ayağa Kalkma'),
          Text(
            'Emekleme, tutunarak kalkma ve kısa ayakta durma gündeme gelebilir. '
            'Bazı bebekler emeklemeden tutunarak yürümeye yönelir. Güvenli oda '
            've yerde oyun süresi işini kolaylaştırır.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Keşif yolu',
            'Salonda güvenli bir hat çiz; sonuna oyuncak koy. Cesaretlendir '
            'ama sürükleme.',
          ),
          const SizedBox(height: 8),
          _activityCard(
            'Tutunarak ayağa',
            'Sağlam bir kenarda tutunmasına izin ver. Yanında ol; zorla “yürü” '
            'dedirtme.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetoColors.primary, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Videolu Anlatım — Prematüre Bebeklerle Tummy Time',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const YoutubeEmbed(
                  videoId: youtubeVideoId,
                  title: 'Prematüre Bebek Tummy Time',
                  height: 240,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kaynak: Pathways.org — Uyarlama: Engelsiz Club',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('Bölüm 4 — Türkiye’de Takip'),
          _bullet('SGK — kontrol ve rapor süreçlerinde haklarını sor'),
          _bullet('Erken Müdahale — gecikme şüphesinde zamanında değerlendirme'),
          _bullet('Fizik Tedavi — gerektiğinde çocuk fizyoterapisi desteği'),
          _bullet('Çocuk Doktoru — büyüme, aşı ve düzeltilmiş yaş izlemi'),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Bu içerik tıbbi tavsiye değildir. Bebeğin için kararları '
              'mutlaka doktorunuzla birlikte alın.',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kaynak: Pathways.org — Uyarlama: Engelsiz Club',
            style: GoogleFonts.nunito(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
      ),
    );
  }

  static TextStyle get _bodyStyle => GoogleFonts.nunito(
        fontSize: 15,
        height: 1.55,
        color: MetoColors.mutedFg,
        fontWeight: FontWeight.w600,
      );

  static Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: MetoColors.primary,
            height: 1.3,
          ),
        ),
      );

  static Widget _activityCard(String title, String body) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MetoColors.selectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MetoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ev aktivitesi: $title',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: _bodyStyle.copyWith(fontSize: 14)),
          ],
        ),
      );

  static Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '•  ',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                color: MetoColors.primary,
              ),
            ),
            Expanded(child: Text(text, style: _bodyStyle)),
          ],
        ),
      );
}
