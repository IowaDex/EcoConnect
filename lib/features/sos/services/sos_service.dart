import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/services/provisioning_service.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/sos_incident.dart';

/// The result of sending one SOS: the saved incident and how many officers it
/// actually reached.
class SosDispatch {
  const SosDispatch({required this.incident, required this.officerCount});

  final SosIncident incident;
  final int officerCount;

  bool get reachedAnyone => officerCount > 0;
}

/// SOS incidents at `sos_incidents/{id}`.
///
/// DSQC writes the incident and the service addresses it to the District
/// Officers who cover that district. The officers read only their own district,
/// and a call is a separate record that never changes the incident status.
class SosService {
  SosService({FirebaseFirestore? firestore, NotificationService? notifications})
    : _db = firestore ?? FirebaseFirestore.instance,
      _notifications = notifications ?? NotificationService();

  final FirebaseFirestore _db;
  final NotificationService _notifications;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sos_incidents');

  /// Every incident, newest first. City Hall's monitoring board.
  Stream<List<SosIncident>> watchAll() => _col.limit(100).snapshots().map(
    (snap) => _sorted(snap.docs),
  );

  /// The incidents addressed to one officer.
  ///
  /// The district query is what the security rules allow; an officer whose
  /// account has no district falls back to the incidents that named them
  /// personally, so nothing is silently shown outside their assignment.
  Stream<List<SosIncident>> watchForOfficer({
    required String uid,
    String? district,
  }) {
    final value = district?.trim() ?? '';
    final query = value.isEmpty
        ? _col.where('officerUids', arrayContains: uid)
        : _col.where('district', isEqualTo: value);
    return query.limit(100).snapshots().map((snap) => _sorted(snap.docs));
  }

  /// The incidents for one barangay, for the barangay desk's reference.
  Stream<List<SosIncident>> watchForBarangay(String barangay) => _col
      .where('barangay', isEqualTo: barangay)
      .limit(100)
      .snapshots()
      .map((snap) => _sorted(snap.docs));

  Stream<SosIncident?> watchOne(String id) => _col.doc(id).snapshots().map(
    (snap) => snap.exists ? SosIncident.fromDoc(snap.id, snap.data()!) : null,
  );

  Future<SosIncident?> get(String id) async {
    final snap = await _col.doc(id).get();
    return snap.exists ? SosIncident.fromDoc(snap.id, snap.data()!) : null;
  }

  static List<SosIncident> _sorted(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final items = docs
        .map((doc) => SosIncident.fromDoc(doc.id, doc.data()))
        .whereType<SosIncident>()
        .toList();
    items.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return items;
  }

  /// Saves the incident and rings the right District Officer.
  ///
  /// [submissionId] is generated once when the form opens. A double tap or a
  /// retry reuses it, so the same SOS cannot produce two records.
  Future<SosDispatch> send({
    required String submissionId,
    required String description,
    required String reason,
    required DateTime incidentAt,
    required String district,
    required String barangay,
    required String createdBy,
    required String createdByName,
    String? truckPlate,
    String? route,
  }) async {
    final ref = _col.doc(submissionId);
    final existing = await ref.get();
    if (existing.exists) {
      final incident = SosIncident.fromDoc(ref.id, existing.data()!);
      if (incident != null) {
        // The record was written but the dispatch step did not finish. Retry
        // it so a failed notification is not silently lost.
        if (incident.notifiedAt == null) {
          final retried = await _dispatch(
            ref: ref,
            code: incident.code,
            reason: incident.reason,
            district: incident.district,
            barangay: incident.barangay,
          );
          return retried;
        }
        return SosDispatch(
          incident: incident,
          officerCount: incident.officerUids.length,
        );
      }
    }

    final code = await _nextCode();
    await ref.set({
      'code': code,
      'description': description.trim(),
      'reason': reason.trim(),
      'incidentAt': Timestamp.fromDate(incidentAt),
      'district': district.trim(),
      'barangay': barangay.trim(),
      if (truckPlate != null && truckPlate.trim().isNotEmpty)
        'truckPlate': truckPlate.trim(),
      if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
      'status': SosStatus.newAlert.name,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'officerUids': <String>[],
    });

    return _dispatch(
      ref: ref,
      code: code,
      reason: reason.trim(),
      district: district.trim(),
      barangay: barangay.trim(),
    );
  }

