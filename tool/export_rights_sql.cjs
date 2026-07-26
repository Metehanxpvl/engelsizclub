const fs = require('fs');
const path = require('path');

const src = fs.readFileSync(
  path.join(__dirname, '../lib/data/rights_data.dart'),
  'utf8',
);

const start = src.indexOf('const allRights');
const listEnd = src.indexOf('\n];', start);
const body = src.slice(start, listEnd);

function findBlocks(text) {
  const blocks = [];
  let i = text.indexOf('RightItem(');
  while (i >= 0) {
    let depth = 0;
    let j = i;
    for (; j < text.length; j++) {
      if (text[j] === '(') depth++;
      else if (text[j] === ')') {
        depth--;
        if (depth === 0) {
          j++;
          break;
        }
      }
    }
    blocks.push(text.slice(i, j));
    i = text.indexOf('RightItem(', j);
  }
  return blocks;
}

function parseStringExpr(expr) {
  if (!expr) return '';
  const parts = [];
  const re = /'((?:\\'|[^'])*)'|"((?:\\"|[^"])*)"/g;
  let m;
  while ((m = re.exec(expr))) {
    const raw = m[1] != null ? m[1] : m[2];
    parts.push(raw.replace(/\\'/g, "'").replace(/\\"/g, '"').replace(/\\n/g, '\n'));
  }
  return parts.join('');
}

function field(block, name) {
  // Match name: <value>, where value can be concatenated strings or Color(...) or bool/number
  const re = new RegExp(
    name +
      ':\\s*((?:(?:\'(?:\\\\\'|[^\'])*\'|"(?:\\\\"|[^"])*")\\s*\\+\\s*)*(?:\'(?:\\\\\'|[^\'])*\'|"(?:\\\\"|[^"])*")|Color\\(0x[0-9A-Fa-f]+\\)|true|false|\\d+)',
  );
  const m = block.match(re);
  return m ? m[1] : null;
}

function colorArgb(expr) {
  const m = /0x([0-9A-Fa-f]+)/.exec(expr || '');
  return m ? parseInt(m[1], 16) : 4281568586;
}

function steps(block) {
  const m = block.match(/steps:\s*\[([\s\S]*?)\],\s*where:/);
  if (!m) return [];
  const items = [];
  const re = /'((?:\\'|[^'])*)'|"((?:\\"|[^"])*)"/g;
  let x;
  while ((x = re.exec(m[1]))) {
    const raw = x[1] != null ? x[1] : x[2];
    items.push(raw.replace(/\\'/g, "'").replace(/\\"/g, '"'));
  }
  return items;
}

function sqlStr(s) {
  return "'" + String(s).replace(/'/g, "''") + "'";
}

const blocks = findBlocks(body);
const lines = [];
lines.push('-- Engelsiz Club — app_rights seed');
lines.push('-- Supabase SQL Editor → New query → Run');
lines.push('-- Table Editor ile tek tek doldurmaya GEREK YOK');
lines.push('');
lines.push('truncate table public.app_rights restart identity cascade;');
lines.push('');

let sort = 0;
for (const b of blocks) {
  const id = parseStringExpr(field(b, 'id'));
  if (!id) continue;
  sort++;
  const title = parseStringExpr(field(b, 'title'));
  const amount = parseStringExpr(field(b, 'amount'));
  const category = parseStringExpr(field(b, 'category'));
  const icon = parseStringExpr(field(b, 'icon'));
  const color = colorArgb(field(b, 'color'));
  const bg = colorArgb(field(b, 'bg'));
  const minRate = parseInt(field(b, 'minRate') || '0', 10);
  const maxAge = parseInt(field(b, 'maxAge') || '99', 10);
  const income = (field(b, 'incomeLimit') || 'false').includes('true');
  const desc = parseStringExpr(field(b, 'desc'));
  const where = parseStringExpr(field(b, 'where'));
  const stepArr = steps(b);
  const stepsJson = JSON.stringify(stepArr);

  lines.push('insert into public.app_rights (');
  lines.push(
    '  id, title, amount, category, icon, color, bg, min_rate, max_age,',
  );
  lines.push(
    '  income_limit, description, steps, where_text, sort_order, active',
  );
  lines.push(') values (');
  lines.push(`  ${sqlStr(id)},`);
  lines.push(`  ${sqlStr(title)},`);
  lines.push(`  ${sqlStr(amount)},`);
  lines.push(`  ${sqlStr(category)},`);
  lines.push(`  ${sqlStr(icon)},`);
  lines.push(`  ${color},`);
  lines.push(`  ${bg},`);
  lines.push(`  ${minRate},`);
  lines.push(`  ${maxAge},`);
  lines.push(`  ${income},`);
  lines.push(`  ${sqlStr(desc)},`);
  lines.push(`  ${sqlStr(stepsJson)}::jsonb,`);
  lines.push(`  ${sqlStr(where)},`);
  lines.push(`  ${sort},`);
  lines.push('  true');
  lines.push(');');
  lines.push('');
}

lines.push(
  "update public.app_catalog_versions set version = version + 1, updated_at = now() where name = 'rights';",
);
lines.push("notify pgrst, 'reload schema';");

const out = path.join(__dirname, '../supabase/app_catalog_seed_rights.sql');
fs.writeFileSync(out, lines.join('\n'), 'utf8');
console.log(`OK: ${sort} rights -> ${out}`);
