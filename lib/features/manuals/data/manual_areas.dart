import 'package:latlong2/latlong.dart';

import '../../../core/constants/resident_areas.dart';

/// One subdivision, village or sitio a manual can send a truck through.
///
/// The name is what the manual prints and what the routes checklist shows.
/// [center] is the pin, and [route] is the pre-made loop the map draws when the
/// area is picked — Iswim never has to trace the streets by hand.
class ManualArea {
  const ManualArea({
    required this.name,
    required this.center,
    required this.shape,
  });

  final String name;
  final LatLng center;

  /// Varies the loop footprint so neighbouring areas do not overlap exactly.
  final int shape;

  /// The pre-made loop for this area. It is a small block around [center],
  /// which is enough for the desk to see which streets a truck will cover.
  List<LatLng> get route {
    final dLat = 0.0008 + (shape % 3) * 0.00012;
    final dLng = 0.0010 + (shape % 4) * 0.00018;
    return [
      LatLng(center.latitude - dLat, center.longitude - dLng * 0.45),
      LatLng(center.latitude - dLat * 0.55, center.longitude + dLng),
      LatLng(center.latitude + dLat, center.longitude + dLng * 0.72),
      LatLng(center.latitude + dLat * 0.62, center.longitude - dLng),
      LatLng(center.latitude - dLat, center.longitude - dLng * 0.45),
    ];
  }
}

/// Pins for the barangay's areas, laid out roughly south-west to north-east.
///
/// The list follows [ResidentAreas.all] so the sign-up picker and the manual
/// desk always speak about the same places. Coordinates sit inside Batasan
/// Hills; the loops are demo footprints, not surveyed street centrelines.
final List<ManualArea> kManualAreas = _buildAreas();

const List<LatLng> _centers = [
  // Row 1
  LatLng(14.6715, 121.0865),
  LatLng(14.6715, 121.0915),
  LatLng(14.6715, 121.0965),
  LatLng(14.6715, 121.1015),
  LatLng(14.6715, 121.1065),
  LatLng(14.6715, 121.1100),
  // Row 2
  LatLng(14.6757, 121.0865),
  LatLng(14.6757, 121.0915),
  LatLng(14.6757, 121.0965),
  LatLng(14.6757, 121.1015),
  LatLng(14.6757, 121.1065),
  LatLng(14.6757, 121.1100),
  // Row 3
  LatLng(14.6799, 121.0865),
  LatLng(14.6799, 121.0915),
  LatLng(14.6799, 121.0965),
  LatLng(14.6799, 121.1015),
  LatLng(14.6799, 121.1065),
  LatLng(14.6799, 121.1100),
  // Row 4
  LatLng(14.6841, 121.0865),
  LatLng(14.6841, 121.0915),
  LatLng(14.6841, 121.0965),
  LatLng(14.6841, 121.1015),
  LatLng(14.6841, 121.1065),
  LatLng(14.6841, 121.1100),
  // Row 5
  LatLng(14.6883, 121.0865),
  LatLng(14.6883, 121.0915),
  LatLng(14.6883, 121.0965),
  LatLng(14.6883, 121.1015),
  LatLng(14.6883, 121.1065),
  LatLng(14.6883, 121.1100),
  // Row 6
  LatLng(14.6925, 121.0865),
  LatLng(14.6925, 121.0915),
  LatLng(14.6925, 121.0965),
  LatLng(14.6925, 121.1015),
  LatLng(14.6925, 121.1065),
  LatLng(14.6925, 121.1100),
  // Row 7
  LatLng(14.6958, 121.0965),
];

List<ManualArea> _buildAreas() {
  final names = [
    for (final name in ResidentAreas.all)
      if (!ResidentAreas.isOther(name)) name,
  ];
  assert(
    names.length <= _centers.length,
    'Every resident area needs a map pin before it can be scheduled.',
  );
  return List<ManualArea>.unmodifiable([
    for (var i = 0; i < names.length && i < _centers.length; i++)
      ManualArea(name: names[i], center: _centers[i], shape: i),
  ]);
}

/// The area with this name, or null when the record holds an older free-text
/// route that is not one of the barangay's listed areas.
ManualArea? manualAreaByName(String name) {
  final needle = name.trim().toLowerCase();
  for (final area in kManualAreas) {
    if (area.name.toLowerCase() == needle) return area;
  }
  return null;
}

/// The areas behind a list of names, in the order the names were given.
List<ManualArea> manualAreasFor(Iterable<String> names) => [
  for (final name in names)
    if (manualAreaByName(name) case final area?) area,
];

/// One continuous path through the picked areas: each area's loop joined to
/// the next, so the map reads as a single collection run.
List<LatLng> manualRouteForAreas(Iterable<ManualArea> areas) {
  final points = <LatLng>[];
  for (final area in areas) {
    points.addAll(area.route);
  }
  return points;
}
