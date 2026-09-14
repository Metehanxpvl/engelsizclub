import { loadConditions } from './config.mjs';
import { foldTr } from './hash.mjs';

export function blobOf(item) {
  if (typeof item === 'string') return item;
  return [
    item.title,
    item.originalTitle,
    item.summary,
    item.journal,
    ...(Array.isArray(item.conditions) ? item.conditions : []),
  ]
    .filter(Boolean)
    .join(' ');
}

function compiledReject(config) {
  return (config.reject_unless_keep || []).map((k) => foldTr(k));
}

function compiledKeep(config) {
  return (config.keep_keywords || []).map((k) => foldTr(k));
}

function compiledPediatric(config) {
  return (config.pediatric_neuro_keep || []).map((k) => foldTr(k));
}

function compiledWordRe(config) {
  return (config.keep_word_re || []).map((p) => new RegExp(p, 'i'));
}

export function hasKeepKeyword(text, config = loadConditions()) {
  const hay = foldTr(text);
  if (!hay) return false;
  if (compiledKeep(config).some((k) => k && hay.includes(k))) return true;
  if (compiledWordRe(config).some((re) => re.test(hay))) return true;
  if (compiledPediatric(config).some((k) => k && hay.includes(k))) return true;
  return false;
}

export function isOffTopicReject(text, config = loadConditions()) {
  const hay = foldTr(text);
  if (!hay) return true;
  if (hasKeepKeyword(hay, config)) return false;
  return compiledReject(config).some((k) => k && hay.includes(k));
}

/**
 * Cheap prefilter before AI.
 * Keep PVL/CP/HIE and listed neurodevelopmental terms.
 * Drop clearly unrelated (adult oncology-only, random domains).
 * Conservative: no keep keyword → drop.
 */
export function prefilterKeep(item, config = loadConditions()) {
  const blob = blobOf(item);
  if (!String(blob).trim()) return false;
  if (hasKeepKeyword(blob, config)) return true;
  if (isOffTopicReject(blob, config)) return false;
  return false;
}

export function shouldInsertResearch(treatmentPotential) {
  const v = String(treatmentPotential || '')
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  return v === 'HIGH_VALUE' || v === 'POTENTIAL_VALUE';
}

/**
 * CP / PVL / HIE / autism / pediatric neuro that already passed prefilter
 * must not be dropped as IRRELEVANT — keep as POTENTIAL_VALUE at least.
 */
export function promoteKeepTopicPotential(
  item,
  treatmentPotential,
  config = loadConditions(),
) {
  const v = String(treatmentPotential || '')
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (v === 'HIGH_VALUE' || v === 'POTENTIAL_VALUE') return v;
  if (prefilterKeep(item, config)) return 'POTENTIAL_VALUE';
  return v || 'IRRELEVANT';
}
