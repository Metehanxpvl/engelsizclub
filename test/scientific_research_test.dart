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
        'image_url': 'https://cdn.example/science.jpg',
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
      expect(row.imageUrl, 'https://cdn.example/science.jpg');
      expect(row.status, 'pending_review');
      expect(row.treatmentPotential, 'HIGH_VALUE');
      expect(row.relevanceScore, 82);
      expect(row.scientificImportanceScore, 71);
      expect(row.treatmentPotentialScore, 74);
      expect(row.recruitmentStatus, 'RECRUITING');
      expect(row.stageLabel, 'İnsan · Faz 1');
      expect(row.stageLabel.toLowerCase(), isNot(contains('tedavi bulundu')));
    });

    test('English title shows TR stub; original stays separate; withdrawn → rejected', () {
      final row = ScientificResearch.fromJson({
        'id': '2',
        'title': 'Çalışmada belirtilmemiş',
        'original_title': 'Animal remyelination study',
        'human_or_animal': 'animal',
        'study_phase': '',
        'treatment_potential': 'potential-value',
        'status': 'withdrawn',
      });
      expect(row.displayTitle, kScientificResearchTitleTrFallback);
      expect(row.originalTitle, 'Animal remyelination study');
      expect(row.displayTitle, isNot(row.originalTitle));
      expect(row.status, 'rejected');
      expect(row.stageLabel, 'Hayvan');
      expect(row.treatmentPotential, 'POTENTIAL_VALUE');
    });

    test('detects English title and prefers Turkish title after backfill', () {
      expect(looksEnglishResearchCopy('Gait trial in cerebral palsy'), isTrue);
      expect(
        looksEnglishResearchCopy('Serebral palside yürüyüş denemesi'),
        isFalse,
      );
      expect(looksTurkishResearchCopy('Serebral palside yürüyüş denemesi'), isTrue);
      final english = ScientificResearch.fromJson({
        'id': '3',
        'title': 'Gait trial in cerebral palsy',
        'original_title': 'Gait trial in cerebral palsy',
        'treatment_potential': 'POTENTIAL_VALUE',
        'status': 'pending_review',
      });
      expect(english.displayTitle, kScientificResearchTitleTrFallback);
      expect(english.originalTitle, 'Gait trial in cerebral palsy');
      final backfilled = ScientificResearch.fromJson({
        'id': '4',
        'title': 'Serebral palside yürüyüş denemesi',
        'original_title': 'Gait trial in cerebral palsy',
        'treatment_potential': 'POTENTIAL_VALUE',
        'status': 'pending_review',
      });
      expect(backfilled.displayTitle, 'Serebral palside yürüyüş denemesi');
      expect(backfilled.displayTitle, isNot(backfilled.originalTitle));
    });
  });

  group('approve publishes duyuru story', () {
    test('flags notify and patch stays status-only', () {
      expect(kScientificResearchApproveCreatesDuyuru, isTrue);
      expect(kScientificResearchApproveNotify, isTrue);
      expect(kScientificResearchApproveNeedImageMessage, 'Önce görsel ekle');
      final patch = scientificResearchApprovePatch();
      expect(patch, {'status': 'published'});
      expect(patch.containsKey('notify'), isFalse);
      expect(patch.keys, ['status']);
      expect(scientificResearchRejectPatch(), {'status': 'rejected'});
      expect(scientificResearchUnpublishPatch(), {'status': 'rejected'});
    });

    test('fromJson reads image_url', () {
      expect(
        ScientificResearch.fromJson({
          'id': '1',
          'title': 'A',
          'image_url': 'https://cdn.example/a.jpg',
          'treatment_potential': 'POTENTIAL_VALUE',
          'status': 'pending_review',
        }).imageUrl,
        'https://cdn.example/a.jpg',
      );
      expect(
        ScientificResearch.fromJson({
          'id': '2',
          'title': 'B',
          'treatment_potential': 'POTENTIAL_VALUE',
          'status': 'pending_review',
        }).imageUrl,
        '',
      );
    });

    test('approve maps to duyuru draft with image', () {
      final draft = scientificResearchToDuyuruDraft(
        ScientificResearch.fromJson({
          'id': '1',
          'title': '  Serebral palsi denemesi  ',
          'original_title': 'Gait trial in cerebral palsy',
          'summary': 'Küçük örneklemli faz 1 insan çalışması.',
          'source_url': 'https://pubmed.ncbi.nlm.nih.gov/123',
          'image_url': 'https://cdn.example/a.jpg',
          'treatment_potential': 'HIGH_VALUE',
          'status': 'pending_review',
        }),
      );
      expect(draft.title, 'Serebral palsi denemesi');
      expect(draft.title, isNot('Gait trial in cerebral palsy'));
      expect(draft.body, 'Küçük örneklemli faz 1 insan çalışması.');
      expect(draft.imageUrl, 'https://cdn.example/a.jpg');
      expect(draft.sourceUrl, 'https://pubmed.ncbi.nlm.nih.gov/123');
      expect(draft.requireImage, isTrue);
      expect(draft.notify, isTrue);
      expect(draft.notify, kScientificResearchApproveNotify);
      expect(draft.body.toLowerCase(), isNot(contains('tedavi bulundu')));
      final picked = scientificResearchToDuyuruDraft(
        ScientificResearch.fromJson({
          'id': '1',
          'title': 'Serebral palsi denemesi',
          'summary': 'Küçük örneklemli faz 1 insan çalışması.',
          'source_url': 'https://pubmed.ncbi.nlm.nih.gov/123',
          'image_url': 'https://cdn.example/a.jpg',
          'treatment_potential': 'HIGH_VALUE',
          'status': 'pending_review',
        }),
        imageUrl: 'https://cdn.example/picked.jpg',
      );
      expect(picked.imageUrl, 'https://cdn.example/picked.jpg');
      expect(picked.notify, isTrue);
    });

    test('duyuru story prefers Turkish title, not original_title', () {
      final englishOnly = scientificResearchToDuyuruDraft(
        ScientificResearch.fromJson({
          'id': '1',
          'title': 'Çalışmada belirtilmemiş',
          'original_title': 'Animal remyelination study',
          'summary': 'Hayvan çalışması; insan tedavisi değildir.',
          'image_url': 'https://cdn.example/a.jpg',
          'treatment_potential': 'POTENTIAL_VALUE',
          'status': 'pending_review',
        }),
      );
      expect(englishOnly.title, 'Bilimsel araştırma');
      expect(englishOnly.title, isNot('Animal remyelination study'));
      expect(englishOnly.body, contains('Hayvan'));

      final copiedEnglish = scientificResearchToDuyuruDraft(
        ScientificResearch.fromJson({
          'id': '2',
          'title': 'Stem cells in PVL',
          'original_title': 'Stem cells in PVL',
          'summary': '',
          'why_important': 'Erken sinyal; kesin sonuç değildir.',
          'image_url': 'https://cdn.example/b.jpg',
          'treatment_potential': 'POTENTIAL_VALUE',
          'status': 'pending_review',
        }),
      );
      expect(copiedEnglish.title, 'Bilimsel araştırma');
      expect(copiedEnglish.body, contains('Erken sinyal'));
    });

    test('no image blocks approve', () {
      final item = ScientificResearch.fromJson({
        'id': '1',
        'title': 'Araştırma',
        'summary': 'Özet korunur.',
        'treatment_potential': 'POTENTIAL_VALUE',
        'status': 'pending_review',
      });
      expect(scientificResearchNeedsStoryImage(item), isTrue);
      expect(item.imageUrl, '');
      final emptyDraft = scientificResearchToDuyuruDraft(item);
      expect(emptyDraft.imageUrl, '');
      expect(emptyDraft.requireImage, isTrue);
      expect(
        () => ensureScientificResearchStoryImage(emptyDraft.imageUrl),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            kScientificResearchApproveNeedImageMessage,
          ),
        ),
      );
      final withPhoto = item.copyWith(imageUrl: 'https://cdn.example/a.jpg');
      expect(scientificResearchNeedsStoryImage(withPhoto), isFalse);
      ensureScientificResearchStoryImage(withPhoto.imageUrl);
    });

    test('repository approve path uses addDuyuru with notify', () {
      final src = File(
        'lib/features/scientific_research/scientific_research_repository.dart',
      ).readAsStringSync();
      expect(src.contains('addDuyuru('), isTrue);
      expect(src.contains("import '../../duyuru_store.dart'"), isTrue);
      expect(src.contains('notify: draft.notify'), isTrue);
      expect(src.contains('requireImage: draft.requireImage'), isTrue);
      expect(src.contains('ensureScientificResearchStoryImage'), isTrue);
      expect(src.contains('scientificResearchApprovePatch()'), isTrue);
      final addAt = src.indexOf('await addDuyuru(');
      final pubAt = src.indexOf('...published');
      expect(addAt, greaterThan(0));
      expect(pubAt, greaterThan(addAt));
      final approveIdx = src.indexOf('await addDuyuru(');
      final publishIdx = src.indexOf('scientificResearchApprovePatch()');
      expect(approveIdx, greaterThan(0));
      expect(publishIdx, greaterThan(approveIdx));
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

  test('admin review shows TR title, gallery picker and story approve', () {
    final src = File(
      'lib/features/scientific_research/admin_science_review_screen.dart',
    ).readAsStringSync();
    expect(src.contains('item.displayTitle'), isTrue);
    expect(src.contains("'Orijinal başlık'"), isTrue);
    expect(src.contains('Başlık (TR)'), isTrue);
    expect(src.contains('Galeriden yükle'), isTrue);
    expect(src.contains('veya görsel URL (https://...)'), isTrue);
    expect(src.contains('kScientificResearchApproveNeedImageMessage'), isTrue);
    expect(src.contains('Güncel Duyurular'), isTrue);
    expect(src.contains('ImagePicker'), isTrue);
    expect(src.contains('Bildirim veya ana sayfa duyurusu gönderilmedi'), isFalse);
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

  test('image_url additive SQL does not drop data', () {
    final sql =
        File('supabase/scientific_researches_image.sql').readAsStringSync();
    expect(sql.toLowerCase(), contains('add column if not exists image_url'));
    expect(sql.toLowerCase(), isNot(contains('drop table')));
    expect(sql.toLowerCase(), isNot(contains('drop column')));
  });
}
