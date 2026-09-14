import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/models/medicine_report.dart';
import 'package:engelsizclub/services/titck_kubkt_service.dart';
import 'package:engelsizclub/services/titck_skrs_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(TitckSkrsIndex.debugReset);

  test('SKRS barcode lookup uses GTIN-14 and EAN-13 keys', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '8699717010109',
        name: 'PAROL 500 MG 20 TABLET',
        activeIngredient: 'paracetamol',
      ),
    ]);
    final hit = await TitckSkrsIndex.findByBarcode('08699717010109');
    expect(hit?.name, 'PAROL 500 MG 20 TABLET');
    expect(hit?.activeIngredient, 'paracetamol');
    expect(TitckSkrsIndex.lastMatchForm, isNotNull);

    final noCheck = await TitckSkrsIndex.findByBarcode('869971701010');
    expect(noCheck, isNull);
  });

  test('truncated / prefix GTIN does not return a different drug', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '8682329000019',
        name: 'LEVOXIMED 250MG FILM KAPLI TABLET , 7 TABLET',
        activeIngredient: 'levofloxacin',
      ),
      const TitckSkrsHit(
        barcode: '86823290000194',
        name: 'ZAGERA 300 MG SERT KAPSÜL, 56 ADET',
        activeIngredient: 'pregabalin',
      ),
      const TitckSkrsHit(
        barcode: '8699717010109',
        name: 'PAROL 500 MG 20 TABLET',
        activeIngredient: 'paracetamol',
      ),
    ]);

    expect(
      (await TitckSkrsIndex.findByBarcode('86823290000194'))?.name,
      startsWith('ZAGERA'),
    );
    expect(
      (await TitckSkrsIndex.findByBarcode('8682329000019'))?.name,
      startsWith('LEVOXIMED'),
    );
    expect(await TitckSkrsIndex.findByBarcode('86823290000190'), isNull);
    expect(await TitckSkrsIndex.findByBarcode('869971701010'), isNull);
    expect(
      (await TitckSkrsIndex.findByBarcode('08699717010109'))?.name,
      'PAROL 500 MG 20 TABLET',
    );
  });

  test('GTIN override overwrites a wrong index row', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '8683060650037',
        name: 'ROXEM 150 MG FILM TABLET',
        activeIngredient: 'roxithromycin',
      ),
    ]);
    TitckSkrsIndex.debugApplyOverride(
      const TitckSkrsHit(
        barcode: '8683060650037',
        name: 'DULCOSOFT Oral Solüsyon 5 g/10 ml 250 ml',
        activeIngredient: 'Makrogol 4000',
      ),
    );
    final hit = await TitckSkrsIndex.findByBarcode('08683060650037');
    expect(hit?.name, contains('DULCOSOFT'));
    expect(hit?.activeIngredient, 'Makrogol 4000');
  });

  test('GTIN index stays a singleton map across lookups', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '8699717010109',
        name: 'PAROL 500 MG 20 TABLET',
        activeIngredient: 'paracetamol',
      ),
    ]);
    final a = await TitckSkrsIndex.findByBarcode('8699717010109');
    final b = await TitckSkrsIndex.findByBarcode('08699717010109');
    expect(identical(a, b), isTrue);
  });

  test('SKRS name search prefers prefix matches', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '1',
        name: 'PAROL PLUS 30 TABLET',
        activeIngredient: 'paracetamol',
      ),
      const TitckSkrsHit(
        barcode: '2',
        name: 'APRIL PAROLAT',
        activeIngredient: 'x',
      ),
    ]);
    final hits = await TitckSkrsIndex.searchByName('parol');
    expect(hits.first.name, 'PAROL PLUS 30 TABLET');
  });

  test('TİTCK leaflet prefers KT URL over KÜB', () {
    const hit = TitckLeafletHit(
      name: 'PAROL',
      ktUrl: 'https://www.titck.gov.tr/kt.pdf',
      kubUrl: 'https://www.titck.gov.tr/kub.pdf',
    );
    expect(hit.prospectusUrl, 'https://www.titck.gov.tr/kt.pdf');
  });

  test('TİTCK leaflet search query uses first tokens', () {
    expect(
      TitckKubktService.searchQuery(
        'PAROL 500 MG 20 TABLET FILM KAPLI',
      ),
      'PAROL 500 MG',
    );
  });

  test('MedicineRecord parses indications and prospectus_url', () {
    final rec = MedicineRecord.fromJson({
      'medicine_name': 'PAROL 500 MG 20 TABLET',
      'active_ingredient': 'paracetamol',
      'indications': 'Ağrı ve ateş',
      'usage': 'Günde en fazla 4 kez',
      'prospectus_url': 'https://www.titck.gov.tr/storage/kt.pdf',
      'drug_interactions': ['Warfarin'],
    });
    expect(rec.indications, 'Ağrı ve ateş');
    expect(rec.hasOfficialProspectus, isTrue);
    expect(rec.drugInteractions, ['Warfarin']);
    expect(rec.toInsertJson()['prospectus_url'], contains('titck.gov.tr'));
  });

  test('SKRS identity is found but not a full prospectus', () {
    const rec = MedicineRecord(
      medicineName: 'PAROL 500 MG 20 TABLET',
      activeIngredient: 'paracetamol',
      source: 'titck',
    );
    expect(rec.isFound, isTrue);
    expect(rec.isComplete, isFalse);
    expect(rec.hasProspectusDetails, isFalse);
    expect(rec.needsLeaflet, isTrue);
    expect(rec.needsEnrichment, isTrue);
  });

  test('Gemini summary without KT URL still needs leaflet', () {
    const rec = MedicineRecord(
      medicineName: 'PAROL 500 MG 20 TABLET',
      indications: 'Ağrı ve ateş',
      source: 'llm',
    );
    expect(rec.isComplete, isTrue);
    expect(rec.hasProspectusDetails, isTrue);
    expect(rec.hasOfficialProspectus, isFalse);
    expect(rec.needsLeaflet, isTrue);
  });

  test('Official KT URL is enough to open prospectus', () {
    const rec = MedicineRecord(
      medicineName: 'PAROL 500 MG 20 TABLET',
      prospectusUrl: 'https://www.titck.gov.tr/storage/kt.pdf',
    );
    expect(rec.hasOfficialProspectus, isTrue);
    expect(rec.needsLeaflet, isFalse);
  });

  test('Placeholder Yok does not count as prospectus details', () {
    final rec = MedicineRecord.fromJson({
      'medicine_name': 'PAROL 500 MG 20 TABLET',
      'side_effects': ['Yok'],
      'drug_interactions': ['Bilinmiyor'],
      'safety_warnings': 'Yoktur',
    });
    expect(rec.sideEffects, isEmpty);
    expect(rec.drugInteractions, isEmpty);
    expect(rec.safetyWarnings, isEmpty);
    expect(rec.isComplete, isFalse);
    expect(MedicineRecord.isUnknownText('Yok'), isTrue);
    expect(MedicineRecord.isUnknownText('Bilinmiyor.'), isTrue);
  });

  test('Numeric SKRS product id is not a useful medicine name', () {
    const rec = MedicineRecord(
      medicineName: '41513',
      activeIngredient: 'treprostinil',
      source: 'titck',
    );
    expect(rec.hasUsefulName, isFalse);
    expect(rec.isComplete, isFalse);
    expect(rec.isFound, isTrue);
  });

  test('SKRS name search skips numeric product ids', () async {
    TitckSkrsIndex.debugSetHits([
      const TitckSkrsHit(
        barcode: '1111111100755',
        name: '41513',
        activeIngredient: 'treprostinil',
      ),
      const TitckSkrsHit(
        barcode: '8699717010109',
        name: 'PAROL 500 MG 20 TABLET',
        activeIngredient: 'paracetamol',
      ),
    ]);
    expect(await TitckSkrsIndex.searchByName('415'), isEmpty);
    final hits = await TitckSkrsIndex.searchByName('parol');
    expect(hits, hasLength(1));
    expect(hits.first.name, 'PAROL 500 MG 20 TABLET');
  });

  test('Gemini ingredients maps to indications', () {
    final rec = MedicineRecord.fromGemini({
      'product_name': 'Parol',
      'ingredients': 'Ağrı kesici olarak kullanılır',
      'usage': 'Bol su ile',
    });
    expect(rec.indications, contains('Ağrı'));
  });

  test('29k GTIN asset loads once; lookup is the same map entry', () async {
    await TitckSkrsIndex.ensureLoaded();
    final hit = await TitckSkrsIndex.findByBarcode('1111111100755');
    expect(hit, isNotNull);
    expect(hit!.activeIngredient, 'treprostinil');
    final again = await TitckSkrsIndex.findByBarcode('1111111100755');
    expect(identical(hit, again), isTrue);
  });

  test('live index: 14-digit neighbor is not a 13-digit prefix hit', () async {
    await TitckSkrsIndex.ensureLoaded();
    final zagera = await TitckSkrsIndex.findByBarcode('86823290000194');
    expect(zagera?.name, contains('ZAGERA'));
    final levox = await TitckSkrsIndex.findByBarcode('8682329000019');
    expect(levox?.name, contains('LEVOXIMED'));
    expect(await TitckSkrsIndex.findByBarcode('86823290000190'), isNull);

    final dulco = await TitckSkrsIndex.findByBarcode('8683060650037');
    expect(dulco?.name, contains('DULCOSOFT'));
    expect(
      await TitckSkrsIndex.findByBarcode('8690000000004'),
      isNull,
    );
  });
}
