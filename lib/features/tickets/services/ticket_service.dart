import 'package:cloud_firestore/cloud_firestore.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/trip_ticket.dart';

/// All reads and writes for trip tickets.
///
/// The chain is enforced here rather than in the UI: a ticket can only move to
/// the next status from the status before it, so two devices tapping at the
/// same time cannot skip a signature.
class TicketService {
  TicketService._();
  static final TicketService instance = TicketService._();
  factory TicketService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('trip_tickets');

  /// Tickets waiting on, or already handled by, one driver.
  ///
  /// A manual the driver has been named on shows up as soon as Iswim saves it,
  /// marked "waiting for City Hall", so the crew knows a schedule is coming
  /// even though the ticket is not theirs to take yet.
  Stream<List<TripTicket>> watchForDriver(String driverId) => _col
      .where('driverId', isEqualTo: driverId)
      .limit(50)
      .snapshots()
      .map(_parse);

  /// Everything issued against one truck — the per-truck history.
  Stream<List<TripTicket>> watchForTruck(String truckId) => _col
      .where('truckId', isEqualTo: truckId)
      .limit(100)
      .snapshots()
      .map(_parse)
      .map(_signedOnly);

  /// The truck history is also read by the guide and by residents, so a manual
  /// that City Hall has not signed is left out of it.
  static List<TripTicket> _signedOnly(List<TripTicket> tickets) =>
      tickets.where((t) => !t.approvalPending).toList(growable: false);

  /// The signature queue for one signer: `barangay`, `iswim` or `cityHall`.
  Stream<List<TripTicket>> watchSignerQueue(TicketStatusSigner signer) => _col
      .where('pendingSigner', isEqualTo: signer.wireName)
      .limit(50)
      .snapshots()
      .map(_parse);

  /// Everything Iswim has issued, newest first.
  ///
  /// The desk dashboard raises [limit] so it can search a full year of
  /// records; the smaller default keeps the mobile lists light.
  Stream<List<TripTicket>> watchAll({int limit = 100}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_parse);

