import 'dart:io';

import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:engelsizclub/features/scientific_research/scientific_research_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse row', () {
    test('fromJson maps TR title, scores, ids and status', () {
      final row = ScientificResearch.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'title': '  Serebral palside yürüyüş denemesi  ',
        'original_title': 'Gait trial in cerebral palsy',
        'summary': 'Küçük örneklemli faz 1 insan çalışması.',
        'why_important': 'Hedef kitleyle ilgili erken klinik sinyal.',
        'limitations': 'Örneklem küçük; sonuç kesin değildir.',
        'conditions': ['serebral palsi', 'PVL'],
        'categories': ['rehabilitasyon'],
        'study_type': 'clinical trial',
        'evidence_level': 'phase 1',
        'study_phase': 'Phase 1',
        'human_or_animal': 'human',
        'pediatric_relevance': 'çocuk',
        'relevance_score': 82,
        'scientific_importance_score': '71',
        'treatment_potential_score': 74,
        'clinical_readiness_score': 40,
        'treatment_potential': 'HIGH_VALUE',
        'recruitment_status': 'RECRUITING',
        'publication_date': '2026-03-01',
        'doi': '10.1000/example',
        'pmid': '12345678',
        'nct_id': 'NCT00000001',
        'source_name': 'ClinicalTrials.gov',
        'source_url': 'https://clinicaltrials.gov/study/NCT00000001',
        'status': 'pending_review',
      });

      expect(row.displayTitle, 'Serebral palside yürüyüş denemesi');
      expect(row.originalTitle, 'Gait trial in cerebral palsy');
      expect(row.displayTitle, isNot(row.originalTitle));
      expect(row.summary, contains('faz 1'));
      expect(row.whyImportant, isNotEmpty);
      expect(row.limitations, contains('kesin değildir'));
      expect(row.pmid, '12345678');
      expect(row.nctId, 'NCT00000001');
      expect(row.doi, '10.1000/example');
      expect(row.sourceUrl, startsWith('https://'));
      expect(row.status, 'pending_review');
      expect(row.treatmentPotential, 'HIGH_VALUE');
      expect(row.relevanceScore, 82);
      expect(row.scientificImportanceScore, 71);
      expect(row.treatmentPotentialScore, 74);
      expect(row.recruitmentStatus, 'RECRUITING');
      expect(row.stageLabel, 'İnsan · Faz 1');
      expect(row.stageLabel.toLowerCase(), isNot(contains('tedavi bulundu')));
    });

    test('falls back to original title and maps withdrawn to rejected', () {
      final row = ScientificResearch.fromJson({
        'id': '2',
        'title': 'Çalışmada belirtilmemiş',
        'original_title': 'Animal remyelination study',
        'human_or_animal': 'animal',
        'study_phase': '',
        'treatment_potential': 'potential-value',
        'status': 'withdrawn',
      });
      expect(row.displayTitle, 'Animal remyelination study');
      expect(row.status, 'rejected');
      expect(row.stageLabel, 'Hayvan');
      expect(row.treatmentPotential, 'POTENTIAL_VALUE');
    });
  });

  group('approve does not call duyuru', () {
    test('approve patch is status-only and flags stay off', () {
      expect(kScientificResearchApproveCreatesDuyuru, isFalse);
      expect(kScientificResearchApproveNotify, isFalse);
      final patch = scientificResearchApprovePatch();
      expect(patch, {'status': 'published'});
      expect(patch.containsKey('notify'), isFalse);
      expect(patch.keys, ['status']);
      expect(scientificResearchRejectPatch(), {'status': 'rejected'});
      expect(scientificResearchUnpublishPatch(), {'status': 'rejected'});
    });

    test('repository source never imports addDuyuru or notify', () {
      final src = File(
        'lib/features/scientific_research/scientific_research_repository.dart',
      ).readAsStringSync();
      expect(src.contains('addDuyuru('), isFalse);
      expect(src.contains("import '../../duyuru_store.dart'"), isFalse);
      expect(src.contains("import '../../data/duyuru_data.dart'"), isFalse);
      expect(src.contains('notify:'), isFalse);
      expect(src.contains('scientificResearchApprovePatch()'), isTrue);
    });
  });

  group('HIGH_VALUE filter', () {
    ScientificResearch item({
      String potential = 'POTENTIAL_VALUE',
      int? treatmentScore,
      int? clinicalScore,
      String nct = '',
      String studyType = '',
      String pediatric = '',
      String title = 'Araştırma',
    }) =>
        ScientificResearch.fromJson({
          'id': 'x',
          'title': title,
          'treatment_potential': potential,
          'treatment_potential_score': treatmentScore,
          'clinical_readiness_score': clinicalScore,
          'nct_id': nct,
          'study_type': studyType,
          'pediatric_relevance': pediatric,
          'status': 'pending_review',
        });

    test('matches HIGH_VALUE label or high scores', () {
      expect(isHighTreatmentPotential(item(potential: 'HIGH_VALUE')), isTrue);
      expect(
        isHighTreatmentPotential(item(treatmentScore: 70)),
        isTrue,
      );
      expect(
        isHighTreatmentPotential(item(clinicalScore: 88)),
        isTrue,
      );
      expect(
        isHighTreatmentPotential(item(treatmentScore: 40, clinicalScore: 20)),
        isFalse,
      );
      expect(
        matchesScienceAdminFilter(
          item(potential: 'HIGH_VALUE'),
          ScienceAdminFilter.highValue,
        ),
        isTrue,
      );
      expect(
        matchesScienceAdminFilter(
          item(treatmentScore: 12),
          ScienceAdminFilter.highValue,
        ),
        isFalse,
      );
    });

    test('clinical and pediatric filters', () {
      expect(
        isClinicalResearch(item(nct: 'NCT1')),
        isTrue,
      );
      expect(
        isClinicalResearch(item(studyType: 'randomized clinical trial')),
        isTrue,
      );
      expect(isClinicalResearch(item()), isFalse);
      expect(isPediatricResearch(item(pediatric: 'çocuk')), isTrue);
      expect(
        isPediatricResearch(item(title: 'Pediatric PVL cohort')),
        isTrue,
      );
      expect(isPediatricResearch(item()), isFalse);
    });
  });

  test('admin review shows TR title first and original label', () {
    final src = File(
      'lib/features/scientific_research/admin_science_review_screen.dart',
    ).readAsStringSync();
    expect(src.contains('item.displayTitle'), isTrue);
    expect(src.contains("'Orijinal başlık'"), isTrue);
    expect(src.contains('Başlık (TR)'), isTrue);
  });

  test('science admin is not in Daha Fazlası', () {
    expect(MoreMenuItem.builtinRoutes.contains('bilimsel'), isFalse);
    expect(MoreMenuItem.builtinRoutes.contains('scientific'), isFalse);
    expect(
      defaultMoreMenuItems().any(
        (e) =>
            e.link.toLowerCase().contains('bilim') ||
            e.link.toLowerCase().contains('science'),
      ),
      isFalse,
    );
  });

  test('missing table message points at scientific_researches.sql', () {
    expect(
      isScientificResearchesTableMissing(
        Exception(
          "Could not find the table 'public.scientific_researches' in the schema cache",
        ),
      ),
      isTrue,
    );
    expect(
      scientificResearchLoadError(Exception('PGRST205 scientific_researches')),
      kScientificResearchesMissingSqlMessage,
    );
  });
}
