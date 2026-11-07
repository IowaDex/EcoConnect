import 'package:latlong2/latlong.dart';

String _distanceLabel(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String _durationLabel(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? '$hours h'
      : '$hours h ${rest.toString().padLeft(2, '0')}';
}

/// One leg of a driving route: the drive between two consecutive waypoints.
class RouteLeg {
  const RouteLeg({required this.distanceMeters, required this.durationSeconds});

  final double distanceMeters;
  final double durationSeconds;

  String get distanceLabel => _distanceLabel(distanceMeters);

  String get durationLabel => _durationLabel(durationSeconds);
}

/// A road-following route between waypoints, as returned by the routing
/// service. [polyline] already follows streets, so it can be drawn directly.
class RouteDirections {
  const RouteDirections({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.legs,
  });

  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteLeg> legs;

  bool get isEmpty => polyline.isEmpty;

  String get distanceLabel => _distanceLabel(distanceMeters);

  String get durationLabel => _durationLabel(durationSeconds);
}
