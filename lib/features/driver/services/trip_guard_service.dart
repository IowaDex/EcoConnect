import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

/// Why the barangay is being alerted about a running trip.
enum TripAlertKind { connection, radius }

extension TripAlertKindX on TripAlertKind {
  String get wireName => switch (this) {
        TripAlertKind.connection => 'connection',
        TripAlertKind.radius => 'radius',
      };

  /// Field on the live route document staff read.
  String get field => switch (this) {
        TripAlertKind.connection => 'connectionState',
        TripAlertKind.radius => 'geofenceState',
      };
}

/// Watches the two rules a garbage truck must keep while a trip is running:
///
///  * the phone must stay online — a crew that switches wifi/data off takes the
///    truck off the map, so it is treated as an alert, not a preference;
///  * the truck must stay inside the 100 m radius of its assigned zone.
///
/// Both checks are pure enough to unit test: [metresBetween],
/// [isOutsideRadius] and [isBackInside] take plain numbers.
class TripGuardService {
  TripGuardService._();
  static final TripGuardService instance = TripGuardService._();
  factory TripGuardService() => instance;

  /// Barangay rule: the truck stays within 100 m of its zone centre.
  static const double radiusMeters = 100;

  /// Coming back needs a little slack so a truck parked on the line does not
  /// flicker between "inside" and "outside" on GPS noise.
  static const double hysteresisMeters = 8;

  static const Distance _distance = Distance();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  static double metresBetween(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) =>
      _distance.as(
        LengthUnit.Meter,
        LatLng(fromLat, fromLng),
        LatLng(toLat, toLng),
      );

  /// True the moment the truck crosses the radius.
  static bool isOutsideRadius(double metres) => metres > radiusMeters;

  /// True once the truck is comfortably back inside, so the warning clears.
  static bool isBackInside(double metres) =>
      metres <= radiusMeters - hysteresisMeters;

  /// Which point the radius is measured from.
  ///
  /// The zone centre is the real rule, but a crew testing away from Batasan
  /// would trip the alarm before the trip even starts. When the device is far
  /// from the zone centre we fall back to where the trip started, which keeps
  /// the same "stay within 100 m" behaviour anywhere.
  static ({double lat, double lng}) resolveCenter({
    required double zoneLat,
    required double zoneLng,
    required double startLat,
    required double startLng,
  }) {
    final fromZone = metresBetween(startLat, startLng, zoneLat, zoneLng);
    if (fromZone <= 3000) return (lat: zoneLat, lng: zoneLng);
    return (lat: startLat, lng: startLng);
  }

  /// Publishes the current trip guard state on the live route document.
  ///
  /// [notify] is true only on the transition into a problem, so staff get one
  /// alert per incident instead of one per heartbeat.
  Future<void> reportState({
    required String driverId,
    required String driverName,
    required TripAlertKind kind,
    required bool alert,
    double? metres,
    double? centerLat,
    double? centerLng,
    bool notify = false,
  }) async {
    await _db.collection('routes').doc(driverId).set({
      kind.field: alert ? 'alert' : 'ok',
      if (metres != null) 'geofenceMeters': metres.round(),
      if (centerLat != null) 'geofenceLat': centerLat,
      if (centerLng != null) 'geofenceLng': centerLng,
      'geofenceRadius': radiusMeters,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!notify || !alert) return;
    await _notifications.notifyStaff(
      title: switch (kind) {
        TripAlertKind.connection => 'Driver went offline',
        TripAlertKind.radius => 'Truck left its zone',
      },
      body: switch (kind) {
        TripAlertKind.connection =>
          '$driverName turned off mobile data or wifi while the trip was '
              'running. The truck is off the live map.',
        TripAlertKind.radius =>
          '$driverName is ${metres?.round() ?? 'over'} m from the zone centre '
              '— past the ${radiusMeters.round()} m limit.',
      },
      type: AppNotificationType.route,
      data: {'driverId': driverId, 'kind': kind.wireName},
    );
  }
}
