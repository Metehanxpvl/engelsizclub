import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  classifyScienceKeep,
  isPhase2Plus,
  prefilterKeep,
  promoteKeepTopicPotential,
  shouldInsertResearch,
} from './filter.mjs';

describe('prefilterKeep', () => {
  it('keeps PVL and cerebral palsy', () => {
    assert.equal(
      prefilterKeep('Periventricular leukomalacia in preterm infants'),
      true,
    );
    assert.equal(prefilterKeep('PVL white matter injury MRI'), true);
    assert.equal(prefilterKeep('Cerebral palsy gait training RCT'), true);
    assert.equal(prefilterKeep('Serebral palsi rehabilitasyon denemesi'), true);
    assert.equal(
      prefilterKeep({
        title: 'Hypoxic ischemic encephalopathy cooling trial',
        summary: 'Neonates with HIE',
      }),
      true,
    );
  });

  it('drops random unrelated and oncology-only', () => {
    assert.equal(prefilterKeep('Random adult knee osteoarthritis protocol'), false);
    assert.equal(prefilterKeep('Metastatic breast cancer chemotherapy trial'), false);
    assert.equal(prefilterKeep('Stock market volatility and weather'), false);
    assert.equal(prefilterKeep('Dental caries in adults'), false);
  });

  it('keeps autism / pediatric trials', () => {
    assert.equal(prefilterKeep('Autism spectrum disorder parent training RCT'), true);
    assert.equal(prefilterKeep('Autism in toddlers: communication therapy'), true);
    assert.equal(
      prefilterKeep({
        title: 'Pediatric epilepsy ketogenic diet',
        conditions: ['Epilepsy'],
      }),
      true,
    );
    assert.equal(
      prefilterKeep('Pediatric glioma and cerebral palsy outcomes'),
      true,
    );
  });
});

describe('phase 2 keep / phase 1 drop / recruiting-only drop', () => {
  it('keeps completed phase 2 / 2/3 / 3 / 4 with results', () => {
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT111',
        title: 'MSC for cerebral palsy',
        summary: 'Phase 2 outcomes posted.',
        studyPhase: 'PHASE2',
        recruitmentStatus: 'COMPLETED',
        hasResults: true,
      }).keep,
      true,
    );
    assert.equal(
      isPhase2Plus({ studyPhase: 'PHASE2, PHASE3', title: 'Phase 2/3 CP trial' }),
      true,
    );
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT222',
        title: 'Phase 2/3 CP trial',
        summary: 'Completed.',
        studyPhase: 'PHASE2, PHASE3',
        recruitmentStatus: 'COMPLETED',
        resultsFirstPostDate: '2025-01-15',
      }).reason,
      'phase2',
    );
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT333',
        title: 'Phase 4 follow-up',
        summary: 'Outcomes.',
        studyPhase: 'PHASE4',
        recruitmentStatus: 'COMPLETED',
        hasResults: true,
      }).keep,
      true,
    );
  });

  it('drops phase 1 only, early phase 1, and NA', () => {
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT401',
        title: 'Phase 1 CP safety',
        summary: 'Dose escalation.',
        studyPhase: 'PHASE1',
        recruitmentStatus: 'COMPLETED',
        hasResults: true,
      }).keep,
      false,
    );
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT402',
        title: 'Early phase 1 HIE',
        summary: 'First in human.',
        studyPhase: 'EARLY_PHASE1',
        recruitmentStatus: 'COMPLETED',
        hasResults: true,
      }).keep,
      false,
    );
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT403',
        title: 'Observational CP registry',
        summary: 'No interventional phase.',
        studyPhase: 'NA',
        recruitmentStatus: 'COMPLETED',
        hasResults: true,
      }).keep,
      false,
    );
  });

  it('drops recruiting-only / ise alim listings without results', () => {
    const recruiting = classifyScienceKeep({
      nctId: 'NCT501',
      title: 'Now recruiting children with CP',
      summary: 'We are recruiting participants. Ise alim.',
      studyPhase: 'PHASE2',
      recruitmentStatus: 'RECRUITING',
      hasResults: false,
    });
    assert.equal(recruiting.keep, false);
    assert.equal(recruiting.reason, 'recruiting');

    const notYet = classifyScienceKeep({
      nctId: 'NCT502',
      title: 'MSC for autism',
      summary: 'Not yet open.',
      studyPhase: 'PHASE3',
      recruitmentStatus: 'NOT_YET_RECRUITING',
      hasResults: false,
    });
    assert.equal(notYet.keep, false);
    assert.equal(notYet.reason, 'recruiting');

    const phase1Recruit = classifyScienceKeep({
      nctId: 'NCT503',
      title: 'Seeking participants phase 1',
      summary: 'Currently recruiting.',
      studyPhase: 'PHASE1',
      recruitmentStatus: 'RECRUITING',
    });
    assert.equal(phase1Recruit.keep, false);
    assert.equal(phase1Recruit.reason, 'recruiting');
  });

  it('drops completed phase 2 without posted results', () => {
    const noResults = classifyScienceKeep({
      nctId: 'NCT550',
      title: 'Phase 2 CP trial completed',
      summary: 'Completed, results not posted.',
      studyPhase: 'PHASE2',
      recruitmentStatus: 'COMPLETED',
      hasResults: false,
    });
    assert.equal(noResults.keep, false);
    assert.equal(noResults.reason, 'no_results');
  });

  it('keeps phase 2 recruiting only when results are posted', () => {
    assert.equal(
      classifyScienceKeep({
        nctId: 'NCT601',
        title: 'Phase 2 CP extension, currently recruiting',
        summary: 'Primary outcomes posted; extension open.',
        studyPhase: 'PHASE2',
        recruitmentStatus: 'RECRUITING',
        hasResults: true,
        resultsFirstPostDate: '2024-11-01',
      }).keep,
      true,
    );
  });

  it('drops PubMed protocol-only, no-abstract, and phase 1 papers', () => {
    assert.equal(
      classifyScienceKeep({
        pmid: '1',
        title: 'Study protocol: autism parent training RCT',
        summary: 'This protocol describes a future trial.',
        publicationTypes: ['Journal Article'],
        studyType: 'Study Protocol',
      }).keep,
      false,
    );
    assert.equal(
      classifyScienceKeep({
        pmid: '2',
        title: 'Autism review without abstract',
        summary: '',
        publicationTypes: ['Review'],
      }).keep,
      false,
    );
    assert.equal(
      classifyScienceKeep({
        pmid: '3',
        title: 'Phase 1 stem cell trial in cerebral palsy',
        summary: 'Safety results in 8 children.',
        publicationTypes: ['Clinical Trial'],
        studyPhase: 'Phase 1',
      }).keep,
      false,
    );
  });

  it('keeps FDA drug_approval rows without phase 2', () => {
    assert.equal(
      classifyScienceKeep({
        studyType: 'drug_approval',
        title: 'SMA için FDA ilacı (onaylandı)',
        summary: 'FDA kaydı.',
        conditions: ['SMA'],
        sourceUrl:
          'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?event=overview.process&ApplNo=209531',
        sourceName: 'FDA',
        externalId: 'fda:NDA209531',
      }).keep,
      true,
    );
  });

  it('keeps PubMed RCT / results when phase is 2 plus or unstated', () => {
    assert.equal(
      classifyScienceKeep({
        pmid: '4',
        title: 'Randomized gait training in cerebral palsy',
        summary: 'RCT results: 60 children, primary outcome improved.',
        publicationTypes: ['Randomized Controlled Trial'],
      }).keep,
      true,
    );
    assert.equal(
      classifyScienceKeep({
        pmid: '5',
        title: 'Phase 2 MSC trial in CP',
        summary: 'Randomized efficacy findings in patients.',
        studyPhase: 'Phase 2',
        publicationTypes: ['Clinical Trial'],
      }).keep,
      true,
    );
    assert.equal(
      classifyScienceKeep({
        pmid: '6',
        title: 'Autism prevalence in toddlers',
        summary: 'Epidemiology survey of diagnosis rates.',
        publicationTypes: ['Journal Article'],
      }).keep,
      false,
    );
  });
});

