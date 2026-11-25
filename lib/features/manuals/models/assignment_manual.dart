import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tickets/models/trip_ticket.dart';
import 'manual_assignment.dart';

/// Where an assignment manual is in the City Hall approval loop.
///
/// [pendingApproval] is set the moment Iswim submits it; [approved] is written
/// when the City Hall signature lands on every ticket it generated. City Hall
/// may instead send it back with [rejected] and a reason, and Iswim edits the
/// manual and submits it again.
enum AssignmentManualStatus { pendingApproval, approved, rejected, cancelled }

extension AssignmentManualStatusX on AssignmentManualStatus {
  String get label => switch (this) {
    AssignmentManualStatus.pendingApproval => 'Waiting for City Hall',
    AssignmentManualStatus.approved => 'Approved by City Hall',
    AssignmentManualStatus.rejected => 'Rejected by City Hall',
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
/// It is a bulk roster: several [assignments], each with its own driver,
/// plate, areas, days, start time and recurrence. One trip ticket is generated
/// per assignment, and the manual is only [AssignmentManualStatus.approved]
/// once City Hall has signed all of them.
///
/// The single-driver fields are kept as the first assignment's copy so older
/// screens and records written before bulk manuals still read correctly.
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
    this.assignments = const [],
    this.ticketIds = const [],
    this.requestId,
    this.ticketId,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedByName,
    this.rejectedAt,
    this.rejectedByName,
    this.rejectionReason,
    this.revision = 1,
  });

  final String id;
  final String title;

  final String driverId;
  final String driverName;

  final String truckId;
  final String plateNumber;
  final int wheelers;

  /// Up to [maxRoutes] area names for the first assignment.
  final List<String> routes;

  /// The map points behind [routes], kept so the driver's map can draw them.
  final List<ManualRoutePoint> routePoints;

  /// Every driver row in the manual. Empty on records written before bulk
  /// manuals, in which case [allAssignments] falls back to the legacy fields.
  final List<ManualAssignment> assignments;

  /// One trip ticket per assignment, in the same order.
  final List<String> ticketIds;

  /// Days of the week, 1 = Monday … 7 = Sunday (first assignment).
  final List<int> days;

  /// `HH:mm`, 24-hour clock. There is no end time: the driver marks the run
  /// complete instead.
  final String startTime;

  final ManualRecurrence recurrence;
  final AssignmentManualStatus status;

  /// The City Hall manual request this answers, when it came from one.
  final String? requestId;

  /// The first generated trip ticket.
  final String? ticketId;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedByName;

  /// Set when City Hall sent the manual back instead of approving it.
  final DateTime? rejectedAt;
  final String? rejectedByName;
  final String? rejectionReason;

  /// Bumped on every submission, so a resubmitted manual notifies City Hall
  /// again without the dedupe key swallowing the alert.
  final int revision;

  int get maxRoutes => maxRoutesForWheelers(wheelers);

  int get assignmentCount => assignments.isEmpty ? 1 : assignments.length;

  bool get isApproved => status == AssignmentManualStatus.approved;

  bool get isRejected => status == AssignmentManualStatus.rejected;

  bool get isCancelled => status == AssignmentManualStatus.cancelled;

  bool get awaitsApproval => status == AssignmentManualStatus.pendingApproval;

  /// The last day this schedule covers.
  ///
  /// Counted from City Hall's signature when there is one, so a manual that
  /// waited a week for approval still gets its full week.
  DateTime get validUntil => manualValidUntil(
    recurrence: recurrence,
    from: approvedAt ?? createdAt ?? DateTime.now(),
  );

  /// The roster, with a one-row fallback for records written before the
  /// assignments array existed.
  List<ManualAssignment> get allAssignments {
    if (assignments.isNotEmpty) return assignments;
    return [
      ManualAssignment(
        driverId: driverId,
        driverName: driverName,
        truckId: truckId,
        plateNumber: plateNumber,
        wheelers: wheelers,
        routes: routes,
        routePoints: routePoints,
        days: days,
        startTime: startTime,
        recurrence: recurrence,
      ),
    ];
  }

  /// Every distinct area the manual covers, in roster order.
  List<String> get allRoutes {
    final seen = <String>{};
    for (final assignment in allAssignments) {
      seen.addAll(assignment.routes);
    }
    return seen.toList(growable: false);
  }

  /// Whether the crew is expected on [date].
  ///
  /// The recurrence is how long the roster stays in force, not how often it
  /// repeats: the listed weekdays are worked every week, weekly runs until it
  /// is cancelled, monthly for one month from creation and yearly for one
  /// year. See [manualRunsOn] for the shared rule.
  bool runsOn(DateTime date) {
    if (status == AssignmentManualStatus.cancelled ||
        status == AssignmentManualStatus.rejected) {
      return false;
    }
    for (final assignment in allAssignments) {
      if (manualRunsOn(
        days: assignment.days,
        recurrence: assignment.recurrence,
        createdAt: createdAt,
        date: date,
      )) {
        return true;
      }
    }
    return false;
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
    'assignments': [for (final assignment in assignments) assignment.toMap()],
    'ticketIds': ticketIds,
    'days': days,
    'startTime': startTime,
    'recurrence': recurrence.name,
    'status': status.name,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'revision': revision,
    if (requestId != null) 'requestId': requestId,
    if (ticketId != null) 'ticketId': ticketId,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static AssignmentManual? fromDoc(String id, Map<String, dynamic> data) {
    final assignments = ManualAssignment.listFromDynamic(data['assignments']);

    final routes =
        (data['routes'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const [];
    final routePoints =
        (data['routePoints'] as List?)
            ?.map(ManualRoutePoint.fromDynamic)
            .whereType<ManualRoutePoint>()
            .toList(growable: false) ??
        const [];
    final days =
        (data['days'] as List?)
            ?.whereType<num>()
            .map((day) => day.toInt())
            .toList(growable: false) ??
        const [];
    final startTime = data['startTime'] as String? ?? '06:00';
    final recurrence = ManualRecurrenceX.fromName(
      data['recurrence'] as String?,
    );

    final first = assignments.isNotEmpty
        ? assignments.first
        : ManualAssignment(
            driverId: data['driverId'] as String? ?? '',
            driverName: (data['driverName'] as String?)?.trim() ?? '',
            truckId: data['truckId'] as String? ?? '',
            plateNumber: (data['plateNumber'] as String?)?.trim() ?? '',
            wheelers: (data['wheelers'] as num?)?.toInt() ?? 4,
            routes: routes,
            routePoints: routePoints,
            days: days,
            startTime: startTime,
            recurrence: recurrence,
          );

    if (first.driverName.trim().isEmpty) return null;

    final ticketIds =
        (data['ticketIds'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const [];
    final ticketId = data['ticketId'] as String?;

    return AssignmentManual(
      id: id,
      title: data['title'] as String? ?? 'Collection manual',
      driverId: first.driverId,
      driverName: first.driverName,
      truckId: first.truckId,
      plateNumber: first.plateNumber,
      wheelers: first.wheelers,
      routes: first.routes,
      routePoints: first.routePoints,
      assignments: assignments,
      ticketIds: ticketIds.isNotEmpty
          ? ticketIds
          : [if (ticketId != null) ticketId],
      days: first.days,
      startTime: first.startTime,
      recurrence: first.recurrence,
      status: AssignmentManualStatusX.fromName(data['status'] as String?),
      requestId: data['requestId'] as String?,
      ticketId: ticketId ?? (ticketIds.isEmpty ? null : ticketIds.first),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Iswim',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      approvedAt: _date(data['approvedAt']),
      approvedByName: data['approvedByName'] as String?,
      rejectedAt: _date(data['rejectedAt']),
      rejectedByName: data['rejectedByName'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      revision: (data['revision'] as num?)?.toInt() ?? 1,
    );
  }
}
