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
      .map(_parse);

  /// The signature queue for one signer: `barangay`, `iswim` or `cityHall`.
  Stream<List<TripTicket>> watchSignerQueue(TicketStatusSigner signer) => _col
      .where('pendingSigner', isEqualTo: signer.wireName)
      .limit(50)
      .snapshots()
      .map(_parse);

  /// Everything Iswim has issued, newest first.
  Stream<List<TripTicket>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(_parse);

  Stream<TripTicket?> watchOne(String id) => _col.doc(id).snapshots().map(
        (snap) => snap.exists ? TripTicket.fromDoc(snap.id, snap.data()!) : null,
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

  Future<void> accept(String id) async {
    await _advance(
      id,
      from: TicketStatus.issued,
      data: {
        'status': TicketStatus.accepted.name,
        'pendingSigner': null,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> decline(String id, String reason) async {
    await _advance(
      id,
      from: TicketStatus.issued,
      data: {
        'status': TicketStatus.declined.name,
        'pendingSigner': null,
        'declineReason': reason,
      },
    );
  }

  /// Called when the driver actually starts moving on this ticket.
  Future<void> markRunning(String id) async {
    await _advance(
      id,
      from: TicketStatus.accepted,
      data: {
        'status': TicketStatus.running.name,
        'startedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// End of trip: the driver submits and the ticket walks to the barangay.
  Future<void> submit(String id, {String driverName = 'Driver'}) async {
    await _advance(
      id,
      from: TicketStatus.running,
      data: {
        'status': TicketStatus.submitted.name,
        'pendingSigner': TicketStatusSigner.barangay.wireName,
        'submittedAt': FieldValue.serverTimestamp(),
      },
    );
    await _notifications.notifyStaff(
      title: 'Trip ticket for signature',
      body: '$driverName submitted a trip ticket. Barangay signature needed.',
      type: AppNotificationType.route,
      data: {'ticketId': id, 'kind': 'ticketSubmitted'},
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

    final next = switch (signer) {
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
      if (next == TicketStatus.completed)
        'completedAt': FieldValue.serverTimestamp(),
    });

    // Signed copy goes back to the barangay the moment City Hall signs.
    if (next == TicketStatus.completed) {
      await _notifications.notifyStaff(
        title: 'Trip ticket signed copy · ${ticket.code}',
        body: '${ticket.plateNumber} · ${ticket.driverName}. Fully signed by '
            'Barangay, Iswim and City Hall.',
        type: AppNotificationType.route,
        data: {'ticketId': id, 'kind': 'ticketCompleted'},
      );
    }

    return next;
  }

  Future<void> cancel(String id) async {
    await _col.doc(id).update({
      'status': TicketStatus.cancelled.name,
      'pendingSigner': null,
    });
  }

  /// Status-guarded write: the ticket must still be in [from], so a double tap
  /// or a second device cannot move it twice.
  Future<void> _advance(
    String id, {
    required TicketStatus from,
    required Map<String, dynamic> data,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const TicketException('Ticket not found.');
      final current = TicketStatusX.fromName(
        snap.data()?['status'] as String?,
      );
      if (current != from) {
        throw TicketException(
          'This ticket already moved (${current.label}). Pull to refresh.',
        );
      }
      tx.update(ref, data);
    });
  }
}

class TicketException implements Exception {
  const TicketException(this.message);
  final String message;

  @override
  String toString() => message;
}
