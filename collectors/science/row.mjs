import { MISSING } from './config.mjs';

function missingIfEmpty(v) {
  const s = String(v ?? '').trim();
  return s || MISSING;
}

export function buildInsertRow(item, ai, source, contentHash) {
  const pub = item.publicationDate || null;
  return {
    source_id: source?.id || item.sourceId || null,
    title: String(ai.title || item.title).slice(0, 400),
    original_title: String(
      ai.original_title || item.originalTitle || item.title || '',
    ).slice(0, 400),
    summary: String(ai.summary || '').slice(0, 4000),
    why_important: missingIfEmpty(ai.why_important),
    limitations: missingIfEmpty(ai.limitations),
    conditions: Array.isArray(ai.conditions) ? ai.conditions : [],
    categories: Array.isArray(ai.categories) ? ai.categories : [],
    study_type: ai.study_type || item.studyType || null,
    evidence_level: ai.evidence_level || null,
    study_phase: ai.study_phase || item.studyPhase || null,
    human_or_animal: ai.human_or_animal || item.humanOrAnimal || null,
    pediatric_relevance: ai.pediatric_relevance || null,
    relevance_score: ai.relevance_score,
    scientific_importance_score: ai.scientific_importance_score,
    treatment_potential_score: ai.treatment_potential_score,
    clinical_readiness_score: ai.clinical_readiness_score,
    treatment_potential: ai.treatment_potential,
    recruitment_status: item.recruitmentStatus || null,
    publication_date:
      pub && /^\d{4}-\d{2}-\d{2}/.test(String(pub)) ? String(pub).slice(0, 10) : null,
    country: item.country || null,
    journal: item.journal || null,
    doi: item.doi || null,
    pmid: item.pmid || null,
    nct_id: item.nctId || null,
    source_name: source?.name || item.sourceName || '',
    source_url: item.sourceUrl || '',
    external_id: item.externalId || null,
    content_hash: contentHash,
    status: 'pending_review',
    ai_notes: String(ai.ai_notes || '').slice(0, 800),
  };
}
