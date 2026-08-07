/**
 * Wrap Text('...') string literals with L10nText and common named strings with S.auto.
 * Source language is Turkish product copy (even without diacritics).
 * Usage: node tool/bulk_l10n_wrap.cjs
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const targets = [
  'lib/main_shell.dart',
  'lib/main.dart',
  'lib/home_page.dart',
  'lib/pages/ilanlar_page.dart',
  'lib/pages/forum_page.dart',
  'lib/pages/merkezler_page.dart',
  'lib/pages/haklar_page.dart',
  'lib/pages/kartlar_page.dart',
  'lib/pages/tibbi_sorumluluk_reddi_page.dart',
  'lib/widgets/guest_gate.dart',
  'lib/widgets/user_safety_sheet.dart',
  'lib/widgets/hastaliklar_section.dart',
  'lib/widgets/duyurular_section.dart',
  'lib/cvi/cvi_disclaimer_page.dart',
  'lib/cvi/cvi_entry.dart',
  'lib/cvi/cvi_results_page.dart',
  'lib/mchat/mchat_entry.dart',
  'lib/mchat/mchat_onboarding_page.dart',
  'lib/mchat/mchat_quiz_page.dart',
  'lib/mchat/mchat_guest_guard.dart',
  'lib/mchat/mchat_result_page.dart',
  'lib/mchat/mchat_privacy_page.dart',
  'lib/cvi/cvi_exercise_page.dart',
  'lib/forum/presentation/widgets/forum_filter_bar.dart',
  'lib/forum/presentation/widgets/forum_scaled_feed.dart',
  'lib/widgets/home_hero_admin_sheet.dart',
];

const skipExact = new Set([
  'OK',
  'Id',
  'ID',
  'PDF',
  'CVI',
  'SMA',
  '•',
  '·',
  '—',
  '-',
  '…',
  '...',
  'M-CHAT',
  'M-CHAT-R',
  'PubMed',
  'JSON',
  'HTTP',
  'HTTPS',
  'URL',
  'API',
  'GPS',
]);

function importFor(file, which) {
  // depth under lib/: lib/a.dart → 0, lib/a/b.dart → 1, lib/a/b/c.dart → 2
  const under = file.replace(/^lib\//, '');
  const depth = under.includes('/') ? under.split('/').length - 1 : 0;
  const prefix = depth === 0 ? '' : '../'.repeat(depth);
  const name = which === 'strings' ? 'app_strings.dart' : 'l10n_text.dart';
  return `import '${prefix}l10n/${name}';`;
}

function ensureImports(src, file) {
  let out = src;
  const lines = out.split('\n');
  const has = (p) => lines.some((l) => l.includes(p));
  const insert = [];
  if (out.includes('S.auto(') && !has('l10n/app_strings.dart')) {
    insert.push(importFor(file, 'strings'));
  }
  if (out.includes('L10nText(') && !has('l10n/l10n_text.dart')) {
    insert.push(importFor(file, 'text'));
  }
  // Avoid duplicate if already importing app_strings via relative forms
  if (insert.length === 0) return out;
  let lastImport = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('import ')) lastImport = i;
  }
  if (lastImport >= 0) lines.splice(lastImport + 1, 0, ...insert);
  return lines.join('\n');
}

function skipContent(s) {
  const t = s.trim();
  if (t.length < 2) return true;
  if (skipExact.has(t)) return true;
  if (/^https?:\/\//i.test(t)) return true;
  if (/^assets\//.test(t) || t.includes('assets/')) return true;
  if (/@/.test(t) && /\./.test(t)) return true;
  if (/\.sql\b/i.test(t)) return true;
  if (/^[0-9₺$€.,\s:%+]+$/.test(t)) return true;
  if (/^[A-Z0-9_./\\-]+$/.test(t) && t.length <= 24) return true;
  // package / path-ish
  if (t.includes('package:') || t.includes('.dart')) return true;
  // Already dynamic / key-like
  if (t.startsWith('nav_') || t.startsWith('menu_')) return true;
  return false;
}

function wrapFile(rel) {
  const fp = path.join(root, rel);
  if (!fs.existsSync(fp)) {
    console.log('skip missing', rel);
    return;
  }
  let src = fs.readFileSync(fp, 'utf8');
  const before = src;

  // Text('...') / Text("...") — not Text(S...) / Text(variable)
  src = src.replace(/\bText\(\s*(['"])((?:\\.|(?!\1)[^])*)\1/g, (m, q, inner) => {
    if (m.includes('L10nText')) return m;
    const decoded = inner.replace(/\\n/g, '\n').replace(/\\'/g, "'").replace(/\\"/g, '"');
    if (skipContent(decoded)) return m;
    return m.replace(/^Text\(/, 'L10nText(');
  });

  const named = [
    'tooltip',
    'hintText',
    'labelText',
    'helperText',
    'counterText',
    'semanticLabel',
  ];
  for (const name of named) {
    const re = new RegExp(
      `\\b${name}:\\s*(['"])((?:\\\\.|(?!\\1)[^])*)\\1`,
      'g',
    );
    src = src.replace(re, (m, q, inner) => {
      if (m.includes('S.auto(') || m.includes('S.t(')) return m;
      const decoded = inner.replace(/\\n/g, '\n');
      if (skipContent(decoded)) return m;
      return `${name}: S.auto(${q}${inner}${q})`;
    });
  }

  // SnackBar(content: Text → already L10nText
  // ChoiceChip label: Text → covered

  if (src === before) {
    console.log('no changes', rel);
    return;
  }
  src = ensureImports(src, rel);
  fs.writeFileSync(fp, src);
  console.log('updated', rel, 'delta', src.length - before.length);
}

for (const t of targets) wrapFile(t);
console.log('done');
