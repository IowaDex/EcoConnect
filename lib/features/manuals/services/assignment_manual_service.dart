import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fleet/services/fleet_service.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../models/assignment_manual.dart';
import '../models/manual_assignment.dart';

/// Reads and writes for the collection manual Iswim builds.
///
/// The manual is the bulk roster; submitting it generates one trip ticket per
/// assignment. Nothing here bypasses City Hall: the manual stays
/// [AssignmentManualStatus.pendingApproval] until every ticket has a City Hall
/// signature.
class AssignmentManualService {
  AssignmentManualService._();
  static final AssignmentManualService instance = AssignmentManualService._();
  factory AssignmentManualService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('assignment_manuals');

  /// Every manual, newest first. Used by Iswim and City Hall.
  Stream<List<AssignmentManual>> watchAll() => _col
      .orderBy('updatedAt', descending: true)
      .limit(60)
      .snapshots()
      .map(_parse);

  /// Only the schedules City Hall has approved. The barangay, drivers and
  /// residents read this list; a pending manual never reaches them.
  Stream<List<AssignmentManual>> watchApproved() => _col
      .where('status', isEqualTo: AssignmentManualStatus.approved.name)
      .limit(60)
      .snapshots()
      .map(_parse);

  Stream<AssignmentManual?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (snap) => snap.exists
            ? AssignmentManual.fromDoc(snap.id, snap.data()!)
            : null,
      );

  /// One manual, read once. Used where a live listener would outlive the
  /// screen — the PDF export, for instance.
  Future<AssignmentManual?> findOne(String id) async {
    try {
      final snap = await _col.doc(id).get();
      if (!snap.exists) return null;
      return AssignmentManual.fromDoc(snap.id, snap.data()!);
    } catch (_) {
      return null;
    }
  }

  static List<AssignmentManual> _parse(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final items = snap.docs
        .map((doc) => AssignmentManual.fromDoc(doc.id, doc.data()))
        .whereType<AssignmentManual>()
        .toList();
    items.sort((a, b) {
      final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
      final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
      return right.compareTo(left);
    });
    return items;
  }

  /// A driver needs six hours between shifts, a plate cannot be on two routes
  /// at the same moment, and an area is only covered once per slot. Returns a
  /// human explanation, or null when the slot is free.
  ///
  /// Every pending and approved manual is checked, not only the one being
  /// written: an area another manual already booked cannot be ticked again.
  /// [excludeManualId] leaves the manual being edited out of its own check.
  Future<String?> findConflict({
    required String driverId,
    required String driverName,
    required String truckId,
    required List<String> routes,
    required List<int> days,
    required String startTime,
    Map<int, List<String>> dayRoutes = const {},
    String? excludeManualId,
  }) async {
    try {
      final snap = await _col
          .where(
            'status',
            whereIn: [
              AssignmentManualStatus.pendingApproval.name,
              AssignmentManualStatus.approved.name,
            ],
          )
          .get();
      List<String> mineOn(int day) {
        final specific = dayRoutes[day];
        if (specific != null && specific.isNotEmpty) return specific;
        return routes;
      }

      for (final doc in snap.docs) {
        if (doc.id == excludeManualId) continue;
        final other = AssignmentManual.fromDoc(doc.id, doc.data());
        if (other == null) continue;
        for (final row in other.allAssignments) {
          final sharedDays = row.days.where(days.contains).toList();
          if (sharedDays.isEmpty) continue;
          final sameDriver = manualSameDriver(
            driverId: driverId,
            driverName: driverName,
            otherDriverId: row.driverId,
            otherDriverName: row.driverName,
          );
          final sameTruck = truckId.isNotEmpty && row.truckId == truckId;
          final clash = sameDriver
              ? manualSlotsClash(row.startTime, startTime)
              : row.startTime == startTime;
          final shared = sharedDays.map(manualDayLabel).join(', ');
          if ((sameDriver || sameTruck) && clash) {
            if (sameDriver) {
              return '${row.driverName} already starts on $shared at '
                  '${row.startTime}. Leave 6 hours between shifts.';
            }
            return 'Plate ${row.plateNumber} is already out on $shared at '
                '${row.startTime}.';
          }
          // Areas are compared per day, so a per-day schedule only blocks the
          // day it actually covers. The start time is deliberately not part of
          // this test: an area another manual already runs is not free just
          // because this one starts at a different hour.
          for (final day in sharedDays) {
            final taken = mineOn(
              day,
            ).where(row.routesForDay(day).contains).toList();
            if (taken.isEmpty) continue;
            return '${taken.join(', ')} is already covered by '
                '${row.driverName} on ${manualDayLabel(day)} at '
                '${row.startTime}.';
          }
        }
      }
      return null;
    } catch (_) {
      // A failed pre-check must not block a legitimate submission; the same
      // validation runs again in the form before this call.
      return null;
    }
  }

  /// Every driver row already booked by a manual still in force.
  ///
  /// The assignment form uses this to grey out an area another manual already
  /// covers, so a clash is visible while the officer picks instead of only
  /// when the submission is refused.
  Future<List<ManualAssignment>> loadBookings({
    String? excludeManualId,
  }) async {
    try {
      final snap = await _col
          .where(
            'status',
            whereIn: [
              AssignmentManualStatus.pendingApproval.name,
              AssignmentManualStatus.approved.name,
            ],
          )
          .get();
      final rows = <ManualAssignment>[];
      for (final doc in snap.docs) {
        if (doc.id == excludeManualId) continue;
        final manual = AssignmentManual.fromDoc(doc.id, doc.data());
        if (manual == null) continue;
        rows.addAll(manual.allAssignments);
      }
      return rows;
    } catch (_) {
      return const [];
    }
  }

  /// Saves a bulk manual and generates one trip ticket per assignment.
  ///
  /// Pass [existing] to resubmit a manual City Hall rejected: the previous
  /// tickets are retired, the roster is replaced and the manual goes back into
  /// the approval queue. City Hall is told once, not once per driver.
  ///
  /// The manual is saved first, then each ticket it generates; every ticket id
  /// is stamped back as it is issued. A refused manual write therefore leaves
  /// no orphan tickets behind.
  Future<AssignmentManual> submitBatch({
    required String title,
    required List<ManualAssignment> assignments,
    required String byId,
    required String byName,
    String? requestId,
    AssignmentManual? existing,
  }) async {
    if (assignments.isEmpty) {
      throw const AssignmentException(
        'Add at least one driver to this manual.',
      );
    }

    _checkBatchConflicts(assignments);

    for (final assignment in assignments) {
      final conflict = await findConflict(
        driverId: assignment.driverId,
        driverName: assignment.driverName,
        truckId: assignment.truckId,
        routes: assignment.routes,
        days: assignment.days,
        startTime: assignment.startTime,
        dayRoutes: assignment.dayRoutes,
        excludeManualId: existing?.id,
      );
      if (conflict != null) throw AssignmentException(conflict);
    }

    final first = assignments.first;
    final ref = existing == null ? _col.doc() : _col.doc(existing.id);
    final revision = (existing?.revision ?? 0) + 1;
    final cleanTitle = title.trim().isEmpty ? 'Collection manual' : title.trim();

    if (existing == null) {
      // The manual is written first. If the rules refuse it, nothing else has
      // happened yet — no trip tickets and no approval alerts for City Hall to
      // chase. Each ticket id is stamped on right after it is issued.
      await ref.set(
        AssignmentManual(
          id: ref.id,
          title: cleanTitle,
          driverId: first.driverId,
          driverName: first.driverName,
          truckId: first.truckId,
          plateNumber: first.plateNumber,
          wheelers: first.wheelers,
          routes: first.routes,
          routePoints: first.routePoints,
          assignments: assignments,
          days: first.days,
          startTime: first.startTime,
          recurrence: first.recurrence,
          status: AssignmentManualStatus.pendingApproval,
          requestId: requestId,
          createdBy: byId,
          createdByName: byName,
          revision: revision,
        ).toMap(),
      );
    } else {
      // Retire the tickets the rejected submission generated, so the roster
      // on the road matches the roster City Hall is looking at now.
      for (final id in existing.ticketIds) {
        try {
          await _db.collection('trip_tickets').doc(id).update({
            'status': 'cancelled',
            'pendingSigner': null,
            'approvalPending': false,
          });
        } catch (_) {
          // A ticket that already moved on is left as it is.
        }
      }
      await ref.update({
        'title': cleanTitle,
        'driverId': first.driverId,
        'driverName': first.driverName,
        'truckId': first.truckId,
        'plateNumber': first.plateNumber,
        'wheelers': first.wheelers,
        'routes': first.routes,
        'routePoints': [for (final point in first.routePoints) point.toMap()],
        'assignments': [for (final row in assignments) row.toMap()],
        'days': first.days,
        'startTime': first.startTime,
        'recurrence': first.recurrence.name,
        'status': AssignmentManualStatus.pendingApproval.name,
        'revision': revision,
        'ticketIds': <String>[],
        'ticketId': null,
        'rejectionReason': null,
        'rejectedAt': null,
        'rejectedByName': null,
        'approvedAt': null,
        'approvedByName': null,
        if (requestId != null) 'requestId': requestId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final ticketIds = <String>[];
    for (final assignment in assignments) {
      final ticket = await TicketService().createAssignment(
        assignmentId: ref.id,
        truckId: assignment.truckId,
        plateNumber: assignment.plateNumber,
        wheelers: assignment.wheelers,
        driverId: assignment.driverId,
        driverName: assignment.driverName,
        routes: assignment.routes,
        routePoints: assignment.routePoints,
        dayRoutes: assignment.dayRoutes,
        days: assignment.days,
        startTime: assignment.startTime,
        recurrence: assignment.recurrence,
        createdBy: byId,
      );
      ticketIds.add(ticket.id);
      await ref.update({
        'ticketIds': FieldValue.arrayUnion([ticket.id]),
        'ticketId': ticketIds.first,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // The manual is also where the driver meets the plate. Stamp the pairing
    // on the truck so the fleet row loses its NEW tag and the crew's
    // dashboard can find the vehicle. Best effort: the manual and tickets
    // already exist, so a failed mirror must not undo the submission.
    for (final assignment in assignments) {
      try {
        await FleetService().assignDriver(
          truckId: assignment.truckId,
          driverId: assignment.driverId,
          driverName: assignment.driverName,
        );
      } catch (_) {
        // The fleet link can be repaired from the Fleet screen later.
      }
    }

    final saved = await ref.get();
    final manual = AssignmentManual.fromDoc(ref.id, saved.data()!)!;

    // One alert for the whole manual: City Hall opens the manual, not one
    // notification per driver.
    await NotificationService().notifyCityHall(
      title: 'Manual for approval',
      body: existing == null
          ? '$byName submitted "${manual.title}" · '
                '${assignments.length} '
                '${assignments.length == 1 ? 'driver' : 'drivers'}.'
          : '$byName resubmitted "${manual.title}" · '
                '${assignments.length} '
                '${assignments.length == 1 ? 'driver' : 'drivers'} after your '
                'rejection.',
      type: AppNotificationType.system,
      data: {
        'assignmentManualId': ref.id,
        'kind': 'manualApproval',
        'ticketId': ticketIds.isEmpty ? null : ticketIds.first,
      },
      dedupeKey: 'assignment_manual_${ref.id}_approval_r$revision',
    );

    if (requestId != null && requestId.isNotEmpty) {
      try {
        await _db.collection('manual_requests').doc(requestId).update({
          'status': 'fulfilled',
          'assignmentManualId': ref.id,
          'ticketId': ticketIds.first,
          'ticketIds': ticketIds,
          'fulfilledAt': FieldValue.serverTimestamp(),
          'fulfilledByName': byName,
        });
      } catch (_) {
        // The manual and tickets already exist; the request can be linked from
        // the request desk later.
      }
    }

    return manual;
  }

  /// Catches a driver, plate or area booked twice inside the same manual
  /// before any write happens.
  static void _checkBatchConflicts(List<ManualAssignment> assignments) {
    for (var i = 0; i < assignments.length; i++) {
      for (var j = i + 1; j < assignments.length; j++) {
        final left = assignments[i];
        final right = assignments[j];
        final sharedDays = left.days.where(right.days.contains).toList();
        if (sharedDays.isEmpty) continue;
        final shared = sharedDays.map(manualDayLabel).join(', ');
        final sameDriver = manualSameDriver(
          driverId: left.driverId,
          driverName: left.driverName,
          otherDriverId: right.driverId,
          otherDriverName: right.driverName,
        );
        final sameTruck =
            left.truckId.isNotEmpty && left.truckId == right.truckId;
        // Six hours between shifts for a driver; a plate cannot be on two
        // routes at the same moment.
        final clash = sameDriver
            ? manualSlotsClash(left.startTime, right.startTime)
            : left.startTime == right.startTime;
        if ((sameDriver || sameTruck) && clash) {
          if (sameDriver) {
            throw AssignmentException(
              '${left.driverName} is booked twice on $shared '
              '(${left.startTime} and ${right.startTime}). Leave 6 hours '
              'between shifts.',
            );
          }
          throw AssignmentException(
            'Plate ${left.plateNumber} is on two assignments on $shared at '
            '${left.startTime}. Move one to another day or time.',
          );
        }

        // An area can only be covered once on a given day, whoever drives it
        // and whatever the start time: the same street cannot be handed to a
        // second manual just because its shift begins later.
        for (final day in sharedDays) {
          final taken = left
              .routesForDay(day)
              .where(right.routesForDay(day).contains)
              .toList();
          if (taken.isEmpty) continue;
          throw AssignmentException(
            '${taken.join(', ')} is already covered by ${left.driverName} on '
            '${manualDayLabel(day)} at ${left.startTime}. Pick another area '
            'or another time.',
          );
        }
      }
    }
  }

  Future<void> cancel(String id) async {
    await _col.doc(id).update({
      'status': AssignmentManualStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AssignmentException implements Exception {
  const AssignmentException(this.message);
  final String message;

  @override
  String toString() => message;
}
