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
    # Belediye / devlet / müze kaynaklarının çoğu scripts/kultur_sources.json
    # üzerinden avm_scraper.py (Gemini + detay sayfası) ile okunuyor.
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
]
