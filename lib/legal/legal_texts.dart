/// Engelsiz Club — yasal metinler (uygulama içi).
/// Play / App Store incelemesi için temel sorumluluk reddi, kullanım koşulları ve gizlilik.
library;

enum LegalDocKind {
  terms,
  privacy,
  disclaimer,
}

extension LegalDocKindX on LegalDocKind {
  String get titleTr => switch (this) {
        LegalDocKind.terms => 'Kullanım Koşulları',
        LegalDocKind.privacy => 'Gizlilik Politikası',
        LegalDocKind.disclaimer => 'Sorumluluk Reddi',
      };

  String get subtitleTr => switch (this) {
        LegalDocKind.terms => 'Engelsiz Club kullanım şartları',
        LegalDocKind.privacy => 'Kişisel verilerinizin korunması',
        LegalDocKind.disclaimer => 'Tıbbi / hukuki bilgilendirme',
      };
}

/// Ana sorumluluk reddi özeti (kayıt, banner, kısa uyarılar).
const kDisclaimerSummaryTr =
    'Bu uygulama (Engelsiz Club) sadece ailelerin ve uzmanların deneyim '
    'paylaştığı bir dayanışma ve iletişim platformudur. Burada paylaşılan '
    'hiçbir bilgi, içerik veya öneri profesyonel tıbbi tanı, tedavi veya hekim '
    'tavsiyesi niteliği taşımaz. Sağlık sorunlarınız için mutlaka uzman bir '
    'doktora başvurun.';

String legalDocumentBody(LegalDocKind kind) => switch (kind) {
      LegalDocKind.disclaimer => _disclaimerBody,
      LegalDocKind.terms => _termsBody,
      LegalDocKind.privacy => _privacyBody,
    };

const _disclaimerBody = '''
Son güncelleme: 7 Ağustos 2026

1. Platformun niteliği

$kDisclaimerSummaryTr

Engelsiz Club; özel gereksinimli bireyler, aileleri, bakıcılar ve uzmanlar arasında bilgi paylaşımı, dayanışma ve iletişimi kolaylaştırmayı amaçlayan bir sosyal destek platformudur.

2. Tıbbi hizmet değildir

Bu uygulama:
• Klinik hizmet sunmaz.
• Uzman hekim / sağlık kuruluşu görüşü yerine geçmez.
• Paylaşılan içerikleri tavsiye, reçete veya tedavi planı olarak sunmaz.
• Kurum, terapi, cihaz veya ilaç seçiminde karar vermez.
• Yalnızca topluluk, bilgilendirme ve iletişim amaçlıdır.

3. Kullanıcı içerikleri

Forum, ilan, sohbet ve benzeri alanlardaki içerikler kullanıcılar tarafından üretilir. Engelsiz Club, bu içeriklerin doğruluğu, güncelliği veya uygunluğu konusunda garanti vermez. Paylaşımlar kişisel deneyim niteliğindedir.

4. Araştırma / açık kaynak aramaları

Uygulama içindeki açık bilimsel kaynak araması (ör. PubMed, ClinicalTrials.gov) yalnızca herkese açık veri tabanlarında arama kolaylığı sağlar. Sonuçlar uygulama tarafından üretilmez, yorumlanmaz veya tavsiye olarak sunulmaz.

5. Sorumluluğun sınırlandırılması

Uygulamayı kullanarak elde ettiğiniz bilgilerden veya kullanıcı etkileşimlerinden doğabilecek doğrudan veya dolaylı zararlardan Engelsiz Club, geliştiricileri ve yayıncıları sorumlu tutulamaz. Önemli kişisel, tıbbi veya hukuki kararlarınız için yetkili uzmanlara danışınız.

6. Acil durumlar

Acil sağlık durumunda derhal 112’yi arayın veya en yakın sağlık kuruluşuna başvurun. Bu uygulama acil müdahale aracı değildir.
''';

