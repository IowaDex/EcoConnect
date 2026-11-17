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
  });
}
