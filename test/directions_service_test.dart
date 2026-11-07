import 'dart:convert';

import 'package:eco_connect/features/route/services/directions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DirectionsService', () {
    test('parses the road polyline, distance and legs', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/route/v1/driving/'));
        expect(request.url.queryParameters['geometries'], 'geojson');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 2400.0,
                'duration': 420.0,
                'geometry': {
                  'coordinates': [
                    [121.0, 14.6],
                    [121.001, 14.601],
                    [121.002, 14.602],
                  ],
                },
                'legs': [
                  {'distance': 1200.0, 'duration': 210.0},
                  {'distance': 1200.0, 'duration': 210.0},
                ],
              },
            ],
          }),
          200,
        );
      });

      final route = await DirectionsService(client: client).drivingRoute(const [
        LatLng(14.6, 121.0),
        LatLng(14.602, 121.002),
      ]);

      expect(route, isNotNull);
      expect(route!.polyline, hasLength(3));
      // OSRM returns longitude first; the model must swap to lat/lng.
      expect(route.polyline.first.latitude, 14.6);
      expect(route.polyline.first.longitude, 121.0);
      expect(route.legs, hasLength(2));
      expect(route.distanceLabel, '2.4 km');
      expect(route.durationLabel, '7 min');
    });

    test('does not call the server with a single waypoint', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      final route = await DirectionsService(client: client)
          .drivingRoute(const [LatLng(14.6, 121.0)]);

      expect(route, isNull);
      expect(called, isFalse);
    });

    test('returns null when no route exists', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'code': 'NoRoute'}), 200),
      );

      final route = await DirectionsService(client: client).drivingRoute(const [
        LatLng(14.6, 121.0),
        LatLng(14.7, 121.1),
      ]);

      expect(route, isNull);
    });

    test('returns null when the server rejects the request', () async {
      final client = MockClient(
        (_) async => http.Response('rate limited', 429),
      );

      final route = await DirectionsService(client: client).drivingRoute(const [
        LatLng(14.6, 121.0),
        LatLng(14.7, 121.1),
      ]);

      expect(route, isNull);
    });

    test('parses turn-by-turn steps with the stop name', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['steps'], 'true');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 1200.0,
                'duration': 300.0,
                'geometry': {
                  'coordinates': [
                    [121.0, 14.6],
                    [121.01, 14.61],
                  ],
                },
                'legs': [
                  {
                    'distance': 1200.0,
                    'duration': 300.0,
                    'steps': [
                      {
                        'maneuver': {'type': 'depart', 'modifier': ''},
                        'name': 'Mabini St',
                        'distance': 200.0,
                        'duration': 60.0,
                      },
                      {
                        'maneuver': {'type': 'turn', 'modifier': 'left'},
                        'name': 'Rizal Ave',
                        'distance': 800.0,
                        'duration': 200.0,
                      },
                      {
                        'maneuver': {'type': 'arrive', 'modifier': ''},
                        'name': '',
                        'distance': 0.0,
                        'duration': 0.0,
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          200,
        );
      });

      final route = await DirectionsService(client: client).drivingRoute(
        const [LatLng(14.6, 121.0), LatLng(14.61, 121.01)],
        stopNames: const ['Covered court'],
      );

      expect(route, isNotNull);
      expect(route!.steps, hasLength(3));
      expect(route.steps.first.instruction, 'Start on Mabini St');
      expect(route.steps[1].instruction, 'Turn left onto Rizal Ave');
      expect(route.steps.last.instruction, 'Arrive at Covered court');
      expect(route.steps.last.arrivesAtStop, isTrue);
      expect(route.steps[1].legIndex, 0);
    });

    test('end-of-road turns read as words, not raw code', () async {
      Future<String> instructionFor(String name) async {
        final client = MockClient((_) async => http.Response(
              jsonEncode({
                'code': 'Ok',
                'routes': [
                  {
                    'distance': 100.0,
                    'duration': 30.0,
                    'geometry': {
                      'coordinates': [
                        [121.0, 14.6],
                        [121.01, 14.61],
                      ],
                    },
                    'legs': [
                      {
                        'distance': 100.0,
                        'duration': 30.0,
                        'steps': [
                          {
                            'maneuver': {
                              'type': 'end of road',
                              'modifier': 'right',
                            },
                            'name': name,
                            'distance': 100.0,
                            'duration': 30.0,
                          },
                        ],
                      },
                    ],
                  },
                ],
              }),
              200,
            ));
        final route = await DirectionsService(client: client).drivingRoute(
          const [LatLng(14.6, 121.0), LatLng(14.61, 121.01)],
        );
        return route!.steps.single.instruction;
      }

      expect(await instructionFor('Rizal Ave'), 'Turn right onto Rizal Ave');
      expect(await instructionFor(''), 'Turn right at the end of the road');
    });

    test('returns null for a malformed body instead of throwing', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));

      final route = await DirectionsService(client: client).drivingRoute(const [
        LatLng(14.6, 121.0),
        LatLng(14.7, 121.1),
      ]);

      expect(route, isNull);
    });
  });
}
