import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/services/medicine_repository.dart';

void main() {
  test('Dulcosoft box name matches brand variants', () {
    expect(
      MedicineRepository.namesAgree(
        'Dulcosoft',
        'DULCOSOFT Oral Solüsyon 5 g/10 ml 250 ml',
      ),
      isTrue,
    );
  });

  test('Roxem is not Dulcosoft', () {
    expect(
      MedicineRepository.namesAgree(
        'Roxem',
        'DULCOSOFT Oral Solüsyon 5 g/10 ml 250 ml',
      ),
      isFalse,
    );
  });
}
