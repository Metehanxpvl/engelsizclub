-- Resmi TR belediye + bakanlık kaynakları → public.content_sources
-- SQL Editor → Run. events / kariyer / push tablolarına dokunmaz.
-- Collector YALNIZ pending_review yazar; yayın ve FCM yok.
-- is_active=true yalnızca 2026-09-14 HEAD/GET ile doğrulanmış RSS/Atom.
-- TBB indeks sayfaları ve Bursa genel RSS bilinçli kapalı.
-- muğla.bel.tr → mugla.bel.tr

insert into public.content_sources (name, url, method, is_active, fetch_interval_hours, notes)
select * from (values
  (
    'Ağrı BB RSS',
    'https://www.agri.bel.tr/rss/',
    'rss',
    true,
    24,
    'GET: RSS, 30 madde (2026-09-14)'
  ),
  (
    'Bolu BB RSS',
    'https://www.bolu.bel.tr/feed/',
    'rss',
    true,
    24,
    'GET: WordPress Atom/RSS, 10 madde (2026-09-14)'
  ),
  (
    'Burdur BB RSS',
    'https://burdur.bel.tr/feed/',
    'rss',
    true,
    24,
    'GET: WordPress feed, 10 madde (2026-09-14)'
  ),
  (
    'Giresun BB RSS',
    'https://giresun.bel.tr/feed/',
    'rss',
    true,
    24,
    'GET: WordPress feed, 10 madde (2026-09-14)'
  ),
  (
    'Gümüşhane BB RSS',
    'https://www.gumushane.bel.tr/rss/',
    'rss',
    true,
    24,
    'GET: RSS, 20 madde (2026-09-14)'
  ),
  (
    'Kahramanmaraş BB RSS',
    'https://www.kahramanmaras.bel.tr/rss.xml',
    'rss',
    true,
    24,
    'GET: rss.xml, 10 madde (2026-09-14)'
  ),
  (
    'Kastamonu BB RSS',
    'https://www.kastamonu.bel.tr/feed/',
    'rss',
    true,
    24,
    'GET: WordPress feed, 10 madde (2026-09-14)'
  ),
  (
    'Kilis BB RSS',
    'https://www.kilis.bel.tr/index.php/feed/',
    'rss',
    true,
    24,
    'GET: WordPress feed, 10 madde (2026-09-14)'
  ),
  (
    'Kocaeli BB RSS',
    'https://www.kocaeli.bel.tr/rss.xml',
    'rss',
    true,
    24,
    'GET: rss.xml, 20 madde (2026-09-14)'
  ),
  (
    'Osmaniye BB RSS',
    'https://osmaniye-bld.gov.tr/feed',
    'rss',
    true,
    24,
    'osmaniye.bel.tr → osmaniye-bld.gov.tr/feed (GET RSS, 2026-09-14)'
  ),
  (
    'Şırnak BB RSS',
    'https://www.sirnak.bel.tr/feed/',
    'rss',
    true,
    24,
    'GET: WordPress feed, 5 madde (2026-09-14)'
  ),
  (
    'MEB ORGM duyurular RSS',
    'https://orgm.meb.gov.tr/meb_iys_dosyalar/xml/rss_duyurular.xml',
    'rss',
    true,
    24,
    'Özel Eğitim ve Rehberlik Hizmetleri GM. GET: RSS 50 madde (2026-09-14). www.meb.gov.tr/rss.php 404.'
  ),
  (
    'MEB ORGM haberler RSS',
    'https://orgm.meb.gov.tr/meb_iys_dosyalar/xml/rss_haberler.xml',
    'rss',
    true,
    24,
    'Özel Eğitim ve Rehberlik Hizmetleri GM. GET: RSS 5 madde (2026-09-14).'
  ),
  (
    'Bursa BB RSS',
    'https://www.bursa.bel.tr/rss',
    'rss',
    false,
    168,
    'GET ile RSS doğrulandı ama genel haber; spor/konser dökülmesin diye KAPALI. Engelli süzgeci olsa da açmayın.'
  ),
  (
    'Adana BB',
    'https://www.adana.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Adıyaman BB',
    'https://www.adiyaman.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Afyonkarahisar BB',
    'https://www.afyon.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS/Atom madde yok. is_active=false.'
  ),
  (
    'Amasya BB',
    'https://www.amasya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Ankara BB',
    'https://www.ankara.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). /rss HTML SPA; XML değil. is_active=false.'
  ),
  (
    'Antalya BB',
    'https://www.antalya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Artvin BB',
    'https://www.artvin.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Aydın BB',
    'https://www.aydin.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Balıkesir BB',
    'https://www.balikesir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Bilecik BB',
    'https://www.bilecik.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Bingöl BB',
    'https://www.bingol.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Bitlis BB',
    'https://www.bitlis.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). /feed XML ama madde yok. is_active=false.'
  ),
  (
    'Çanakkale BB',
    'https://www.canakkale.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Çankırı BB',
    'https://www.cankiri.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Çorum BB',
    'https://www.corum.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Denizli BB',
    'https://www.denizli.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Diyarbakır BB',
    'https://www.diyarbakir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). çok dilli sitemap; RSS madde yok. is_active=false.'
  ),
  (
    'Düzce BB',
    'https://www.duzce.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Edirne BB',
    'https://www.edirne.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Elazığ BB',
    'https://www.elazig.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Erzincan BB',
    'https://www.erzincan.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Erzurum BB',
    'https://www.erzurum.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Eskişehir BB',
    'https://www.eskisehir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Gaziantep BB',
    'https://www.gaziantep.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Hakkari BB',
    'https://www.hakkari.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Hatay BB',
    'https://www.hatay.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Iğdır BB',
    'https://www.igdir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Isparta BB',
    'https://www.isparta.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'İBB',
    'https://www.ibb.istanbul',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; /rss 404. HTML ana sayfa tarama KAPALI.. is_active=false.'
  ),
  (
    'İzmir BB',
    'https://www.izmir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Karabük BB',
    'https://www.karabuk.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Karaman BB',
    'https://www.karaman.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Kars BB',
    'https://www.kars.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Kayseri BB',
    'https://www.kayseri.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Kırıkkale BB',
    'https://www.kirikkale.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Kırklareli BB',
    'https://www.kirklareli.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Kırşehir BB',
    'https://www.kirsehir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Konya BB',
    'https://www.konya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Kütahya BB',
    'https://www.kutahya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Malatya BB',
    'https://www.malatya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Manisa BB',
    'https://www.manisa.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Mardin BB',
    'https://www.mardin.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Mersin BB',
    'https://www.mersin.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Muğla BB',
    'https://www.mugla.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). muğla.bel.tr → mugla.bel.tr. is_active=false.'
  ),
  (
    'Muş BB',
    'https://www.mus.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Nevşehir BB',
    'https://www.nevsehir.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Niğde BB',
    'https://www.nigde.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Ordu BB',
    'https://www.ordu.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Osmaniye BB ana sayfa',
    'https://www.osmaniye.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). RSS osmaniye-bld.gov.tr/feed (ayrı aktif kayıt). is_active=false.'
  ),
  (
    'Rize BB',
    'https://www.rize.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Sakarya BB',
    'https://www.sakarya.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Samsun BB',
    'https://www.samsun.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Siirt BB',
    'https://www.siirt.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Sinop BB',
    'https://www.sinop.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Sivas BB',
    'https://www.sivas.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Şanlıurfa BB',
    'https://www.sanliurfa.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Tekirdağ BB',
    'https://www.tekirdag.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Tokat BB',
    'https://www.tokat.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Trabzon BB',
    'https://www.trabzon.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Tunceli BB',
    'https://www.tunceli.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Uşak BB',
    'https://www.usak.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Van BB',
    'https://www.van.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Yalova BB',
    'https://www.yalova.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Yozgat BB',
    'https://www.yozgat.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Zonguldak BB',
    'https://www.zonguldak.bel.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI. is_active=false.'
  ),
  (
    'Adalet Bakanlığı',
    'https://www.adalet.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Aile ve Sosyal Hizmetler Bakanlığı',
    'https://www.aile.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). EYHGM HTML var; RSS/sitemap 404. HTML döküm KAPALI.'
  ),
  (
    'Çalışma ve Sosyal Güvenlik Bakanlığı',
    'https://www.csgb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Çevre, Şehircilik ve İklim Değişikliği Bakanlığı',
    'https://www.csb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Dışişleri Bakanlığı',
    'https://www.mfa.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Yalnız İngilizce RSS bulundu; TR engelli haberi değil, KAPALI.'
  ),
  (
    'Enerji ve Tabii Kaynaklar Bakanlığı',
    'https://www.enerji.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok'
  ),
  (
    'Gençlik ve Spor Bakanlığı',
    'https://www.gsb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Hazine ve Maliye Bakanlığı',
    'https://www.hmb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'İçişleri Bakanlığı',
    'https://www.icisleri.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Kültür ve Turizm Bakanlığı',
    'https://www.kultur.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Millî Eğitim Bakanlığı',
    'https://www.meb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). rss.php 404. Aktif kaynak: orgm.meb.gov.tr RSS.'
  ),
  (
    'Millî Savunma Bakanlığı',
    'https://www.msb.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Sağlık Bakanlığı',
    'https://www.saglik.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). RSS tanıtım sayfası HTML; XML akış yok'
  ),
  (
    'Sanayi ve Teknoloji Bakanlığı',
    'https://www.sanayi.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok'
  ),
  (
    'Tarım ve Orman Bakanlığı',
    'https://www.tarimorman.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok'
  ),
  (
    'Ticaret Bakanlığı',
    'https://www.ticaret.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). Ana sayfa HTML tarama KAPALI.'
  ),
  (
    'Ulaştırma ve Altyapı Bakanlığı',
    'https://www.uab.gov.tr',
    'scrape',
    false,
    168,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap var; RSS madde yok'
  ),
  (
    'TBB Büyükşehir Belediyeleri',
    'https://www.tbb.gov.tr/tr/buyuksehir-belediyeleri',
    'scrape',
    false,
    168,
    'Belediye indeks listesi; haber RSS yok. Çekme.'
  ),
  (
    'TBB İl Belediyeleri',
    'https://www.tbb.gov.tr/tr/il-belediyeleri',
    'scrape',
    false,
    168,
    'Belediye indeks listesi; haber RSS yok. Çekme.'
  ),
  (
    'TBB Bağlı İdareler',
    'https://www.tbb.gov.tr/tr/bagli-idareler',
    'scrape',
    false,
    168,
    'İdare indeks listesi; haber RSS yok. Çekme.'
  )
) as v(name, url, method, is_active, fetch_interval_hours, notes)
where not exists (
  select 1 from public.content_sources s where s.url = v.url
);

