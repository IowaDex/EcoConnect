import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tickets/models/trip_ticket.dart';

/// Where an assignment manual is in the City Hall approval loop.
///
/// [pendingApproval] is set the moment Iswim submits it; [approved] is written
/// when the City Hall signature lands on the generated trip ticket.
enum AssignmentManualStatus { pendingApproval, approved, cancelled }

extension AssignmentManualStatusX on AssignmentManualStatus {
  String get label => switch (this) {
    AssignmentManualStatus.pendingApproval => 'Waiting for City Hall',
    AssignmentManualStatus.approved => 'Approved by City Hall',
    AssignmentManualStatus.cancelled => 'Cancelled',
  };

  static AssignmentManualStatus fromName(String? name) =>
      AssignmentManualStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AssignmentManualStatus.pendingApproval,
      );
}

DateTime? _date(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// The collection manual Iswim builds after City Hall asks for one.
///
/// It is the roster entry: one driver, the truck that comes with the driver,
/// up to three routes, the days it runs, the start time and how often it
/// repeats. A [TripTicket] with [TicketKind.assignment] is generated from it.
class AssignmentManual {
  const AssignmentManual({
    required this.id,
    required this.title,
    required this.driverId,
    required this.driverName,
    required this.truckId,
    required this.plateNumber,
    required this.wheelers,
    required this.routes,
    required this.days,
    required this.startTime,
    required this.recurrence,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    this.routePoints = const [],
    this.requestId,
    this.ticketId,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedByName,
  });

  final String id;
  final String title;

  final String driverId;
  final String driverName;

  final String truckId;
  final String plateNumber;
  final int wheelers;

  /// Up to [maxRoutes] streets.
  final List<String> routes;

  /// The map points behind [routes], kept so the driver's map can draw them.
  final List<ManualRoutePoint> routePoints;

  /// Days of the week, 1 = Monday … 7 = Sunday.
  final List<int> days;

  /// `HH:mm`, 24-hour clock. There is no end time: the driver marks the run
  /// complete instead.
  final String startTime;

  final ManualRecurrence recurrence;
  final AssignmentManualStatus status;

  /// The City Hall manual request this answers, when it came from one.
  final String? requestId;

  /// The generated trip ticket.
  final String? ticketId;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedByName;

  int get maxRoutes => maxRoutesForWheelers(wheelers);

  bool get isApproved => status == AssignmentManualStatus.approved;

  /// Whether the crew is expected on [date].
  ///
  /// The recurrence is how long the roster stays in force, not how often it
  /// repeats: the listed weekdays are worked every week, weekly runs until it
  /// is cancelled, monthly for one month from creation and yearly for one
  /// year. See [manualRunsOn] for the shared rule.
  bool runsOn(DateTime date) {
    if (status == AssignmentManualStatus.cancelled) return false;
    return manualRunsOn(
      days: days,
      recurrence: recurrence,
      createdAt: createdAt,
      date: date,
    );
  }

  String get scheduleLabel {
    final names = [...days]..sort();
    return '${names.map(manualDayLabel).join(', ')} · $startTime · '
        '${recurrence.label}';
  }

  String get routesLabel => routes.join(' · ');

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'driverId': driverId,
    'driverName': driverName,
    'truckId': truckId,
    'plateNumber': plateNumber,
    'wheelers': wheelers,
    'routes': routes,
    'routePoints': [for (final point in routePoints) point.toMap()],
    'days': days,
    'startTime': startTime,
    'recurrence': recurrence.name,
    'status': status.name,
    'createdBy': createdBy,
    'createdByName': createdByName,
    if (requestId != null) 'requestId': requestId,
    if (ticketId != null) 'ticketId': ticketId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static AssignmentManual? fromDoc(String id, Map<String, dynamic> data) {
    final driverName = (data['driverName'] as String?)?.trim() ?? '';
    if (driverName.isEmpty) return null;
    return AssignmentManual(
      id: id,
      title: data['title'] as String? ?? 'Collection manual',
      driverId: data['driverId'] as String? ?? '',
      driverName: driverName,
      truckId: data['truckId'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      wheelers: (data['wheelers'] as num?)?.toInt() ?? 4,
      routes:
          (data['routes'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      routePoints:
          (data['routePoints'] as List?)
              ?.map(ManualRoutePoint.fromDynamic)
              .whereType<ManualRoutePoint>()
              .toList(growable: false) ??
          const [],
      days:
          (data['days'] as List?)
              ?.whereType<num>()
              .map((d) => d.toInt())
              .toList(growable: false) ??
          const [],
      startTime: data['startTime'] as String? ?? '06:00',
      recurrence: ManualRecurrenceX.fromName(data['recurrence'] as String?),
      status: AssignmentManualStatusX.fromName(data['status'] as String?),
      requestId: data['requestId'] as String?,
      ticketId: data['ticketId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Iswim',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      approvedAt: _date(data['approvedAt']),
      approvedByName: data['approvedByName'] as String?,
    );
  }
}
