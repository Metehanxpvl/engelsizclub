/**
 * Build a compact GTIN → name + etken madde index from public TİTCK / SGK files.
 * No ITS / Oyak API. Sources: dinamikmodul/43 (all sheets), dinamikmodul/85,
 * SGK EK-4/A Excel, optional GitHub mirrors.
 *
 *   node tool/build_titck_gtin_index.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outPath = path.join(root, 'assets', 'medicines', 'titck_skrs_gtin.json');
const tmpDir = path.join(root, 'tool', '.gtin-cache');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

function loadXlsx() {
  const require = createRequire(import.meta.url);
  const candidates = [
    path.join(__dirname, 'node_modules', 'xlsx'),
    path.join(root, 'node_modules', 'xlsx'),
    'xlsx',
  ];
  for (const c of candidates) {
    try {
      return require(c);
    } catch (_) {}
  }
  throw new Error('xlsx yok. Önce: npm install xlsx --prefix tool');
}

async function fetchBuf(url, { timeoutMs = 120000 } = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      redirect: 'follow',
      headers: {
        'User-Agent': UA,
        Accept: '*/*',
        'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
      },
    });
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    return Buffer.from(await res.arrayBuffer());
  } finally {
    clearTimeout(t);
  }
}

async function fetchText(url) {
  const buf = await fetchBuf(url, { timeoutMs: 60000 });
  return buf.toString('utf8');
}

function absUrl(base, href) {
  try {
    return new URL(href, base).href;
  } catch {
    return null;
  }
}

function xlsxHrefs(html, base) {
  const hrefs = [];
  const re = /href\s*=\s*["']([^"']+\.xlsx)["']/gi;
  let m;
  while ((m = re.exec(html))) {
    const u = absUrl(base, m[1].replace(/&amp;/g, '&'));
    if (u) hrefs.push(u);
  }
  return [...new Set(hrefs)];
}

function digits(raw) {
  return String(raw ?? '').replace(/\D/g, '');
}

function padGtin(d) {
  if (d.length === 13) return `0${d}`;
  if (d.length === 12) return `00${d}`;
  if (d.length === 8) return d;
  if (d.length === 14) return d;
  return d;
}

function pickField(row, names, { rejectKey } = {}) {
  const keys = Object.keys(row);
  for (const want of names) {
    const w = want.toLowerCase();
    const hit = keys.find((k) => {
      const norm = k.toLowerCase().replace(/\s+/g, ' ');
      if (!norm.includes(w)) return false;
      if (rejectKey && rejectKey.test(norm)) return false;
      return true;
    });
    if (hit && String(row[hit] ?? '').trim()) return String(row[hit]).trim();
  }
  return '';
}

function addHit(by, barcode, name, ingredient, sourceCounts, source) {
  const d = digits(barcode);
  if (d.length < 8 || d.length > 14) return;
  const nameClean = String(name ?? '').replace(/\s+/g, ' ').trim();
  const nameIsId = /^\d{3,}$/.test(nameClean);
  if (nameClean.length < 3 || nameIsId) {
    const ingOnly = String(ingredient ?? '').replace(/\s+/g, ' ').trim();
    const keyEarly = d.length === 14 && d.startsWith('0') ? d.slice(1) : d;
    const prevEarly = by.get(keyEarly);
    if (prevEarly && ingOnly && !prevEarly[1]) prevEarly[1] = ingOnly;
    return;
  }
  const ing = String(ingredient ?? '').replace(/\s+/g, ' ').trim();
  const key = d.length === 14 && d.startsWith('0') ? d.slice(1) : d;
  const prev = by.get(key);
  if (!prev) {
    by.set(key, [nameClean, ing]);
    sourceCounts[source] = (sourceCounts[source] || 0) + 1;
    return;
  }
  if (/^\d{3,}$/.test(prev[0]) && nameClean) prev[0] = nameClean;
  if (ing && !prev[1]) prev[1] = ing;
}

