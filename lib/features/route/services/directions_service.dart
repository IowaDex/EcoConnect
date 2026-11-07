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

  Future<RouteDirections?> drivingRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    final coords = waypoints
        .map((point) =>
            '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}')
        .join(';');
    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=false&alternatives=false',
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

      final legs = <RouteLeg>[
        for (final leg in (route['legs'] as List? ?? const []))
          if (leg is Map)
            RouteLeg(
              distanceMeters: (leg['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (leg['duration'] as num?)?.toDouble() ?? 0,
            ),
      ];

      return RouteDirections(
        polyline: polyline,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
        legs: legs,
      );
    } catch (_) {
      // Offline, rate limited or a malformed payload: the caller falls back.
      return null;
    }
  }
}
