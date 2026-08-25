/**
 * One-off Keşfet seed: discover REAL YouTube Shorts (no invented IDs),
 * score with kesfet_seed.sql keywords, oEmbed-validate, write SQL.
 * Does not read or write API keys. InnerTube is YouTube's public web search.
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
const SHORTS_PARAMS = 'EgIYAQ==';
const MIN_SCORE = 12;
const TARGET = 500;
const PAGES_PER_QUERY = 5;

const QUERIES = [
  'Serebral Palsi',
  'Otizm spektrum',
  'Otizm özel eğitim',
  'Down sendromu',
  'SMA hastalığı',
  'engelli hakları',
  'engelli raporu',
  'ÖTV muafiyeti engelli',
  'evde bakım yardımı',
  'özel eğitim BEP',
  'erişilebilirlik engelli',
  'fizyoterapi serebral palsi',
  'epilepsi nöbet',
  'multipl skleroz',
  'ALS hastalığı',
  'spina bifida',
  'nadir hastalık',
  'tekerlekli sandalye erişilebilir',
  'engelli aylığı',
  'kaynaştırma eğitimi',
  'Duchenne DMD',
  'Rett sendromu',
  'Angelman sendromu',
  'DEHB özel eğitim',
  'rehabilitasyon engelli',
  'işaret dili',
  'görme engelli',
  'işitme engelli',
  'disleksi özel eğitim',
  'ergoterapi otizm',
  'konuşma terapisi otizm',
  'prematüre gelişim geriliği',
  'engelli kimlik kartı',
  'ortez protez',
  'cerebral palsy physiotherapy',
  'autism special education',
  'down syndrome awareness',
  'spinal muscular atrophy SMA',
  'wheelchair accessibility',
  'sign language ASL',
  'special needs IEP',
  'epilepsy first aid',
  'multiple sclerosis MS',
  'rett syndrome',
  'angelman syndrome',
  'duchenne muscular dystrophy',
  'spina bifida awareness',
  'ADHD special education',
  'occupational therapy autism',
  'speech therapy autism',
  'visually impaired accessibility',
  'hearing loss deaf education',
  'inclusive education disability',
  'disability rights',
  'rare disease awareness',
  'caregiver special needs',
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
        '';
      acc.videos.set(node.videoId, { id: node.videoId, titleHint: t });
    }
  }
  const tok = node.continuationCommand?.token;
  if (typeof tok === 'string' && tok.length > 30) acc.continuations.push(tok);
  for (const v of Object.values(node)) walkCollect(v, acc);
}

async function innertubeSearch(query, continuation) {
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

async function main() {
  const keywords = loadKeywords();
  console.log('keywords', keywords.length);

  const found = new Map();
  for (const q of QUERIES) {
    let continuation;
    try {
      for (let page = 0; page < PAGES_PER_QUERY; page++) {
        const json = await innertubeSearch(q, continuation);
        const acc = { videos: new Map(), continuations: [] };
        walkCollect(json, acc);
        for (const v of acc.videos.values()) {
          if (!found.has(v.id)) found.set(v.id, { ...v, query: q });
        }
        continuation = acc.continuations.find((t) => t.length > 40);
        console.log(`search "${q}" p${page + 1} +${acc.videos.size} total=${found.size}`);
        if (!continuation) break;
        await sleep(250);
      }
    } catch (e) {
      console.warn('search fail', q, e.message);
    }
    await sleep(200);
  }

  console.log('unique ids before oembed', found.size);
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

  const header = `-- Engelsiz Club — Keşfet seed videos (approved Shorts)
-- Run AFTER kesfet_schema.sql, kesfet_scoring.sql, kesfet_seed.sql, kesfet_admin.sql
-- ${seed.length} oEmbed-validated unique youtube_video_id values. No invented IDs.
-- ON CONFLICT: safe to re-run. Status = approved (initial feed seed).

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

  const outPath = path.join(ROOT, 'supabase', 'kesfet_seed_videos.sql');
  fs.writeFileSync(outPath, header + chunks.join('\n'), 'utf8');
  const summary = {
    discovered: found.size,
    validated: validated.length,
    seeded: seed.length,
    byCategory: {},
  };
  for (const v of seed) {
    summary.byCategory[v.category] = (summary.byCategory[v.category] || 0) + 1;
  }
  fs.writeFileSync(
    path.join(ROOT, 'tools', '_kesfet_seed_summary.json'),
    JSON.stringify(summary, null, 2),
  );
  console.log(JSON.stringify(summary, null, 2));
  console.log('wrote', outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
