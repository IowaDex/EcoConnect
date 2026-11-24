import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// No device call may hang the app. A browser prompt the crew never answers
  /// leaves the platform future pending forever, which used to keep the driver
  /// dashboard waiting before it drew anything.
  static const _platformTimeout = Duration(seconds: 6);

  // Location stream for real-time updates; skips fixes under 20 m apart.
  // With [background] the stream keeps running while the app is minimised or
  // the screen is off: an Android foreground service (with its ongoing
  // notification) or the iOS background-location mode.
  Stream<Position> positionStream({bool background = false}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(background),
    );
  }

  LocationSettings _settings(bool background) {
    if (!background || kIsWeb) {
      return const LocationSettings(distanceFilter: 20);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          distanceFilter: 20,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'EcoConnect collection run',
            notificationText:
                'Your truck location is shared with residents until the run ends.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 20,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(distanceFilter: 20);
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    // A platform that cannot answer is treated as enabled: the permission and
    // fix checks below still catch a genuinely disabled GPS.
    return await Geolocator.isLocationServiceEnabled().timeout(
      _platformTimeout,
      onTimeout: () => true,
    );
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermissions() async {
    return await Geolocator.checkPermission().timeout(
      _platformTimeout,
      onTimeout: () => LocationPermission.denied,
    );
  }

  /// Request location permissions
  Future<LocationPermission> requestPermissions() async {
    // First check if location permission is granted
    LocationPermission permission = await checkPermissions();

    if (permission == LocationPermission.denied) {
      if (kIsWeb) {
        // The browser raises its own prompt on the first position request, and
        // geolocator's requestPermission() calls that same request with no
        // time limit — so every failure, a slow fix included, comes back as
        // "permanently denied". Let the position request do the asking; a
        // timeout then stays a timeout instead of a lie about the permission.
        return LocationPermission.whileInUse;
      }
      // An unanswered prompt resolves as "denied" after the timeout instead of
      // holding the caller for the rest of the session.
      permission = await Geolocator.requestPermission().timeout(
        _platformTimeout,
        onTimeout: () => LocationPermission.denied,
      );
    }

    return permission;
  }

  /// The last failure from a position attempt, kept so the caller can say why
  /// the fix did not arrive.
  String? _lastFixError;

  /// Get the current position, falling back to a coarse fix.
  ///
  /// A desktop browser has no GPS: it guesses from Wi-Fi and IP, and a
  /// high-accuracy request can burn the whole time limit and still give up —
  /// the browser reports it as `TimeoutException: Timeout expired`. When that
  /// happens we ask again with low accuracy, which resolves in a second or two
  /// and is close enough to drop the pin on the barangay map.
  Future<Position> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // Check and request permissions
      LocationPermission permission = await checkPermissions();

      if (permission == LocationPermission.denied) {
        permission = await requestPermissions();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. '
          'Please enable them in device settings.',
        );
      }

      // A cached fix from the platform is the fastest answer when it exists.
      final lastKnown = await getLastKnownPosition();

      final fix =
          await _attemptFix(LocationAccuracy.best, _fixLimit) ??
          await _attemptFix(LocationAccuracy.low, _fixLimit);

      if (fix != null) {
        _lastFixError = null;
        return fix;
      }
      if (lastKnown != null) return lastKnown;
      throw Exception(_lastFixError ?? 'Could not get your location.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get current location: $e');
    }
  }

  static const _fixLimit = Duration(seconds: 14);

  /// One position attempt. Returns null instead of throwing so the caller can
  /// try a coarser accuracy, and remembers why it failed.
  Future<Position?> _attemptFix(
    LocationAccuracy accuracy,
    Duration limit,
  ) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: limit,
        forceAndroidLocationManager: true,
      ).timeout(limit + const Duration(seconds: 4));
    } catch (error) {
      _lastFixError = _readableError(error);
      return null;
    }
  }

  /// Turns a platform error into a line a resident can act on.
  String _readableError(Object error) {
    final text = error.toString();
    if (text.contains('Timeout expired') || text.contains('TimeoutException')) {
      return 'Your browser could not get a fix. Turn on Windows location '
          'services, or allow location for this site, then tap Retry.';
    }
    if (text.contains('PositionUpdateException') ||
        text.contains('position unavailable')) {
      return 'Your device has no location signal right now. Move near a '
          'window or turn on location services, then tap Retry.';
    }
    if (text.contains('PermissionDenied')) {
      return 'Location is blocked for this site. Allow it in the browser '
          'address bar, then tap Retry.';
    }
    return 'Could not get your location. Please try again.';
  }

  /// Start listening to location updates (real-time)
  Stream<Position> startLocationUpdates({bool background = false}) =>
      positionStream(background: background);

  /// Get the last known location (faster but may be stale)
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition().timeout(
        _platformTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      // The web build has no last-known cache and the platform call throws
      // UnsupportedError. This is only a shortcut to a faster first fix, so a
      // missing cache must never fail the whole lookup — that is what left the
      // tracking map stuck on "Locating your position…".
      return null;
    }
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings().timeout(
      _platformTimeout,
      onTimeout: () => false,
    );
  }

  /// Open app settings for permission management
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings().timeout(
      _platformTimeout,
      onTimeout: () => false,
    );
  }
}
