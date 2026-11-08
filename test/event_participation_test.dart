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

    test('keeps streets whose name starts like a house marker', () {
      expect(streetKeyOf('Northville St'), 'northville st');
      expect(streetKeyOf('Norte Street'), 'norte st');
      expect(streetKeyOf('Lotus St'), 'lotus st');
      expect(streetKeyOf('Houseman Rd'), 'houseman rd');
      expect(streetKeyOf('Northville St'), isNot(streetKeyOf('Lotus St')));
    });

    test('keeps ordinal street names apart', () {
      expect(streetKeyOf('1st Street'), '1st st');
      expect(streetKeyOf('2nd Street'), '2nd st');
      expect(streetKeyOf('5th Ave'), '5th ave');
      expect(streetKeyOf('15th Ave'), '15th ave');
      expect(streetKeyOf('5th Ave'), isNot(streetKeyOf('15th Ave')));
      expect(streetKeyOf('12 5th Ave'), '5th ave');
      expect(streetKeyOf('12A 5th Ave.'), '5th ave');
    });

    test('strips stacked block and lot markers', () {
      expect(streetKeyOf('Blk 7 Lot 12 Mabini St'), 'mabini st');
      expect(streetKeyOf('No. 12 Mabini St'), 'mabini st');
      expect(streetKeyOf('Unit4B Rizal Ave'), 'rizal ave');
    });

    test('keeps genuinely different streets apart', () {
      expect(streetKeyOf('Mabini St'), isNot(streetKeyOf('Rizal St')));
      expect(streetKeyOf('Mabini St'), isNot(streetKeyOf('Mabini Ave')));
    });

    test('drops house numbers and punctuation', () {
      expect(streetKeyOf('24-B Sampaguita Lane'), 'sampaguita lane');
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

    test('derives the ranking key from the street, not the stored key', () {
      final person = EventParticipant.fromDoc('u1', {
        'name': 'Ana',
        'street': '1st Street',
        'streetKey': 'st st', // written by an older, buggy build
        'barangay': 'B1',
      });
      expect(person.streetKey, '1st st');
    });
  });
}
