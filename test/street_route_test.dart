import 'dart:convert';

import 'package:eco_connect/features/manuals/services/street_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const _a = LatLng(14.6715, 121.0865);
const _b = LatLng(14.6757, 121.0965);
const _c = LatLng(14.6799, 121.1015);

/// An OSRM answer with a street line and per-leg distances.
String _body({
  required List<List<double>> coordinates,
  required List<List<double>> waypoints,
  required List<double> legMeters,
}) => jsonEncode({
  'code': 'Ok',
  'waypoints': [
    for (final point in waypoints)
      {
        'location': point,
      },
  ],
  'routes': [
    {
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
      'legs': [
        for (final meters in legMeters) {'distance': meters},
      ],
    },
  ],
});

void main() {
  group('osrm request', () {
    test('sends lon,lat pairs in pick order with the full overview', () {
      final url = osrmUrl([_a, _b]);
      expect(
        url,
        startsWith(
          'https://router.project-osrm.org/route/v1/driving/'
          '121.08650,14.67150;121.09650,14.67570',
        ),
      );
      expect(url, contains('overview=full'));
      expect(url, contains('geometries=geojson'));
    });
  });

  group('osrm answer', () {
    test('cuts the line at each waypoint', () {
      final route = parseOsrmRoute(
        _body(
          coordinates: [
            [121.0865, 14.6715],
            [121.0880, 14.6725],
            [121.0900, 14.6740],
            [121.0965, 14.6757],
          ],
          waypoints: [
            [121.0865, 14.6715],
            [121.0900, 14.6740],
            [121.0965, 14.6757],
          ],
          legMeters: [420, 780],
        ),
        pins: [_a, _b, _c],
      );

      expect(route.legs, hasLength(2));
      expect(route.legs.every((leg) => leg.followsStreets), isTrue);
      expect(route.legs.first.points.first, _a);
      expect(route.legs.first.points.last, const LatLng(14.6740, 121.0900));
      expect(route.legs.last.points.last, const LatLng(14.6757, 121.0965));
    });

    test('a leg that loops around a wall becomes a straight connector', () {
      final route = parseOsrmRoute(
        _body(
          coordinates: [
            [121.0865, 14.6715],
            [121.1200, 14.6800],
            [121.0965, 14.6757],
          ],
          waypoints: [
            [121.0865, 14.6715],
            [121.0965, 14.6757],
          ],
          legMeters: [12800],
        ),
        pins: [_a, _b],
      );

      expect(route.legs, hasLength(1));
      expect(route.legs.single.followsStreets, isFalse);
      expect(route.legs.single.points, [_a, _b]);
    });

    test('an error answer is a straight run, so the caller can draw it', () {
      final route = parseOsrmRoute('{"code":"NoRoute"}', pins: [_a, _b, _c]);
      expect(route.legs, hasLength(2));
      expect(route.followsStreets, isFalse);
      expect(route.legs.first.points, [_a, _b]);
    });
  });

  group('route planner', () {
    test('draws the streets the server returned', () async {
      final planner = StreetRoutePlanner(
        client: MockClient(
          (_) async => http.Response(
            _body(
              coordinates: [
                [121.0865, 14.6715],
                [121.0900, 14.6740],
                [121.0965, 14.6757],
              ],
              waypoints: [
                [121.0865, 14.6715],
                [121.0965, 14.6757],
              ],
              legMeters: [520],
            ),
            200,
          ),
        ),
      );

      final route = await planner.route([_a, _b]);
      expect(route.followsStreets, isTrue);
      expect(route.legs.single.points, hasLength(3));
      // A street line bends; a straight leg would keep the midpoint on the
      // line between the two pins.
      expect(route.legs.single.points[1].longitude, isNot(closeTo(121.0915, 1e-4)));
    });

    test('falls back to the pins when the server cannot be reached', () async {
      final planner = StreetRoutePlanner(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      final route = await planner.route([_a, _b]);
      expect(route.followsStreets, isFalse);
      expect(route.legs.single.points, [_a, _b]);
    });

    test('asks once per set of pins', () async {
      var calls = 0;
      final planner = StreetRoutePlanner(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            _body(
              coordinates: [
                [121.0865, 14.6715],
                [121.0965, 14.6757],
              ],
              waypoints: [
                [121.0865, 14.6715],
                [121.0965, 14.6757],
              ],
              legMeters: [500],
            ),
            200,
          );
        }),
      );

      await planner.route([_a, _b]);
      await planner.route([_a, _b]);
      expect(calls, 1);
    });

    test('a single pin needs no request', () async {
      var calls = 0;
      final planner = StreetRoutePlanner(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      final route = await planner.route([_a]);
      expect(calls, 0);
      expect(route.legs, isEmpty);
    });
  });
}
