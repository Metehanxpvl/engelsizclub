-- Resmi TR belediye + bakanlık kaynakları → public.content_sources
-- SQL Editor → Run. events / kariyer / push tablolarına dokunmaz.
-- Collector YALNIZ pending_review yazar; yayın ve FCM yok.
-- is_active=true: doğrulanmış RSS/Atom + ASHB EYHGM HTML + Resmi Gazete fihrist
-- + .bel.tr ana sayfa scrape (Faz 2 site tarama: haberler/duyurular/ilanlar).
-- TBB indeks sayfaları ve Bursa genel RSS bilinçli kapalı.
-- muğla.bel.tr → mugla.bel.tr
-- Canlı DB’de yalnız .bel.tr açmak için kısa dosya: useful_content_bel_tr_activate.sql

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
    'ORGM https://orgm.meb.gov.tr/ HTML; /rss 404. Aktif akış: meb_iys_dosyalar/xml/rss_duyurular.xml (GET RSS, 2026-09-14).'
  ),
  (
    'MEB ORGM haberler RSS',
    'https://orgm.meb.gov.tr/meb_iys_dosyalar/xml/rss_haberler.xml',
    'rss',
    true,
    24,
    'ORGM https://orgm.meb.gov.tr/ HTML; aktif akış: meb_iys_dosyalar/xml/rss_haberler.xml (GET RSS, 2026-09-14).'
  ),
  (
    'Resmi Gazete',
    'https://www.resmigazete.gov.tr/',
    'scrape',
    true,
    24,
    'RSS/Atom yok: /rss /rss.xml /feed /sitemap.xml HTML SPA, /reg/rss.aspx 404 (2026-09-14). Collector bugün + son 3 gün fihrist (/eskiler/YYYY/MM/YYYYMMDD-N.htm). İlan arşivi yok. Engelli süzgeci zorunlu.'
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
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Adıyaman BB',
    'https://www.adiyaman.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Afyonkarahisar BB',
    'https://www.afyon.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS/Atom madde yok. is_active=false.'
  ),
  (
    'Amasya BB',
    'https://www.amasya.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Ankara BB',
    'https://www.ankara.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). /rss HTML SPA; XML değil. is_active=false.'
  ),
  (
    'Antalya BB',
    'https://www.antalya.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Artvin BB',
    'https://www.artvin.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Aydın BB',
    'https://www.aydin.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Balıkesir BB',
    'https://www.balikesir.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Bilecik BB',
    'https://www.bilecik.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Bingöl BB',
    'https://www.bingol.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Bitlis BB',
    'https://www.bitlis.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). /feed XML ama madde yok. is_active=false.'
  ),
  (
    'Çanakkale BB',
    'https://www.canakkale.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Çankırı BB',
    'https://www.cankiri.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Çorum BB',
    'https://www.corum.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Denizli BB',
    'https://www.denizli.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Diyarbakır BB',
    'https://www.diyarbakir.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). çok dilli sitemap; RSS madde yok. is_active=false.'
  ),
  (
    'Düzce BB',
    'https://www.duzce.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Edirne BB',
    'https://www.edirne.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Elazığ BB',
    'https://www.elazig.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Erzincan BB',
    'https://www.erzincan.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Erzurum BB',
    'https://www.erzurum.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Eskişehir BB',
    'https://www.eskisehir.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Gaziantep BB',
    'https://www.gaziantep.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Hakkari BB',
    'https://www.hakkari.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Hatay BB',
    'https://www.hatay.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Iğdır BB',
    'https://www.igdir.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Isparta BB',
    'https://www.isparta.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'İBB',
    'https://www.ibb.istanbul',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; /rss 404. HTML ana sayfa tarama KAPALI.. is_active=false.'
  ),
  (
    'İzmir BB',
    'https://www.izmir.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Karabük BB',
    'https://www.karabuk.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Karaman BB',
    'https://www.karaman.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Kars BB',
    'https://www.kars.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Kayseri BB',
    'https://www.kayseri.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Kırıkkale BB',
    'https://www.kirikkale.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Kırklareli BB',
    'https://www.kirklareli.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Kırşehir BB',
    'https://www.kirsehir.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Konya BB',
    'https://www.konya.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Kütahya BB',
    'https://www.kutahya.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Malatya BB',
    'https://www.malatya.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Manisa BB',
    'https://www.manisa.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Mardin BB',
    'https://www.mardin.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Mersin BB',
    'https://www.mersin.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Muğla BB',
    'https://www.mugla.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). muğla.bel.tr → mugla.bel.tr. is_active=false.'
  ),
  (
    'Muş BB',
    'https://www.mus.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Nevşehir BB',
    'https://www.nevsehir.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Niğde BB',
    'https://www.nigde.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Ordu BB',
    'https://www.ordu.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Osmaniye BB ana sayfa',
    'https://www.osmaniye.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). RSS osmaniye-bld.gov.tr/feed (ayrı aktif kayıt). is_active=false.'
  ),
  (
    'Rize BB',
    'https://www.rize.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Sakarya BB',
    'https://www.sakarya.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Samsun BB',
    'https://www.samsun.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Siirt BB',
    'https://www.siirt.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Sinop BB',
    'https://www.sinop.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Sivas BB',
    'https://www.sivas.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Şanlıurfa BB',
    'https://www.sanliurfa.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Tekirdağ BB',
    'https://www.tekirdag.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Tokat BB',
    'https://www.tokat.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Trabzon BB',
    'https://www.trabzon.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Tunceli BB',
    'https://www.tunceli.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Uşak BB',
    'https://www.usak.bel.tr',
    'scrape',
    true,
    24,
    'Doğrulanmış RSS/Atom yok (2026-09-14). sitemap.xml var; RSS madde yok. is_active=false.'
  ),
  (
    'Van BB',
    'https://www.van.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Yalova BB',
    'https://www.yalova.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Yozgat BB',
    'https://www.yozgat.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  ),
  (
    'Zonguldak BB',
    'https://www.zonguldak.bel.tr',
    'scrape',
    true,
    24,
    'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
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
    'Bakanlık ana sayfa HTML; RSS/sitemap 404. Aktif kaynak: https://www.aile.gov.tr/eyhgm'
  ),
  (
    'ASHB EYHGM (Engelli ve Yaşlı Hizmetleri)',
    'https://www.aile.gov.tr/eyhgm',
    'scrape',
    true,
    24,
    'RSS/Atom yok (2026-09-14). Collector /eyhgm/haberler + /eyhgm/duyurular HTML listesini çeker; bakanlık ana sayfa kapalı.'
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

-- ASHB EYHGM: RSS yok, dar HTML liste (haberler + duyurular).
update public.content_sources
set
  is_active = true,
  method = 'scrape',
  fetch_interval_hours = 24,
  notes = 'RSS/Atom yok (2026-09-14). Collector /eyhgm/haberler + /eyhgm/duyurular HTML listesini çeker.',
  updated_at = now()
where url in (
  'https://www.aile.gov.tr/eyhgm',
  'https://www.aile.gov.tr/eyhgm/',
  'https://www.aile.gov.tr/eyhgm/haberler',
  'https://www.aile.gov.tr/eyhgm/duyurular'
);

-- Resmi Gazete: RSS/Atom yok, dar HTML fihrist (bugün + son 3 gün).
update public.content_sources
set
  name = 'Resmi Gazete',
  is_active = true,
  method = 'scrape',
  fetch_interval_hours = 24,
  notes = 'RSS/Atom yok: /rss /rss.xml /feed /sitemap.xml HTML SPA, /reg/rss.aspx 404 (2026-09-14). Collector bugün + son 3 gün fihrist (/eskiler/YYYY/MM/YYYYMMDD-N.htm). İlan arşivi yok. Engelli süzgeci zorunlu.',
  updated_at = now()
where url in (
  'https://www.resmigazete.gov.tr/',
  'https://www.resmigazete.gov.tr'
);

-- Faz 2: mevcut .bel.tr (ve İBB) ana sayfa scrape satırlarını aç.
-- RSS satırlarına dokunmaz. İçerik silinmez. TBB / bakanlık ana sayfa kapalı kalır.
update public.content_sources
set
  is_active = true,
  method = 'scrape',
  fetch_interval_hours = 24,
  notes = case
    when notes ilike '%Faz 2%' then notes
    else 'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.'
  end,
  updated_at = now()
where method = 'scrape'
  and (
    url ~* '\.bel\.tr([/?#]|$)'
    or url ~* '(^|://)([^/]*\.)?ibb\.istanbul([/?#]|$)'
  )
  and url !~* 'tbb\.gov\.tr'
  and url !~* 'bursa\.bel\.tr/rss';

update public.content_sources
set
  is_active = false,
  notes = '404 /reg/rss.aspx. Aktif kaynak: https://www.resmigazete.gov.tr/',
  updated_at = now()
where url ilike '%resmigazete.gov.tr/reg/rss.aspx%';

update public.content_sources
set
  is_active = false,
  notes = 'Bakanlık ana sayfa HTML; RSS yok. Aktif kaynak: https://www.aile.gov.tr/eyhgm',
  updated_at = now()
where url in (
  'https://www.aile.gov.tr',
  'https://www.aile.gov.tr/',
  'https://www.aile.gov.tr/sitemap.xml'
);

-- Bursa genel haber RSS: doğrulanmış olsa da kapalı. Ana sayfa scrape satırı yoksa dokunulmaz.
update public.content_sources
set
  is_active = false,
  notes = 'genel haber RSS; spor/konser dökülmesin diye kapalı. Faz 2 filtreyle scrape ayrı URL ister.',
  updated_at = now()
where url ilike '%bursa.bel.tr%rss%'
   or url ~* 'bursa\.bel\.tr/rss';

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