-- Yeniden çalıştırılırsa doğrulanmış RSS'leri aç (Bursa hariç).
update public.content_sources
set
  is_active = true,
  method = 'rss',
  fetch_interval_hours = 24,
  notes = case
    when btrim(notes) = '' then 'GET ile RSS/Atom doğrulandı (2026-09-14).'
    else notes
  end,
  updated_at = now()
where url in (
  'https://www.agri.bel.tr/rss/',
  'https://www.bolu.bel.tr/feed/',
  'https://burdur.bel.tr/feed/',
  'https://giresun.bel.tr/feed/',
  'https://www.gumushane.bel.tr/rss/',
  'https://www.kahramanmaras.bel.tr/rss.xml',
  'https://www.kastamonu.bel.tr/feed/',
  'https://www.kilis.bel.tr/index.php/feed/',
  'https://www.kocaeli.bel.tr/rss.xml',
  'https://osmaniye-bld.gov.tr/feed',
  'https://www.sirnak.bel.tr/feed/',
  'https://orgm.meb.gov.tr/meb_iys_dosyalar/xml/rss_duyurular.xml',
  'https://orgm.meb.gov.tr/meb_iys_dosyalar/xml/rss_haberler.xml'
);

-- Bursa genel haber RSS: doğrulanmış olsa da kapalı.
update public.content_sources
set
  is_active = false,
  notes = 'genel haber RSS; spor/konser dökülmesin diye kapalı. Engelli süzgeci olsa da açmayın.',
  updated_at = now()
where url ilike '%bursa.bel.tr%';

-- TBB belediye listeleri haber değil.
update public.content_sources
set
  is_active = false,
  notes = 'belediye/idare indeks listesi; haber RSS yok',
  updated_at = now()
where url ilike '%tbb.gov.tr/tr/buyuksehir-belediyeleri%'
   or url ilike '%tbb.gov.tr/tr/il-belediyeleri%'
   or url ilike '%tbb.gov.tr/tr/bagli-idareler%';

notify pgrst, 'reload schema';
