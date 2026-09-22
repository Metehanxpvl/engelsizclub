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

export const TABLES_SQL_HINT = `
Tablo yok. Supabase Dashboard → SQL Editor → supabase/scientific_researches.sql dosyasının TAMAMINI yapıştırıp Run edin.

  public.scientific_sources
  public.scientific_researches

İlk Action'dan önce bu SQL bir kez koşmalı. Collector pending_review yazar; yayın / FCM yok.
`.trim();

export const EMPTY_SOURCES_SQL_HINT = `
scientific_sources boş veya is_active=true satır yok — bu yüzden tarama 0 kâğıt bulur.

Supabase Dashboard → SQL Editor → supabase/scientific_researches.sql TAMAMINI Run edin
(PubMed + ClinicalTrials.gov satırları is_active=true, method=api olmalı).

Collector şimdi yine de collectors/science/conditions.json sorgularıyla PubMed + ClinicalTrials + FDA tarayacak.
`.trim();

/** Used when DB has no active API sources so the first run still searches. */
export function fallbackSources() {
  return [
    {
      id: null,
      name: 'PubMed',
      url: 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/',
      method: 'api',
      query: '',
      fetch_interval_hours: 6,
      last_fetched_at: null,
      fallback: true,
    },
    {
      id: null,
      name: 'ClinicalTrials.gov',
      url: 'https://clinicaltrials.gov/api/v2/studies',
      method: 'api',
      query: '',
      fetch_interval_hours: 6,
      last_fetched_at: null,
      fallback: true,
    },
    {
      id: null,
      name: 'FDA',
      url: 'https://api.fda.gov/drug/drugsfda.json',
      method: 'api',
      query: '',
      fetch_interval_hours: 6,
      last_fetched_at: null,
      fallback: true,
    },
  ];
}
