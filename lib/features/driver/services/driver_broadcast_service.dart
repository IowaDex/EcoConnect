import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../location/models/shared_location.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../route/models/route_plan.dart';

/// Which proximity message a resident should receive.
enum BroadcastStage { approaching, arrived, passed }

/// Turns a driver's live position into resident notifications.
///
/// The rules are distance based so they work without any routing service:
/// residents who opted into location sharing get an "approaching" alert when
/// the truck enters their area, an "arrived" alert when it is on top of them,
/// and a "passed" alert once it has driven away again.
class DriverBroadcastService {
  DriverBroadcastService._();
  static final DriverBroadcastService instance = DriverBroadcastService._();

  factory DriverBroadcastService() => instance;

  static const double approachingMeters = 700;
  static const double arrivedMeters = 150;

  /// How long before the same resident can be told the same thing again.
  static const Duration _cooldown = Duration(minutes: 10);

  final NotificationService _notifications = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Distance _distance = const Distance();

  /// Previous distance per resident, used to detect a pass.
  final Map<String, double> _lastDistance = {};
  final Map<String, DateTime> _lastSent = {};

  Future<int> notifyNearby({
    required String driverId,
    required String driverName,
    required double latitude,
    required double longitude,
    RoutePlan? plan,
  }) async {
    List<SharedLocation> residents;
    try {
      final snap = await _db.collection('shared_locations').get();
      residents = [];
      for (final doc in snap.docs) {
        final item = SharedLocation.tryParse(doc.id, doc.data());
        if (item == null) continue;
        if (item.role != 'user' || item.userId == driverId) continue;
        residents.add(item);
      }
    } catch (_) {
      // A driver without directory access simply sends no fan-out; the
      // position itself was already written by the caller.
      return 0;
    }
    if (residents.isEmpty) return 0;

    final truck = LatLng(latitude, longitude);
    final stop = _nearestStop(plan, truck);
    var sent = 0;

    for (final resident in residents) {
      final metres = _distance.as(
        LengthUnit.Meter,
        truck,
        LatLng(resident.latitude, resident.longitude),
      );
      final previous = _lastDistance[resident.userId];
      _lastDistance[resident.userId] = metres;

      final stage = stageFor(metres: metres, previous: previous);
      if (stage == null) continue;
      if (!_maySend(resident.userId, stage)) continue;

      final where = stop == null
          ? 'your area'
          : 'the ${stop.name} stop';
      final body = switch (stage) {
        BroadcastStage.approaching =>
          '$driverName is about ${_rounded(metres)} m from you, near $where. '
              'Please have your waste ready.',
        BroadcastStage.arrived =>
          '$driverName has arrived near $where. The collection truck is in your '
              'area now.',
        BroadcastStage.passed =>
          '$driverName has passed $where. If you missed the truck, submit a new '
              'collection request.',
      };

      await _notifications.push(
        userId: resident.userId,
        title: switch (stage) {
          BroadcastStage.approaching => 'Truck approaching',
          BroadcastStage.arrived => 'Truck is in your area',
          BroadcastStage.passed => 'Truck passed your area',
        },
        body: body,
        type: AppNotificationType.route,
        data: {'driverId': driverId, 'stage': stage.name},
      );
      _lastSent[_key(resident.userId, stage)] = DateTime.now();
      sent++;
    }
    return sent;
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
        metres > approachingMeters * 1.5) {
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

  static RouteStop? _nearestStop(RoutePlan? plan, LatLng truck) {
    if (plan == null) return null;
    const distance = Distance();
    RouteStop? best;
    var bestMetres = double.infinity;
    for (final stop in plan.stops) {
      final lat = stop.latitude;
      final lng = stop.longitude;
      if (lat == null || lng == null) continue;
      final metres = distance.as(LengthUnit.Meter, truck, LatLng(lat, lng));
      if (metres < bestMetres) {
        bestMetres = metres;
        best = stop;
      }
    }
    return bestMetres <= 400 ? best : null;
  }
}
