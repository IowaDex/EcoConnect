import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../driver/services/driver_session_service.dart';

enum RouteStatus { inTransit, delayed, paused, completed, idle }

extension RouteStatusX on RouteStatus {
  String get label => switch (this) {
        RouteStatus.inTransit => 'In transit',
        RouteStatus.delayed => 'Delayed',
        RouteStatus.paused => 'Paused',
        RouteStatus.completed => 'Completed',
        RouteStatus.idle => 'Not started',
      };

  Color get color => switch (this) {
        RouteStatus.inTransit => AppColors.lime,
        RouteStatus.delayed => const Color(0xFFF2B441),
        RouteStatus.paused => AppColors.warning,
        RouteStatus.completed => AppColors.sage,
        RouteStatus.idle => AppColors.inkMuted,
      };

  static RouteStatus fromName(String? name) => RouteStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RouteStatus.idle,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A driver's live collection run. Stored at routes/{driverId}.
class CollectionRoute {
  const CollectionRoute({
    required this.driverId,
    required this.driverName,
    required this.status,
    this.phone,
    this.zone,
    this.latitude,
    this.longitude,
    this.etaMinutes,
    this.planId,
    this.sessionId,
    this.startedAt,
    this.pausedAt,
    this.resumedAt,
    this.completedAt,
    this.lastSeenAt,
    this.updatedAt,
    this.locationState = DriverLocationState.ok,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.locationUpdatedAt,
    this.pauseReason,
    this.truckPlate,
    this.truckWheelers,
    this.crewRole,
    this.connectionAlert = false,
    this.outsideRadius = false,
    this.geofenceMeters,
    this.geofenceLatitude,
    this.geofenceLongitude,
  });

  /// A route that has not sent a heartbeat for this long is treated as
  /// offline, so residents never watch a frozen truck.
  static const staleAfter = Duration(minutes: 5);

  final String driverId;
  final String driverName;
  final RouteStatus status;
  final String? phone;
  final String? zone;
  final double? latitude;
  final double? longitude;
  final int? etaMinutes;
  final String? planId;
  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? completedAt;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;
  final DriverLocationState locationState;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? locationUpdatedAt;
  final String? pauseReason;

  /// Truck the crew picked after signing in. Null on routes started before
  /// the fleet list existed.
  final String? truckPlate;
  final int? truckWheelers;

  /// 'driver' or 'guide' — who is holding the device.
  final String? crewRole;

  /// The crew switched wifi/data off during the run. Staff get an alert the
  /// moment it happens; the flag clears when the phone reconnects.
  final bool connectionAlert;

  /// The truck went past the 100 m zone radius.
  final bool outsideRadius;

  /// How far the truck is from the zone centre, in metres.
  final int? geofenceMeters;

  /// Centre of the zone the truck must stay within 100 m of.
  final double? geofenceLatitude;
  final double? geofenceLongitude;

  /// Moving statuses — what residents should see on the tracking map.
  bool get isLive =>
      status == RouteStatus.inTransit || status == RouteStatus.delayed;

  /// A run that has started and not yet finished, including paused runs.
  bool get isActiveRun => isLive || status == RouteStatus.paused;

  bool get isPaused => status == RouteStatus.paused;

  /// True when the driver's device stopped reporting. The position is the
  /// last known one, not a live one.
  bool get isStale {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt!) > staleAfter;
  }

  /// Best position to draw for a paused or offline driver.
  double? get displayLatitude => latitude ?? lastKnownLatitude;
  double? get displayLongitude => longitude ?? lastKnownLongitude;

  bool get hasLocationWarning => locationState.needsAttention || isStale;

  /// One of the two trip rules is broken: offline, or out of the radius.
  bool get hasTripGuardAlert => connectionAlert || outsideRadius;

  /// What staff should read first about this run.
  String? get guardAlertLabel {
    if (connectionAlert && outsideRadius) {
      return 'Offline · outside radius';
    }
    if (connectionAlert) return 'Device offline';
    if (outsideRadius) {
      return geofenceMeters == null
          ? 'Outside radius'
          : 'Outside radius · $geofenceMeters m';
    }
    return null;
  }

  Duration? get elapsed =>
      startedAt == null ? null : DateTime.now().difference(startedAt!);

  static bool isStaleData(Map<String, dynamic> data) {
    final raw = data['lastSeenAt'] ?? data['updatedAt'];
    final seenAt = raw is Timestamp ? raw.toDate() : null;
    if (seenAt == null) return false;
    return DateTime.now().difference(seenAt) > staleAfter;
  }

  static CollectionRoute? fromDoc(String id, Map<String, dynamic> data) {
    final status = RouteStatusX.fromName(data['status'] as String?);
    if (status == RouteStatus.idle) return null;
    return CollectionRoute(
      driverId: id,
      driverName: (data['driverName'] as String?)?.trim().isNotEmpty == true
          ? data['driverName'] as String
          : 'Your collector',
      status: status,
      phone: data['phone'] as String?,
      zone: data['zone'] as String?,
      latitude: (data['lat'] as num?)?.toDouble(),
      longitude: (data['lng'] as num?)?.toDouble(),
      etaMinutes: (data['etaMinutes'] as num?)?.toInt(),
      planId: data['planId'] as String?,
      sessionId: data['sessionId'] as String?,
      startedAt: _asDate(data['startedAt']),
      pausedAt: _asDate(data['pausedAt']),
      resumedAt: _asDate(data['resumedAt']),
      completedAt: _asDate(data['completedAt']),
      lastSeenAt: _asDate(data['lastSeenAt']),
      updatedAt: _asDate(data['updatedAt']),
      locationState:
          DriverLocationStateX.fromWire(data['locationState'] as String?),
      lastKnownLatitude: (data['lastKnownLat'] as num?)?.toDouble(),
      lastKnownLongitude: (data['lastKnownLng'] as num?)?.toDouble(),
      locationUpdatedAt: _asDate(data['locationUpdatedAt']),
      pauseReason: data['pauseReason'] as String?,
      truckPlate: data['truckPlate'] as String?,
      truckWheelers: (data['truckWheelers'] as num?)?.toInt(),
      crewRole: data['crewRole'] as String?,
      connectionAlert: data['connectionState'] == 'alert',
      outsideRadius: data['geofenceState'] == 'alert',
      geofenceMeters: (data['geofenceMeters'] as num?)?.toInt(),
      geofenceLatitude: (data['geofenceLat'] as num?)?.toDouble(),
      geofenceLongitude: (data['geofenceLng'] as num?)?.toDouble(),
    );
  }
}