function parseWorkbook(XLSX, buf, by, sourceCounts, source) {
  const wb = XLSX.read(buf, { type: 'buffer', cellDates: false });
  let rows = 0;
  for (const sheetName of wb.SheetNames) {
    const ws = wb.Sheets[sheetName];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
    let headerRow = -1;
    for (let i = 0; i < Math.min(8, raw.length); i++) {
      const joined = raw[i].map((c) => String(c)).join(' ').toLowerCase();
      if (
        joined.includes('barkod') ||
        joined.includes('gtin') ||
        joined.includes('ilaç adı') ||
        joined.includes('ilac adi') ||
        joined.includes('ürün adı') ||
        joined.includes('urun adi') ||
        joined.includes('ticari ad')
      ) {
        headerRow = i;
        break;
      }
    }
    if (headerRow < 0) continue;
    const headers = raw[headerRow].map((h) => String(h || '').trim());
    for (let r = headerRow + 1; r < raw.length; r++) {
      const line = raw[r];
      if (!line || !line.some((c) => String(c).trim())) continue;
      const obj = {};
      headers.forEach((h, i) => {
        if (h) obj[h] = line[i];
      });
      const barcode =
        pickField(obj, [
          'barkod',
          'gtin',
          'barcode',
          'karekod',
          'ürün barkod',
          'urun barkod',
        ]) || digits(line.find((c) => /^\d{8,14}$/.test(digits(c))) || '');
      const name = pickField(
        obj,
        [
          'ilaç adı',
          'ilac adi',
          'ürün adı',
          'urun adi',
          'ticari ad',
          'ilacadi',
          'ürün adı',
          'ilac',
          'name',
        ],
        { rejectKey: /\b(no|kod|id|numara|numarası|number)\b/i },
      );
      const ingredient = pickField(obj, [
        'atc adı',
        'atc adi',
        'etken madde',
        'etkin madde',
        'aktif madde',
        'atc isim',
        'atc',
      ]);
      if (barcode && name) {
        addHit(by, barcode, name, ingredient, sourceCounts, `${source}:${sheetName}`);
        rows += 1;
      }
    }
    console.log(`  sheet ${sheetName}: parsed data rows with headers`);
  }
  return rows;
}

function ingestJsonArray(data, by, sourceCounts, source) {
  const list = Array.isArray(data) ? data : data.by ? null : data.items || data.data;
  if (data && data.by && typeof data.by === 'object' && !Array.isArray(data.by)) {
    for (const [k, v] of Object.entries(data.by)) {
      const name = Array.isArray(v) ? v[0] : v;
      const ing = Array.isArray(v) && v.length > 1 ? v[1] : '';
      addHit(by, k, name, ing, sourceCounts, source);
    }
    return;
  }
  if (!Array.isArray(list)) return;
  for (const row of list) {
    if (!row || typeof row !== 'object') continue;
    const barcode =
      row.barcode ||
      row.Barkod ||
      row.barkod ||
      row.gtin ||
      row.GTIN ||
      row.barcode_number;
    const name =
      row.Product_Name ||
      row.product_name ||
      row.ilac_adi ||
      row.name ||
      row.urun_adi ||
      row.drug_name;
    const ingredient =
      row.Active_Ingredient ||
      row.active_ingredient ||
      row.etken_madde ||
      row.atc_name ||
      row.ATC_code ||
      '';
    addHit(by, barcode, name, ingredient, sourceCounts, source);
  }
}

async function tryTitckPage(pageUrl, by, sourceCounts, label) {
  console.log(`Fetching ${pageUrl}`);
  const html = await fetchText(pageUrl);
  const hrefs = xlsxHrefs(html, pageUrl);
  if (!hrefs.length) {
    console.log(`  no xlsx on ${label}`);
    return;
  }
  const url = hrefs[0];
  console.log(`  latest xlsx: ${url}`);
  const buf = await fetchBuf(url);
  fs.writeFileSync(path.join(tmpDir, `${label}.xlsx`), buf);
  const XLSX = loadXlsx();
  parseWorkbook(XLSX, buf, by, sourceCounts, label);
}

async function trySgk(by, sourceCounts) {
  const pages = [
    'https://www.sgk.gov.tr/duyuru/detay/08042026-Tarihli-ve-33218-Sayili-Resm-Gazetede-Yayimlanan-Sosyal-Guvenlik-Kurumu-Saglik-Uygulama-Tebliginde-Degisiklik-Yapilmasina-Dair-Teblig-2026-04-08-04-56-20',
    'https://www.sgk.gov.tr/duyuru/detay/Bedeli-Odenecek-Ilaclar-Listesinde-Yapilan-Duzenlemeler-Hakkinda-Duyuru-202611-2026-03-11-03-36-18',
  ];
  const XLSX = loadXlsx();
  for (const page of pages) {
    try {
      console.log(`Fetching SGK ${page}`);
      const html = await fetchText(page);
      const hrefs = xlsxHrefs(html, page).filter((u) =>
        /4a|ek-4a|ek4a|bedeli/i.test(decodeURIComponent(u)),
      );
      const pick = hrefs[0] || xlsxHrefs(html, page)[0];
      if (!pick) continue;
      console.log(`  SGK xlsx: ${pick}`);
      const buf = await fetchBuf(pick);
      fs.writeFileSync(path.join(tmpDir, 'sgk_ek4a.xlsx'), buf);
      parseWorkbook(XLSX, buf, by, sourceCounts, 'sgk_ek4a');
      return;
    } catch (e) {
      console.log(`  SGK skip: ${e.message}`);
    }
  }
}

