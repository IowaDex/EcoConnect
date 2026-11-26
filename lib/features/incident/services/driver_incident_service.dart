import 'package:cloud_firestore/cloud_firestore.dart';

import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/driver_incident.dart';

/// Crew incident reports.
///
/// The driver files one from the truck; it lands on the Iswim desk, which
/// decides whether the round is delayed and files the formal delay report.
/// Nothing here touches the DSQC chain directly — that stays Iswim's call.
class DriverIncidentService {
  DriverIncidentService._();
  static final DriverIncidentService instance = DriverIncidentService._();
  factory DriverIncidentService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('driver_incidents');

  /// Files a report and pushes it to the Iswim desk.
  ///
  /// Returns the new record's id. A failed notification write does not throw:
  /// the report is already saved and Iswim still sees it on the delay desk.
  Future<String> submit({
    required String driverId,
    required String driverName,
    required String plateNumber,
    required DriverIncidentKind kind,
    required String description,
    String zone = '',
    String? ticketId,
    double? latitude,
    double? longitude,
  }) async {
    final ref = await _col.add({
      'driverId': driverId,
      'driverName': driverName,
      'plateNumber': plateNumber,
      'zone': zone,
      'kind': kind.name,
      'description': description.trim(),
      'status': DriverIncidentStatus.open.name,
      if (ticketId != null) 'ticketId': ticketId,
      'lat': latitude,
      'lng': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyIswim(
      title: 'Driver incident · ${kind.label}',
      body:
          '$driverName (${plateNumber.isEmpty ? 'no plate' : plateNumber})'
          '${zone.isEmpty ? '' : ' on $zone'}: ${description.trim()}',
      type: AppNotificationType.request,
      data: {'kind': 'driverIncident', 'incidentId': ref.id},
      dedupeKey: 'driver_incident_${ref.id}',
    );

    return ref.id;
  }

  /// Reports the Iswim desk still has to look at, newest first.
  ///
  /// One equality filter only, sorted on the client: a `where` plus an
  /// `orderBy` would need a composite index the barangay has to deploy.
  Stream<List<DriverIncident>> watchOpen() => _col
      .where('status', isEqualTo: DriverIncidentStatus.open.name)
      .snapshots()
      .map((snap) {
        final items =
            snap.docs
                .map((doc) => DriverIncident.fromDoc(doc.id, doc.data()))
                .whereType<DriverIncident>()
                .toList()
              ..sort((a, b) {
                final left =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final right =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return right.compareTo(left);
              });
        return items;
      });

  /// Everything the crew filed, newest first, for a history view.
  Stream<List<DriverIncident>> watchMine(
    String driverId,
  ) => _col.where('driverId', isEqualTo: driverId).limit(30).snapshots().map((
    snap,
  ) {
    final items =
        snap.docs
            .map((doc) => DriverIncident.fromDoc(doc.id, doc.data()))
            .whereType<DriverIncident>()
            .toList()
          ..sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
    return items;
  });

  /// Marks the report seen, which takes it off the open queue.
  Future<void> acknowledge(String id, {required String byName}) =>
      _col.doc(id).update({
        'status': DriverIncidentStatus.acknowledged.name,
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'acknowledgedByName': byName,
      });

  Future<void> close(String id) =>
      _col.doc(id).update({'status': DriverIncidentStatus.closed.name});
}
