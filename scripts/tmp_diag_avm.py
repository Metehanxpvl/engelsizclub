"""Geçici teşhis: büyükşehir AVM etkinlik sayfaları. Sonuç: diag_out.json"""
import json, re, sys, time, urllib.parse
import httpx
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

T = [
 ("Türkiye","Kültür Portalı",["https://www.kulturportali.gov.tr/etkinlikler","https://www.kulturportali.gov.tr/turkiye/etkinlikler","https://www.kulturportali.gov.tr/etkinlik"]),
 ("İstanbul","İBB Kültür",["https://kultur.istanbul/etkinlikler","https://kultur.istanbul/","https://kultursanat.istanbul/"]),
 ("İstanbul","İBB Şehir Tiyatroları",["https://sehirtiyatrolari.ibb.istanbul/","https://sehirtiyatrolari.ibb.istanbul/oyunlar","https://sehirtiyatrolari.ibb.istanbul/cocuk-oyunlari"]),
 ("Türkiye","Devlet Tiyatroları",["https://www.devtiyatro.gov.tr/DevletTiyatro/tr/oyunlar","https://www.devtiyatro.gov.tr/DevletTiyatro/tr/takvim","https://www.devtiyatro.gov.tr/"]),
 ("Türkiye","Devlet Opera ve Balesi",["https://www.operabale.gov.tr/tr-TR/Sayfalar/Takvim.aspx","https://www.operabale.gov.tr/tr-TR/Sayfalar/default.aspx","https://www.operabale.gov.tr/"]),
 ("Ankara","Ankara Büyükşehir",["https://www.ankara.bel.tr/etkinlikler","https://kultursanat.ankara.bel.tr/","https://www.ankara.bel.tr/kultur-sanat"]),
 ("İzmir","İzmir Büyükşehir",["https://kultursanat.izmir.bel.tr/tr/Etkinlikler","https://www.izmir.bel.tr/tr/Etkinlikler","https://kultursanat.izmir.bel.tr/"]),
 ("Bursa","Bursa Büyükşehir",["https://www.bursa.bel.tr/etkinlikler","https://www.bursa.bel.tr/kultur-sanat","https://kultur.bursa.bel.tr/"]),
 ("Antalya","Antalya Büyükşehir",["https://www.antalya.bel.tr/tr/etkinlikler","https://www.antalya.bel.tr/etkinlikler"]),
 ("Konya","Konya Bilim Merkezi",["https://www.konyabilimmerkezi.com/etkinlikler","https://www.konyabilimmerkezi.com/"]),
 ("Ankara","Millet Kütüphanesi",["https://www.milletkutuphanesi.gov.tr/etkinlikler","https://www.milletkutuphanesi.gov.tr/"]),
 ("İstanbul","Rahmi Koç Müzesi",["https://www.rmk-museum.org.tr/","https://www.rmk-museum.org.tr/tr/etkinlikler"]),
 ("İstanbul","İstanbul Modern",["https://www.istanbulmodern.org/etkinlikler","https://www.istanbulmodern.org/tr/etkinlikler"]),
 ("İstanbul","Pera Müzesi",["https://www.peramuzesi.org.tr/etkinlikler","https://www.peramuzesi.org.tr/"]),
 ("İstanbul","Sabancı Müzesi",["https://www.sakipsabancimuzesi.org/etkinlikler","https://www.sakipsabancimuzesi.org/"]),
 ("Türkiye","Özel Olimpiyatlar",["https://www.ozelolimpiyatlar.org.tr/","https://www.specialolympicsturkey.org/"]),
 ("Türkiye","TOHAD",["https://www.tohad.org.tr/","https://tohad.org/"]),
 ("İstanbul","Kadıköy Belediyesi",["https://www.kadikoy.bel.tr/etkinlikler","https://kultur.kadikoy.bel.tr/"]),
 ("İstanbul","Beşiktaş Belediyesi",["https://www.besiktas.bel.tr/etkinlikler","https://www.besiktas.bel.tr/"]),
 ("Ankara","Çankaya Belediyesi",["https://www.cankaya.bel.tr/etkinlikler","https://www.cankaya.bel.tr/"]),
 ("Bursa","Nilüfer Belediyesi",["https://www.nilufer.bel.tr/etkinlikler","https://www.nilufer.bel.tr/"]),
 ("İzmir","Bornova Belediyesi",["https://www.bornova.bel.tr/etkinlikler","https://www.bornova.bel.tr/"]),
 ("İzmir","Karşıyaka Belediyesi",["https://www.karsiyaka.bel.tr/etkinlikler","https://www.karsiyaka.bel.tr/"]),
 ("Türkiye","TÜBİTAK Bilim Merkezleri",["https://bilimmerkezleri.tubitak.gov.tr/","https://bilimmerkezleri.tubitak.gov.tr/etkinlikler"]),
 ("İstanbul","Üsküdar Belediyesi",["https://www.uskudar.bel.tr/tr/etkinlikler","https://www.uskudar.bel.tr/"]),
 ("İstanbul","Ataşehir Belediyesi",["https://www.atasehir.bel.tr/etkinlikler","https://www.atasehir.bel.tr/"]),
 ("Ankara","Keçiören Belediyesi",["https://www.kecioren.bel.tr/etkinlikler","https://www.kecioren.bel.tr/"]),
 ("Gaziantep","Gaziantep Büyükşehir",["https://www.gaziantep.bel.tr/tr/etkinlikler","https://www.gaziantep.bel.tr/"]),
 ("Kocaeli","Kocaeli Büyükşehir",["https://www.kocaeli.bel.tr/tr/main/etkinlikler","https://www.kocaeli.bel.tr/"]),
 ("Eskişehir","Eskişehir Büyükşehir",["https://www.eskisehir.bel.tr/etkinlikler","https://www.eskisehir.bel.tr/"]),
]
targets = [(c,n,u,False) for c,n,u in T]
MONTH = r"(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)"
DATE_RE = re.compile(r"\b\d{1,2}(\s*[-–]\s*\d{1,2})?\s+" + MONTH + r"|\b\d{1,2}[./]\d{1,2}[./]20\d\d", re.I)
EV_RE = re.compile(r"etkinlik|event|aktivite|atolye|atölye|program|kampanya", re.I)
PATHS = ["", "etkinlikler", "etkinlik", "tr/etkinlikler", "etkinlikler-ve-kampanyalar", "events", "tr/etkinlik", "etkinlik-ve-kampanyalar", "duyurular"]
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

