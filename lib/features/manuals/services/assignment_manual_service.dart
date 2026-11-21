import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../models/assignment_manual.dart';

/// Reads and writes for the collection manual Iswim builds.
///
/// The manual is the roster entry; submitting it generates a trip ticket that
/// sits in City Hall's signature queue. Nothing here bypasses that approval:
/// the manual stays [AssignmentManualStatus.pendingApproval] until the City
/// Hall signature lands on the ticket.
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

  /// A driver or truck cannot hold two schedules on the same day at the same
  /// start time. Returns a human explanation, or null when the slot is free.
  Future<String?> findConflict({
    required String driverId,
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
        if (other.startTime != startTime) continue;
        if (!other.days.any(days.contains)) continue;
        final sameDriver = driverId.isNotEmpty && other.driverId == driverId;
        final sameTruck = truckId.isNotEmpty && other.truckId == truckId;
        if (!sameDriver && !sameTruck) continue;
        return '${other.driverName} is already assigned to '
            '${other.plateNumber} at $startTime on '
            '${other.days.where(days.contains).map(manualDayLabel).join(', ')}.';
      }
      return null;
    } catch (_) {
      // A failed pre-check must not block a legitimate submission; the same
      // validation runs again in the form before this call.
      return null;
    }
  }

  /// Saves the manual and generates its trip ticket in one go.
  ///
  /// The manual is saved first, then the ticket it generates; the ticket id is
  /// stamped back onto the manual. A refused manual write therefore leaves no
  /// orphan ticket and no approval alert behind.
  Future<AssignmentManual> submit({
    required String title,
    required String driverId,
    required String driverName,
    required String truckId,
    required String plateNumber,
    required int wheelers,
    required List<String> routes,
    List<ManualRoutePoint> routePoints = const [],
    required List<int> days,
    required String startTime,
    required ManualRecurrence recurrence,
    required String byId,
    required String byName,
    String? requestId,
  }) async {
    final conflict = await findConflict(
      driverId: driverId,
      truckId: truckId,
      days: days,
      startTime: startTime,
    );
    if (conflict != null) throw AssignmentException(conflict);

    final ref = _col.doc();
    // The manual is written first. If the rules refuse it, nothing else has
    // happened yet — no trip ticket and no approval alert for City Hall to
    // chase. The ticket id is stamped on right after it is issued.
    await ref.set(
      AssignmentManual(
        id: ref.id,
        title: title.trim().isEmpty ? 'Collection manual' : title.trim(),
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
        status: AssignmentManualStatus.pendingApproval,
        requestId: requestId,
        createdBy: byId,
        createdByName: byName,
      ).toMap(),
    );

    final ticket = await TicketService().createAssignment(
      assignmentId: ref.id,
      truckId: truckId,
      plateNumber: plateNumber,
      wheelers: wheelers,
      driverId: driverId,
      driverName: driverName,
      routes: routes,
      routePoints: routePoints,
      days: days,
      startTime: startTime,
      recurrence: recurrence,
      createdBy: byId,
    );

    await ref.update({
      'ticketId': ticket.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final saved = await ref.get();
    final manual = AssignmentManual.fromDoc(ref.id, saved.data()!)!;

    if (requestId != null && requestId.isNotEmpty) {
      try {
        await _db.collection('manual_requests').doc(requestId).update({
          'status': 'fulfilled',
          'assignmentManualId': ref.id,
          'ticketId': ticket.id,
          'fulfilledAt': FieldValue.serverTimestamp(),
          'fulfilledByName': byName,
        });
      } catch (_) {
        // The manual and ticket already exist; the request can be linked from
        // the request desk later.
      }
    }

    return manual;
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
