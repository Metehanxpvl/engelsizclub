/**
 * Keşfet seed batch 2: 500 ADDITIONAL real YouTube Shorts.
 * Skips IDs already in kesfet_seed_videos.sql. oEmbed-validates. No API keys.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const CLIENT = {
  clientName: 'WEB',
  clientVersion: '2.20240815.01.00',
  hl: 'tr',
  gl: 'TR',
};
const CLIENT_US = { ...CLIENT, hl: 'en', gl: 'US' };
const SHORTS_PARAMS = 'EgIYAQ==';
const MIN_SCORE = 12;
const TARGET = 500;
const PAGES_PER_QUERY = 6;

const QUERIES = [
  'Serebral Palsi egzersiz',
  'Otizm ABA terapi',
  'Otizm erken müdahale',
  'Down sendromu dil konuşma',
  'SMA fizyoterapi',
  'engelli istihdam EKPSS',
  'ÇÖZGER engelli raporu',
  'ÖTV muafiyeti araç',
  'malulen emeklilik engelli',
  'özel eğitim RAM BEP',
  'braille görme engelli',
  'Türk işaret dili TİD',
  'koklear implant çocuk',
  'epilepsi ilk yardım nöbet',
  'multipl skleroz belirtileri',
  'ALS iletişim cihazı',
  'spina bifida farkındalık',
  'Duchenne DMD egzersiz',
  'Rett sendromu bakım',
  'Angelman sendromu',
  'DEHB özel eğitim strateji',
  'disleksi okuma çalışması',
  'ergoterapi duyu bütünleme',
  'konuşma terapisi afazi',
  'prematüre gelişim takibi',
  'ortez AFO serebral palsi',
  'omurilik felci rehabilitasyon',
  'inme felç fizyoterapi',
  'parapleji tekerlekli sandalye',
  'protez bacak yürüyüş',
  'hidrosefali şant',
  'Williams sendromu',
  'Fragile X sendromu',
  'Prader Willi sendromu',
  'Tourette sendromu',
  'PECS otizm iletişim',
  'AAC alternatif iletişim',
  'kaynaştırma eğitimi nedir',
  'engelli kimlik kartı başvuru',
  'evde bakım maaşı 2025',
  'engelli aylığı SGK',
  'H sınıfı ehliyet engelli',
  'erişilebilir rampa standart',
  'sesli betimleme nedir',
  'ekran okuyucu görme engelli',
  'rehber köpek görme engelli',
  'nadir hastalık farkındalık',
  'kistik fibroz fizyoterapi',
  'fenilketonüri PKU',
  'hemofili nedir',
  'Parkinson bakım veren',
  'demans Alzheimer bakım',
  'afazi konuşma terapisi',
  'travmatik beyin hasarı rehabilitasyon',
  'selektif dorsal rizotomi',
  'duyu bütünleme bozukluğu',
  'disgrafi disleksi',
  'diskalkuli özel eğitim',
  'görme azlığı düşük görme',
  'işitme cihazı çocuk',
  'sağır eğitim işaret dili',
  'Engelsiz üniversite YÖK',
  'korumalı işyeri engelli',
  'bakım veren özel gereksinim',
  'kardeş otizm aile',
  'cerebral palsy stretching',
  'autism AAC PECS',
  'down syndrome speech therapy',
  'SMA nusinersen physiotherapy',
  'wheelchair ramp accessibility',
  'ASL sign language alphabet',
  'IEP special education rights',
  'epilepsy seizure first aid',
  'multiple sclerosis fatigue',
  'rett syndrome awareness',
  'angelman syndrome therapy',
  'duchenne muscular dystrophy care',
  'spina bifida catheter care',
  'ADHD classroom strategies',
  'occupational therapy sensory',
  'speech therapy apraxia',
  'visually impaired white cane',
  'deaf education cochlear implant',
  'inclusive classroom disability',
  'disability employment rights',
  'rare disease day',
  'caregiver burnout special needs',
  'amputee prosthetic training',
  'spinal cord injury rehab',
  'aphasia speech therapy',
  'Parkinson caregiver tips',
  'ALS communication board',
  'hydrocephalus awareness',
  'fragile X autism',
  'Prader Willi syndrome',
  'Tourette syndrome education',
  'CVI cortical visual impairment',
  'dyslexia Orton Gillingham',
  'dysgraphia occupational therapy',
  'guide dog training blind',
  'audio description accessibility',
  'screen reader NVDA blind',
  'supported employment disability',
  'early intervention autism',
  'DIR floortime autism',
  'TEACCH autism classroom',
  'visual schedule autism',
  'meltdown support autism',
  'power wheelchair accessibility',
  'standing frame cerebral palsy',
  'AFO orthosis CP',
  'botulinum toxin cerebral palsy',
  'baclofen pump spasticity',
  'Lennox Gastaut epilepsy',
  'Dravet syndrome',
  'West syndrome infantile spasms',
  'tuberous sclerosis',
  'CHARGE syndrome',
  'Usher syndrome deafblind',
  'achondroplasia dwarfism',
  'osteogenesis imperfecta',
  'limb difference prosthetic',
  'stroke occupational therapy',
  'TBI brain injury rehab',
  'MS mobility aid',
  'cystic fibrosis airway clearance',
  'PKU diet phenylketonuria',
  'hemophilia joint protection',
  'Down syndrome rights Turkey',
  'engelli hakları 5378',
  'özürlüler kanunu',
  'engelli kontenjanı işe alım',
  'vergi indirimi engelli rapor',
  'MTV muafiyeti engelli',
  'özel tertibatlı araç engelli',
  'gündüz bakımevi engelli',
  'Aile Sosyal Hizmetler engelli',
  'SHM sosyal hizmet merkezi engelli',
  'RAM özel eğitim değerlendirme',
  'BEP bireyselleştirilmiş eğitim',
  'kaynaştırma öğrenci destek',
  'otizm spektrum belirtileri',
  'serebral palsi tipleri',
  'down sendromu mozaik',
  'SMA tip 1 bakım',
  'DMD Duchenne belirtileri',
  'spina bifida myelomeningosel',
  'epilepsi ketojenik diyet',
  'işaret dili alfabesi Türkiye',
  'görme engelli bağımsız hareket',
  'beyaz baston eğitimi',
  'işitme engelli aile',
  'koklear implant rehabilitasyon',
  'dil konuşma terapisi kekemelik engel',
  'otizm özel eğitim sınıfı',
  'down sendromu fizyoterapi',
  'serebral palsi hidroterapi',
  'engelli spor paralimpik',
  'goalball görme engelli',
  'tekerlekli sandalye basketbol',
  'erişilebilir toplu taşıma',
  'WCAG erişilebilirlik',
  'altyazı işitme engelli',
  'kolay okunur metin engelli',
  'bağımsız yaşam engelli',
  'kişisel asistan engelli',
  'respite bakım özel gereksinim',
  'ebeveyn eğitimi otizm',
  'kardeş desteği down sendromu',
];

const HARD_REJECT = [
  /yemek tarifi/i,
  /\brecipe\b/i,
  /\bfoodie\b/i,
  /yemek yap/i,
  /futbol maç/i,
  /\bfootball match\b/i,
  /kedi videos/i,
  /funny cat/i,
  /\bcomedy skit\b/i,
  /\bunboxing\b/i,
  /\bvlog\b/i,
  /iphone incele/i,
  /tech review/i,
  /minecraft gameplay/i,
  /fortnite/i,
  /makyaj tutorial/i,
  /\bprank\b/i,
  /müzik klibi/i,
  /tiktok dans/i,
  /heals autism/i,
  /cure autism/i,
  /otizmi bitir/i,
  /mucize tedavi/i,
  /kesin iyileştirir/i,
];

function loadKeywords() {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase', 'kesfet_seed.sql'), 'utf8');
  const out = [];
  const re =
    /\('((?:[^']|'')*)',\s*'(positive|negative|safety)',\s*(-?\d+),\s*'([^']*)',\s*(true|false)\)/g;
  let m;
  while ((m = re.exec(sql))) {
    out.push({
      phrase: m[1].replaceAll("''", "'"),
      polarity: m[2],
      weight: Number(m[3]),
      categoryHint: m[4],
      isWeak: m[5] === 'true',
    });
  }
  if (out.length < 40) throw new Error(`keyword parse failed (${out.length})`);
  return out;
}

function loadExistingIds() {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase', 'kesfet_seed_videos.sql'), 'utf8');
  const ids = [...sql.matchAll(/youtube\.com\/shorts\/([A-Za-z0-9_-]{11})/g)].map((m) => m[1]);
  return new Set(ids);
}

function loadExistingHandles() {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase', 'kesfet_seed_videos.sql'), 'utf8');
  const handles = [...sql.matchAll(/youtube\.com\/(@[A-Za-z0-9._-]+)/g)].map((m) => m[1]);
  return [...new Set(handles)].filter((h) => h.length >= 4);
}

function phraseIn(hay, phrase) {
  const p = phrase.toLowerCase();
  if (p.length <= 4) {
    const escaped = p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`(^|[^a-z0-9çğıöşü])${escaped}(?=[^a-z0-9çğıöşü]|$)`, 'i').test(hay);
  }
  return hay.includes(p);
}

function scoreKesfet(title, description, tags, channel, keywords) {
  const hay = [title, description, tags.join(' '), channel].join(' ').toLowerCase();
  let score = 0;
  let safety = false;
  const notes = [];
  const pos = [];
  const neg = [];
  const catVotes = {};
  for (const k of keywords) {
    const p = k.phrase.trim();
    if (!p || !phraseIn(hay, p)) continue;
    if (k.polarity === 'positive') {
      score += k.weight;
      pos.push(k.phrase);
      const hint = (k.categoryHint || '').trim();
      if (hint && hint !== 'sana-ozel') {
        catVotes[hint] = (catVotes[hint] || 0) + k.weight;
      }
    } else if (k.polarity === 'negative') {
      neg.push(k.phrase);
      score -= k.isWeak ? Math.max(1, Math.ceil(k.weight / 2)) : k.weight;
    } else if (k.polarity === 'safety') {
      safety = true;
      score -= 5;
      notes.push(k.phrase);
    }
  }
  let cat = 'engellilik';
  let best = 0;
  for (const [slug, w] of Object.entries(catVotes)) {
    if (w > best) {
      best = w;
      cat = slug;
    }
  }
  const strongPos = pos.filter((ph) => {
    const k = keywords.find((x) => x.phrase === ph && x.polarity === 'positive');
    return k && !k.isWeak && k.weight >= 10;
  });
  return {
    score,
    safetyFlag: safety,
    suggestedCategory: cat,
    safetyNote: safety ? `Sağlık iddiası tespit edildi: ${notes.join(', ')}` : '',
    matchedPositives: pos,
    matchedNegatives: neg,
    strongPos,
  };
}

function walkCollect(node, acc) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (const x of node) walkCollect(x, acc);
    return;
  }
  const entityId = node.entityId;
  if (typeof entityId === 'string' && entityId.startsWith('shorts-shelf-item-')) {
    const id = entityId.slice('shorts-shelf-item-'.length);
    if (/^[A-Za-z0-9_-]{11}$/.test(id)) {
      const title = node.overlayMetadata?.primaryText?.content || '';
      const prev = acc.videos.get(id);
      if (!prev || (title && !prev.titleHint)) {
        acc.videos.set(id, { id, titleHint: title });
      }
    }
  }
  if (typeof node.videoId === 'string' && /^[A-Za-z0-9_-]{11}$/.test(node.videoId)) {
    if (!acc.videos.has(node.videoId)) {
      const t =
        node.title?.runs?.[0]?.text ||
        node.title?.simpleText ||
        node.headline?.simpleText ||
        node.overlayMetadata?.primaryText?.content ||
        '';
      acc.videos.set(node.videoId, { id: node.videoId, titleHint: t });
    }
  }
  const tok = node.continuationCommand?.token;
  if (typeof tok === 'string' && tok.length > 30) acc.continuations.push(tok);
  for (const v of Object.values(node)) walkCollect(v, acc);
}

async function innertubeSearch(query, continuation, client = CLIENT) {
  const body = continuation
    ? { context: { client }, continuation }
    : { context: { client }, query, params: SHORTS_PARAMS };
  const res = await fetch('https://www.youtube.com/youtubei/v1/search?prettyPrint=false', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': UA },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`search ${res.status}`);
  return res.json();
}

async function innertubeNext(videoId) {
  const res = await fetch('https://www.youtube.com/youtubei/v1/next?prettyPrint=false', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': UA },
    body: JSON.stringify({ context: { client: CLIENT }, videoId }),
  });
  if (!res.ok) return null;
  return res.json();
}

async function innertubeBrowse(browseId, params, continuation) {
  const body = continuation
    ? { context: { client: CLIENT }, continuation }
    : { context: { client: CLIENT }, browseId, params };
  const res = await fetch('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': UA },
    body: JSON.stringify(body),
  });
  if (!res.ok) return null;
  return res.json();
}

async function resolveChannelBrowse(handle) {
  const url = `https://www.youtube.com/${handle}/shorts`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': UA,
      'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
      Cookie: 'CONSENT=YES+1',
    },
  });
  if (!res.ok) return { browseId: null, ids: [] };
  const html = await res.text();
  const ids = [];
  const re = /"videoId":"([A-Za-z0-9_-]{11})"/g;
  let m;
  while ((m = re.exec(html))) ids.push(m[1]);
  const browse =
    html.match(/"browseId":"(UC[A-Za-z0-9_-]{22})"/)?.[1] ||
    html.match(/"channelId":"(UC[A-Za-z0-9_-]{22})"/)?.[1] ||
    null;
  return { browseId: browse, ids: [...new Set(ids)] };
}

async function oembed(id) {
  const url = `https://www.youtube.com/oembed?url=${encodeURIComponent(
    `https://www.youtube.com/watch?v=${id}`,
  )}&format=json`;
  const res = await fetch(url, {
    headers: { Accept: 'application/json', 'User-Agent': UA },
  });
  if (res.status === 404 || res.status === 401) return null;
  if (!res.ok) return null;
  const j = await res.json();
  if (!j || !j.title) return null;
  return {
    title: String(j.title || ''),
    authorName: String(j.author_name || ''),
    authorUrl: String(j.author_url || ''),
    thumbnailUrl: String(j.thumbnail_url || `https://i.ytimg.com/vi/${id}/hqdefault.jpg`),
  };
}

function sqlStr(s) {
  return `'${String(s ?? '').replaceAll("'", "''")}'`;
}

function sqlTags(arr) {
  const clean = [...new Set(arr.map((t) => String(t).trim()).filter(Boolean))].slice(0, 12);
  if (!clean.length) return `'{}'::text[]`;
  return `ARRAY[${clean.map(sqlStr).join(', ')}]::text[]`;
}

function detectLang(title) {
  return /[ığüşöçİĞÜŞÖÇ]/.test(title) ? 'tr' : 'en';
}

function hardReject(text) {
  return HARD_REJECT.some((re) => re.test(text));
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function mapPool(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  async function worker() {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

function pickDiverse(rows, n) {
  const byCat = new Map();
  for (const r of rows) {
    const k = r.category || 'engellilik';
    if (!byCat.has(k)) byCat.set(k, []);
    byCat.get(k).push(r);
  }
  for (const list of byCat.values()) list.sort((a, b) => b.score - a.score);
  const picked = [];
  const used = new Set();
  while (picked.length < n) {
    let added = false;
    for (const list of byCat.values()) {
      const next = list.find((x) => !used.has(x.id));
      if (!next) continue;
      used.add(next.id);
      picked.push(next);
      added = true;
      if (picked.length >= n) break;
    }
    if (!added) break;
  }
  return picked;
}

function addFound(found, existing, id, titleHint, query) {
  if (!id || existing.has(id) || found.has(id)) return;
  if (!/^[A-Za-z0-9_-]{11}$/.test(id)) return;
  found.set(id, { id, titleHint: titleHint || '', query: query || '' });
}

async function main() {
  const keywords = loadKeywords();
  const existing = loadExistingIds();
  const handles = loadExistingHandles();
  console.log('keywords', keywords.length, 'existingIds', existing.size, 'handles', handles.length);

  const found = new Map();

  for (const [i, q] of QUERIES.entries()) {
    const client = i % 5 === 0 ? CLIENT_US : CLIENT;
    let continuation;
    try {
      for (let page = 0; page < PAGES_PER_QUERY; page++) {
        const json = await innertubeSearch(q, continuation, client);
        const acc = { videos: new Map(), continuations: [] };
        walkCollect(json, acc);
        for (const v of acc.videos.values()) addFound(found, existing, v.id, v.titleHint, q);
        continuation = acc.continuations.find((t) => t.length > 40);
        console.log(`search "${q}" p${page + 1} +${acc.videos.size} new=${found.size}`);
        if (!continuation) break;
        await sleep(180);
      }
    } catch (e) {
      console.warn('search fail', q, e.message);
    }
    await sleep(140);
  }

  console.log('after search new ids', found.size);

  const existingArr = [...existing];
  const sample = existingArr.filter((_, i) => i % 4 === 0).slice(0, 120);
  for (const id of sample) {
    try {
      const json = await innertubeNext(id);
      if (json) {
        const acc = { videos: new Map(), continuations: [] };
        walkCollect(json, acc);
        for (const v of acc.videos.values()) addFound(found, existing, v.id, v.titleHint, 'related');
      }
    } catch (e) {
      console.warn('next fail', id, e.message);
    }
    await sleep(120);
  }
  console.log('after related new ids', found.size);

  const handleSample = handles.slice(0, 160);
  await mapPool(handleSample, 3, async (handle) => {
    try {
      const { browseId, ids } = await resolveChannelBrowse(handle);
      for (const id of ids) addFound(found, existing, id, '', `channel:${handle}`);
      if (browseId) {
        const json = await innertubeBrowse(browseId, 'EgZzaG9ydHM=');
        if (json) {
          const acc = { videos: new Map(), continuations: [] };
          walkCollect(json, acc);
          for (const v of acc.videos.values()) {
            addFound(found, existing, v.id, v.titleHint, `channel:${handle}`);
          }
          const cont = acc.continuations.find((t) => t.length > 40);
          if (cont) {
            const json2 = await innertubeBrowse(browseId, 'EgZzaG9ydHM=', cont);
            if (json2) {
              const acc2 = { videos: new Map(), continuations: [] };
              walkCollect(json2, acc2);
              for (const v of acc2.videos.values()) {
                addFound(found, existing, v.id, v.titleHint, `channel:${handle}`);
              }
            }
          }
        }
      }
      if (found.size % 80 === 0) console.log('channel scrape new=', found.size, handle);
    } catch (e) {
      console.warn('channel fail', handle, e.message);
    }
  });

  console.log('unique NEW ids before oembed', found.size);
  const ids = [...found.keys()];
  const validated = [];
  let done = 0;
  await mapPool(ids, 6, async (id) => {
    const meta = found.get(id);
    if (meta.titleHint && hardReject(meta.titleHint)) {
      done++;
      return;
    }
    if (meta.titleHint) {
      const pre = scoreKesfet(meta.titleHint, '', [], '', keywords);
      if (pre.score < 8 && pre.strongPos.length === 0) {
        done++;
        return;
      }
    }
    try {
      const om = await oembed(id);
      done++;
      if (done % 50 === 0) console.log(`oembed ${done}/${ids.length} ok=${validated.length}`);
      if (!om) return;
      const blob = `${om.title} ${om.authorName} ${meta.titleHint || ''}`;
      if (hardReject(blob)) return;
      const sc = scoreKesfet(om.title, meta.titleHint || '', [], om.authorName, keywords);
      if (sc.safetyFlag) return;
      if (sc.score < MIN_SCORE) return;
      if (sc.strongPos.length === 0) return;
      validated.push({
        id,
        title: om.title.slice(0, 300),
        description: (meta.titleHint || om.title).slice(0, 500),
        channel: om.authorName.slice(0, 120),
        channelUrl: om.authorUrl.slice(0, 300),
        thumb: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
        oembedThumb: om.thumbnailUrl,
        category: sc.suggestedCategory,
        tags: [...new Set(sc.matchedPositives)],
        score: sc.score,
        query: meta.query,
        oembed: om,
        lang: detectLang(om.title),
      });
    } catch {
      done++;
    }
  });

  validated.sort((a, b) => b.score - a.score);
  const seed = pickDiverse(validated, TARGET);
  console.log(`validated ${validated.length}, seeding ${seed.length}`);

  const header = `-- Engelsiz Club — Keşfet seed videos batch 2 (approved Shorts)
-- 500 ADDITIONAL oEmbed-validated unique youtube_video_id values (not in kesfet_seed_videos.sql).
-- Same criteria/scoring/safety as batch 1. No invented IDs.
-- If schema + kesfet_seed_videos.sql already applied: run ONLY this file in SQL Editor.
-- Otherwise order: kesfet_schema.sql → kesfet_scoring.sql → kesfet_seed.sql → kesfet_admin.sql → kesfet_seed_videos.sql → this file.
-- ON CONFLICT: safe to re-run. Status = approved.

`;

  const chunks = [];
  const batchSize = 40;
  for (let i = 0; i < seed.length; i += batchSize) {
    const batch = seed.slice(i, i + batchSize);
    const values = batch.map((v) => {
      const ytUrl = `https://www.youtube.com/shorts/${v.id}`;
      const oembedJson = JSON.stringify({
        title: v.oembed.title,
        author_name: v.oembed.authorName,
        author_url: v.oembed.authorUrl,
        thumbnail_url: v.oembed.thumbnailUrl,
      }).replaceAll("'", "''");
      return `(
    ${sqlStr(v.id)},
    ${sqlStr(ytUrl)},
    ${sqlStr(v.title)},
    ${sqlStr(v.description)},
    ${sqlStr(v.thumb)},
    ${sqlStr(v.channel)},
    ${sqlStr(v.channelUrl)},
    ${sqlStr(v.category)},
    ${sqlTags(v.tags)},
    ${sqlStr(ytUrl)},
    'approved',
    ${v.score},
    false,
    '',
    ${sqlStr(v.lang)},
    'seed',
    '${oembedJson}'::jsonb,
    now()
  )`;
    });
    chunks.push(`insert into public.kesfet_videos (
  youtube_video_id, youtube_url, title, description, thumbnail_url,
  channel_name, channel_url, category, tags, source_url,
  status, relevance_score, safety_flag, safety_note, language,
  crawl_source, oembed, published_at
) values
${values.join(',\n')}
on conflict (youtube_video_id) do nothing;
`);
  }

  const outPath = path.join(ROOT, 'supabase', 'kesfet_seed_videos_batch2.sql');
  fs.writeFileSync(outPath, header + chunks.join('\n'), 'utf8');
  const summary = {
    existingSkipped: existing.size,
    discoveredNew: found.size,
    validated: validated.length,
    seeded: seed.length,
    byCategory: {},
  };
  for (const v of seed) {
    summary.byCategory[v.category] = (summary.byCategory[v.category] || 0) + 1;
  }
  fs.writeFileSync(
    path.join(ROOT, 'tools', '_kesfet_seed_batch2_summary.json'),
    JSON.stringify(summary, null, 2),
  );
  console.log(JSON.stringify(summary, null, 2));
  console.log('wrote', outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
