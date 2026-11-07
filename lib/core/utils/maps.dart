import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps turn-by-turn directions to a pinned location.
///
/// Returns false when no browser or maps app accepted the link, so callers can
/// show a message instead of failing silently.
Future<bool> openDirections(double latitude, double longitude) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

/// Opens a read-only pin in Google Maps, used when the driver just wants to
/// look at the location first.
Uri mapPinUri(double latitude, double longitude) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

/// Opens Google Maps driving directions that visit every stop in order, from
/// [origin] (usually the truck) to the last stop. Google accepts up to nine
/// waypoints, so longer runs are trimmed to the first nine stops.
Future<bool> openRouteDirections({
  required List<LatLng> stops,
  LatLng? origin,
}) async {
  if (stops.isEmpty) return false;

  final capped = stops.take(9).toList();
  final destination = capped.last;
  final waypoints = capped.length > 1
      ? capped.sublist(0, capped.length - 1)
      : const <LatLng>[];

  final query = StringBuffer('api=1&travelmode=driving');
  if (origin != null) {
    query.write('&origin=${origin.latitude},${origin.longitude}');
  }
  query.write('&destination=${destination.latitude},${destination.longitude}');
  if (waypoints.isNotEmpty) {
    query.write(
      '&waypoints=${waypoints.map((p) => '${p.latitude},${p.longitude}').join('|')}',
    );
  }

  final uri = Uri.parse('https://www.google.com/maps/dir/?$query');
  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
