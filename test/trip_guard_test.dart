import 'package:eco_connect/features/driver/data/mock_trucks.dart';
import 'package:eco_connect/features/driver/models/truck_crew_role.dart';
import 'package:eco_connect/features/driver/services/trip_guard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('truck list', () {
    test('shows ten trucks, each with a plate and a wheel count', () {
      expect(kMockTrucks.length, 10);
      for (final truck in kMockTrucks) {
        expect(truck.plateNumber.trim(), isNotEmpty);
        expect([4, 6, 8], contains(truck.wheelers));
        expect(truck.wheelerLabel, '${truck.wheelers}-wheeler');
      }
    });

    test('plate numbers are unique so a crew cannot pick the wrong truck', () {
      final plates = kMockTrucks.map((t) => t.plateNumber).toSet();
      expect(plates.length, kMockTrucks.length);
    });

    test('a truck survives the round trip through local storage', () {
      final truck = kMockTrucks.first;
      final restored = truckById(truck.id);
      expect(restored?.plateNumber, truck.plateNumber);
      expect(restored?.wheelers, truck.wheelers);
    });

    test('unknown ids resolve to null instead of throwing', () {
      expect(truckById('truck-99'), isNull);
      expect(truckById(null), isNull);
    });
  });

  group('trip radius', () {
    test('inside the radius is fine, past 100 m is not', () {
      expect(TripGuardService.isOutsideRadius(0), isFalse);
      expect(TripGuardService.isOutsideRadius(99.9), isFalse);
      expect(TripGuardService.isOutsideRadius(100), isFalse);
      expect(TripGuardService.isOutsideRadius(100.1), isTrue);
      expect(TripGuardService.isOutsideRadius(240), isTrue);
    });

    test('coming back inside needs the hysteresis margin', () {
      // 95 m is inside the radius but not yet "back", so the banner does not
      // flicker while the truck sits on the line.
      expect(TripGuardService.isBackInside(95), isFalse);
      expect(TripGuardService.isBackInside(92), isTrue);
      expect(TripGuardService.isBackInside(40), isTrue);
    });

    test('distance between two points is in metres', () {
      // ~0.0009 degrees of latitude is ~100 m.
      final metres = TripGuardService.metresBetween(
        14.6792,
        121.0961,
        14.6801,
        121.0961,
      );
      expect(metres, greaterThan(90));
      expect(metres, lessThan(110));
    });
  });

  group('radius centre', () {
    test('uses the assigned zone centre when the crew is nearby', () {
      final center = TripGuardService.resolveCenter(
        zoneLat: 14.6792,
        zoneLng: 121.0961,
        startLat: 14.6795,
        startLng: 121.0965,
      );
      expect(center.lat, 14.6792);
      expect(center.lng, 121.0961);
    });

    test('falls back to the start point when testing far from the zone', () {
      // A laptop in another city must not trip the alarm before moving.
      final center = TripGuardService.resolveCenter(
        zoneLat: 14.6792,
        zoneLng: 121.0961,
        startLat: 10.3157,
        startLng: 123.8854,
      );
      expect(center.lat, 10.3157);
      expect(center.lng, 123.8854);
    });
  });

  group('crew role', () {
    test('guide and driver keep the same labels apart', () {
      expect(TruckCrewRole.guide.label, 'Truck Guide');
      expect(TruckCrewRole.driver.label, 'Truck Driver');
      expect(TruckCrewRoleX.fromName('guide'), TruckCrewRole.guide);
      expect(TruckCrewRoleX.fromName(null), TruckCrewRole.driver);
    });
  });
}