  /// Addresses a saved incident to the officers of its district and records
  /// who it reached. Safe to run twice: the notification keys are stable.
  Future<SosDispatch> _dispatch({
    required DocumentReference<Map<String, dynamic>> ref,
    required String code,
    required String reason,
    required String district,
    required String barangay,
  }) async {
    final officers = await ProvisioningService().officersForDistrict(district);
    final officerUids = officers.map((officer) => officer.uid).toList();

    for (final officer in officers) {
      await _notifications.push(
        userId: officer.uid,
        title: 'SOS ALERT · $code',
        body:
            '$reason · $barangay, $district. '
            'Open the alert for the full incident details.',
        type: AppNotificationType.sos,
        data: {
          'kind': 'sos',
          'sosId': ref.id,
          'code': code,
          'district': district,
          'barangay': barangay,
        },
        dedupeKey: 'sos_${ref.id}_${officer.uid}',
      );
    }

    // Nobody covers the district: City Hall must see that before it assumes
    // the alert was delivered.
    if (officers.isEmpty) {
      await _notifications.notifyCityHall(
        title: 'SOS not assigned · $code',
        body:
            'No active District Officer is assigned to $district. '
            'Assign one and contact the barangay directly.',
        type: AppNotificationType.sos,
        data: {'kind': 'sos', 'sosId': ref.id, 'code': code},
        dedupeKey: 'sos_${ref.id}_unassigned',
      );
    }

    await ref.update({
      'officerUids': officerUids,
      'notifiedAt': FieldValue.serverTimestamp(),
    });

    final saved = await ref.get();
    final incident = SosIncident.fromDoc(ref.id, saved.data()!)!;
    return SosDispatch(incident: incident, officerCount: officers.length);
  }

  /// Moves the incident along its own track. Ending a call never calls this.
  Future<void> setStatus(
    String id,
    SosStatus status, {
    required String uid,
    required String name,
    String? resolutionNote,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _col.doc(id).update({
      'status': status.name,
      'statusUpdatedAt': now,
      'statusUpdatedBy': uid,
      'statusUpdatedByName': name,
      if (status == SosStatus.acknowledged) 'receivedAt': now,
      if (status == SosStatus.acknowledged) 'acknowledgedAt': now,
      if (status == SosStatus.coordinating) 'coordinatingAt': now,
      if (status == SosStatus.resolved) 'resolvedAt': now,
      if (status == SosStatus.resolved) 'resolvedBy': uid,
      if (status == SosStatus.resolved) 'resolvedByName': name,
      if (status == SosStatus.resolved && resolutionNote != null)
        'resolutionNote': resolutionNote.trim(),
    });
  }

  /// Opening the incident is the acknowledgement: no extra button.
  Future<void> markAcknowledged(
    String id, {
    required String uid,
    required String name,
  }) async {
    final incident = await get(id);
    if (incident == null || incident.status != SosStatus.newAlert) return;
    await setStatus(id, SosStatus.acknowledged, uid: uid, name: name);
  }

  /// The officer started contacting the barangay. Only ever moves forward, so
  /// a second call on an already resolved incident cannot reopen it.
  Future<void> markCoordinating(
    String id, {
    required String uid,
    required String name,
  }) async {
    final incident = await get(id);
    if (incident == null) return;
    if (incident.status != SosStatus.newAlert &&
        incident.status != SosStatus.acknowledged) {
      return;
    }
    await setStatus(id, SosStatus.coordinating, uid: uid, name: name);
  }

  /// Closes the incident with the officer's outcome note.
  Future<void> resolve(
    String id, {
    required String uid,
    required String name,
    String? note,
  }) async {
    final incident = await get(id);
    if (incident == null || incident.status == SosStatus.resolved) return;
    await setStatus(
      id,
      SosStatus.resolved,
      uid: uid,
      name: name,
      resolutionNote: note,
    );
  }

  Future<String> _nextCode() async {
    final year = DateTime.now().year;
    final ref = _db.collection('counters').doc('sos_incidents_$year');
    final next = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final value = current + 1;
      tx.set(ref, {'value': value}, SetOptions(merge: true));
      return value;
    });
    return 'SOS-$year-${next.toString().padLeft(4, '0')}';
  }
}
