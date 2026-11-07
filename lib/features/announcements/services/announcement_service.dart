import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';
import '../../../core/utils/image_payload.dart';

/// Announcement reads and writes.
///
/// Queries deliberately avoid composite indexes: filtering and sorting happen
/// in Dart so a fresh Firebase project works without deploying indexes.
class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('announcements');

  Stream<List<Announcement>> watchAll() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => Announcement.fromDoc(doc.id, doc.data()))
          .toList();
      items.sort(_newestFirst);
      return items;
    });
  }

  Stream<List<Announcement>> watchPublished() {
    return _col
        .where('status', isEqualTo: AnnouncementStatus.published.name)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => Announcement.fromDoc(doc.id, doc.data()))
          .where((a) => a.isLive)
          .toList();
      items.sort(_newestFirst);
      return items;
    });
  }

  static int _newestFirst(Announcement a, Announcement b) {
    final aDate = a.publishAt ?? a.createdAt ?? DateTime(2000);
    final bDate = b.publishAt ?? b.createdAt ?? DateTime(2000);
    return bDate.compareTo(aDate);
  }

  Future<String> save({
    String? id,
    required String title,
    required String body,
    required AnnouncementCategory category,
    UploadPayload? image,
    bool removeImage = false,
    required AnnouncementStatus status,
    DateTime? publishAt,
    required String authorId,
    required String authorName,
    String? barangay,
  }) async {
    final ref = id == null ? _col.doc() : _col.doc(id);
    final data = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'category': category.name,
      'status': status.name,
      'publishAt': Timestamp.fromDate(publishAt ?? DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
      'authorId': authorId,
      'authorName': authorName,
      'barangay': barangay,
    };
    if (removeImage) {
      data['image'] = null;
    } else if (image != null) {
      data['image'] = image.toMap();
    }
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(data);
    } else {
      await ref.update(data);
    }
    return ref.id;
  }

  Future<void> setStatus(String id, AnnouncementStatus status) {
    return _col.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == AnnouncementStatus.published)
        'publishAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
