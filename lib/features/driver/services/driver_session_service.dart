import 'package:cloud_firestore/cloud_firestore.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

/// Why the driver's device stopped reporting a position.
///
/// The distinction matters: a disabled GPS toggle, a denied permission and a
/// dropped connection look identical on the map but need different wording so
/// a driver is never accused of switching tracking off on purpose.
enum DriverLocationState { ok, disabled, permission, offline, unknown }

extension DriverLocationStateX on DriverLocationState {
  String get wireName => switch (this) {
        DriverLocationState.ok => 'ok',
        DriverLocationState.disabled => 'disabled',
        DriverLocationState.permission => 'permission',
        DriverLocationState.offline => 'offline',
        DriverLocationState.unknown => 'unknown',
      };

  String get label => switch (this) {
        DriverLocationState.ok => 'Location active',
        DriverLocationState.disabled => 'GPS turned off',
        DriverLocationState.permission => 'Location permission needed',
        DriverLocationState.offline => 'No internet connection',
        DriverLocationState.unknown => 'Location unavailable',
      };

  /// Neutral wording for staff: states what the device reported, never intent.
  String get staffMessage => switch (this) {
        DriverLocationState.ok => 'Driver location is updating.',
        DriverLocationState.disabled =>
          'The driver\'s device location is turned off. Tracking will resume when it is enabled.',
        DriverLocationState.permission =>
          'The app cannot access the driver\'s location because permission was not granted.',
        DriverLocationState.offline =>
          'The driver appears to be offline. The last known position is shown.',
        DriverLocationState.unknown =>
          'The driver\'s location is unavailable. The last known position is shown.',
      };

  bool get needsAttention => this != DriverLocationState.ok;

  static DriverLocationState fromWire(String? value) {
    return DriverLocationState.values.firstWhere(
      (s) => s.wireName == value,
      orElse: () => DriverLocationState.unknown,
    );
  }
}

/// Publishes location-health changes on the driver's live route document and
/// raises a staff notification the first time a problem appears.
class DriverSessionService {
  static final DriverSessionService _instance = DriverSessionService._internal();
  factory DriverSessionService() => _instance;
  DriverSessionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  Future<void> reportLocationState({
    required String driverId,
    required String driverName,
    required DriverLocationState state,
    double? lastLatitude,
    double? lastLongitude,
    bool notifyStaff = false,
  }) async {
    await _db.collection('routes').doc(driverId).set({
      'locationState': state.wireName,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      if (lastLatitude != null) 'lastKnownLat': lastLatitude,
      if (lastLongitude != null) 'lastKnownLng': lastLongitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (notifyStaff && state.needsAttention) {
      await _notifications.notifyStaff(
        title: 'Driver location unavailable',
        body: '$driverName: ${state.staffMessage}',
        type: AppNotificationType.route,
        data: {'driverId': driverId, 'state': state.wireName},
      );
    }
  }
}
