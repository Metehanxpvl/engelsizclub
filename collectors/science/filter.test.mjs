import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { prefilterKeep, shouldInsertResearch } from './filter.mjs';

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

  it('keeps oncology only when our neuro terms are present', () => {
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
