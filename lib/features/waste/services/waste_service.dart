import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/waste_submission.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

class WasteService {
  static final WasteService _instance = WasteService._internal();
  factory WasteService() => _instance;
  WasteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('wasteSubmissions');

  Stream<List<WasteSubmission>> watchMine(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_sorted);
  }

  Stream<List<WasteSubmission>> watchAll() => _col.snapshots().map(_sorted);

  List<WasteSubmission> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final items = snap.docs
        .map((doc) => WasteSubmission.fromDoc(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    return items;
  }

  Future<String> submit({
    required String userId,
    required String userName,
    required String description,
    required WasteCategory category,
    required String quantity,
    required String location,
    String? barangay,
    required List<UploadPayload> images,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'userId': userId,
      'userName': userName,
      'description': description.trim(),
      'category': category.name,
      'quantity': quantity.trim(),
      'location': location.trim(),
      'barangay': barangay,
      'images': images.map((image) => image.toMap()).toList(),
      'status': WasteStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyStaff(
      title: 'New waste upload',
      body: '$userName submitted ${category.label.toLowerCase()} waste for validation.',
      type: AppNotificationType.waste,
      data: {'wasteId': ref.id},
    );
    return ref.id;
  }

  /// Validates a submission. Approving with [points] credits the resident in
  /// the same transaction and writes an immutable ledger row keyed by the
  /// submission id, so a double tap or a second reviewer cannot pay twice.
  Future<int> validate({
    required WasteSubmission submission,
    required WasteStatus status,
    required String actorId,
    required String actorName,
    String? remarks,
    int points = 0,
  }) async {
    final award = status == WasteStatus.approved && points > 0 ? points : 0;
    final ledgerRef = _db
        .collection('points_transactions')
        .doc('waste_${submission.id}');
    final userRef = _db.collection('users').doc(submission.userId);

    await _db.runTransaction((tx) async {
      final wasteRef = _col.doc(submission.id);
      final wasteSnap = await tx.get(wasteRef);
      if (!wasteSnap.exists) {
        throw const WasteException('Submission not found.');
      }
      final current = WasteStatusX.fromName(
        wasteSnap.data()?['status'] as String?,
      );
      if (current != WasteStatus.pending) {
        throw const WasteException(
          'This submission was already reviewed. Pull to refresh.',
        );
      }

      if (award > 0) {
        final ledgerSnap = await tx.get(ledgerRef);
        if (ledgerSnap.exists) {
          throw const WasteException(
            'Points were already credited for this submission.',
          );
        }
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw const WasteException('Resident account no longer exists.');
        }
        tx.set(ledgerRef, {
          'residentId': submission.userId,
          'residentName': submission.userName,
          'points': award,
          'reason': 'Waste validation · ${submission.category.label}',
          'sourceType': 'wasteSubmission',
          'sourceId': submission.id,
          'byUid': actorId,
          'byName': actorName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(userRef, {
          'points': FieldValue.increment(award),
          'pointsUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(wasteRef, {
        'status': status.name,
        'remarks': remarks?.trim(),
        'validatedBy': actorName,
        'validatedById': actorId,
        'validatedAt': FieldValue.serverTimestamp(),
        'pointsAwarded': award,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _notifications.push(
      userId: submission.userId,
      title: status == WasteStatus.rejected
          ? 'Waste submission rejected'
          : 'Waste submission approved',
      body: remarks?.trim().isNotEmpty == true
          ? remarks!.trim()
          : status == WasteStatus.rejected
              ? 'Your waste upload did not pass validation. Please review the segregation guidelines.'
              : award > 0
                  ? 'Your waste upload was validated. +$award points credited.'
                  : 'Your waste upload was validated by barangay staff.',
      type: award > 0
          ? AppNotificationType.points
          : AppNotificationType.waste,
      data: {
        'wasteId': submission.id,
        if (award > 0) 'points': award,
      },
    );

    return award;
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

class WasteException implements Exception {
  const WasteException(this.message);
  final String message;

  @override
  String toString() => message;
}
