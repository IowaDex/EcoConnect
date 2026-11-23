import 'package:eco_connect/features/driver/models/garbage_truck.dart';
import 'package:eco_connect/features/fleet/services/fleet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const truck = GarbageTruck(
    id: 'sk-4821',
    plateNumber: 'SK 4821',
    wheelers: 8,
    bodyType: 'Compactor',
    barangay: 'Batasan Hills',
    zone: 'Zone 4',
    centerLatitude: 14.6792,
    centerLongitude: 121.0961,
    driverName: 'Ramon Dela Cruz',
  );

  group('fleet search', () {
    test('an empty query keeps every truck', () {
      expect(truckMatchesQuery(truck, ''), isTrue);
      expect(truckMatchesQuery(truck, '  '), isTrue);
    });

    test('matches the plate, the body, the driver and the zone', () {
      expect(truckMatchesQuery(truck, '4821'), isTrue);
      expect(truckMatchesQuery(truck, 'compactor'), isTrue);
      expect(truckMatchesQuery(truck, 'ramon'), isTrue);
      expect(truckMatchesQuery(truck, 'zone 4'), isTrue);
    });

    test('matches the wheel count through the body description', () {
      expect(truckMatchesQuery(truck, '8-wheeler'), isTrue);
    });

    test('is case-insensitive and trims the query', () {
      expect(truckMatchesQuery(truck, '  sk 4821  '), isTrue);
      expect(truckMatchesQuery(truck, 'DELA CRUZ'), isTrue);
    });

    test('rejects plates and drivers the registry does not hold', () {
      expect(truckMatchesQuery(truck, 'SK 9999'), isFalse);
      expect(truckMatchesQuery(truck, 'zone 9'), isFalse);
    });
  });

  group('new truck marker', () {
    GarbageTruck plate({String driver = 'Unassigned', String? account}) =>
        GarbageTruck(
          id: 'sk-9999',
          plateNumber: 'SK 9999',
          wheelers: 6,
          bodyType: 'Compactor',
          barangay: 'Batasan Hills',
          zone: '',
          centerLatitude: 14.6792,
          centerLongitude: 121.0961,
          driverName: driver,
          driverAccountId: account,
        );

    test('a plate with no driver is new', () {
      expect(plate().isNew, isTrue);
    });

    test('a named or paired plate is no longer new', () {
      expect(plate(driver: 'Ramon Dela Cruz').isNew, isFalse);
      expect(plate(driver: 'Ramon Dela Cruz', account: 'd1').isNew, isFalse);
    });
  });
}
