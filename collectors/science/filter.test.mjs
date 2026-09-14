import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { prefilterKeep, promoteKeepTopicPotential, shouldInsertResearch } from './filter.mjs';

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
  it('does not drop CP/PVL as IRRELEVANT', () => {
    assert.equal(
      promoteKeepTopicPotential(
        { title: 'Cerebral palsy stem cell trial', summary: 'Children with CP' },
        'IRRELEVANT',
      ),
      'POTENTIAL_VALUE',
    );
    assert.equal(
      promoteKeepTopicPotential(
        { title: 'PVL oligodendrocyte study', summary: 'Preterm' },
        'irrelevant',
      ),
      'POTENTIAL_VALUE',
    );
    assert.equal(
      promoteKeepTopicPotential(
        { title: 'Metastatic breast cancer chemotherapy trial', summary: '' },
        'IRRELEVANT',
      ),
      'IRRELEVANT',
    );
    assert.equal(
      promoteKeepTopicPotential(
        { title: 'Cerebral palsy gait RCT', summary: '' },
        'HIGH_VALUE',
      ),
      'HIGH_VALUE',
    );
  });
});
