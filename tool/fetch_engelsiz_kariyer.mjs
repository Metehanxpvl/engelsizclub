/**
 * İŞKUR açık iş ilanları (Engelli kutusu işaretli) → web/ + assets JSON.
 * Katalog Supabase'e yazılmaz.
 *
 * Engelli filtresi (Ara postback, her sayfada):
 *   özel: ctl04$ctlEngelli=on
 *   kamu: ctl04$ctlKisiselDurum=10 (İlan Türü = Engelli)
 * İşyeri türü: ctl04$IsyeriTuruRadios = ozelSektorRadio | kamuRadio
 * Querystring meslek (mid=79417) bakım elemanı kilitler; kullanılmaz.
 * Node fetch POST WAF’ta elenir; curl geçer. 0 ilan / blokta mevcut JSON korunur.
 */
import {
  writeFileSync,
  readFileSync,
  mkdirSync,
  existsSync,
  mkdtempSync,
  rmSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SOURCE =
  'https://esube.iskur.gov.tr/istihdam/AcikIsIlanAra.aspx';
const DETAIL =
  'https://esube.iskur.gov.tr/Istihdam/AcikIsIlanDetay.aspx?uiID=';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const SEARCH_TARGET = 'ctl04$ctlAcikIsPageCommand$CommandItem_Search';
const NEXT_TARGET = 'ctl04$ctlDataPagerDetay$btnNext';
const JUMP_TARGET = 'ctl04$ctlDataPagerDetay$btnChangeCurrentPage';
const RADIO_NAME = 'ctl04$IsyeriTuruRadios';
const RADIO = { ozel: 'ozelSektorRadio', kamu: 'kamuRadio' };
const ENGELLI_CHECK = 'ctl04$ctlEngelli';
const KAMU_ILAN_TURU = 'ctl04$ctlKisiselDurum';
const KAMU_ILAN_ENGELLI = '10';
const curlBin = process.platform === 'win32' ? 'curl.exe' : 'curl';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const webOut = join(root, 'web', 'engelsiz-kariyer.json');
const assetOut = join(
  root,
  'assets',
  'engelsiz_kariyer',
  'engelsiz-kariyer.json',
);

function decodeEntities(s) {
  return String(s ?? '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .trim();
}

function attr(block, name) {
  const re = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(['"])([\\s\\S]*?)\\1`, 'i');
  const m = block.match(re);
  return m ? decodeEntities(m[2]) : '';
}

function inputValue(html, id) {
  const re = new RegExp(`<input[^>]*\\bid=["']${id}["'][^>]*>`, 'i');
  const tag = html.match(re)?.[0] ?? '';
  return attr(tag, 'value');
}

function parseCity(raw) {
  const text = decodeEntities(raw).replace(/\s+/g, ' ').trim();
  const paren = text.match(/\((?:Çalışma Yeri:\s*)?([^)]+)\)/i);
  const core = (paren ? paren[1] : text).replace(/\s+/g, ' ').trim();
  if (!core) return '';
  return core
    .split('/')
    .map((p) => {
      const t = p.trim();
      if (!t) return '';
      return t.charAt(0) + t.slice(1).toLocaleLowerCase('tr-TR');
    })
    .filter(Boolean)
    .join(' / ');
}

function normalizeSektor(employerType, fallback = '') {
  const t = String(employerType || '')
    .toLocaleLowerCase('tr-TR')
    .replaceAll('ö', 'o');
  if (t.includes('kamu')) return 'kamu';
  if (t.includes('ozel')) return 'ozel';
  return fallback === 'kamu' || fallback === 'ozel' ? fallback : '';
}

function tagItem(item, sektor) {
  const resolved = normalizeSektor(item.employerType, sektor) || sektor;
  return {
    ...item,
    employerType:
      item.employerType ||
      (resolved === 'kamu' ? 'Kamu' : resolved === 'ozel' ? 'Özel' : ''),
    sektor: resolved,
  };
}

function parseItems(html, sektor) {
  const items = [];
  const seen = new Set();
  const re = /<a\b[^>]*class=["'][^"']*share-toggle[^"']*["'][^>]*>/gi;
  let m;
  while ((m = re.exec(html))) {
    const tag = m[0];
    const id = attr(tag, 'data-ilanno');
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const title = attr(tag, 'data-meslekler') || 'Açık iş ilanı';
    const applyUrl = (attr(tag, 'data-url') || `${DETAIL}${id}`).replace(
      /^http:\/\//i,
      'https://',
    );
    items.push(
      tagItem(
        {
          id,
          title,
          city: parseCity(attr(tag, 'data-il')),
          date: attr(tag, 'data-sontarih'),
          applyUrl,
          positions: attr(tag, 'data-acikissayi'),
          employerType: attr(tag, 'data-isverentur'),
          workType: attr(tag, 'data-calismasekli'),
        },
        sektor,
      ),
    );
  }
  return items;
}

function pageInfo(html) {
  const cur = inputValue(html, 'ctl04_ctlDataPagerDetay_txtCurrentPage');
  const slash = html.match(
    /ctl04_ctlDataPagerDetay_txtCurrentPage[\s\S]{0,180}?\/\s*(\d+)/i,
  );
  const total = html.match(/Toplam\s+Kayıt:\s*(\d+)/i);
  const nextDisabled = /ctl04_ctlDataPagerDetay_btnNext[^>]*aspNetDisabled/i.test(
    html,
  );
  return {
    current: Number.parseInt(cur, 10) || 1,
    pages: Number.parseInt(slash?.[1] ?? '1', 10) || 1,
    totalRecords: Number.parseInt(total?.[1] ?? '0', 10) || 0,
    hasNext:
      !nextDisabled &&
      (Number.parseInt(cur, 10) || 1) <
        (Number.parseInt(slash?.[1] ?? '1', 10) || 1),
  };
}

function collectForm(html) {
  const form =
    html.match(/<form\b[^>]*id=["']form1["'][\s\S]*?<\/form>/i)?.[0] ?? html;
  const fields = {};
  const inputRe = /<input\b[^>]*>/gi;
  let m;
  while ((m = inputRe.exec(form))) {
    const tag = m[0];
    if (/type=["'](?:submit|image|button|file)["']/i.test(tag)) continue;
    const name = attr(tag, 'name');
    if (!name) continue;
    const type = (attr(tag, 'type') || 'text').toLowerCase();
    if (type === 'checkbox' || type === 'radio') {
      if (!/\bchecked\b/i.test(tag)) continue;
    }
    fields[name] = attr(tag, 'value');
  }
  const selectRe = /<select\b([^>]*)>([\s\S]*?)<\/select>/gi;
  while ((m = selectRe.exec(form))) {
    const open = m[1];
    if (/\bdisabled\b/i.test(open)) continue;
    const name = attr(`<select ${open}>`, 'name');
    if (!name) continue;
    const selected =
      m[2].match(/<option\b[^>]*selected[^>]*value=["']([^"']*)["']/i) ||
      m[2].match(/<option\b[^>]*value=["']([^"']*)["'][^>]*selected/i);
    fields[name] = selected ? decodeEntities(selected[1]) : fields[name] ?? '';
  }
  return fields;
}

function applyEngelliFilter(fields, sektor) {
  fields[ENGELLI_CHECK] = 'on';
  if (sektor === 'kamu') {
    fields[RADIO_NAME] = RADIO.kamu;
    fields[KAMU_ILAN_TURU] = KAMU_ILAN_ENGELLI;
  } else {
    fields[RADIO_NAME] = RADIO.ozel;
  }
  return fields;
}

function runCurl(args) {
  const r = spawnSync(curlBin, args, {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
  });
  if (r.status !== 0) {
    throw new Error(
      (r.stderr || r.stdout || `curl exit ${r.status}`).trim() ||
        `curl exit ${r.status}`,
    );
  }
  return r;
}

function curlGet(cookieFile) {
  const out = join(dirname(cookieFile), 'iskur-get.html');
  runCurl([
    '-sS',
    '-L',
    '-c',
    cookieFile,
    '-b',
    cookieFile,
    '-A',
    UA,
    '-H',
    'Accept: text/html,application/xhtml+xml',
    '-H',
    'Accept-Language: tr-TR,tr;q=0.9,en;q=0.8',
    '-o',
    out,
    SOURCE,
  ]);
  const html = readFileSync(out, 'utf8');
  if (/Request Rejected/i.test(html) || html.length < 2000) {
    throw new Error('İŞKUR GET WAF/engel');
  }
  return html;
}

function curlPost(cookieFile, fields, eventTarget) {
  const work = dirname(cookieFile);
  const bodyFile = join(work, 'iskur-post.txt');
  const out = join(work, 'iskur-post.html');
  const body = new URLSearchParams();
  for (const [k, v] of Object.entries(fields)) {
    if (k === '__EVENTTARGET' || k === '__EVENTARGUMENT') continue;
    body.set(k, v ?? '');
  }
  body.set('__EVENTTARGET', eventTarget);
  body.set('__EVENTARGUMENT', '');
  writeFileSync(bodyFile, body.toString());
  runCurl([
    '-sS',
    '-L',
    '-c',
    cookieFile,
    '-b',
    cookieFile,
    '-A',
    UA,
    '-H',
    'Accept: text/html,application/xhtml+xml',
    '-H',
    'Accept-Language: tr-TR,tr;q=0.9,en;q=0.8',
    '-H',
    'Origin: https://esube.iskur.gov.tr',
    '-H',
    'Content-Type: application/x-www-form-urlencoded',
    '-e',
    SOURCE,
    '-X',
    'POST',
    '--data-binary',
    `@${bodyFile}`,
    '-o',
    out,
    SOURCE,
  ]);
  const html = readFileSync(out, 'utf8');
  if (/Request Rejected/i.test(html) || html.length < 2000) {
    throw new Error('İŞKUR POST WAF/engel');
  }
  return html;
}

function paginate(html, cookieFile, sektor) {
  const all = [];
  const seen = new Set();
  const push = (list) => {
    for (const item of list) {
      if (seen.has(item.id)) continue;
      seen.add(item.id);
      all.push(item);
    }
  };
  push(parseItems(html, sektor));
  let info = pageInfo(html);
  const firstTotal = info.totalRecords;
  let guard = 0;
  while (info.hasNext && guard < 250) {
    guard += 1;
    const before = all.length;
    const fields = applyEngelliFilter(collectForm(html), sektor);
    html = curlPost(cookieFile, fields, NEXT_TARGET);
    push(parseItems(html, sektor));
    if (all.length === before) {
      const jump = applyEngelliFilter(collectForm(html), sektor);
      jump['ctl04$ctlDataPagerDetay$txtCurrentPage'] = String(info.current + 1);
      html = curlPost(cookieFile, jump, JUMP_TARGET);
      push(parseItems(html, sektor));
    }
    info = pageInfo(html);
  }
  return { items: all, info, firstTotal };
}

function fetchSector(sektor) {
  const work = mkdtempSync(join(tmpdir(), `iskur-${sektor}-`));
  const cookieFile = join(work, 'cookies.txt');
  try {
    writeFileSync(cookieFile, '');
    let html = curlGet(cookieFile);
    const fields = applyEngelliFilter(collectForm(html), sektor);
    html = curlPost(cookieFile, fields, SEARCH_TARGET);
    return paginate(html, cookieFile, sektor);
  } finally {
    try {
      rmSync(work, { recursive: true, force: true });
    } catch {
      /* ignore */
    }
  }
}

function fetchAll() {
  const ozel = fetchSector('ozel');
  let kamu;
  try {
    kamu = fetchSector('kamu');
  } catch (err) {
    console.warn(
      `Kamu listesi alınamadı: ${err instanceof Error ? err.message : err}`,
    );
    kamu = { items: [], info: { totalRecords: 0 }, firstTotal: 0 };
  }
  const items = [...kamu.items, ...ozel.items];
  return {
    items,
    ozel,
    kamu,
    firstTotal:
      (ozel.firstTotal || ozel.info.totalRecords || ozel.items.length) +
      (kamu.firstTotal || kamu.info.totalRecords || kamu.items.length),
  };
}

function readExisting() {
  if (!existsSync(webOut)) return null;
  try {
    return JSON.parse(readFileSync(webOut, 'utf8'));
  } catch {
    return null;
  }
}

function writeCatalog(payload) {
  const json = `${JSON.stringify(payload, null, 2)}\n`;
  mkdirSync(dirname(webOut), { recursive: true });
  mkdirSync(dirname(assetOut), { recursive: true });
  writeFileSync(webOut, json);
  writeFileSync(assetOut, json);
}

const existing = readExisting();
try {
  const { items, ozel, kamu, firstTotal } = fetchAll();
  if (!items.length) {
    console.warn(
      'İŞKUR 0 ilan döndü (JS/engel?). Mevcut JSON korunuyor. Fallback: web/engelsiz-kariyer.json dosyasını elle güncelleyin; Action tekrar dener.',
    );
    if (!existing?.items?.length) {
      writeCatalog({
        source: SOURCE,
        fetchedAt: new Date().toISOString(),
        ok: false,
        reason: 'empty_fetch',
        counts: { kamu: 0, ozel: 0 },
        items: [],
      });
    }
    process.exitCode = existing?.items?.length ? 0 : 2;
  } else {
    const payload = {
      source: SOURCE,
      fetchedAt: new Date().toISOString(),
      ok: true,
      totalHint: firstTotal || items.length,
      counts: {
        kamu: kamu.items.length,
        ozel: ozel.items.length,
      },
      items,
    };
    writeCatalog(payload);
    const ozelHint = ozel.firstTotal || ozel.info.totalRecords || 0;
    const note =
      ozelHint > ozel.items.length
        ? ` (özel kaynak ${ozelHint} kayıt bildirdi; sonraki sayfa atlandı)`
        : '';
    console.log(
      `Engelsiz Kariyer: ${items.length} ilan yazıldı (kamu ${kamu.items.length}, özel ${ozel.items.length}) (${webOut})${note}`,
    );
  }
} catch (err) {
  console.warn(
    `İŞKUR çekilemedi: ${err instanceof Error ? err.message : err}. Mevcut JSON korunuyor.`,
  );
  if (!existing?.items?.length) {
    writeCatalog({
      source: SOURCE,
      fetchedAt: new Date().toISOString(),
      ok: false,
      reason: 'fetch_error',
      counts: { kamu: 0, ozel: 0 },
      items: [],
    });
    process.exitCode = 2;
  }
}
