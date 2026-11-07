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

  Future<void> validate({
    required WasteSubmission submission,
    required WasteStatus status,
    required String actorName,
    String? remarks,
  }) async {
    await _col.doc(submission.id).update({
      'status': status.name,
      'remarks': remarks?.trim(),
      'validatedBy': actorName,
      'validatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
              : 'Your waste upload was validated by barangay staff.',
      type: AppNotificationType.waste,
      data: {'wasteId': submission.id},
    );
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
