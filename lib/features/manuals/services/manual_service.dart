import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/manual.dart';

/// Manuals and manual requests.
///
/// Business rule: a manual update goes **directly** from Iswim to City Hall.
/// It is never routed through a district officer or the barangay, so both the
/// read rules and the notification targets only cover those two desks.
class ManualService {
  ManualService._();
  static final ManualService instance = ManualService._();
  factory ManualService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _manuals =>
      _db.collection('manuals');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('manual_requests');

  Stream<List<Manual>> watchManuals() => _manuals
      .orderBy('updatedAt', descending: true)
      .limit(60)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Manual.fromDoc(doc.id, doc.data()))
          .whereType<Manual>()
          .toList(growable: false));

  Stream<Manual?> watchOne(String id) => _manuals.doc(id).snapshots().map(
        (snap) => snap.exists ? Manual.fromDoc(snap.id, snap.data()!) : null,
      );

  Stream<List<ManualVersion>> watchVersions(String manualId) => _manuals
      .doc(manualId)
      .collection('versions')
      .limit(60)
      .snapshots()
      .map((snap) {
        final versions = snap.docs
            .map((doc) => ManualVersion.fromDoc(doc.id, doc.data()))
            .whereType<ManualVersion>()
            .toList()
          ..sort((a, b) => b.version.compareTo(a.version));
        return versions;
      });

  Stream<List<ManualRequest>> watchRequests() => _requests
      .orderBy('createdAt', descending: true)
      .limit(60)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => ManualRequest.fromDoc(doc.id, doc.data()))
          .whereType<ManualRequest>()
          .toList(growable: false));

  /// Creates a manual and its first version in one write.
  Future<String> createManual({
    required String title,
    required ManualCategory category,
    required String summary,
    required String notes,
    required UploadPayload file,
    required String byId,
    required String byName,
  }) async {
    final ref = _manuals.doc();
    final versionRef = ref.collection('versions').doc('v1');
    final batch = _db.batch();

    batch.set(ref, {
      'title': title.trim(),
      'category': category.name,
      'summary': summary.trim(),
      'version': 1,
      'status': ManualStatus.submitted.name,
      'createdBy': byId,
      'createdByName': byName,
      'currentNotes': notes.trim(),
      'file': file.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(versionRef, {
      'version': 1,
      'notes': notes.trim(),
      'file': file.toMap(),
      'submittedBy': byId,
      'submittedByName': byName,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await _notifications.notifyCityHall(
      title: 'New manual · ${title.trim()}',
      body: '$byName submitted version 1 of "${title.trim()}".',
      type: AppNotificationType.system,
      data: {'manualId': ref.id, 'kind': 'manualSubmitted'},
    );

    return ref.id;
  }

  /// Publishes the next revision. The version number is allocated inside a
  /// transaction so two devices cannot both write "version 2".
  Future<int> publishVersion({
    required Manual manual,
    required String notes,
    required UploadPayload file,
    required String byId,
    required String byName,
  }) async {
    final manualRef = _manuals.doc(manual.id);
    final version = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(manualRef);
      if (!snap.exists) throw const ManualException('Manual not found.');
      final current = (snap.data()?['version'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      final versionRef = manualRef.collection('versions').doc('v$next');

      tx.set(versionRef, {
        'version': next,
        'notes': notes.trim(),
        'file': file.toMap(),
        'submittedBy': byId,
        'submittedByName': byName,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      tx.update(manualRef, {
        'version': next,
        'status': ManualStatus.submitted.name,
        'currentNotes': notes.trim(),
        'file': file.toMap(),
        'acknowledgedAt': null,
        'acknowledgedByName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return next;
    });

    await _notifications.notifyCityHall(
      title: 'Manual updated · ${manual.title}',
      body: '$byName published version $version.',
      type: AppNotificationType.system,
      data: {
        'manualId': manual.id,
        'kind': 'manualUpdated',
        'version': version,
      },
    );

    return version;
  }

  /// City Hall records that it received the latest revision.
  Future<void> acknowledge({
    required Manual manual,
    required String byName,
  }) async {
    await _manuals.doc(manual.id).update({
      'status': ManualStatus.acknowledged.name,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedByName': byName,
    });

    await _notifications.notifyIswim(
      title: 'Manual received by City Hall',
      body: '${manual.title} v${manual.version} was acknowledged by $byName.',
      type: AppNotificationType.system,
      data: {'manualId': manual.id, 'kind': 'manualAcknowledged'},
    );
  }

  /// City Hall asks Iswim for a manual that does not exist yet.
  Future<String> requestManual({
    required String title,
    required String details,
    required String byName,
    DateTime? neededBy,
  }) async {
    final code = await _nextRequestCode();
    final ref = _requests.doc();
    await ref.set({
      'code': code,
      'title': title.trim(),
      'details': details.trim(),
      'requestedByName': byName,
      'status': ManualRequestStatus.pending.name,
      if (neededBy != null) 'neededBy': Timestamp.fromDate(neededBy),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyIswim(
      title: 'Manual request · $code',
      body: '$byName requested "${title.trim()}".',
      type: AppNotificationType.system,
      data: {'manualRequestId': ref.id, 'kind': 'manualRequested'},
    );

    return ref.id;
  }

  /// Iswim links a submitted manual to the request, closing the loop.
  Future<void> fulfillRequest({
    required ManualRequest request,
    required Manual manual,
    required String byName,
  }) async {
    await _requests.doc(request.id).update({
      'status': ManualRequestStatus.fulfilled.name,
      'manualId': manual.id,
      'fulfilledAt': FieldValue.serverTimestamp(),
      'fulfilledByName': byName,
    });

    await _notifications.notifyCityHall(
      title: 'Manual request fulfilled · ${request.code}',
      body: '$byName submitted "${manual.title}" v${manual.version}.',
      type: AppNotificationType.system,
      data: {
        'manualRequestId': request.id,
        'manualId': manual.id,
        'kind': 'manualRequestFulfilled',
      },
    );
  }

  Future<void> cancelRequest(ManualRequest request, {String? reason}) async {
    await _requests.doc(request.id).update({
      'status': ManualRequestStatus.cancelled.name,
      if (reason != null && reason.trim().isNotEmpty) 'cancelReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _nextRequestCode() async {
    final year = DateTime.now().year;
    final ref = _db.collection('counters').doc('manual_requests_$year');
    final next = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final value = current + 1;
      tx.set(ref, {'value': value}, SetOptions(merge: true));
      return value;
    });
    return 'MR-$year-${next.toString().padLeft(4, '0')}';
  }
}

class ManualException implements Exception {
  const ManualException(this.message);
  final String message;

  @override
  String toString() => message;
}
