import 'package:eco_connect/features/collection_points/models/collection_point.dart';
import 'package:eco_connect/features/route/models/route_plan.dart';
import 'package:eco_connect/features/route/services/route_service.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionPoint _point(
  String name, {
  double lat = 14.6,
  double lng = 121.0,
  String address = 'Test address',
  List<String> days = const [],
  String? time,
  String? notes,
  CollectionPointStatus status = CollectionPointStatus.active,
}) {
  return CollectionPoint(
    id: name,
    name: name,
    address: address,
    latitude: lat,
    longitude: lng,
    scheduleDays: days,
    scheduleTime: time,
    notes: notes,
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

    test('point details travel with the stop', () {
      final merged = RouteService.mergeAssignedStops(
        const [],
        [
          _point(
            'Covered court',
            address: 'Mabini St. cor. Rizal Ave.',
            days: ['Mon', 'Thu'],
            time: '07:00',
            notes: 'Gate 2, beside the court',
          ),
        ],
      );

      expect(merged.single.address, 'Mabini St. cor. Rizal Ave.');
      expect(merged.single.schedule, 'Mon, Thu · 07:00');
      expect(merged.single.notes, 'Gate 2, beside the court');
      expect(merged.single.hasDetails, isTrue);
    });

    test('a listed stop keeps its pin but gains missing details', () {
      final merged = RouteService.mergeAssignedStops(
        const [RouteStop(name: 'Covered court', latitude: 9, longitude: 9)],
        [_point('Covered court', address: 'Mabini St.')],
      );

      expect(merged, hasLength(1));
      expect(merged.single.latitude, 9);
      expect(merged.single.address, 'Mabini St.');
    });

    test('stops round-trip their details through Firestore maps', () {
      const stop = RouteStop(
        name: 'Covered court',
        latitude: 14.6,
        longitude: 121.0,
        address: 'Mabini St.',
        schedule: 'Mon · 07:00',
        notes: 'Gate 2',
      );

      final back = RouteStop.fromDynamic(stop.toMap());

      expect(back.name, 'Covered court');
      expect(back.latitude, 14.6);
      expect(back.address, 'Mabini St.');
      expect(back.schedule, 'Mon · 07:00');
      expect(back.notes, 'Gate 2');
      expect(back.hasDetails, isTrue);
    });

    test('blank details are dropped instead of rendered empty', () {
      final stop = RouteStop.fromDynamic({
        'name': 'Covered court',
        'lat': 14.6,
        'lng': 121.0,
        'address': '   ',
      });

      expect(stop.address, isNull);
      expect(stop.hasDetails, isFalse);
    });
  });
}
