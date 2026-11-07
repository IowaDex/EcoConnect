import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_directions.dart';

/// Road routing through the public OSRM demo server (OpenStreetMap data).
///
/// No API key is required, which keeps the capstone build self-contained. The
/// demo server is rate limited, so every failure is treated as "no road route"
/// and the map falls back to a straight-line preview instead of an error.
class DirectionsService {
  DirectionsService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://router.project-osrm.org';

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 12);

  /// [stopNames] labels each leg with the stop it ends at, so the arrival step
  /// reads "Arrive at Purok 3 covered court" instead of a generic message.
  Future<RouteDirections?> drivingRoute(
    List<LatLng> waypoints, {
    List<String> stopNames = const [],
  }) async {
    if (waypoints.length < 2) return null;

    final coords = waypoints
        .map((point) =>
            '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}')
        .join(';');
    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=true&alternatives=false',
    );

    try {
      final response = await _client.get(
        uri,
        headers: const {'User-Agent': 'com.example.ecoconnect'},
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['code'] != 'Ok') return null;

      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first;
      if (route is! Map<String, dynamic>) return null;

      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      if (coordinates is! List) return null;

      final polyline = <LatLng>[
        for (final pair in coordinates)
          if (pair is List && pair.length >= 2)
            LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ),
      ];
      if (polyline.length < 2) return null;

      final legs = <RouteLeg>[];
      final steps = <RouteStep>[];
      final rawLegs = route['legs'] as List? ?? const [];
      for (var legIndex = 0; legIndex < rawLegs.length; legIndex++) {
        final leg = rawLegs[legIndex];
        if (leg is! Map) continue;
        legs.add(
          RouteLeg(
            distanceMeters: (leg['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (leg['duration'] as num?)?.toDouble() ?? 0,
          ),
        );

        final stopName =
            legIndex < stopNames.length ? stopNames[legIndex] : null;
        final rawSteps = leg['steps'] as List? ?? const [];
        for (final rawStep in rawSteps) {
          if (rawStep is! Map) continue;
          final maneuver = rawStep['maneuver'];
          final type = maneuver is Map
              ? (maneuver['type'] as String? ?? 'turn')
              : 'turn';
          steps.add(
            RouteStep(
              instruction: _instruction(rawStep, stopName),
              maneuver: type,
              distanceMeters:
                  (rawStep['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds:
                  (rawStep['duration'] as num?)?.toDouble() ?? 0,
              legIndex: legIndex,
              arrivesAtStop: type == 'arrive',
            ),
          );
        }
      }

      return RouteDirections(
        polyline: polyline,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
        legs: legs,
        steps: steps,
      );
    } catch (_) {
      // Offline, rate limited or a malformed payload: the caller falls back.
      return null;
    }
  }

  static String _instruction(Map<dynamic, dynamic> step, String? stopName) {
    final maneuver = step['maneuver'];
    final type = maneuver is Map
        ? (maneuver['type'] as String? ?? 'turn')
        : 'turn';
    final modifier = maneuver is Map
        ? (maneuver['modifier'] as String? ?? '')
        : '';
    final rawName = (step['name'] as String?)?.trim();
    final road = rawName == null || rawName.isEmpty ? null : rawName;

    switch (type) {
      case 'depart':
        return road == null ? 'Start driving' : 'Start on $road';
      case 'arrive':
        if (stopName != null) return 'Arrive at $stopName';
        return 'Arrive at the stop';
      case 'turn':
        final direction = _turnWord(modifier);
        return road == null
            ? 'Turn $direction'
            : 'Turn $direction onto $road';
      case 'end of road':
        return road == null
            ? 'Turn $_turnWord(modifier) at the end of the road'
            : 'Turn $_turnWord(modifier) onto $road';
      case 'new name':
        return road == null ? 'Continue' : 'Continue onto $road';
      case 'merge':
        return road == null ? 'Merge' : 'Merge onto $road';
      case 'fork':
        final side = modifier.contains('left')
            ? 'left'
            : modifier.contains('right')
                ? 'right'
                : 'straight';
        return road == null
            ? 'Keep $side at the fork'
            : 'Keep $side onto $road';
      case 'roundabout':
      case 'rotary':
        return road == null
            ? 'Take the roundabout'
            : 'Take the roundabout onto $road';
      case 'on ramp':
        return road == null ? 'Take the ramp' : 'Take the ramp onto $road';
      case 'off ramp':
        return road == null ? 'Take the exit' : 'Take the exit onto $road';
      case 'continue':
        return road == null ? 'Continue straight' : 'Continue on $road';
      default:
        return road == null ? 'Continue' : 'Continue on $road';
    }
  }

  static String _turnWord(String modifier) {
    switch (modifier) {
      case 'slight left':
        return 'slightly left';
      case 'slight right':
        return 'slightly right';
      case 'sharp left':
        return 'sharp left';
      case 'sharp right':
        return 'sharp right';
      case 'uturn':
        return 'around';
      case 'left':
        return 'left';
      case 'right':
        return 'right';
      case 'straight':
        return 'straight';
      default:
        return 'ahead';
    }
  }
}
