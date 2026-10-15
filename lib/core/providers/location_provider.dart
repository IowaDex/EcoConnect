import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTracking => _isTracking;

  // Convenience getters
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  bool get hasLocation => _currentPosition != null;

  String get locationString {
    if (_currentPosition == null) return 'No location';
    return '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  Future<bool> getCurrentLocation() async {
    _setLoading(true);
    _clearError();

    try {
      _currentPosition = await _locationService.getCurrentPosition();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;
    notifyListeners();

    _positionSubscription = _locationService.startLocationUpdates().listen(
      (Position position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        _setError(error.toString());
        stopTracking();
      },
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<bool> openLocationSettings() async {
    return await _locationService.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return await _locationService.openAppSettings();
  }

  Future<LocationPermission> checkPermissions() async {
    return await _locationService.checkPermissions();
  }

  Future<LocationPermission> requestPermissions() async {
    return await _locationService.requestPermissions();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}