describe('shouldInsertResearch', () => {
  it('does not insert IRRELEVANT', () => {
    assert.equal(shouldInsertResearch('IRRELEVANT'), false);
    assert.equal(shouldInsertResearch('irrelevant'), false);
    assert.equal(shouldInsertResearch('HIGH_VALUE'), true);
    assert.equal(shouldInsertResearch('POTENTIAL_VALUE'), true);
    assert.equal(shouldInsertResearch(''), false);
  });
});

describe('promoteKeepTopicPotential', () => {
  it('marks completed phase 2 plus with outcomes HIGH_VALUE', () => {
    assert.equal(
      promoteKeepTopicPotential(
        {
          nctId: 'NCT700',
          title: 'Cerebral palsy stem cell trial',
          summary: 'Children with CP, outcomes posted.',
          studyPhase: 'PHASE2',
          recruitmentStatus: 'COMPLETED',
          hasResults: true,
        },
        'IRRELEVANT',
      ),
      'HIGH_VALUE',
    );
    assert.equal(
      promoteKeepTopicPotential(
        {
          nctId: 'NCT701',
          title: 'PVL oligodendrocyte phase 3',
          summary: 'Completed trial.',
          studyPhase: 'PHASE3',
          recruitmentStatus: 'COMPLETED',
          resultsFirstPostDate: '2025-06-01',
        },
        'POTENTIAL_VALUE',
      ),
      'HIGH_VALUE',
    );
  });

  it('does not promote phase 1 or recruiting-only topic matches', () => {
    assert.equal(
      promoteKeepTopicPotential(
        {
          nctId: 'NCT702',
          title: 'Cerebral palsy gait RCT',
          summary: 'Now recruiting. Ise alim.',
          studyPhase: 'PHASE1',
          recruitmentStatus: 'RECRUITING',
        },
        'POTENTIAL_VALUE',
      ),
      'IRRELEVANT',
    );
    assert.equal(
      promoteKeepTopicPotential(
        {
          title: 'Metastatic breast cancer chemotherapy trial',
          summary: '',
        },
        'IRRELEVANT',
      ),
      'IRRELEVANT',
    );
  });

  it('keeps PubMed RCT topic as POTENTIAL when AI said IRRELEVANT', () => {
    assert.equal(
      promoteKeepTopicPotential(
        {
          title: 'Cerebral palsy gait RCT',
          summary: 'Randomized trial results in children.',
          publicationTypes: ['Randomized Controlled Trial'],
        },
        'IRRELEVANT',
      ),
      'POTENTIAL_VALUE',
    );
  });
});
