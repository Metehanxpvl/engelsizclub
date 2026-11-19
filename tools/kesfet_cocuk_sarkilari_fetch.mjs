/**
 * Keşfet: çocuk şarkıları adayları (YouTube Shorts). Geçici tek seferlik script.
 * Arama + oEmbed doğrulama (gömülebilir olmayanlar elenir). API anahtarı yok.
 * Çıktı: tools/_cocuk_sarkilari.json (veritabanına yazmaz).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const CLIENT = { clientName: 'WEB', clientVersion: '2.20240815.01.00', hl: 'tr', gl: 'TR' };
const SHORTS_PARAMS = 'EgIYAQ==';
const PAGES = 3;

const GROUPS = {
  egitici: [
    'çocuk şarkısı sayılar',
    'çocuk şarkısı renkler',
    'hayvanlar şarkısı çocuk',
    'vücudumuz şarkısı çocuk',
    'okul öncesi eğitici şarkı',
    'alfabe şarkısı çocuk',
    'meyveler şarkısı çocuk',
    'günler şarkısı çocuk',
    'eğitici çocuk şarkıları',
    'el yıkama şarkısı çocuk',
    'diş fırçalama şarkısı çocuk',
  ],
  isaret_dili: [
    'işaret dili çocuk şarkısı',
    'işaret diliyle şarkı çocuk',
    'TİD çocuk şarkısı',
    'işaret dili ile eğitici şarkı',
  ],
  ninni: [
    'ninni bebek',
    'ninni çocuk uyku',
    'sakinleştirici ninni',
    'Türkçe ninni',
  ],
};

const MUST = /şarkı|şarkısı|ninni|sarki|song|şarkıları|tekerleme/i;
const REJECT = [
  /\bprank\b/i, /şaka/i, /korku/i, /horror/i, /scary/i, /\belsa\b/i, /spider.?man/i,
  /örümcek adam/i, /joker/i, /hulk/i, /skibidi/i, /huggy/i, /poppy playtime/i,
  /tiktok/i, /dans challenge/i, /\bvlog\b/i, /reklam/i, /kumar/i, /bahis/i,
  /silah/i, /kavga/i, /\bgun\b/i, /öp(ü|ücük)/i, /sevgili/i, /aşk/i,
  /oyuncak aç/i, /unboxing/i, /siyaset/i, /seçim/i,
];

function walk(node, acc) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (const n of node) walk(n, acc);
    return;
  }
  if (typeof node.videoId === 'string' && /^[A-Za-z0-9_-]{11}$/.test(node.videoId)) {
    if (!acc.videos.has(node.videoId)) {
      const t =
        node.title?.runs?.[0]?.text ||
        node.title?.simpleText ||
        node.headline?.simpleText ||
        node.overlayMetadata?.primaryText?.content ||
        '';
      acc.videos.set(node.videoId, t);
    }
  }
  const tok = node.continuationCommand?.token;
  if (typeof tok === 'string' && tok.length > 30) acc.continuations.push(tok);
  for (const v of Object.values(node)) walk(v, acc);
}

async function search(query, continuation) {
  const body = continuation
    ? { context: { client: CLIENT }, continuation }
    : { context: { client: CLIENT }, query, params: SHORTS_PARAMS };
  const res = await fetch('https://www.youtube.com/youtubei/v1/search?prettyPrint=false', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': UA },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`search ${res.status}`);
  return res.json();
}

async function oembed(id) {
  const url = `https://www.youtube.com/oembed?url=${encodeURIComponent(
    `https://www.youtube.com/watch?v=${id}`,
  )}&format=json`;
  const res = await fetch(url, { headers: { Accept: 'application/json', 'User-Agent': UA } });
  if (!res.ok) return null;
  const j = await res.json().catch(() => null);
  if (!j?.title) return null;
  return {
    title: String(j.title),
    author_name: String(j.author_name || ''),
    author_url: String(j.author_url || ''),
    thumbnail_url: String(j.thumbnail_url || `https://i.ytimg.com/vi/${id}/hqdefault.jpg`),
  };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const found = new Map(); // id -> {group, hint, query}
  for (const [group, queries] of Object.entries(GROUPS)) {
    for (const q of queries) {
      let cont;
      try {
        for (let p = 0; p < PAGES; p++) {
          const acc = { videos: new Map(), continuations: [] };
          walk(await search(q, cont), acc);
          for (const [id, hint] of acc.videos) {
            if (!found.has(id)) found.set(id, { group, hint, query: q });
          }
          cont = acc.continuations.find((t) => t.length > 40);
          console.log(`"${q}" s${p + 1} toplam=${found.size}`);
          if (!cont) break;
          await sleep(200);
        }
      } catch (e) {
        console.warn('arama hata', q, e.message);
      }
      await sleep(150);
    }
  }

  const out = [];
  const ids = [...found.keys()];
  for (let i = 0; i < ids.length; i += 6) {
    await Promise.all(
      ids.slice(i, i + 6).map(async (id) => {
        const meta = found.get(id);
        const om = await oembed(id).catch(() => null);
        if (!om) return;
        const blob = `${om.title} ${meta.hint}`;
        if (!MUST.test(blob)) return;
        if (REJECT.some((re) => re.test(`${blob} ${om.author_name}`))) return;
        out.push({ id, group: meta.group, query: meta.query, hint: meta.hint, ...om });
      }),
    );
  }
  const byGroup = {};
  for (const v of out) byGroup[v.group] = (byGroup[v.group] || 0) + 1;
  console.log('aday', found.size, 'gecerli', out.length, JSON.stringify(byGroup));
  fs.writeFileSync(path.join(__dirname, '_cocuk_sarkilari.json'), JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
