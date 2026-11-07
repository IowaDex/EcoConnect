import 'package:eco_connect/features/events/models/event_participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streetKeyOf', () {
    test('folds the spellings of one street into one bucket', () {
      final variants = [
        'Mabini St.',
        'mabini street',
        '12 Mabini St',
        '  MABINI ST  ',
        '#12 Mabini St.',
        'Unit 4b Mabini St',
      ];
      final keys = variants.map(streetKeyOf).toSet();
      expect(keys, {'mabini st'});
    });

    test('keeps genuinely different streets apart', () {
      expect(streetKeyOf('Mabini St'), isNot(streetKeyOf('Rizal St')));
      expect(streetKeyOf('Mabini St'), isNot(streetKeyOf('Mabini Ave')));
    });

    test('drops house numbers and punctuation', () {
      expect(streetKeyOf('24-B Sampaguita Lane'), 'b sampaguita lane');
      expect(streetKeyOf('7 Katipunan Ave.'), 'katipunan ave');
    });

    test('handles missing or blank input', () {
      expect(streetKeyOf(null), '');
      expect(streetKeyOf('   '), '');
      expect(streetKeyOf('12'), '');
    });
  });

  group('StreetStanding', () {
    test('awards ten points per attendance', () {
      const standing = StreetStanding(
        key: 'mabini st',
        label: 'Mabini St',
        residents: 3,
        attendances: 7,
        events: 2,
      );
      expect(standing.points, 70);
    });
  });

  group('EventParticipant', () {
    test('falls back to the street label when the street is blank', () {
      const person = EventParticipant(
        uid: 'u1',
        name: 'Ana',
        street: '',
        streetKey: '',
        barangay: 'Barangay 1',
      );
      expect(person.streetLabel, 'Street not set');
    });
  });
}