  Stream<TripTicket?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (snap) =>
            snap.exists ? TripTicket.fromDoc(snap.id, snap.data()!) : null,
      );

  /// Sorted here, not in the query: a `where` plus `orderBy` on another field
  /// would demand a composite index the barangay would have to deploy.
  static List<TripTicket> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final tickets = snap.docs
        .map((doc) => TripTicket.fromDoc(doc.id, doc.data()))
        .whereType<TripTicket>()
        .toList();
    tickets.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return tickets;
  }

  /// Issues a ticket. Iswim always names the truck, and the truck's permanent
  /// driver comes with it.
  Future<TripTicket> create({
    required String truckId,
    required String plateNumber,
    required int wheelers,
    required String driverId,
    required String driverName,
    required String route,
    required String zone,
    required String date,
    required String windowStart,
    required String windowEnd,
    required String notes,
    required int wave,
    required String createdBy,
  }) async {
    final code = await _nextCode();
    final draft = TripTicket(
      id: '',
      code: code,
      wave: wave,
      truckId: truckId,
      plateNumber: plateNumber,
      wheelers: wheelers,
      driverId: driverId,
      driverName: driverName,
      route: route,
      zone: zone,
      date: date,
      windowStart: windowStart,
      windowEnd: windowEnd,
      notes: notes,
      status: TicketStatus.issued,
      createdBy: createdBy,
    );

    final ref = await _col.add(draft.toMap());

    // The driver hears about it immediately; he cannot move until he accepts.
    if (driverId.isNotEmpty) {
      await _notifications.push(
        userId: driverId,
        title: 'New trip ticket · ${draft.code}',
        body: '$plateNumber · $route ($zone). Accept it to start the trip.',
        type: AppNotificationType.request,
        data: {'ticketId': ref.id, 'kind': 'ticketIssued'},
        dedupeKey: 'ticket_${ref.id}_issued',
      );
    }

    final snap = await ref.get();
    return TripTicket.fromDoc(ref.id, snap.data()!)!;
  }

  /// `TT-2026-0001` — one counter per year so codes never repeat.
  Future<String> _nextCode() async {
    final year = DateTime.now().year;
    final ref = _db.collection('counters').doc('trip_tickets_$year');
    final next = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final value = current + 1;
      tx.set(ref, {'value': value}, SetOptions(merge: true));
      return value;
    });
    return 'TT-$year-${next.toString().padLeft(4, '0')}';
  }

  /// Issues a manual ticket: the schedule Iswim builds from a City Hall manual
  /// request. It starts in `issued` (the only status the rules accept on
  /// create) with [TripTicket.approvalPending] set, so City Hall sees it in
  /// its signature queue and the driver sees "waiting for approval" instead of
  /// an accept button.
  Future<TripTicket> createAssignment({
    required String assignmentId,
    required String truckId,
    required String plateNumber,
    required int wheelers,
    required String driverId,
    required String driverName,
    required List<String> routes,
    List<ManualRoutePoint> routePoints = const [],
    required List<int> days,
    required String startTime,
    required ManualRecurrence recurrence,
    required String createdBy,
  }) async {
    final code = await _nextCode();
    final draft = TripTicket(
      id: '',
      code: code,
      wave: 1,
      truckId: truckId,
      plateNumber: plateNumber,
      wheelers: wheelers,
      driverId: driverId,
      driverName: driverName,
      route: routes.join(' · '),
      zone: '',
      date: '',
      windowStart: startTime,
      windowEnd: '',
      notes: '',
      status: TicketStatus.issued,
      createdBy: createdBy,
      kind: TicketKind.assignment,
      routes: routes,
      routePoints: routePoints,
      days: days,
      recurrence: recurrence,
      assignmentId: assignmentId,
      approvalPending: true,
    );

    final data = draft.toMap();
    // The manual ticket is never the driver's to accept: City Hall signs it
    // first, then the schedule becomes valid.
    data['pendingSigner'] = TicketStatusSigner.cityHall.wireName;
    data['approvalPending'] = true;
    final ref = await _col.add(data);

    await _notifications.notifyCityHall(
      title: 'Manual awaiting your approval · ${draft.code}',
      body:
          '${draft.plateNumber} · ${draft.driverName} · '
          '${draft.scheduleLabel}. Sign it to make the schedule valid.',
      type: AppNotificationType.system,
      data: {'ticketId': ref.id, 'kind': 'manualApproval'},
      dedupeKey: 'manual_ticket_${ref.id}_approval',
    );

    // The crew hears about the schedule as soon as it is written, with the
    // approval still pending, so nobody is surprised when the ticket turns
    // valid. It is not theirs to accept yet.
    if (driverId.isNotEmpty) {
      await _notifications.push(
        userId: driverId,
        title: 'New schedule · waiting for City Hall',
        body:
            '${draft.plateNumber} · ${draft.routesLabel} · '
            '${draft.scheduleLabel}. City Hall still has to sign it.',
        type: AppNotificationType.route,
        data: {'ticketId': ref.id, 'kind': 'manualAssigned'},
        dedupeKey: 'assignment_${ref.id}_assigned',
      );
    }

    final snap = await ref.get();
    return TripTicket.fromDoc(ref.id, snap.data()!)!;
  }

  /// The driver marks a City Hall-approved manual run as done. There is no end
  /// time on a manual, so this is the only completion signal.
  Future<void> completeAssignment(
    String id, {
    String byUid = '',
    String byName = 'Driver',
  }) async {
    final ticket = await _load(id);
    if (!ticket.isAssignment) {
      throw const TicketException('This ticket is not a manual schedule.');
    }
    await _advance(
      id,
      from: TicketStatus.valid,
      data: {
        'status': TicketStatus.completed.name,
        'pendingSigner': null,
        'completedAt': FieldValue.serverTimestamp(),
      },
      byUid: byUid,
      byName: byName,
      note: 'Run marked complete by the driver',
    );
    await _notifications.notifyIswim(
      title: 'Manual run completed · ${ticket.code}',
      body:
          '${ticket.plateNumber} · ${ticket.driverName} completed '
          '${ticket.routesLabel}.',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'assignmentCompleted'},
      dedupeKey: 'assignment_${id}_completed',
    );
  }

  Future<void> accept(
    String id, {
    String byUid = '',
    String byName = 'Driver',
  }) async {
    final ticket = await _load(id);
    if (ticket.approvalPending) {
      throw const TicketException(
        'This manual is waiting for the City Hall signature.',
      );
    }
    await _advance(
      id,
      from: TicketStatus.issued,
      data: {
        'status': TicketStatus.accepted.name,
        'pendingSigner': null,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
      byUid: byUid,
      byName: byName,
      note: 'Ticket received by driver',
    );
  }

  Future<void> decline(
    String id,
    String reason, {
    String byUid = '',
    String byName = 'Driver',
  }) async {
    await _advance(
      id,
      from: TicketStatus.issued,
      data: {
        'status': TicketStatus.declined.name,
        'pendingSigner': null,
        'declineReason': reason,
      },
      byUid: byUid,
      byName: byName,
      note: reason,
    );
    await _notifications.notifyIswim(
      title: 'Trip ticket declined',
      body: '$byName declined a ticket: $reason',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketDeclined'},
      dedupeKey: 'ticket_${id}_declined',
    );
  }

  /// Called when the driver actually starts moving on this ticket.
  Future<void> markRunning(
    String id, {
    String byUid = '',
    String byName = 'Driver',
  }) async {
    await _advance(
      id,
      from: TicketStatus.accepted,
      data: {
        'status': TicketStatus.running.name,
        'startedAt': FieldValue.serverTimestamp(),
      },
      byUid: byUid,
      byName: byName,
      note: 'Route started',
    );
  }

  /// End of trip: the driver submits and the ticket walks to the barangay.
  Future<void> submit(
    String id, {
    String driverName = 'Driver',
    String byUid = '',
    String note = 'Route completed and submitted',
  }) async {
    final ticket = await _load(id);
    await _advance(
      id,
      from: TicketStatus.running,
      data: {
        'status': TicketStatus.submitted.name,
        'pendingSigner': TicketStatusSigner.barangay.wireName,
        'submittedAt': FieldValue.serverTimestamp(),
      },
      byUid: byUid,
      byName: driverName,
      note: note,
    );
    await _notifications.notifyStaff(
      title: 'Trip ticket for signature',
      body: '$driverName submitted a trip ticket. Barangay signature needed.',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketSubmitted'},
      dedupeKey: 'ticket_${id}_submitted_${ticket.history.length}',
    );
  }

  /// Barangay returns the ticket to the driver instead of approving it. The
  /// driver can correct the trip and submit again; the previous record stays
  /// in the audit trail.
  Future<void> returnForRevision({
    required String id,
    required String reason,
    required String byUid,
    required String byName,
  }) async {
    final ticket = await _load(id);
    await _advance(
      id,
      from: TicketStatus.submitted,
      data: {
        'status': TicketStatus.revisionRequired.name,
        'pendingSigner': TicketStatusSigner.driver.wireName,
        'revisionReason': reason,
      },
      byUid: byUid,
      byName: byName,
      note: reason,
    );
    await _notifications.push(
      userId: ticket.driverId,
      title: 'Trip ticket needs revision · ${ticket.code}',
      body: reason,
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketRevision'},
      dedupeKey: 'ticket_${id}_revision_${ticket.history.length}',
    );
  }

  /// Final rejection. Barangay can reject before signing, Iswim can reject
  /// after the barangay approved.
  Future<void> reject({
    required String id,
    required String reason,
    required String byUid,
    required String byName,
  }) async {
    final ticket = await _load(id);
    await _advanceFromAny(
      id,
      allowed: const [TicketStatus.submitted, TicketStatus.barangaySigned],
      data: {
        'status': TicketStatus.rejected.name,
        'pendingSigner': null,
        'rejectionReason': reason,
      },
      byUid: byUid,
      byName: byName,
      note: reason,
    );
    await _notifications.push(
      userId: ticket.driverId,
      title: 'Trip ticket rejected · ${ticket.code}',
      body: reason,
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketRejected'},
      dedupeKey: 'ticket_${id}_rejected_${ticket.history.length}',
    );
    await _notifications.notifyStaff(
      title: 'Trip ticket rejected · ${ticket.code}',
      body: '$byName rejected the ticket: $reason',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketRejected'},
      dedupeKey: 'ticket_${id}_rejected_staff_${ticket.history.length}',
    );
  }

  /// Driver resubmits after a barangay revision request.
  Future<void> resubmit({
    required String id,
    required String byUid,
    required String byName,
    String note = 'Corrected and resubmitted',
  }) async {
    final ticket = await _load(id);
    await _advance(
      id,
      from: TicketStatus.revisionRequired,
      data: {
        'status': TicketStatus.submitted.name,
        'pendingSigner': TicketStatusSigner.barangay.wireName,
        'submittedAt': FieldValue.serverTimestamp(),
      },
      byUid: byUid,
      byName: byName,
      note: note,
    );
    await _notifications.notifyStaff(
      title: 'Trip ticket resubmitted',
      body: '$byName corrected and resubmitted a trip ticket.',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketResubmitted'},
      dedupeKey: 'ticket_${id}_resubmitted_${ticket.history.length}',
    );
  }

  /// One signature. Barangay -> Iswim -> City Hall, then the chain closes and
  /// the barangay keeps a signed copy.
  Future<TicketStatus> sign({
    required String id,
    required TicketStatusSigner signer,
    required String uid,
    required String name,
    required String image,
  }) async {
    final doc = await _col.doc(id).get();
    final ticket = TripTicket.fromDoc(doc.id, doc.data() ?? {});
    if (ticket == null) throw const TicketException('Ticket not found.');

    // Only the expected signer may sign, in order.
    final expected = ticket.awaitingSignature;
    if (expected != signer) {
      throw TicketException(
        'This ticket is waiting for ${expected?.label ?? 'no one'} — not '
        '${signer.label}.',
      );
    }

    // A manual ticket stops at City Hall: its signature turns the schedule
    // valid instead of closing the barangay -> Iswim -> City Hall chain.
    final approvingManual =
        ticket.approvalPending && signer == TicketStatusSigner.cityHall;

    final next = approvingManual
        ? TicketStatus.valid
        : switch (signer) {
            TicketStatusSigner.barangay => TicketStatus.barangaySigned,
            TicketStatusSigner.iswim => TicketStatus.iswimSigned,
            TicketStatusSigner.cityHall => TicketStatus.completed,
            TicketStatusSigner.driver => TicketStatus.submitted,
          };

    await _col.doc(id).update({
      'signatures.${signer.wireName}': {
        'name': name,
        'uid': uid,
        'image': image,
        'signedAt': FieldValue.serverTimestamp(),
      },
      'status': next.name,
      'pendingSigner': next.pendingSigner?.wireName,
      if (approvingManual) 'approvalPending': false,
      if (next == TicketStatus.completed)
        'completedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        TicketHistoryEntry(
          status: next,
          previousStatus: ticket.status,
          byUid: uid,
          byName: name,
          note: approvingManual
              ? 'Manual approved by City Hall'
              : '${signer.label} signature recorded',
        ).toMap(),
      ]),
    });

    if (approvingManual) {
      await _approveManual(ticket, byName: name);
      await _notifications.notifyIswim(
        title: 'Manual request, approved · ${ticket.code}',
        body:
            'City Hall approved ${ticket.driverName}\'s schedule for '
            '${ticket.plateNumber}. The trip ticket is now valid.',
        type: AppNotificationType.system,
        data: {'ticketId': id, 'kind': 'manualApproved'},
        dedupeKey: 'manual_ticket_${id}_approved',
      );
      // The barangay keeps a copy of the approved schedule, and residents get
      // the route and collection time on their own desk.
      await _notifications.notifyStaff(
        title: 'Collection schedule approved · ${ticket.code}',
        body:
            '${ticket.plateNumber} · ${ticket.driverName} · '
            '${ticket.scheduleLabel}. ${ticket.routesLabel}',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'manualApprovedCopy'},
        dedupeKey: 'manual_ticket_${id}_approved_staff',
      );
      await _notifications.notifyResidents(
        title: 'Collection schedule · ${ticket.routesLabel}',
        body:
            '${ticket.scheduleLabel}. Truck ${ticket.plateNumber} will cover '
            'your area.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'manualApprovedSchedule'},
        dedupeKey: 'manual_ticket_${id}_approved_residents',
      );
      // The driver only hears about the run once City Hall has signed it.
      if (ticket.driverId.isNotEmpty) {
        await _notifications.push(
          userId: ticket.driverId,
          title: 'Collection schedule approved · ${ticket.code}',
          body:
              '${ticket.plateNumber} · ${ticket.routesLabel} · '
              '${ticket.scheduleLabel}. Mark the run complete when you finish.',
          type: AppNotificationType.route,
          data: {'ticketId': id, 'kind': 'manualApprovedDriver'},
          dedupeKey: 'assignment_${id}_approved',
        );
      }
    }

    // Each hop tells the next signer that the document is waiting for them.
    if (next == TicketStatus.barangaySigned) {
      await _notifications.notifyIswim(
        title: 'Signed trip ticket · ${ticket.code}',
        body:
            'Barangay signed ${ticket.plateNumber} (${ticket.driverName}). '
            'Iswim verification is next.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'ticketBarangaySigned'},
        dedupeKey: 'ticket_${id}_barangay_signed',
      );
    }
    if (next == TicketStatus.iswimSigned) {
      await _notifications.notifyCityHall(
        title: 'Trip ticket for final signature · ${ticket.code}',
        body:
            '${ticket.plateNumber} · ${ticket.driverName} was verified by '
            'Iswim and needs the City Hall signature.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'ticketIswimSigned'},
        dedupeKey: 'ticket_${id}_iswim_signed',
      );
    }

    // Signed copy goes back to the barangay the moment City Hall signs.
    if (next == TicketStatus.completed) {
      await _notifications.notifyStaff(
        title: 'Trip ticket signed copy · ${ticket.code}',
        body:
            '${ticket.plateNumber} · ${ticket.driverName}. Fully signed by '
            'Barangay, Iswim and City Hall.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'ticketCompleted'},
        dedupeKey: 'ticket_${id}_completed_staff',
      );
      await _notifications.notifyIswim(
        title: 'Trip ticket completed · ${ticket.code}',
        body:
            'City Hall signed ${ticket.plateNumber}. The signed copy is '
            'ready to forward.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'ticketCompleted'},
        dedupeKey: 'ticket_${id}_completed_iswim',
      );
    }

    return next;
  }

  /// Mirrors City Hall's approval onto the assignment manual and closes the
  /// manual request that started it. Best effort: the ticket is already valid,
  /// so a failed mirror must not surface as a signing error.
  Future<void> _approveManual(
    TripTicket ticket, {
    required String byName,
  }) async {
    final assignmentId = ticket.assignmentId;
    if (assignmentId == null || assignmentId.isEmpty) return;
    try {
      await _db.collection('assignment_manuals').doc(assignmentId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedByName': byName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final requests = await _db
          .collection('manual_requests')
          .where('assignmentManualId', isEqualTo: assignmentId)
          .get();
      if (requests.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in requests.docs) {
        batch.update(doc.reference, {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedByName': byName,
        });
      }
      await batch.commit();
    } catch (_) {
      // The ticket is the source of truth; the mirror can be repaired later.
    }
  }

  Future<void> cancel(String id) async {
    await _col.doc(id).update({
      'status': TicketStatus.cancelled.name,
      'pendingSigner': null,
    });
  }

  Future<TripTicket> _load(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) throw const TicketException('Ticket not found.');
    return TripTicket.fromDoc(snap.id, snap.data()!)!;
  }

  /// Status-guarded write: the ticket must still be in [from], so a double tap
  /// or a second device cannot move it twice.
  Future<void> _advance(
    String id, {
    required TicketStatus from,
    required Map<String, dynamic> data,
    String byUid = '',
    String byName = '',
    String note = '',
  }) => _advanceFromAny(
    id,
    allowed: [from],
    data: data,
    byUid: byUid,
    byName: byName,
    note: note,
  );

  /// Same guard, but accepts one of several current statuses. Used by the
  /// rejection step, which can happen before or after the barangay signature.
  Future<void> _advanceFromAny(
    String id, {
    required List<TicketStatus> allowed,
    required Map<String, dynamic> data,
    String byUid = '',
    String byName = '',
    String note = '',
  }) async {
    final next = TicketStatusX.fromName(data['status'] as String?);
    final entry = TicketHistoryEntry(
      status: next,
      previousStatus: null,
      byUid: byUid,
      byName: byName,
      note: note,
    );
    await _db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const TicketException('Ticket not found.');
      final current = TicketStatusX.fromName(snap.data()?['status'] as String?);
      if (!allowed.contains(current)) {
        throw TicketException(
          'This ticket already moved (${current.label}). Pull to refresh.',
        );
      }
      // Fill the previous status from the document so the audit entry is
      // accurate even when the caller allowed several statuses.
      tx.update(ref, {
        ...data,
        'history': FieldValue.arrayUnion([
          {...entry.toMap(), 'previousStatus': current.name},
        ]),
      });
    });
  }
}

class TicketException implements Exception {
  const TicketException(this.message);
  final String message;

  @override
  String toString() => message;
}
