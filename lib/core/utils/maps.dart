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