http = httpx.Client(verify=False, timeout=20, follow_redirects=True, headers={"User-Agent": UA, "Accept-Language": "tr-TR,tr;q=0.9"})

def text_of(html):
    s = BeautifulSoup(html, "html.parser")
    for t in s(["script", "style", "noscript"]): t.decompose()
    return re.sub(r"\s+", " ", s.get_text(" ")).strip()

def links_of(html, base):
    s = BeautifulSoup(html, "html.parser")
    out = []
    for a in s.find_all("a", href=True):
        h = urllib.parse.urljoin(base, a["href"])
        t = re.sub(r"\s+", " ", a.get_text(" ")).strip()[:80]
        if EV_RE.search(h) or EV_RE.search(t):
            if h not in [o[0] for o in out]: out.append((h, t))
    return out[:25]

def analyze(html, url):
    t = text_of(html)
    return {"url": url, "text_len": len(t), "dates": len(DATE_RE.findall(t)), "links": links_of(html, url), "text": t[:6000], "jsonld_event": html.count('"Event"')}

pw = sync_playwright().start(); br = pw.chromium.launch()
def render(url):
    ctx = br.new_context(user_agent=UA, locale="tr-TR", ignore_https_errors=True)
    try:
        p = ctx.new_page(); p.goto(url, wait_until="domcontentloaded", timeout=30000)
        try: p.wait_for_load_state("networkidle", timeout=8000)
        except Exception: pass
        p.wait_for_timeout(1500)
        return p.content(), p.url
    finally: ctx.close()

results = []
for city, name, url, is_new in targets:
    r = {"city": city, "name": name, "given": url[0], "new": is_new, "tries": []}
    cand = list(url)
    seen = set(); best = None
    for u in cand:
        if u in seen: continue
        seen.add(u)
        try:
            res = http.get(u)
            if res.status_code >= 400:
                r["tries"].append([u, res.status_code]); continue
            a = analyze(res.text, str(res.url)); a["mode"] = "http"
            if a["text_len"] < 400 or a["dates"] == 0:
                try:
                    h2, fu = render(u); b = analyze(h2, fu); b["mode"] = "pw"
                    if b["dates"] > a["dates"] or b["text_len"] > a["text_len"] * 1.5: a = b
                except Exception as e:
                    r["tries"].append([u, "pw:" + str(e)[:80]])
            r["tries"].append([u, a["mode"], a["text_len"], a["dates"]])
            if best is None or (a["dates"], a["text_len"]) > (best["dates"], best["text_len"]): best = a
            pass
        except Exception as e:
            r["tries"].append([u, str(e)[:100]])
        if len(r["tries"]) > 12: break
    r["best"] = best
    results.append(r)
    b = best or {}
    print(f"{city:10} {name:24} best={b.get('url','-')} mode={b.get('mode','-')} len={b.get('text_len',0)} tarih={b.get('dates',0)} link={len(b.get('links',[]))}", flush=True)
    for t in r["tries"]: print("    try:", t, flush=True)
    txt = b.get("text","")
    m = DATE_RE.search(txt)
    if m:
        i = max(0, m.start()-150); print("    örnek:", txt[i:i+500].replace("\n"," "), flush=True)
json.dump(results, open("diag_out.json", "w"), ensure_ascii=False)
br.close(); pw.stop()
