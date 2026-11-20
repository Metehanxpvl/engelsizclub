"""Geçici teşhis: büyükşehir AVM etkinlik sayfaları. Sonuç: diag_out.json"""
import json, re, sys, time, urllib.parse
import httpx, urllib3
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

BIG = {"İstanbul", "Ankara", "İzmir", "Bursa", "Antalya", "Adana", "Konya", "Gaziantep", "Kocaeli", "Mersin", "Kayseri", "Eskişehir", "Samsun", "Diyarbakır"}
src = [s for s in json.load(open("scripts/avm_sources.json")) if s["city"] in BIG]
NEW = [
 ("İstanbul","Marmara Park","https://www.marmarapark.com/"),
 ("İstanbul","Viaport Asia","https://www.viaportasia.com/"),
 ("İstanbul","Optimum İstanbul","https://www.optimumistanbul.com.tr/"),
 ("İstanbul","Venezia Mega Outlet","https://www.veneziamegaoutlet.com/"),
 ("İstanbul","Torium","https://www.torium.com.tr/"),
 ("İstanbul","Aqua Florya","https://www.aquaflorya.com/"),
 ("İstanbul","Starcity","https://www.starcity.com.tr/"),
 ("İstanbul","Marmara Forum","https://www.marmaraforum.com.tr/"),
 ("İstanbul","Buyaka","https://www.buyaka.com.tr/"),
 ("İstanbul","Watergarden","https://www.watergardenistanbul.com/"),
 ("İstanbul","Axis İstanbul","https://www.axisistanbul.com/"),
 ("İstanbul","Brandium","https://www.brandium.com.tr/"),
 ("İstanbul","Galleria Ataköy","https://www.galleria.com.tr/"),
 ("İstanbul","Meydan İstanbul","https://www.meydanistanbul.com.tr/"),
 ("İstanbul","212 İstanbul","https://www.212istanbul.com/"),
 ("İstanbul","Neomarin","https://www.neomarin.com.tr/"),
 ("Ankara","Atlantis","https://www.atlantisavm.com.tr/"),
 ("Ankara","Taurus","https://www.taurusavm.com.tr/"),
 ("Ankara","Optimum Ankara","https://www.optimumankara.com.tr/"),
 ("Ankara","Acity","https://www.acity.com.tr/"),
 ("Ankara","Podium Ankara","https://www.podiumankara.com/"),
 ("Ankara","Antares","https://www.antaresavm.com.tr/"),
 ("Ankara","Nata Vega","https://www.natavega.com.tr/"),
 ("İzmir","Mavibahçe","https://www.mavibahce.com.tr/"),
 ("İzmir","Westpark","https://www.westparkizmir.com/"),
 ("İzmir","Selway","https://www.selway.com.tr/"),
 ("İzmir","Ege Park Balçova","https://www.egeparkbalcova.com/"),
 ("İzmir","Park Bornova","https://www.parkbornova.com/"),
 ("Bursa","Podyum Park","https://www.podyumpark.com/"),
 ("Bursa","Sur Yapı Marka","https://www.suryapimarka.com/"),
 ("Antalya","Migros AVM Antalya","https://www.antalyamigrosavm.com/"),
 ("Antalya","Özdilek Park Antalya","https://www.ozdilekpark.com/"),
 ("Antalya","Deepo Outlet","https://www.deepo.com.tr/"),
]
targets = [(s["city"], s["avm_name"], s["events_url"], False) for s in src] + [(c, n, u, True) for c, n, u in NEW]

MONTH = r"(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)"
DATE_RE = re.compile(r"\b\d{1,2}(\s*[-–]\s*\d{1,2})?\s+" + MONTH + r"|\b\d{1,2}[./]\d{1,2}[./]20\d\d", re.I)
EV_RE = re.compile(r"etkinlik|event|aktivite|atolye|atölye|program|kampanya", re.I)
PATHS = ["", "etkinlikler", "etkinlik", "tr/etkinlikler", "etkinlikler-ve-kampanyalar", "events", "tr/etkinlik", "etkinlik-ve-kampanyalar", "duyurular"]
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
urllib3.disable_warnings()
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
    r = {"city": city, "name": name, "given": url, "new": is_new, "tries": []}
    parsed = urllib.parse.urlparse(url)
    hosts = [parsed.netloc]
    hosts.append(parsed.netloc[4:] if parsed.netloc.startswith("www.") else "www." + parsed.netloc)
    cand = [url] + [f"https://{h}/{p}" for h in hosts for p in PATHS]
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
            if best["dates"] >= 3 and u != url: break
        except Exception as e:
            r["tries"].append([u, str(e)[:100]])
        if len(r["tries"]) > 12: break
    r["best"] = best
    results.append(r)
    b = best or {}
    print(f"{city:10} {name:24} {'YENİ' if is_new else '    '} best={b.get('url','-')} mode={b.get('mode','-')} len={b.get('text_len',0)} tarih={b.get('dates',0)} link={len(b.get('links',[]))}", flush=True)
json.dump(results, open("diag_out.json", "w"), ensure_ascii=False)
br.close(); pw.stop()
