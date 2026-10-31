import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lifecycle of a barangay route assignment.
///
/// A plan is created by staff, activated once by the assigned driver, and
/// closed when the run ends. Only [scheduled] plans can be activated.
enum RoutePlanStatus { scheduled, active, completed, cancelled }

extension RoutePlanStatusX on RoutePlanStatus {
  String get label => switch (this) {
        RoutePlanStatus.scheduled => 'Scheduled',
        RoutePlanStatus.active => 'Running',
        RoutePlanStatus.completed => 'Completed',
        RoutePlanStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        RoutePlanStatus.scheduled => AppColors.moss,
        RoutePlanStatus.active => AppColors.lime,
        RoutePlanStatus.completed => AppColors.sage,
        RoutePlanStatus.cancelled => AppColors.inkMuted,
      };

  static RoutePlanStatus fromName(String? name) =>
      RoutePlanStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RoutePlanStatus.scheduled,
      );
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Firestore hands back a [Timestamp] once written, but a pending
/// `serverTimestamp()` surfaces as a [FieldValue]. Anything else is ignored
/// rather than throwing.
DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// Stable day key used for queries: `2026-10-31`.
String routeDateKey(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// `06:30` from a DateTime, used for shift windows.
String routeTimeKey(DateTime time) =>
    '${_two(time.hour)}:${_two(time.minute)}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String routeDateLabel(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// One stop on a collection route. `lat`/`lng` are optional so plans
/// created before map picking (or typed by hand) still load.
class RouteStop {
  const RouteStop({required this.name, this.latitude, this.longitude});

  final String name;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': latitude,
        'lng': longitude,
      };

  RouteStop renamed(String value) =>
      RouteStop(name: value, latitude: latitude, longitude: longitude);

  static RouteStop fromDynamic(dynamic raw) {
    if (raw is String) {
      final name = raw.trim();
      return RouteStop(name: name.isEmpty ? 'Stop' : name);
    }
    if (raw is Map) {
      final name = (raw['name'] as String?)?.trim();
      return RouteStop(
        name: name == null || name.isEmpty ? 'Stop' : name,
        latitude: (raw['lat'] as num?)?.toDouble(),
        longitude: (raw['lng'] as num?)?.toDouble(),
      );
    }
    return const RouteStop(name: 'Stop');
  }
}

/// A staff-created collection assignment for one driver on one day.
/// Stored at `routePlans/{planId}`.
class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.zone,
    required this.date,
    required this.windowStart,
    required this.windowEnd,
    this.stops = const [],
    this.status = RoutePlanStatus.scheduled,
    this.adHoc = false,
    this.createdBy,
    this.createdAt,
    this.activatedAt,
    this.completedAt,
  });

  final String id;
  final String driverId;
  final String driverName;

  /// Barangay / purok the run covers.
  final String zone;

  /// Local day key, `yyyy-MM-dd`.
  final String date;

  /// `HH:mm` 24h clock.
  final String windowStart;
  final String windowEnd;

  /// Stops in collection order. Each one may carry coordinates so it can be
  /// drawn on the resident and driver maps.
  final List<RouteStop> stops;

  final RoutePlanStatus status;

  /// True when the driver created the run themselves because no assignment
  /// existed for today. Staff can still see and audit these.
  final bool adHoc;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? activatedAt;
  final DateTime? completedAt;

  bool get isToday => date == routeDateKey(DateTime.now());

  bool get canActivate => status == RoutePlanStatus.scheduled && isToday;

  DateTime? get _day => DateTime.tryParse(date);

  DateTime? get startsAt {
    final day = _day;
    final parts = windowStart.split(':');
    if (day == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  DateTime? get endsAt {
    final day = _day;
    final parts = windowEnd.split(':');
    if (day == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// Drivers may start up to 45 minutes early and up to an hour after the
  /// window closes; anything else needs an explicit override.
  bool isOpenAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return true;
    return !now.isBefore(start.subtract(const Duration(minutes: 45))) &&
        !now.isAfter(end.add(const Duration(minutes: 60)));
  }

  String get windowLabel => '$windowStart – $windowEnd';

  /// Only the stops that can be pinned on a map.
  List<RouteStop> get mappedStops =>
      stops.where((stop) => stop.hasCoordinates).toList(growable: false);

  String get stopsLabel => stops.isEmpty
      ? 'No stops listed'
      : '${stops.length} stop${stops.length == 1 ? '' : 's'}';

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'driverName': driverName,
        'zone': zone,
        'date': date,
        'windowStart': windowStart,
        'windowEnd': windowEnd,
        'stops': stops.map((stop) => stop.toMap()).toList(),
        'status': status.name,
        'adHoc': adHoc,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static RoutePlan fromDoc(String id, Map<String, dynamic> data) {
    final rawStops = data['stops'];
    return RoutePlan(
      id: id,
      driverId: (data['driverId'] as String?) ?? '',
      driverName: (data['driverName'] as String?)?.trim().isNotEmpty == true
          ? data['driverName'] as String
          : 'Collector',
      zone: (data['zone'] as String?)?.trim().isNotEmpty == true
          ? data['zone'] as String
          : 'Unassigned zone',
      date: (data['date'] as String?) ?? routeDateKey(DateTime.now()),
      windowStart: (data['windowStart'] as String?) ?? '06:00',
      windowEnd: (data['windowEnd'] as String?) ?? '10:00',
      stops: rawStops is List
          ? rawStops.map(RouteStop.fromDynamic).toList(growable: false)
          : const [],
      status: RoutePlanStatusX.fromName(data['status'] as String?),
      adHoc: data['adHoc'] == true,
      createdBy: data['createdBy'] as String?,
      createdAt: _asDate(data['createdAt']),
      activatedAt: _asDate(data['activatedAt']),
      completedAt: _asDate(data['completedAt']),
    );
  }
}
