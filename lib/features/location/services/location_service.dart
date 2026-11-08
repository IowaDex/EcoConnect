import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
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
    if (!background || kIsWeb) return const LocationSettings(distanceFilter: 20);
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
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermissions() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  Future<LocationPermission> requestPermissions() async {
    // First check if location permission is granted
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Get current position with timeout and fallback
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

      // Try to get last known position first (faster)
      final lastKnown = await getLastKnownPosition();
      if (lastKnown != null) {
        // Also fetch fresh position in background
        try {
          return await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 10),
            forceAndroidLocationManager: true,
          ).timeout(
            const Duration(seconds: 12),
            onTimeout: () => lastKnown,
          );
        } catch (e) {
          return lastKnown;
        }
      }

      // If no last known position, get current with timeout
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: true,
      ).timeout(
        const Duration(seconds: 17),
        onTimeout: () => throw Exception('Location request timed out'),
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get current location: $e');
    }
  }

  /// Start listening to location updates (real-time)
  Stream<Position> startLocationUpdates({bool background = false}) =>
      positionStream(background: background);

  /// Get the last known location (faster but may be stale)
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings for permission management
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}