import 'package:eco_connect/core/constants/service_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('service area', () {
    test('is Batasan Hills, Quezon City', () {
      expect(ServiceArea.barangay, 'Batasan Hills');
      expect(ServiceArea.city, 'Quezon City');
      expect(ServiceArea.displayName, contains('Batasan Hills'));
    });

    test('matches the served barangay regardless of case or padding', () {
      expect(ServiceArea.covers('Batasan Hills'), isTrue);
      expect(ServiceArea.covers('  batasan hills '), isTrue);
      expect(ServiceArea.covers('BATASAN HILLS'), isTrue);
    });

    test('rejects every other barangay and empty values', () {
      expect(ServiceArea.covers('Commonwealth'), isFalse);
      expect(ServiceArea.covers('Batasan'), isFalse);
      expect(ServiceArea.covers(''), isFalse);
      expect(ServiceArea.covers(null), isFalse);
    });

    test('accepts the barangay with a prefix or the city attached', () {
      expect(ServiceArea.covers('Barangay Batasan Hills'), isTrue);
      expect(ServiceArea.covers('Brgy. Batasan Hills'), isTrue);
      expect(ServiceArea.covers('Batasan Hills, Quezon City'), isTrue);
      expect(ServiceArea.covers('Barangay Commonwealth'), isFalse);
    });

    test('counts a record with no barangay as this barangay', () {
      // The desk and the dashboard share this rule, so a request written
      // before the barangay was stored still opens from its counter.
      expect(ServiceArea.belongsToArea(null), isTrue);
      expect(ServiceArea.belongsToArea('   '), isTrue);
      expect(ServiceArea.belongsToArea('Batasan Hills'), isTrue);
      expect(ServiceArea.belongsToArea('Barangay Batasan Hills'), isTrue);
      expect(
        ServiceArea.belongsToArea(
          '55 Kabihasnan Street, Filinvest 1, Batasan Hills, Quezon City',
        ),
        isTrue,
      );
      expect(ServiceArea.belongsToArea('Commonwealth'), isFalse);
      expect(ServiceArea.belongsToArea('Barangay Commonwealth'), isFalse);
    });
  });
}
