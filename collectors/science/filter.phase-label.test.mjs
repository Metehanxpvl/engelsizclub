import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { MISSING } from './config.mjs';
import {
  preferSourceStudyPhase,
  promoteKeepTopicPotential,
} from './filter.mjs';

describe('phase 2 plus HIGH_VALUE label', () => {
  it('promotes recruiting phase 2 with posted results to HIGH_VALUE', () => {
    assert.equal(
      promoteKeepTopicPotential(
        {
          nctId: 'NCT703',
          title: 'Cerebral palsy phase 2 with results',
          summary: 'Outcomes posted while follow-up continues.',
          studyPhase: 'PHASE2',
          recruitmentStatus: 'RECRUITING',
          hasResults: true,
        },
        'POTENTIAL_VALUE',
      ),
      'HIGH_VALUE',
    );
  });

  it('keeps source PHASE2 when AI study_phase is missing', () => {
    assert.equal(
      preferSourceStudyPhase(MISSING, 'PHASE2, PHASE3'),
      'PHASE2, PHASE3',
    );
    assert.equal(preferSourceStudyPhase('Faz 3', 'PHASE2'), 'Faz 3');
  });
});