async function tryGithub(by, sourceCounts) {
  const urls = [
    [
      'https://raw.githubusercontent.com/onatozmenn/klinik-mcp/main/src/health_mcp/data/titck_drugs.json',
      'github_klinik_titck',
    ],
    [
      'https://raw.githubusercontent.com/onatozmenn/klinik-mcp/main/src/health_mcp/data/sgk_ek4a.json',
      'github_klinik_sgk',
    ],
    [
      'https://raw.githubusercontent.com/Tip-Atlasi-Projesi/ilaclardb/main/data/json/ilaclar.json',
      'github_ilaclardb',
    ],
    [
      'https://raw.githubusercontent.com/Tip-Atlasi-Projesi/ilaclardb/master/data/json/ilaclar.json',
      'github_ilaclardb',
    ],
    [
      'https://raw.githubusercontent.com/Tip-Atlasi-Projesi/ilaclardb/main/data/csv/ilaclar.csv',
      'github_ilaclardb_csv',
    ],
  ];
  for (const [url, label] of urls) {
    try {
      console.log(`Fetching ${url}`);
      const buf = await fetchBuf(url, { timeoutMs: 180000 });
      const text = buf.toString('utf8');
      if (url.endsWith('.csv')) {
        const lines = text.split(/\r?\n/);
        const headers = (lines[0] || '').split(',').map((h) => h.replace(/^"|"$/g, '').trim());
        const bIdx = headers.findIndex((h) => /barkod|barcode|gtin/i.test(h));
        const nIdx = headers.findIndex((h) => /name|ad|ürün|urun|ilac/i.test(h));
        const iIdx = headers.findIndex((h) => /etken|ingredient|atc/i.test(h));
        if (bIdx < 0 || nIdx < 0) continue;
        for (let i = 1; i < lines.length; i++) {
          const cols = lines[i].split(',').map((c) => c.replace(/^"|"$/g, ''));
          addHit(
            by,
            cols[bIdx],
            cols[nIdx],
            iIdx >= 0 ? cols[iIdx] : '',
            sourceCounts,
            label,
          );
        }
      } else {
        ingestJsonArray(JSON.parse(text), by, sourceCounts, label);
      }
      console.log(`  ${label} merged, unique now ${by.size}`);
    } catch (e) {
      console.log(`  skip ${label}: ${e.message}`);
    }
  }
}

async function main() {
  fs.mkdirSync(tmpDir, { recursive: true });
  const by = new Map();
  const sourceCounts = {};

  // Keep current snapshot as baseline so a failed download does not shrink the index.
  try {
    const existing = JSON.parse(fs.readFileSync(outPath, 'utf8'));
    ingestJsonArray(existing, by, sourceCounts, 'existing_asset');
    console.log(`Baseline asset: ${by.size}`);
  } catch (e) {
    console.log(`No baseline: ${e.message}`);
  }

  try {
    await tryTitckPage(
      'https://www.titck.gov.tr/dinamikmodul/43',
      by,
      sourceCounts,
      'titck_skrs',
    );
  } catch (e) {
    console.log(`TİTCK SKRS failed: ${e.message}`);
  }
  try {
    await tryTitckPage(
      'https://www.titck.gov.tr/dinamikmodul/85',
      by,
      sourceCounts,
      'titck_ruhsat',
    );
  } catch (e) {
    console.log(`TİTCK ruhsat failed: ${e.message}`);
  }
  try {
    await trySgk(by, sourceCounts);
  } catch (e) {
    console.log(`SGK failed: ${e.message}`);
  }
  await tryGithub(by, sourceCounts);

  const obj = {};
  const sorted = [...by.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  for (const [k, v] of sorted) obj[k] = v[1] ? [v[0], v[1]] : [v[0]];

  const payload = {
    source: 'TITCK SKRS (aktif+pasif) + ruhsat + SGK EK-4/A + public mirrors',
    version: new Date().toISOString().slice(0, 10),
    count: sorted.length,
    sources: sourceCounts,
    by: obj,
  };
  fs.writeFileSync(outPath, JSON.stringify(payload));
  const mb = (fs.statSync(outPath).size / (1024 * 1024)).toFixed(2);
  console.log(`Wrote ${outPath}`);
  console.log(`Unique GTINs: ${sorted.length} (${mb} MB)`);
  console.log('Source adds:', sourceCounts);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
