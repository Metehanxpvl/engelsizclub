import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));

let cached;

export function loadConditions() {
  if (cached) return cached;
  const raw = readFileSync(join(DIR, 'conditions.json'), 'utf8');
  cached = JSON.parse(raw);
  return cached;
}

export function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

export const MISSING = 'Çalışmada belirtilmemiş';
