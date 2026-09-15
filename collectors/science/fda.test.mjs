import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { TITLE_TR_FALLBACK } from './ai.mjs';
import {
  classifyFdaStatus,
  fdaContentHash,
  fdaPendingScore,
  fdaSourceUrl,
  keepFdaStatus,
  mapTextToConditions,
  normalizeDrugsfdaRecord,
  toFdaItem,
  turkishFdaTitle,
} from './fda.mjs';
import { classifyScienceKeep, prefilterKeep } from './filter.mjs';
import { buildInsertRow } from './row.mjs';

const spinraza = {
  application_number: 'NDA209531',
  sponsor_name: 'BIOGEN',
  openfda: {
    brand_name: ['SPINRAZA'],
    generic_name: ['NUSINERSEN'],
  },
  products: [
    {
      brand_name: 'SPINRAZA',
      marketing_status: 'Prescription',
      active_ingredients: [{ name: 'NUSINERSEN SODIUM' }],
    },
  ],
  submissions: [
    {
      submission_type: 'ORIG',
      submission_status: 'AP',
      submission_status_date: '20161223',
    },
  ],
};

describe('FDA row mapping', () => {
  it('maps Drugs@FDA record to a pending_review drug_approval row with condition tags', () => {
    const normalized = normalizeDrugsfdaRecord(spinraza, {
      indicationSnippet:
        'SPINRAZA is indicated for the treatment of spinal muscular atrophy (SMA) in pediatric and adult patients.',
      queryTerm: 'spinal muscular atrophy',
    });
    assert.equal(normalized.applicationNumber, 'NDA209531');
    assert.equal(normalized.status, 'approved');
    assert.equal(keepFdaStatus(normalized.status), true);
    assert.ok(normalized.conditions.some((c) => /sma/i.test(c)));
    assert.equal(
      fdaSourceUrl(normalized.applicationNumber),
      'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?event=overview.process&ApplNo=209531',
    );

    const item = toFdaItem(normalized, { name: 'FDA' });
    assert.equal(item.studyType, 'drug_approval');
    assert.equal(item.sourceName, 'FDA');
    assert.equal(item.externalId, 'fda:NDA209531');
    assert.equal(item.sourceUrl, fdaSourceUrl('NDA209531'));
    assert.match(item.title, /SMA|sma/i);
    assert.match(item.title, /FDA/);
    assert.notEqual(item.title, item.originalTitle);
    assert.match(item.summary, /Tedavi vaadi yoktur/);
    assert.equal(prefilterKeep(item), true);
    assert.equal(classifyScienceKeep(item).keep, true);
    assert.equal(classifyScienceKeep(item).reason, 'fda_approval');

    const ai = fdaPendingScore(item);
    assert.equal(ai.treatment_potential, 'HIGH_VALUE');
    assert.equal(ai.study_type, 'drug_approval');
    const row = buildInsertRow(item, ai, { name: 'FDA' }, 'hash');
    assert.equal(row.status, 'pending_review');
    assert.equal(row.source_name, 'FDA');
    assert.equal(row.study_type, 'drug_approval');
    assert.ok(row.conditions.length);
    assert.equal(row.source_url, item.sourceUrl);
    assert.notEqual(row.status, 'published');
  });

  it('keeps tentative approval and in-review NDA/BLA, drops discontinued-only', () => {
    assert.equal(
      classifyFdaStatus({
        marketingStatuses: ['None (Tentative Approval)'],
        submissions: [{ submission_status: 'TA' }],
      }),
      'tentatively_approved',
    );
    assert.equal(
      classifyFdaStatus({
        marketingStatuses: [],
        submissions: [{ submission_type: 'ORIG', submission_status: 'PENDING' }],
      }),
      'in_review',
    );
    assert.equal(
      classifyFdaStatus({
        marketingStatuses: ['Discontinued'],
        submissions: [],
      }),
      '',
    );
    assert.equal(keepFdaStatus('tentatively_approved'), true);
    assert.equal(keepFdaStatus('in_review'), true);
    assert.equal(keepFdaStatus(''), false);
  });

  it('does not tag a negated cerebral palsy mention', () => {
    const mapped = mapTextToConditions(
      'Cyclobenzaprine have not been found effective in children with cerebral palsy.',
    );
    assert.equal(mapped.includes('serebral palsi'), false);
  });

  it('dedups by application number / generic name hash', () => {
    const a = fdaContentHash('NDA209531', 'nusinersen');
    const b = fdaContentHash('nda209531', 'NUSINERSEN');
    const c = fdaContentHash('NDA209531', 'risdiplam');
    assert.equal(a, b);
    assert.notEqual(a, c);
    assert.equal(a.length, 64);
  });

  it('builds a Turkish FDA title without copying the English brand as title', () => {
    const title = turkishFdaTitle(['SMA'], 'approved');
    assert.match(title, /SMA/);
    assert.match(title, /onaylandı/);
    assert.notEqual(title, TITLE_TR_FALLBACK);
    assert.equal(/spinraza/i.test(title), false);
  });
});
