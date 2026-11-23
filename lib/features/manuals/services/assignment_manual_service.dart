import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fleet/services/fleet_service.dart';
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

  /// A driver needs six hours between shifts, and a plate cannot be on two
  /// routes at the same moment. Returns a human explanation, or null when the
  /// slot is free.
  Future<String?> findConflict({
    required String driverId,
    required String driverName,
    required String truckId,
    required List<int> days,
    required String startTime,
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
      for (final doc in snap.docs) {
        final other = AssignmentManual.fromDoc(doc.id, doc.data());
        if (other == null) continue;
        for (final row in other.allAssignments) {
          if (!row.days.any(days.contains)) continue;
          final sameDriver = manualSameDriver(
            driverId: driverId,
            driverName: driverName,
            otherDriverId: row.driverId,
            otherDriverName: row.driverName,
          );
          final sameTruck = truckId.isNotEmpty && row.truckId == truckId;
          if (!sameDriver && !sameTruck) continue;
          final clash = sameDriver
              ? manualSlotsClash(row.startTime, startTime)
              : row.startTime == startTime;
          if (!clash) continue;
          final shared = row.days
              .where(days.contains)
              .map(manualDayLabel)
              .join(', ');
          if (sameDriver) {
            return '${row.driverName} already starts on $shared at '
                '${row.startTime}. Leave 6 hours between shifts.';
          }
          return 'Plate ${row.plateNumber} is already out on $shared at '
              '${row.startTime}.';
        }
      }
      return null;
    } catch (_) {
      // A failed pre-check must not block a legitimate submission; the same
      // validation runs again in the form before this call.
      return null;
    }
  }

  /// Saves a bulk manual and generates one trip ticket per assignment.
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
        days: assignment.days,
        startTime: assignment.startTime,
      );
      if (conflict != null) throw AssignmentException(conflict);
    }

    final first = assignments.first;
    final ref = _col.doc();
    // The manual is written first. If the rules refuse it, nothing else has
    // happened yet — no trip tickets and no approval alerts for City Hall to
    // chase. Each ticket id is stamped on right after it is issued.
    await ref.set(
      AssignmentManual(
        id: ref.id,
        title: title.trim().isEmpty ? 'Collection manual' : title.trim(),
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
      ).toMap(),
    );

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

  /// Catches a driver or plate booked twice inside the same manual before any
  /// write happens.
  static void _checkBatchConflicts(List<ManualAssignment> assignments) {
    for (var i = 0; i < assignments.length; i++) {
      for (var j = i + 1; j < assignments.length; j++) {
        final left = assignments[i];
        final right = assignments[j];
        if (!left.days.any(right.days.contains)) continue;
        final sameDriver = manualSameDriver(
          driverId: left.driverId,
          driverName: left.driverName,
          otherDriverId: right.driverId,
          otherDriverName: right.driverName,
        );
        final sameTruck =
            left.truckId.isNotEmpty && left.truckId == right.truckId;
        if (!sameDriver && !sameTruck) continue;
        // Six hours between shifts for a driver; a plate cannot be on two
        // routes at the same moment.
        final clash = sameDriver
            ? manualSlotsClash(left.startTime, right.startTime)
            : left.startTime == right.startTime;
        if (!clash) continue;
        final shared = left.days
            .where(right.days.contains)
            .map(manualDayLabel)
            .join(', ');
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
