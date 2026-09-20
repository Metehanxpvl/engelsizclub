import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));

export function papersOutputDir(root = DIR) {
  return join(root, 'output');
}

export function papersJsonPath(root = DIR) {
  return join(papersOutputDir(root), 'papers.json');
}

/** Queue row for Imagen 3 (Python generate_images.py). */
export function paperForImageQueue(row, created) {
  const rec = created && typeof created === 'object' ? created : {};
  return {
    id: rec.id || row.id || null,
    title: String(row.title || rec.title || '').trim(),
    original_title: String(row.original_title || rec.original_title || '').trim(),
    summary: String(row.summary || rec.summary || '').trim().slice(0, 800),
    publication_date: row.publication_date || rec.publication_date || null,
    pmid: row.pmid || rec.pmid || null,
    nct_id: row.nct_id || rec.nct_id || null,
    treatment_potential: row.treatment_potential || rec.treatment_potential || '',
  };
}

export function writePapersJson(papers, root = DIR) {
  const dir = papersOutputDir(root);
  mkdirSync(dir, { recursive: true });
  const dest = papersJsonPath(root);
  const list = Array.isArray(papers) ? papers : [];
  writeFileSync(dest, `${JSON.stringify(list, null, 2)}\n`, 'utf8');
  return dest;
}

/** Repo kökü `output/papers.json` — GitHub raw / jsDelivr / Firebase hosting. */
export function githubPapersJsonPath(scienceRoot = DIR) {
  return join(scienceRoot, '..', '..', 'output', 'papers.json');
}

export function writeGithubPapersJson(papers, dest = githubPapersJsonPath()) {
  mkdirSync(dirname(dest), { recursive: true });
  const list = Array.isArray(papers) ? papers : [];
  writeFileSync(dest, `${JSON.stringify(list, null, 2)}\n`, 'utf8');
  return dest;
}
