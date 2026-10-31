import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;

  /// High accuracy settings used for both one-shot fixes and live updates.
  /// `distanceFilter: 0` means every GPS update is delivered, which is what
  /// the tracker and the driver broadcast need.
  static const LocationSettings _streamSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );

  /// Location stream for real-time updates
  Stream<Position> get positionStream =>
      Geolocator.getPositionStream(locationSettings: _streamSettings);

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermissions() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Resolves the device position.
  ///
  /// A fresh, high-accuracy fix is always preferred — a cached "last known"
  /// position can be hours old and would put the pin on the wrong street.
  /// The cached value is only used as a last resort when the device cannot
  /// produce a fix in time.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    var permission = await checkPermissions();
    if (permission == LocationPermission.denied) {
      permission = await requestPermissions();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. '
        'Please enable them in device settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 25),
      );
    } on TimeoutException {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) return cached;
      throw Exception(
        'Could not get a GPS fix. Move near a window or check that location '
        'is turned on.',
      );
    }
  }

  Stream<Position> startLocationUpdates() => positionStream;

  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  Future<Position?> getLastKnownPosition() =>
      Geolocator.getLastKnownPosition();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
