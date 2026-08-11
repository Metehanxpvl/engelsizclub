import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../meto_theme.dart';
import '../widgets/youtube_embed.dart';

/// Pathways.org preemie kaynaklarından ilham alınmış özgün içerik.
/// URL (web): /bilgi-kutuphanesi/premature-bebek-gelisimi
class PrematureGelisimRehberiPage extends StatelessWidget {
  const PrematureGelisimRehberiPage({super.key});

  /// Pathways.org Tummy Time başlangıç videosu (YouTube).
  static const youtubeVideoId = 'zQfuBFwVZ5E';

  static const routePath = '/bilgi-kutuphanesi/premature-bebek-gelisimi';

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
            'Prematüre Bebek Gelişim Rehberi: 0-12 Ay Düzeltilmiş Takvim',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: MetoColors.foreground,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bebeğin biraz erken dünyaya gelmesi seni yalnız bırakmaz. '
            'Birçok aile aynı yolu yürüyor; endişelenmen doğal ama '
            'adım adım ilerlemek mümkün. Bu rehber, “düzeltilmiş yaş” ile '
            'gelişimi nasıl okuyacağını sade bir dille anlatır.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          Text(
            'Düzeltilmiş yaş şudur: Takvime göre geçen süre değil; '
            'bebeğin doğması gereken tarihe göre hesaplanan “gelişim saati”. '
            'Örneğin 8 hafta erken doğduysa, 4 aylıkken gelişim olarak '
            'kabaca 2 aylık gibi düşünülür. Karşılaştırmaları bu takvime '
            'göre yapmak, seni gereksiz tedirginlikten kurtarır. Yine de '
            'her bebek kendine özgüdür; asıl rehberin çocuk doktorundur.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 28),
          _sectionTitle('0-3 Ay Düzeltilmiş — Boyun ve Baş Kontrolü'),
          Text(
            'Bu dönemde minik adımlar bile büyük başarıdır. Kısa süre '
            'yüzüstü uyanık kalmak (tummy time), boyun ve omuzları güçlendirir. '
            'Bebeğin seni takip etmesi, sesine dönmesi veya kısa süre '
            'başını kaldırmaya çalışması yeterli bir başlangıçtır. '
            'Çekingen veya çabuk yorulan bebekler için göğsünde yüzüstü '
            'duruş da sayılır — zorlamak yok, yanında olmak var.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Evde 3×1 dk Tummy Time yapın',
            'Günde üç kez, uyanık ve doygun olduğu bir anda, her biri '
            'yaklaşık bir dakika. Göbek üstü sende, kucağında veya uygun '
            'bir yüzeyde dene. Ağlarsa bırak; başka bir saatte yeniden dene. '
            'Doktorun izin vermeden yoğun egzersize geçme.',
          ),
          const SizedBox(height: 28),
          _sectionTitle('4-6 Ay Düzeltilmiş — Dönme ve Oturma'),
          Text(
            'Kaslar olgunlaştıkça yanlara dönme, destekli oturma ve ellere '
            'uzanma gündeme gelir. Bazı bebekler önce sırt üstü oyunları, '
            'bazıları yüzüstü keşfi sever. Dengeli oturma henüz sağlam '
            'değilse yastıklarla destekleyebilirsin; “hemen otursun” baskısı '
            'gerekmez. Göz teması, gülümseme ve ses çıkarma da bu dönemin '
            'kıymetli kazanımlarıdır.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Evde destekli oturma oyunu',
            'Bebeği bacakların arasında veya yumuşak bir minderle destekleyerek '
            'kısa süre oturt. Karşısında renkli bir oyuncak tut; uzanmasını '
            'bekle. 2–3 dakikalık turlar yeterlidir. Yorgunluk belirtisinde molayı unutma.',
          ),
          const SizedBox(height: 28),
          _sectionTitle('7-12 Ay Düzeltilmiş — Emekleme ve İlk Adımlar'),
          Text(
            'Bu aralıkta emekleme, tutunarak ayağa kalkma ve kısa süre ayakta '
            'durma görülebilir. Her bebek aynı sırayı izlemez; bazıları '
            'emeklemeden tutunarak yürümeye geçer. Güvenli bir oyun alanı, '
            'üzerine tutunabileceği sağlam mobilya ve bol yerde oyun süresine '
            'ihtiyaç vardır. Ayakkabı baskısı veya “komşunun bebeği yürüdü” '
            'kıyasları seni germesin — düzeltilmiş yaşı hatırla.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _activityCard(
            'Evde keşif koridoru',
            'Salonda güvenli bir hat oluştur: yastık engelleri, uzakta '
            'sevdiği bir oyuncak. Onu cesaretlendir ama sürükleme. '
            'Tutunarak ayağa kalkınca alkışla; düşerse sakinleştir. '
            'Günde birkaç kısa tur idealdir.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Videolu Anlatım: Prematüre Bebeklerle Tummy Time',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                const YoutubeEmbed(
                  videoId: youtubeVideoId,
                  title: 'Prematüre Bebek Egzersizleri',
                  height: 220,
                ),
                const SizedBox(height: 10),
                Text(
                  'Kaynak: Pathways.org | Uyarlama: Engelsiz Club. '
                  'Video sayfadan ayrılmadan oynar.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('Türkiye’de Prematüre Takibi'),
          Text(
            'Ülkemizde erken doğan bebekler için düzenli izlem çok değerli. '
            'Aşağıdaki başlıkları aile hekimi / çocuk doktoru ile birlikte planla:',
            style: _bodyStyle,
          ),
          const SizedBox(height: 8),
          _bullet('Çocuk Doktoru — büyüme, aşı, düzeltilmiş yaşa göre kontrol'),
          _bullet('Fizik Tedavi / gelişimsel değerlendirme — gerektiğinde yönlendirme'),
          _bullet('Erken Müdahale — gelişimsel gecikme şüphesinde zamanında destek'),
          _bullet('SGK — hastane, rapor ve cihaz süreçlerinde haklarını sor'),
          _bullet('Rapor / sağlık kurulu — ihtiyaç halinde engel/sağlık raporları'),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetoColors.accentGold.withValues(alpha: 0.45)),
            ),
            child: Text(
              'Bu içerik tıbbi tavsiye değildir. Doktorunuza danışın. '
              'Engelsiz Club bilgilendirme ve aile dayanışması amacıyla yayınlar; '
              'teşhis, tedavi veya egzersiz reçetesi sunmaz.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetoColors.foreground,
                height: 1.45,
              ),
            ),
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
            fontSize: 18,
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
            Row(
              children: [
                Icon(Icons.toys_outlined, size: 18, color: MetoColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aktivite: $title',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: _bodyStyle.copyWith(fontSize: 14)),
          ],
        ),
      );

  static Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  color: MetoColors.primary,
                )),
            Expanded(child: Text(text, style: _bodyStyle)),
          ],
        ),
      );
}
