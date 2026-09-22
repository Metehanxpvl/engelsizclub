import { loadConditions, MISSING } from './config.mjs';
import { foldTr } from './hash.mjs';

export function blobOf(item) {
  if (typeof item === 'string') return item;
  return [
    item.title,
    item.originalTitle,
    item.summary,
    item.journal,
    item.studyPhase,
    item.studyType,
    item.recruitmentStatus,
    ...(Array.isArray(item.publicationTypes) ? item.publicationTypes : []),
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
export function isFdaDrugItem(item) {
  if (String(item?.studyType || '').toLowerCase() === 'drug_approval') return true;
  if (/^fda:/i.test(String(item?.externalId || ''))) return true;
  const blob = `${item?.sourceName || ''} ${item?.sourceUrl || ''}`;
  return /api\.fda\.gov|accessdata\.fda\.gov|drugsfda/i.test(blob);
}

export function prefilterKeep(item, config = loadConditions()) {
  if (isFdaDrugItem(item) && (item.conditions || []).length) return true;
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

function romanOrDigit(token) {
  const t = String(token || '')
    .trim()
    .toLowerCase();
  if (t === 'iv' || t === '4') return 4;
  if (t === 'iii' || t === '3') return 3;
  if (t === 'ii' || t === '2') return 2;
  if (t === 'i' || t === '1') return 1;
  const n = Number(t);
  return n >= 1 && n <= 4 ? n : null;
}

/** Highest mentioned clinical phase, or null if none / NA / early phase 1. */
export function highestPhase(item) {
  const parts = [
    item?.studyPhase,
    ...(Array.isArray(item?.phases) ? item.phases : []),
    item?.title,
    item?.originalTitle,
    item?.summary,
    item?.evidenceLevel,
  ];
  const s = parts.filter(Boolean).join(' ');
  if (!s.trim()) return null;
  if (/EARLY_PHASE1|EARLY\s*PHASE\s*1|FAZ\s*0/i.test(s) && !/PHASE\s*[2-4]|FAZ\s*[2-4]|PHASE\s*(II|III|IV)\b/i.test(s)) {
    return 1;
  }
  const nums = [];
  const word = /(?:PHASE|FAZ)\s*[-_]?\s*(EARLY\s*)?(NA|N\/A|IV|III|II|I|[1-4])(?:\s*\/\s*(IV|III|II|I|[1-4]))?/gi;
  for (const m of s.matchAll(word)) {
    if (/^NA|N\/A$/i.test(m[2] || '')) continue;
    const a = romanOrDigit(m[2]);
    const b = romanOrDigit(m[3]);
    if (a != null) nums.push(a);
    if (b != null) nums.push(b);
  }
  for (const m of s.matchAll(/\bPHASE\s*([1-4])\b/gi)) {
    nums.push(Number(m[1]));
  }
  if (!nums.length) {
    if (/\b(NA|N\/A|NOT[_ ]APPLICABLE)\b/i.test(String(item?.studyPhase || ''))) {
      return 0;
    }
    return null;
  }
  return Math.max(...nums);
}

export function isPhase2Plus(item) {
  return (highestPhase(item) || 0) >= 2;
}

/** Keep ClinicalTrials PHASE2+ when AI leaves study_phase blank / MISSING. */
export function preferSourceStudyPhase(aiPhase, itemPhase) {
  const ai = String(aiPhase || '').trim();
  const src = String(itemPhase || '').trim();
  const aiBlank =
    !ai ||
    ai === MISSING ||
    /^(unspecified|n\/a|na|null|belirtilmemiş)$/i.test(ai);
  if (src && aiBlank) return src;
  return ai || src || '';
}

export function isPhase1OnlyOrNa(item) {
  const phase = highestPhase(item);
  if (phase === 0 || phase === 1) return true;
  const raw = String(item?.studyPhase || '');
  if (/EARLY_PHASE1/i.test(raw) && !isPhase2Plus(item)) return true;
  if (/^\s*(NA|N\/A|NOT[_ ]APPLICABLE)\s*$/i.test(raw)) return true;
  return false;
}

export function hasPostedResults(item) {
  if (item?.hasResults === true) return true;
  const posted = String(item?.resultsFirstPostDate || '').trim();
  if (posted) return true;
  const blob = blobOf(item);
  return /\b(hasResults|results posted|results first posted|resultsFirstPostDate)\b/i.test(
    blob,
  );
}

export function isCompletedStatus(item) {
  return /\b(COMPLETED|HAS_RESULTS)\b/i.test(String(item?.recruitmentStatus || ''));
}

export function isRecruitingStatus(item) {
  return /\b(NOT_YET_RECRUITING|RECRUITING|ENROLLING_BY_INVITATION)\b/i.test(
    String(item?.recruitmentStatus || ''),
  );
}

export function isHiringRecruitingAd(item) {
  const blob = blobOf(item);
  return /işe alım|ise alim|now recruiting|currently recruiting|recruiting participants|seeking participants|participants wanted|we are recruiting|hasta alımı|gonullu araniyor|gönüllü aranıyor/i.test(
    blob,
  );
}

export function isProtocolOnly(item) {
  const head = [
    item?.title,
    item?.originalTitle,
    item?.studyType,
    ...(Array.isArray(item?.publicationTypes) ? item.publicationTypes : []),
  ]
    .filter(Boolean)
    .join(' ');
  if (!/\b(study protocol|trial protocol|protocol paper|study design protocol)\b/i.test(head)) {
    return false;
  }
  return !/\b(results|findings|outcomes?|efficacy)\b/i.test(String(item?.summary || ''));
}

export function hasPubmedResultSignal(item) {
  const types = [
    ...(Array.isArray(item?.publicationTypes) ? item.publicationTypes : []),
    item?.studyType,
  ]
    .filter(Boolean)
    .join(' ');
  const blob = `${types} ${blobOf(item)}`;
  if (
    /\b(Clinical Trial|Randomized Controlled Trial|Controlled Clinical Trial|Pragmatic Clinical Trial|Equivalence Trial)\b/i.test(
      types,
    )
  ) {
    return true;
  }
  if (/\b(randomized|randomised|double-blind|placebo-controlled|\brct\b)\b/i.test(blob)) {
    return true;
  }
  const summary = String(item?.summary || '');
  if (
    /\b(results|outcomes?|efficacy|findings)\b/i.test(summary) &&
    /\b(trial|patients?|participants?)\b/i.test(blob)
  ) {
    return true;
  }
  return false;
}

function isClinicalTrialItem(item) {
  return Boolean(String(item?.nctId || '').trim()) ||
    /clinicaltrials\.gov/i.test(String(item?.sourceUrl || ''));
}

/**
 * Phase 2+ studies with outcomes. Drops phase 1 / NA / recruiting ads / no-results.
 * reason: phase2 | recruiting | no_results
 */
export function classifyScienceKeep(item) {
  if (isFdaDrugItem(item)) {
    return { keep: true, reason: 'fda_approval' };
  }
  const trial = isClinicalTrialItem(item);
  const recruitingAd =
    (isRecruitingStatus(item) && !hasPostedResults(item)) ||
    (isHiringRecruitingAd(item) && !hasPostedResults(item));

  if (trial) {
    if (isPhase1OnlyOrNa(item) || !isPhase2Plus(item)) {
      return { keep: false, reason: recruitingAd ? 'recruiting' : 'no_results' };
    }
    if (isRecruitingStatus(item) && /NOT_YET_RECRUITING/i.test(String(item?.recruitmentStatus || '')) && !hasPostedResults(item)) {
      return { keep: false, reason: 'recruiting' };
    }
    if (recruitingAd && !hasPostedResults(item)) {
      return { keep: false, reason: 'recruiting' };
    }
    if (hasPostedResults(item)) {
      return { keep: true, reason: 'phase2' };
    }
    return { keep: false, reason: 'no_results' };
  }

  if (!String(item?.summary || '').trim()) {
    return { keep: false, reason: 'no_results' };
  }
  if (isHiringRecruitingAd(item) && !hasPostedResults(item) && !hasPubmedResultSignal(item)) {
    return { keep: false, reason: 'recruiting' };
  }
  if (isProtocolOnly(item)) {
    return { keep: false, reason: 'no_results' };
  }
  const phase = highestPhase(item);
  if (phase != null && phase < 2) {
    return { keep: false, reason: 'no_results' };
  }
  if (!hasPubmedResultSignal(item) && !hasPostedResults(item)) {
    return { keep: false, reason: 'no_results' };
  }
  return { keep: true, reason: 'phase2' };
}

export function isCompletedPhase2WithOutcomes(item) {
  if (!isPhase2Plus(item)) return false;
  if (isPhase1OnlyOrNa(item)) return false;
  if (!hasPostedResults(item) && !hasPubmedResultSignal(item)) return false;
  return true;
}

/**
 * AI override: no results and not phase 2+ → IRRELEVANT.
 * Phase 2+ with posted results / outcomes → HIGH_VALUE (COMPLETED not required).
 * Topic-only IRRELEVANT is not promoted unless the results/phase gate passes.
 */
export function applyResultsPhaseScore(
  item,
  treatmentPotential,
  config = loadConditions(),
) {
  const v = String(treatmentPotential || '')
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  const verdict = classifyScienceKeep(item);
  if (!verdict.keep) return 'IRRELEVANT';
  if (isCompletedPhase2WithOutcomes(item)) return 'HIGH_VALUE';
  if (v === 'HIGH_VALUE' || v === 'POTENTIAL_VALUE') return v;
  if (prefilterKeep(item, config)) return 'POTENTIAL_VALUE';
  return v || 'IRRELEVANT';
}

/**
 * CP / PVL / HIE / autism / pediatric neuro that already passed prefilter
 * must not be dropped as IRRELEVANT — keep as POTENTIAL_VALUE at least,
 * but only when the study is phase 2+ or has posted results.
 */
export function promoteKeepTopicPotential(
  item,
  treatmentPotential,
  config = loadConditions(),
) {
  return applyResultsPhaseScore(item, treatmentPotential, config);
}
