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
      String studyPhase = '',
      String recruitment = '',
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
          'study_phase': studyPhase,
          'recruitment_status': recruitment,
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

    test('includes Phase 2+ even when AI labeled POTENTIAL_VALUE', () {
      expect(
        isHighTreatmentPotential(
          item(potential: 'POTENTIAL_VALUE', studyPhase: 'PHASE2', nct: 'NCT9'),
        ),
        isTrue,
      );
      expect(
        isHighTreatmentPotential(
          item(
            potential: 'POTENTIAL_VALUE',
            studyPhase: 'Phase 3',
            treatmentScore: 40,
          ),
        ),
        isTrue,
      );
      expect(
        isHighTreatmentPotential(item(studyPhase: 'FAZ 4')),
        isTrue,
      );
      expect(
        matchesScienceAdminFilter(
          item(potential: 'POTENTIAL_VALUE', studyPhase: 'PHASE2, PHASE3'),
          ScienceAdminFilter.highValue,
        ),
        isTrue,
      );
    });

    test('does not dump Phase 1 recruiting as high value', () {
      expect(
        isHighTreatmentPotential(
          item(
            potential: 'POTENTIAL_VALUE',
            studyPhase: 'PHASE1',
            recruitment: 'RECRUITING',
            nct: 'NCT1',
            treatmentScore: 40,
          ),
        ),
        isFalse,
      );
      expect(
        isHighTreatmentPotential(
          item(
            potential: 'POTENTIAL_VALUE',
            studyPhase: 'EARLY_PHASE1',
            recruitment: 'NOT_YET_RECRUITING',
          ),
        ),
        isFalse,
      );
      expect(
        isClinicalResearch(
          item(nct: 'NCT1', studyPhase: 'PHASE1', recruitment: 'RECRUITING'),
        ),
        isTrue,
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
    expect(src.contains('science_admin_count'), isTrue);
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

  test('profile science list uses GitHub papers.json with cache bust', () {
    final catalog = File(
      'lib/features/scientific_research/scientific_papers_catalog.dart',
    ).readAsStringSync();
    expect(catalog.contains(kSciencePapersRawUrl), isTrue);
    expect(
      kSciencePapersRawUrl,
      'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/output/papers.json',
    );
    expect(catalog.contains("'t': bust"), isTrue);
    expect(catalog.contains('kSciencePapersCdnUrl'), isTrue);
    final repo = File(
      'lib/features/scientific_research/scientific_research_repository.dart',
    ).readAsStringSync();
    expect(repo.contains('_loadGithubCatalog()'), isTrue);
    expect(repo.contains('loadForApp('), isFalse);
    final parsed = parseSciencePapersJson(
      '[{"id":"1","title":"Serebral palside yürüyüş","status":"pending_review","treatment_potential":"HIGH_VALUE"}]',
    );
    expect(parsed, hasLength(1);
    expect(parsed.first.displayTitle, contains('yürüyüş'));
  });

  test('home search stays on-demand NCBI and does not dump papers', () {
    final src = File('lib/home_page.dart').readAsStringSync();
    expect(src.contains('eutils.ncbi.nlm.nih.gov'), isTrue);
    expect(src.contains('loadForApp('), isFalse);
    expect(src.contains('_reloadFromLive'), isFalse);
    expect(src.contains('ScientificResearchRepository'), isFalse);
    expect(src.contains("if (raw.isEmpty) return;"), isTrue);
  });
    final pubmed = ScientificResearch.fromJson({
      'id': 'p',
      'title': 'Serebral palside yürüyüş denemesi',
      'original_title': 'Gait trial in cerebral palsy',
      'summary': 'Faz 2 insan çalışması',
      'pmid': '12345678',
      'source_url': 'https://pubmed.ncbi.nlm.nih.gov/12345678/',
      'treatment_potential': 'HIGH_VALUE',
      'status': 'pending_review',
    });
    final trial = ScientificResearch.fromJson({
      'id': 't',
      'title': 'Klinik deneme',
      'nct_id': 'NCT00000001',
      'source_name': 'ClinicalTrials.gov',
      'treatment_potential': 'POTENTIAL_VALUE',
      'status': 'published',
    });
    final rejected = ScientificResearch.fromJson({
      'id': 'r',
      'title': 'Red',
      'treatment_potential': 'IRRELEVANT',
      'status': 'rejected',
    });

    expect(isScienceAppVisible(pubmed), isTrue);
    expect(isScienceAppVisible(trial), isTrue);
    expect(isScienceAppVisible(rejected), isFalse);
    expect(matchesScienceSearchQuery(pubmed, 'yürüyüş'), isTrue);
    expect(matchesScienceSearchQuery(pubmed, 'gait'), isTrue);
    expect(matchesScienceSearchQuery(pubmed, 'otizm'), isFalse);
    expect(isScienceTrialCard(trial), isTrue);
    expect(isScienceTrialCard(pubmed), isFalse);
    expect(scienceResultLink(pubmed), contains('pubmed.ncbi.nlm.nih.gov'));
    expect(scienceResultLink(trial), contains('clinicaltrials.gov'));
    expect(kScientificResearchListLimit, 300);
  });

  test('app and admin read the same scientific_researches table', () {
    final repo = File(
      'lib/features/scientific_research/scientific_research_repository.dart',
    ).readAsStringSync();
    expect(repo.contains("static const _table = 'scientific_researches';"), isTrue);
    expect(repo.contains('loadForAdmin('), isTrue);
    expect(repo.contains('loadForApp('), isTrue);
    expect(repo.contains(".inFilter('status', const ['pending_review', 'published'])"), isTrue);
    expect(repo.contains('kScientificResearchListLimit'), isTrue);
    expect(repo.contains('eutils.ncbi.nlm.nih.gov'), isFalse);
    expect(RegExp("['\"]papers\\.json['\"]").hasMatch(repo), isFalse);
    final start = repo.indexOf('Future<List<ScientificResearch>> loadForApp');
    final next = repo.indexOf('Future<void> updateCopy', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(next, greaterThan(start));
    final loadForApp = repo.substring(start, next);
    expect(loadForApp.contains('_requireAdmin()'), isFalse);
  });

  test('home search uses live scientific_researches not NCBI eutils', () {
    final src = File('lib/home_page.dart').readAsStringSync();
    expect(src.contains('ScientificResearchRepository'), isTrue);
    expect(src.contains('loadForApp('), isTrue);
    expect(src.contains('eutils.ncbi.nlm.nih.gov'), isFalse);
    expect(src.contains('clinicaltrials.gov/api/v2'), isFalse);
    expect(RegExp("['\"]papers\\.json['\"]").hasMatch(src), isFalse);
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
