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
    expect(noCheck?.name, 'PAROL 500 MG 20 TABLET');
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
}
