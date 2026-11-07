import 'dart:convert';

import 'package:eco_connect/core/models/route_plan.dart';
import 'package:eco_connect/core/widgets/route_preview_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 1x1 transparent PNG so tiles never touch the network in tests.
final _blankPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _BlankTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_blankPixel);
}

const _stops = [
  RouteStop(name: 'Purok 1', latitude: 14.5995, longitude: 120.9842),
  RouteStop(name: 'Purok 2', latitude: 14.6010, longitude: 120.9860),
  RouteStop(name: 'Public market', latitude: 14.6030, longitude: 120.9880),
];

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 340, height: 220, child: child),
        ),
      ),
    );

void main() {
  group('RouteStop parsing', () {
    test('reads map entries with coordinates', () {
      final stop = RouteStop.fromDynamic(
        {'name': 'Purok 3', 'lat': 14.6, 'lng': 120.9},
      );
      expect(stop.name, 'Purok 3');
      expect(stop.hasCoordinates, isTrue);
      expect(stop.latitude, 14.6);
    });

    test('keeps legacy string stops as name-only', () {
      final stop = RouteStop.fromDynamic('Purok 4');
      expect(stop.name, 'Purok 4');
      expect(stop.hasCoordinates, isFalse);
    });

    test('falls back to a placeholder for junk entries', () {
      expect(RouteStop.fromDynamic(42).name, 'Stop');
      expect(RouteStop.fromDynamic({'name': '  '}).name, 'Stop');
    });
  });

  group('RoutePlan stops', () {
    test('parses a plan written before map picking', () {
      final plan = RoutePlan.fromDoc('p1', {
        'driverId': 'd1',
        'driverName': 'Ana',
        'zone': 'Barangay San Isidro',
        'date': routeDateKey(DateTime.now()),
        'stops': ['Purok 1', 'Purok 2'],
      });

      expect(plan.stops.length, 2);
      expect(plan.stops.first.name, 'Purok 1');
      expect(plan.mappedStops, isEmpty);
      expect(plan.stopsLabel, '2 stops');
    });

    test('keeps only pinned stops for the map layer', () {
      final plan = RoutePlan.fromDoc('p2', {
        'stops': [
          {'name': 'Purok 1', 'lat': 14.5, 'lng': 120.9},
          {'name': 'Purok 2'},
          {'name': 'Market', 'lat': 14.6, 'lng': 121.0},
        ],
      });

      expect(plan.stops.length, 3);
      expect(plan.mappedStops.length, 2);
      expect(plan.stopsLabel, '3 stops');
    });

    test('round-trips stops through toMap', () {
      final plan = RoutePlan.fromDoc('p3', {
        'driverId': 'd1',
        'driverName': 'Ana',
        'zone': 'Z',
        'date': routeDateKey(DateTime.now()),
        'stops': [
          {'name': 'Purok 1', 'lat': 14.5, 'lng': 120.9},
        ],
      });

      final raw = plan.toMap()['stops'] as List;
      final again = RoutePlan.fromDoc('p3', {
        ...plan.toMap(),
        'stops': raw,
      });

      expect(again.stops.single.name, 'Purok 1');
      expect(again.stops.single.latitude, 14.5);
    });

    test('shift window allows a short early and late grace period', () {
      final day = DateTime.now();
      final plan = RoutePlan.fromDoc('p4', {
        'date': routeDateKey(day),
        'windowStart': '06:00',
        'windowEnd': '10:00',
      });

      expect(plan.isOpenAt(DateTime(day.year, day.month, day.day, 5, 30)),
          isTrue);
      expect(plan.isOpenAt(DateTime(day.year, day.month, day.day, 5, 0)),
          isFalse);
      expect(plan.isOpenAt(DateTime(day.year, day.month, day.day, 10, 45)),
          isTrue);
      expect(plan.isOpenAt(DateTime(day.year, day.month, day.day, 12, 0)),
          isFalse);
    });
  });

  group('RoutePreviewMap', () {
    testWidgets('draws one numbered pin per stop plus the path', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoutePreviewMap(stops: _stops, tileProvider: _BlankTileProvider()),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('adds the truck marker when a position is supplied',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoutePreviewMap(
            stops: _stops,
            truck: const LatLng(14.6000, 120.9850),
            tileProvider: _BlankTileProvider(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
    });

    testWidgets('shows an empty state when no stop has coordinates',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RoutePreviewMap(
            stops: [RouteStop(name: 'Purok 1')],
            tileProvider: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No stops pinned yet'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('golden: three stops and the truck', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoutePreviewMap(
            stops: _stops,
            truck: const LatLng(14.6000, 120.9850),
            tileProvider: _BlankTileProvider(),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(RoutePreviewMap),
        matchesGoldenFile('goldens/route_preview.png'),
      );
    });
  });
}
