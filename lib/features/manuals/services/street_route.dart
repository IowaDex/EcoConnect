import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// The line between two consecutive areas.
///
/// When [followsStreets] is true the points are the streets a truck can drive.
/// When it is false the two areas have no sensible through route in the map
/// data — a gated pocket, a one-way loop — and the map draws a dashed
/// connector instead of a multi-kilometre detour.
class RouteLeg {
  const RouteLeg({required this.points, required this.followsStreets});

  final List<LatLng> points;
  final bool followsStreets;
}

/// A run through the picked areas, one leg per hop.
class StreetRoute {
  const StreetRoute({required this.legs});

  final List<RouteLeg> legs;

  /// True when every hop follows a real street.
  bool get followsStreets => legs.every((leg) => leg.followsStreets);
}

/// Turns an ordered list of area pins into a driving line along the streets.
///
/// The app has no routing engine of its own, so this asks the public OSRM
/// server — the same OpenStreetMap data the tiles come from. It is a demo
/// endpoint with a light rate limit, which is why every answer is cached for
/// the session: moving a marker back and forth must not re-ask the server.
class StreetRoutePlanner {
  StreetRoutePlanner({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// One entry per distinct set of pins, so a rebuild never repeats a request.
  final Map<String, Future<StreetRoute>> _cache = {};

  Future<StreetRoute> route(List<LatLng> pins) {
    if (pins.length < 2) {
      return Future.value(const StreetRoute(legs: []));
    }
    final key = [for (final pin in pins) _pinKey(pin)].join(';');
    return _cache.putIfAbsent(key, () => _fetch(pins));
  }

  Future<StreetRoute> _fetch(List<LatLng> pins) async {
    try {
      final response = await _client
          .get(Uri.parse(osrmUrl(pins)))
          .timeout(timeout);
      if (response.statusCode != 200) return straightRoute(pins);
      return parseOsrmRoute(response.body, pins: pins);
    } catch (_) {
      // Offline, blocked, or the demo server is having a bad day: the officer
      // still sees the order of the areas, just not the streets between them.
      return straightRoute(pins);
    }
  }

  static String _pinKey(LatLng pin) =>
      '${pin.latitude.toStringAsFixed(5)},${pin.longitude.toStringAsFixed(5)}';
}

/// The shared planner, so a route fetched by one card is reused by the next.
final StreetRoutePlanner streetRoutePlanner = StreetRoutePlanner();

/// A hop the router may detour: no more than 2.5x the straight distance, and
/// never more than this even when the pins are close together.
const double kMaxLegMeters = 1200;

/// Straight connectors between consecutive pins, one leg per hop.
StreetRoute straightRoute(List<LatLng> pins) => StreetRoute(
  legs: [
    for (var i = 0; i + 1 < pins.length; i++)
      RouteLeg(points: [pins[i], pins[i + 1]], followsStreets: false),
  ],
);

/// The OSRM request for one ordered run: `lon,lat;lon,lat;…`.
///
/// `overview=full` returns the whole street-following line rather than a
/// simplified handful of points, which is what makes the line hug the roads
/// at street zoom.
@visibleForTesting
String osrmUrl(List<LatLng> pins) {
  final path = [
    for (final pin in pins)
      '${pin.longitude.toStringAsFixed(5)},${pin.latitude.toStringAsFixed(5)}',
  ].join(';');
  return 'https://router.project-osrm.org/route/v1/driving/$path'
      '?overview=full&geometries=geojson&steps=false';
}

/// Reads the driving line out of an OSRM answer and cuts it at the waypoints.
///
/// A leg whose driving distance is far longer than the gap between its pins is
/// not a route the officer wants to see — the map data has no through street
/// there — so that hop comes back as a straight connector. Falls back to a
/// straight run when the body is an error.
@visibleForTesting
StreetRoute parseOsrmRoute(String body, {required List<LatLng> pins}) {
  final fallback = straightRoute(pins);
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return fallback;
    if (decoded['code'] != 'Ok') return fallback;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return fallback;
    final route = routes.first;
    if (route is! Map) return fallback;
    final geometry = route['geometry'];
    if (geometry is! Map) return fallback;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return fallback;

    final path = <LatLng>[];
    for (final pair in coordinates) {
      if (pair is! List || pair.length < 2) continue;
      final lon = pair[0];
      final lat = pair[1];
      if (lon is! num || lat is! num) continue;
      path.add(LatLng(lat.toDouble(), lon.toDouble()));
    }
    if (path.length < 2) return fallback;

    final waypoints = decoded['waypoints'];
    final legs = route['legs'];
    if (waypoints is! List ||
        waypoints.length != pins.length ||
        legs is! List ||
        legs.length != pins.length - 1) {
      // No leg breakdown: trust the whole line.
      return StreetRoute(
        legs: [RouteLeg(points: path, followsStreets: true)],
      );
    }

    final snapped = <LatLng>[];
    for (final waypoint in waypoints) {
      final location = waypoint is Map ? waypoint['location'] : null;
      if (location is! List || location.length < 2) return fallback;
      final lon = location[0];
      final lat = location[1];
      if (lon is! num || lat is! num) return fallback;
      snapped.add(LatLng(lat.toDouble(), lon.toDouble()));
    }

    // Where the run passes each waypoint, in order.
    final cuts = <int>[0];
    var cursor = 0;
    for (var i = 1; i + 1 < snapped.length; i++) {
      final index = _nearestIndex(path, snapped[i], from: cursor);
      cuts.add(index);
      cursor = index;
    }
    cuts.add(path.length - 1);

    final out = <RouteLeg>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final distance = leg is Map ? (leg['distance'] as num?)?.toDouble() : null;
      final start = cuts[i];
      final end = cuts[i + 1];
      final usable =
          distance != null &&
          end > start &&
          _plausible(distance, snapped[i], snapped[i + 1]);
      out.add(
        usable
            ? RouteLeg(points: path.sublist(start, end + 1), followsStreets: true)
            : RouteLeg(points: [pins[i], pins[i + 1]], followsStreets: false),
      );
    }
    return StreetRoute(legs: out);
  } catch (_) {
    return fallback;
  }
}

/// Whether a driving leg is a real short hop or a detour around a wall.
bool _plausible(double meters, LatLng from, LatLng to) {
  final straight = const Distance().as(LengthUnit.Meter, from, to);
  return meters <= math.max(kMaxLegMeters, straight * 2.5);
}

int _nearestIndex(List<LatLng> path, LatLng target, {required int from}) {
  var best = from;
  var bestDistance = double.infinity;
  for (var i = from; i < path.length; i++) {
    final d = const Distance().as(LengthUnit.Meter, path[i], target);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}
