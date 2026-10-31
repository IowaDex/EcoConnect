import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum RouteStatus { inTransit, delayed, completed, idle }

extension RouteStatusX on RouteStatus {
  String get label => switch (this) {
        RouteStatus.inTransit => 'In transit',
        RouteStatus.delayed => 'Delayed',
        RouteStatus.completed => 'Completed',
        RouteStatus.idle => 'Not started',
      };

  Color get color => switch (this) {
        RouteStatus.inTransit => AppColors.lime,
        RouteStatus.delayed => const Color(0xFFF2B441),
        RouteStatus.completed => AppColors.sage,
        RouteStatus.idle => AppColors.inkMuted,
      };

  static RouteStatus fromName(String? name) => RouteStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RouteStatus.idle,
      );
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A driver's live collection run. Stored at `routes/{driverId}`.
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
    this.lastSeenAt,
    this.updatedAt,
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
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;

  bool get isLive =>
      status == RouteStatus.inTransit || status == RouteStatus.delayed;

  /// True when the driver's device stopped reporting. The position is the
  /// last known one, not a live one.
  bool get isStale {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt!) > staleAfter;
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
      lastSeenAt: _asDate(data['lastSeenAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }
}
