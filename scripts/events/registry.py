"""Kayıt listesi. Yeni kaynak = bu dosyaya bir satır + gerekirse tek modül."""

from __future__ import annotations

from events.sources.generic import GenericHtmlSource

# robots/ToS/sosyal medya nedeniyle atlananlar (scrape yok).
SKIPPED_SOURCES: list[dict[str, str]] = [
    {
        "name": "Instagram / Facebook / X",
        "reason": "Sosyal medya scraping yok (kural).",
    },
    {
        "name": "Biletix",
        "reason": "Ticari bilet platformu; kullanım koşulları ve JS duvarı.",
    },
    {
        "name": "Passo",
        "reason": "Ticari bilet; resmi açık takvim/API yok.",
    },
    {
        "name": "Bubilet / Biletinial",
        "reason": "Ticari bilet; robots/ToS belirsiz, kart kazıma yok.",
    },
    {
        "name": "Eventbrite TR / Meetup",
        "reason": "API/ToS kısıtı; kimlik gerektirebilir.",
    },
    {
        "name": "Etkinlik.io",
        "reason": "ToS belirsiz; şimdilik atlandı.",
    },
]

SOURCES = [
    GenericHtmlSource(
        source_id="ibb-kultur",
        name="İBB Kültür",
        source_type="belediye",
        start_url="https://kultur.istanbul/etkinlikler",
        city="İstanbul",
        venue="İBB Kültür",
    ),
    GenericHtmlSource(
        source_id="devlet-tiyatrolari",
        name="Devlet Tiyatroları",
        source_type="belediye",
        start_url="https://www.devtiyatro.gov.tr/",
        city="Türkiye",
        venue="Devlet Tiyatroları",
    ),
    GenericHtmlSource(
        source_id="devlet-opera",
        name="Devlet Opera ve Balesi",
        source_type="belediye",
        start_url="https://www.operabale.gov.tr/",
        city="Türkiye",
        venue="Devlet Opera ve Balesi",
    ),
    GenericHtmlSource(
        source_id="ankara-kultur",
        name="Ankara Büyükşehir Kültür",
        source_type="belediye",
        start_url="https://www.ankara.bel.tr/",
        city="Ankara",
        venue="Ankara Büyükşehir",
    ),
    GenericHtmlSource(
        source_id="izmir-kultur",
        name="İzmir Büyükşehir Kültür",
        source_type="belediye",
        start_url="https://www.izmir.bel.tr/",
        city="İzmir",
        venue="İzmir Büyükşehir",
    ),
    GenericHtmlSource(
        source_id="rahmi-koc",
        name="Rahmi Koç Müzesi",
        source_type="muze",
        start_url="https://www.rmk-museum.org.tr/etkinlikler",
        city="İstanbul",
        venue="Rahmi Koç Müzesi",
    ),
    GenericHtmlSource(
        source_id="istanbul-modern",
        name="İstanbul Modern",
        source_type="muze",
        start_url="https://www.istanbulmodern.org/tr/etkinlikler",
        city="İstanbul",
        venue="İstanbul Modern",
    ),
    GenericHtmlSource(
        source_id="pera-muze",
        name="Pera Müzesi",
        source_type="muze",
        start_url="https://www.peramuseum.org/tr/etkinlikler",
        city="İstanbul",
        venue="Pera Müzesi",
    ),
    GenericHtmlSource(
        source_id="sabanci-muze",
        name="Sabancı Müzesi",
        source_type="muze",
        start_url="https://www.sakipsabancimuzesi.org/tr/etkinlikler",
        city="İstanbul",
        venue="Sabancı Müzesi",
    ),
    GenericHtmlSource(
        source_id="salt",
        name="Salt",
        source_type="muze",
        start_url="https://saltonline.org/tr/etkinlikler",
        city="İstanbul",
        venue="Salt",
    ),
    GenericHtmlSource(
        source_id="akbank-sanat",
        name="Akbank Sanat",
        source_type="muze",
        start_url="https://www.akbanksanat.com/etkinlikler",
        city="İstanbul",
        venue="Akbank Sanat",
    ),
    GenericHtmlSource(
        source_id="iksv",
        name="İKSV",
        source_type="platform",
        start_url="https://www.iksv.org/tr",
        city="İstanbul",
        venue="İKSV",
    ),
    GenericHtmlSource(
        source_id="tocev",
        name="TOÇEV",
        source_type="dernek",
        start_url="https://www.tocev.org.tr/",
        city="Türkiye",
        venue="TOÇEV",
    ),
    GenericHtmlSource(
        source_id="toh-ad",
        name="TOHAD",
        source_type="dernek",
        start_url="https://www.tohad.org/",
        city="Türkiye",
        venue="TOHAD",
    ),
    GenericHtmlSource(
        source_id="special-olympics-tr",
        name="Özel Olimpiyatlar Türkiye",
        source_type="dernek",
        start_url="https://www.specialolympics.org.tr/",
        city="Türkiye",
        venue="Özel Olimpiyatlar Türkiye",
    ),
]
