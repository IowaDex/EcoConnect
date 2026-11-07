import 'package:eco_connect/features/collection_points/models/collection_point.dart';
import 'package:eco_connect/features/route/models/route_plan.dart';
import 'package:eco_connect/features/route/services/route_service.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionPoint _point(
  String name, {
  double lat = 14.6,
  double lng = 121.0,
  CollectionPointStatus status = CollectionPointStatus.active,
}) {
  return CollectionPoint(
    id: name,
    name: name,
    address: 'Test address',
    latitude: lat,
    longitude: lng,
    status: status,
  );
}

void main() {
  group('assigned collection points become route stops', () {
    test('appended after the stops staff already listed', () {
      final merged = RouteService.mergeAssignedStops(
        const [RouteStop(name: 'Market', latitude: 1, longitude: 2)],
        [_point('Covered court'), _point('Barangay hall')],
      );

      expect(merged.map((stop) => stop.name), [
        'Market',
        'Covered court',
        'Barangay hall',
      ]);
      expect(merged.last.latitude, 14.6);
      expect(merged.last.longitude, 121.0);
      expect(merged.last.hasCoordinates, isTrue);
    });

    test('inactive points are skipped', () {
      final merged = RouteService.mergeAssignedStops(
        const [],
        [
          _point('Covered court'),
          _point('Old dump site', status: CollectionPointStatus.inactive),
        ],
      );

      expect(merged.map((stop) => stop.name), ['Covered court']);
    });

    test('a listed stop wins on a name clash', () {
      final merged = RouteService.mergeAssignedStops(
        const [RouteStop(name: 'Covered Court', latitude: 9, longitude: 9)],
        [_point('covered court', lat: 1, lng: 1)],
      );

      expect(merged, hasLength(1));
      expect(merged.single.latitude, 9);
      expect(merged.single.longitude, 9);
    });

    test('blank point names are ignored', () {
      final merged = RouteService.mergeAssignedStops(
        const [],
        [_point('   ')],
      );

      expect(merged, isEmpty);
    });

    test('withStops keeps the assignment metadata', () {
      const plan = RoutePlan(
        id: 'plan-1',
        driverId: 'driver-1',
        driverName: 'Juan',
        zone: 'Purok 3',
        date: '2026-11-07',
        windowStart: '06:00',
        windowEnd: '10:00',
        status: RoutePlanStatus.active,
        adHoc: true,
      );

      final merged = plan.withStops(
        const [RouteStop(name: 'Covered court', latitude: 1, longitude: 1)],
      );

      expect(merged.id, 'plan-1');
      expect(merged.driverName, 'Juan');
      expect(merged.zone, 'Purok 3');
      expect(merged.status, RoutePlanStatus.active);
      expect(merged.adHoc, isTrue);
      expect(merged.stopsLabel, '1 stop');
      expect(merged.mappedStops, hasLength(1));
    });
  });
}
