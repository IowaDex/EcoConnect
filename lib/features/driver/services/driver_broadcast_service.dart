import 'package:latlong2/latlong.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

/// Which proximity message a resident should receive.
enum BroadcastStage { approaching, arrived, passed }

/// Tells a resident when the truck is near them.
///
/// This runs on the resident's own phone: it compares the truck's live position
/// (public, from the driver's route) with the resident's own position and
/// notifies only that resident. The resident's location is never uploaded or
/// read by anyone else.
class DriverBroadcastService {
  DriverBroadcastService._();
  static final DriverBroadcastService instance = DriverBroadcastService._();

  factory DriverBroadcastService() => instance;

  static const double approachingMeters = 700;
  static const double arrivedMeters = 150;

  /// The resident counts as "passed" once the truck is this many times the
  /// approach distance away.
  static const double passedFactor = 1.5;

  /// How long before the same resident can be told the same thing again.
  static const Duration _cooldown = Duration(minutes: 10);

  final NotificationService _notifications = NotificationService();
  final Distance _distance = const Distance();

  /// Previous truck distance per resident, used to detect a pass.
  final Map<String, double> _lastDistance = {};
  final Map<String, DateTime> _lastSent = {};

  /// Sends [residentId] a notification when the truck at [truck] is close to
  /// [resident]. Returns whether one was written.
  Future<bool> alertResident({
    required String residentId,
    required String driverId,
    required String driverName,
    required LatLng truck,
    required LatLng resident,
  }) async {
    final metres = _distance.as(LengthUnit.Meter, truck, resident);
    final previous = _lastDistance[residentId];
    _lastDistance[residentId] = metres;

    final stage = stageFor(metres: metres, previous: previous);
    if (stage == null || !_maySend(residentId, stage)) return false;

    final body = switch (stage) {
      BroadcastStage.approaching =>
        '$driverName is about ${_rounded(metres)} m from you. '
            'Please have your waste ready.',
      BroadcastStage.arrived =>
        '$driverName has arrived. The collection truck is in your area now.',
      BroadcastStage.passed =>
        '$driverName has passed your area. If you missed the truck, submit a '
            'new collection request.',
    };

    // Marked before sending so an overlapping call cannot double-notify;
    // undone below if the write fails, so the resident is retried.
    final key = _key(residentId, stage);
    final previousSent = _lastSent[key];
    _lastSent[key] = DateTime.now();
    final ok = await _notifications.push(
      userId: residentId,
      title: switch (stage) {
        BroadcastStage.approaching => 'Truck approaching',
        BroadcastStage.arrived => 'Truck is in your area',
        BroadcastStage.passed => 'Truck passed your area',
      },
      body: body,
      type: AppNotificationType.route,
      data: {'driverId': driverId, 'stage': stage.name},
    );
    if (!ok) {
      if (previousSent == null) {
        _lastSent.remove(key);
      } else {
        _lastSent[key] = previousSent;
      }
    }
    return ok;
  }

  /// Pure proximity rule, exposed so it can be unit tested without Firestore.
  static BroadcastStage? stageFor({
    required double metres,
    required double? previous,
  }) {
    if (metres <= arrivedMeters) return BroadcastStage.arrived;
    if (metres <= approachingMeters) return BroadcastStage.approaching;
    // Was close a moment ago and is now well away: the truck went past.
    if (previous != null &&
        previous <= approachingMeters &&
        metres > approachingMeters * passedFactor) {
      return BroadcastStage.passed;
    }
    return null;
  }

  bool _maySend(String userId, BroadcastStage stage) {
    final last = _lastSent[_key(userId, stage)];
    if (last == null) return true;
    return DateTime.now().difference(last) > _cooldown;
  }

  static String _key(String userId, BroadcastStage stage) =>
      '$userId:${stage.name}';

  static int _rounded(double metres) =>
      metres >= 100 ? (metres / 10).round() * 10 : metres.round();
}
