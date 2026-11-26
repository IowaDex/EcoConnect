import 'package:flutter_test/flutter_test.dart';

import 'package:eco_connect/core/utils/area_match.dart';

void main() {
  group('areaServesResident', () {
    test('matches the resident area exactly', () {
      expect(areaServesResident('Filinvest 1', ['Filinvest 1']), isTrue);
    });

    test('ignores case, spacing and punctuation', () {
      expect(areaServesResident('  filinvest   1 ', ['FILINVEST 1']), isTrue);
      expect(areaServesResident('Doña Pilar', ['DONA PILAR']), isTrue);
    });

    test('matches one area inside a joined route label', () {
      expect(
        areaServesResident('Filinvest 2', ['Filinvest 1 · Filinvest 2']),
        isTrue,
      );
      expect(
        areaServesResident('Northview 1', ['Filinvest 1/Filinvest 2']),
        isFalse,
      );
    });

    test('a different village never matches', () {
      expect(areaServesResident('Filinvest 1', ['Northview 2']), isFalse);
    });

    test('an unknown resident area never matches', () {
      expect(areaServesResident(null, ['Filinvest 1']), isFalse);
      expect(areaServesResident('   ', ['Filinvest 1']), isFalse);
    });

    test('a street-only route does not match an area', () {
      expect(
        areaServesResident('Filinvest 1', [
          'Molave Street',
          'Sampaguita Street',
        ]),
        isFalse,
      );
    });
  });

  group('uniqueAreaNames', () {
    test('splits joined labels and removes repeats', () {
      expect(uniqueAreaNames(['Filinvest 1 · Filinvest 2', 'Filinvest 1']), [
        'Filinvest 1',
        'Filinvest 2',
      ]);
    });
  });
}
