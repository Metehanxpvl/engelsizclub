import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { parseMedlineRecords, toPubmedItem } from './pubmed.mjs';
import { parseStudy, toTrialItem } from './clinicaltrials.mjs';
import { filterRecentItems } from './dates.mjs';

describe('parseMedlineRecords', () => {
  it('reads pmid, title, abstract, doi', () => {
    const raw = `PMID- 38700001
TI  - Cerebral palsy gait training.
AB  - A randomized trial in children.
JT  - Nature
DP  - 2026 Jun 12
PL  - England
LID - 10.1000/xyz [doi]
PT  - Journal Article
PT  - Randomized Controlled Trial
`;
    const [rec] = parseMedlineRecords(raw);
    assert.equal(rec.pmid, '38700001');
    assert.equal(rec.title, 'Cerebral palsy gait training.');
    assert.equal(rec.doi, '10.1000/xyz');
    assert.equal(rec.publicationDate, '2026-06-12');
    const item = toPubmedItem(rec, { name: 'PubMed', id: 'x' });
    assert.equal(item.sourceUrl, 'https://pubmed.ncbi.nlm.nih.gov/38700001/');
    assert.equal(item.externalId, 'pmid:38700001');
    assert.equal(item.hasResults, true);
    assert.ok(item.publicationTypes.includes('Randomized Controlled Trial'));
    const now = new Date('2026-09-15T12:00:00.000Z');
    assert.equal(filterRecentItems([item], now).length, 1);
    assert.equal(
      filterRecentItems([{ ...item, publicationDate: '2018-01-15' }], now).length,
      0,
    );
  });
});

describe('parseStudy', () => {
  it('reads NCT, status, countries', () => {
    const study = {
      hasResults: true,
      protocolSection: {
        identificationModule: {
          nctId: 'NCT01234567',
          briefTitle: 'MSC for cerebral palsy',
          officialTitle: 'Mesenchymal stem cells for CP',
        },
        statusModule: {
          overallStatus: 'COMPLETED',
          startDateStruct: { date: '2024-03-01' },
          lastUpdatePostDateStruct: { date: '2025-03-01' },
          resultsFirstPostDateStruct: { date: '2025-02-01' },
        },
        descriptionModule: { briefSummary: 'Children with CP.' },
        conditionsModule: { conditions: ['Cerebral Palsy'] },
        designModule: { studyType: 'INTERVENTIONAL', phases: ['PHASE2'] },
        eligibilityModule: { stdAges: ['CHILD'] },
        contactsLocationsModule: {
          locations: [{ country: 'Turkey' }, { country: 'Turkey' }],
        },
      },
    };
    const parsed = parseStudy(study);
    assert.equal(parsed.nctId, 'NCT01234567');
    assert.equal(parsed.overallStatus, 'COMPLETED');
    assert.equal(parsed.hasResults, true);
    assert.equal(parsed.resultsFirstPostDate, '2025-02-01');
    const item = toTrialItem(parsed, { name: 'ClinicalTrials.gov' });
    assert.equal(item.recruitmentStatus, 'COMPLETED');
    assert.equal(item.hasResults, true);
    assert.equal(item.humanOrAnimal, 'human');
    assert.equal(item.sourceUrl, 'https://clinicaltrials.gov/study/NCT01234567');
    assert.equal(item.lastUpdatePostDate, '2025-03-01');
  });
});
