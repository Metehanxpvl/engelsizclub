/**
 * Wrap dynamic content Text(obj.field) as L10nText for UGC/catalog fields.
 */
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');

const files = [
  'lib/pages/ilanlar_page.dart',
  'lib/pages/forum_page.dart',
  'lib/pages/haklar_page.dart',
  'lib/pages/kartlar_page.dart',
  'lib/pages/merkezler_page.dart',
  'lib/widgets/hastaliklar_section.dart',
  'lib/widgets/duyurular_section.dart',
  'lib/home_page.dart',
  'lib/main_shell.dart',
  'lib/data/rights_data.dart',
];

const fields =
  'title|note|content|desc|description|body|summary|name|message|ozet|icerik|aciklama|subtitle|etiket';

function ensureL10nImport(src, file) {
  if (!src.includes('L10nText(')) return src;
  if (src.includes('l10n/l10n_text.dart')) return src;
  const nested = file.includes('/pages/') || file.includes('/widgets/') || file.includes('/data/');
  const imp = nested
    ? "import '../l10n/l10n_text.dart';"
    : "import 'l10n/l10n_text.dart';";
  const lines = src.split('\n');
  let last = -1;
  for (let i = 0; i < lines.length; i++) if (lines[i].startsWith('import ')) last = i;
  if (last >= 0) lines.splice(last + 1, 0, imp);
  return lines.join('\n');
}

for (const rel of files) {
  const fp = path.join(root, rel);
  if (!fs.existsSync(fp)) continue;
  let src = fs.readFileSync(fp, 'utf8');
  const before = src;

  // Text(\n  foo.bar,\n
  const reMulti = new RegExp(
    `\\bText\\(\\s*\\n(\\s*)([a-zA-Z_][\\w.]*\\.(?:${fields}))\\s*,`,
    'g',
  );
  src = src.replace(reMulti, 'L10nText(\n$1$2,');

  // Text(foo.bar,
  const reOne = new RegExp(
    `\\bText\\(\\s*([a-zA-Z_][\\w.]*\\.(?:${fields}))\\s*,`,
    'g',
  );
  src = src.replace(reOne, 'L10nText($1,');

  // Text(foo.bar)
  const reBare = new RegExp(
    `\\bText\\(\\s*([a-zA-Z_][\\w.]*\\.(?:${fields}))\\s*\\)`,
    'g',
  );
  src = src.replace(reBare, 'L10nText($1)');

  if (src === before) {
    console.log('no change', rel);
    continue;
  }
  src = ensureL10nImport(src, rel);
  fs.writeFileSync(fp, src);
  console.log('updated', rel);
}
console.log('done');
