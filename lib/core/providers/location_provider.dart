import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shared_location.dart';
import '../repositories/location_repository.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final LocationRepository _locationRepository = LocationRepository();

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  LocationSyncState _syncState = LocationSyncState.synced;
  int _pendingCount = 0;
  bool _isSyncing = false;
  Future<void> _locationOperation = Future<void>.value();
  bool _isSharingLocation = false;
  StreamSubscription<List<SharedLocation>>? _sharedLocationsSubscription;
  List<SharedLocation> _sharedLocations = const [];

  LocationProvider() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) => syncPending());
  }

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTracking => _isTracking;
  LocationSyncState get syncState => _syncState;
  int get pendingCount => _pendingCount;
  bool get isSharingLocation => _isSharingLocation;
  List<SharedLocation> get sharedLocations => _sharedLocations;

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
      await _queueLocationOperation(_currentPosition!);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> setSharingLocation(bool enabled) async {
    try {
      await _locationRepository.setSharingEnabled(enabled);
      _isSharingLocation = enabled;
      if (enabled && _currentPosition != null) {
        await _locationRepository.publishSharedLocation(_currentPosition!);
      }
      notifyListeners();
    } catch (error) {
      _error = 'Unable to update location sharing: $error';
      notifyListeners();
    }
  }

  void startSharedLocationUpdates() {
    _sharedLocationsSubscription ??=
        _locationRepository.watchSharedLocations().listen(
      (locations) {
        _sharedLocations = locations;
        final currentUserId = _locationRepository.currentUserId;
        _isSharingLocation =
            locations.any((location) => location.userId == currentUserId);
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'Unable to load shared locations: $error';
        notifyListeners();
      },
    );
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final permission = await _locationService.requestPermissions();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setError('Location permission is required for tracking.');
      return;
    }

    _isTracking = true;
    await syncPending();
    notifyListeners();

    _positionSubscription = _locationService.startLocationUpdates().listen(
      (Position position) {
        _currentPosition = position;
        _queueLocationOperation(position);
        notifyListeners();
      },
      onError: (error) {
        _setError(error.toString());
        stopTracking();
      },
    );
  }

  Future<void> _queueLocationOperation(Position position) {
    final operation = _locationOperation.then((_) => _saveAndSync(position));
    _locationOperation = operation.catchError((_) {});
    return operation;
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<void> _saveAndSync(Position position) async {
    try {
      final saved = await _locationRepository.savePosition(position);
      if (!saved) return;
      _pendingCount = await _locationRepository.pendingCount();
      _syncState = LocationSyncState.pending;
      notifyListeners();
      await syncPending();
      await _locationRepository.publishSharedLocation(position);
    } catch (error) {
      _syncState = LocationSyncState.failed;
      _error = 'Location sync failed. It will retry automatically.';
      notifyListeners();
    }
  }

  Future<void> syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncState = LocationSyncState.syncing;
    notifyListeners();
    try {
      await _locationRepository.syncPending();
      _pendingCount = await _locationRepository.pendingCount();
      _syncState = _pendingCount == 0
          ? LocationSyncState.synced
          : LocationSyncState.pending;
    } catch (error) {
      _pendingCount = await _locationRepository.pendingCount();
      _syncState = _isOfflineError(error)
          ? LocationSyncState.offline
          : LocationSyncState.failed;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

  }

  bool _isOfflineError(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed';
    }
    return false;
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
    _connectivitySubscription?.cancel();
    _sharedLocationsSubscription?.cancel();
    super.dispose();
  }
}