const _termsBody = '''
Son güncelleme: 7 Ağustos 2026

1. Taraflar ve kabul

Bu Kullanım Koşulları, Engelsiz Club mobil/web uygulamasını (“Uygulama”) kullanan gerçek kişiler (“Kullanıcı”) ile Engelsiz Club arasında geçerlidir. Uygulamayı indirerek, kaydolarak veya kullanarak bu koşulları kabul etmiş sayılırsınız.

2. Hizmetin kapsamı

Engelsiz Club; özel gereksinimli bireyler ve yakınları için topluluk, ilan, forum, harita/merkez keşfi ve bilgilendirme araçları sunan bir dayanışma platformudur. Uygulama tıbbi tanı, tedavi veya profesyonel sağlık hizmeti sağlamaz. Ayrıntılar için Sorumluluk Reddi metnini inceleyiniz.

3. Hesap ve üyelik

• Doğru ve güncel bilgiler vermekle yükümlüsünüz.
• Hesap güvenliğinizden (şifre, oturum) siz sorumlusunuz.
• 18 yaşından küçükler, yasal temsilci gözetiminde kullanmalıdır.
• Hesabınızı kötüye kullanmanız halinde erişim kısıtlanabilir veya sonlandırılabilir.

4. Kullanıcı davranış kuralları

Yasaklardır:
• Hakaret, tehdit, taciz, nefret söylemi veya ayrımcılık.
• Yanlış, yanıltıcı veya yasa dışı ilan / içerik.
• Başkalarının kişisel verilerini izinsiz paylaşma.
• Spam, dolandırıcılık, zararlı yazılım veya sistemi bozmaya yönelik eylemler.
• Telif veya fikri mülkiyet ihlali.

5. İlanlar, teklifler ve ödemeler

İlan ve teklifler kullanıcılar arasındadır. Engelsiz Club, taraflar arasında aracı kurum veya işveren değildir. Uygulama içi puan / teklif paketleri dijital hizmet bedelidir; ilgili mağaza (Google Play / App Store) kuralları ve iade politikaları geçerlidir.

6. Fikri mülkiyet

Uygulama arayüzü, marka, logo ve orijinal içerikler Engelsiz Club’a aittir. Kullanıcının ürettiği içeriklerin sorumluluğu kullanıcıya aittir; platforma yayın için sınırlı bir lisans verirsiniz.

7. Hizmet değişiklikleri

Özellikler, fiyatlar ve kullanım koşulları önceden bildirilerek güncellenebilir. Önemli değişikliklerde uygulama içi bilgilendirme yapılabilir.

8. Hesap silme

Uygulama menüsündeki “Hesabımı Sil” yoluyla silme talebi iletebilirsiniz. Yasal saklama yükümlülükleri saklıdır.

9. Uygulanacak hukuk

Uyuşmazlıklarda Türkiye Cumhuriyeti hukuku uygulanır; yetkili mahkemeler Türkiye’deki kanunlarla belirlenir.

10. İletişim

Görüş, şikâyet ve önerileriniz için uygulama içi “Dilek, Şikayet & Öneri” kanalını kullanabilirsiniz.
''';

const _privacyBody = '''
Son güncelleme: 7 Ağustos 2026

1. Veri sorumlusu

Bu Gizlilik Politikası, Engelsiz Club (“biz”) tarafından sunulan uygulamanın kişisel veri işleme faaliyetlerini açıklar. Kayıt olarak veya uygulamayı kullanarak bu politikayı okuduğunuzu kabul etmiş sayılırsınız.

2. Toplanan veriler

Hizmeti sunmak için işleyebileceğimiz veriler:
• Hesap: ad-soyad, e-posta, hesap türü (aile / uzman / bakıcı), profil bilgileri.
• İçerik: ilanlar, forum gönderileri, mesajlar, yüklenen görseller.
• Teknik: cihaz / oturum bilgileri, çökme günlükleri, push bildirim belirteçleri.
• Ödeme (mobil): satın alma işlemi mağaza (Google Play / App Store) üzerinden yürür; kart bilgileriniz bizde saklanmaz.

3. İşleme amaçları

Veriler şu amaçlarla işlenir:
• Hesap oluşturma ve kimlik doğrulama
• İlan, forum, mesajlaşma ve bildirim hizmetlerinin sunulması
• Güvenlik, kötüye kullanımın önlenmesi ve destek
• Yasal yükümlülüklerin yerine getirilmesi
• (Varsa) hizmet iyileştirme ve hata giderme

4. Hukuki dayanak

KVKK ve ilgili mevzuat kapsamında işleme; sözleşmenin ifası, meşru menfaat ve gerektiğinde açık rızaya dayanabilir.

5. Üçüncü taraflar / altyapı

Hizmeti sağlamak için şu tür hizmet sağlayıcılar kullanılabilir:
• Supabase (kimlik doğrulama ve veritabanı)
• Firebase (bildirim, kimlik yardımcıları)
• Google / Apple (sosyal giriş ve uygulama mağazası ödemeleri)
• Bulut depolama (görseller)

Bu sağlayıcılar yalnızca hizmetin gerektirdiği ölçüde veri işler.

6. Saklama süresi

Veriler, hesabınız aktif olduğu sürece ve yasal zorunluluklar kapsamında gerekli olduğu kadar saklanır. Hesap silme talebinden sonra makul süre içinde silinir veya anonimleştirilir; yasal saklama istisnaları saklıdır.

7. Haklarınız

KVKK kapsamında bilgilendirme, erişim, düzeltme, silme, itiraz ve (uygunsa) taşınabilirlik haklarınız vardır. Taleplerinizi uygulama içi iletişim / hesap silme kanallarından iletebilirsiniz.

8. Güvenlik

Verilerinize erişimi kısıtlamak, iletimi korumak ve yetkisiz erişimi azaltmak için makul teknik ve idari önlemler alınır. İnternet üzerinden hiçbir aktarım %100 güvenli değildir.

9. Çocukların gizliliği

Hizmet genel kitleye yöneliktir. 18 yaş altı kullanımda yasal temsilci sorumluluğu esastır. Bilerek çocuklardan ebeveyn rızası olmadan veri toplamayız.

10. Politika değişiklikleri

Bu metin güncellenebilir. Önemli değişikliklerde uygulama içinde bilgilendirme yapılabilir. Güncel sürüm uygulamada yayınlandığı tarihten itibaren geçerlidir.

11. İletişim

Gizlilik ile ilgili talepleriniz için uygulama menüsündeki iletişim / geri bildirim kanalını kullanınız.
''';
