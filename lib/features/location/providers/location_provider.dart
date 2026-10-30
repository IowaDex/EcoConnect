import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_sync_state.dart';
import '../models/shared_location.dart';
import '../repositories/location_repository.dart';
import '../services/location_service.dart';
import '../../../core/utils/app_logger.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final LocationRepository _locationRepository;

  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Object?>? _connectivitySubscription;
  LocationSyncState _syncState = LocationSyncState.synced;
  int _pendingCount = 0;
  bool _isSyncing = false;
  Future<void> _locationOperation = Future<void>.value();
  bool _isSharingLocation = false;
  StreamSubscription<List<SharedLocation>>? _sharedLocationsSubscription;
  List<SharedLocation> _sharedLocations = const [];
  StreamSubscription<String?>? _authSubscription;
  // Seeded so the stream's first event (the same user) isn't seen as a change.
  late String? _userId;

  /// The arguments exist so tests can swap in fakes; the app uses the defaults.
  LocationProvider({
    LocationRepository? repository,
    LocationService? service,
    Stream<Object?>? connectivityChanges,
  })  : _locationRepository = repository ?? LocationRepository(),
        _locationService = service ?? LocationService() {
    _connectivitySubscription =
        (connectivityChanges ?? Connectivity().onConnectivityChanged)
            .listen((_) => syncPending());
    _userId = _locationRepository.currentUserId;
    _authSubscription =
        _locationRepository.userIdChanges.listen(_onUserChanged);
  }

  // Nothing from the previous account may carry over to the next one.
  void _onUserChanged(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    stopTracking();
    _sharedLocationsSubscription?.cancel();
    _sharedLocationsSubscription = null;
    _sharedLocations = const [];
    _isSharingLocation = false;
    _currentPosition = null;
    _locationRepository.reset();
    notifyListeners();
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
    // Show the change right away; offline, Firestore only confirms on reconnect.
    _isSharingLocation = enabled;
    notifyListeners();
    try {
      final sent = await _locationRepository.setSharingEnabled(enabled);
      if (!sent) {
        _error = 'You are offline. Your location will be hidden as soon as '
            'you reconnect.';
      }
      if (enabled && _currentPosition != null) {
        await _locationRepository.publishSharedLocation(_currentPosition!);
      }
    } catch (error) {
      AppLogger.error('Updating location sharing failed', error);
      _error = enabled
          ? 'Could not share your location yet. It will update with your '
              'next location.'
          : 'Could not turn off sharing. Please try again.';
    }
    _isSharingLocation = _locationRepository.sharingEnabled;
    notifyListeners();
  }

  void startSharedLocationUpdates() {
    if (_sharedLocationsSubscription != null) return;
    _locationRepository.loadSharingEnabled().then((_) {
      _isSharingLocation = _locationRepository.sharingEnabled;
      notifyListeners();
    }, onError: (Object error) {
      AppLogger.error('Checking location sharing failed', error);
      _error = 'Could not check whether you are sharing your location.';
      notifyListeners();
    });
    _sharedLocationsSubscription =
        _locationRepository.watchSharedLocations().listen(
      (locations) {
        _sharedLocations = locations;
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
    unawaited(syncPending());
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

  /// Call before signing out. Stops tracking so no new shared position lands
  /// after the pin is deleted, then deletes it while still signed in.
  /// Returns false if the pin could not be removed (e.g. offline).
  Future<bool> endSession() async {
    stopTracking();
    _locationRepository.reset();
    return _locationRepository.removeSharedLocation();
  }

  Future<void> _saveAndSync(Position position) async {
    try {
      final saved = await _locationRepository.savePosition(position);
      if (!saved) return;
      _pendingCount = await _locationRepository.pendingCount();
      _syncState = LocationSyncState.pending;
      notifyListeners();
    } catch (error) {
      AppLogger.error('Saving location failed', error);
      _syncState = LocationSyncState.failed;
      _error = 'Could not save your location on this phone.';
      notifyListeners();
      return;
    }
    // Not awaited: offline these wait for the network indefinitely and must
    // not hold up saving the next position locally.
    unawaited(syncPending());
    unawaited(_publishShared(position));
  }

  Future<void> _publishShared(Position position) async {
    try {
      await _locationRepository.publishSharedLocation(position);
    } catch (error) {
      AppLogger.error('Updating shared location failed', error);
      _error = 'Could not update your shared location. It will retry with '
          'your next location.';
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
      _syncState = LocationRepository.isOfflineError(error)
          ? LocationSyncState.offline
          : LocationSyncState.failed;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
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
    _authSubscription?.cancel();
    super.dispose();
  }
}