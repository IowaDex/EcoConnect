import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/complaint.dart';

/// Complaints go directly to DSQC / City Hall. They never enter the barangay
/// collection queue, so no staff-channel notification is written here.
class ComplaintService {
  ComplaintService._();
  static final ComplaintService instance = ComplaintService._();
  factory ComplaintService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('complaints');

  Stream<List<Complaint>> watchMine(String residentId) => _col
      .where('residentId', isEqualTo: residentId)
      .limit(50)
      .snapshots()
      .map(_parse);

  Stream<List<Complaint>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .limit(80)
      .snapshots()
      .map(_parse);

  /// One complaint, live, so an open thread shows new replies from either side.
  Stream<Complaint?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (doc) =>
            doc.data() == null ? null : Complaint.fromDoc(doc.id, doc.data()!),
      );

  static List<Complaint> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final items = snap.docs
        .map((doc) => Complaint.fromDoc(doc.id, doc.data()))
        .whereType<Complaint>()
        .toList();
    items.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return items;
  }

  Future<String> submit({
    required String residentId,
    required String residentName,
    String? residentBarangay,
    required String title,
    required String description,
    required ComplaintCategory category,
    String? location,
    WasteCategory? wasteCategory,
    List<UploadPayload> images = const [],
  }) async {
    final reference = _reference();
    final ref = _col.doc();
    await ref.set({
      'referenceNo': reference,
      'residentId': residentId,
      'residentName': residentName,
      'residentBarangay': residentBarangay,
      'title': title.trim(),
      'description': description.trim(),
      'category': category.name,
      if (wasteCategory != null) 'wasteCategory': wasteCategory.name,
      'location': location?.trim(),
      'images': images.map((image) => image.toMap()).toList(),
      'status': ComplaintStatus.pending.name,
      'responses': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyCityHall(
      title: 'New complaint · $reference',
      body: '$residentName: ${title.trim()}',
      type: AppNotificationType.complaint,
      data: {'complaintId': ref.id, 'kind': 'complaintFiled'},
    );

    return ref.id;
  }

  /// Adds a City Hall reply and optionally moves the status. The reply is
  /// stored on the complaint itself, so the resident and City Hall always read
  /// the same thread.
  Future<void> respond({
    required Complaint complaint,
    required String message,
    required ComplaintStatus status,
    required String byName,
  }) async {
    final reply = ComplaintResponse(
      message: message.trim(),
      byName: byName,
      byRole: 'cityHall',
    );

    await _col.doc(complaint.id).update({
      'responses': FieldValue.arrayUnion([reply.toMap()]),
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!status.isOpen) 'resolvedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.push(
      userId: complaint.residentId,
      title: 'Complaint update · ${complaint.referenceNo}',
      body: message.trim().isEmpty
          ? 'Your complaint is now ${status.label.toLowerCase()}.'
          : message.trim(),
      type: AppNotificationType.complaint,
      data: {
        'complaintId': complaint.id,
        'kind': 'complaintResponse',
        'status': status.name,
      },
    );
  }

  /// The resident's side of the conversation. Only their own reply is added
  /// (never a status change); the rules allow it while the complaint is open.
  Future<void> residentReply({
    required Complaint complaint,
    required String message,
    required String byName,
  }) async {
    final text = message.trim();
    if (text.isEmpty) throw ArgumentError('Write a message first.');
    final reply = ComplaintResponse(
      message: text,
      byName: byName,
      byRole: 'resident',
    );

    await _col.doc(complaint.id).update({
      'responses': FieldValue.arrayUnion([reply.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyCityHall(
      title: 'Resident reply · ${complaint.referenceNo}',
      body: '$byName: $text',
      type: AppNotificationType.complaint,
      data: {'complaintId': complaint.id, 'kind': 'complaintReply'},
    );
  }

  Future<void> updateStatus({
    required Complaint complaint,
    required ComplaintStatus status,
    required String byName,
  }) => respond(
    complaint: complaint,
    message: '',
    status: status,
    byName: byName,
  );

  /// `CMP-2026-123456` — readable, unique enough for a single barangay, and
  /// generated without a counter the resident is not allowed to write.
  String _reference() {
    final now = DateTime.now();
    final suffix = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(
      6,
      '0',
    );
    return 'CMP-${now.year}-$suffix';
  }
}
