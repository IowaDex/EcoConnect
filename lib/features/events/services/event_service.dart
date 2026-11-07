import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_event.dart';
import '../../../core/utils/image_payload.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('events');

  Stream<List<CommunityEvent>> watchAll() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => CommunityEvent.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort(_soonestFirst);
      return items;
    });
  }

  Stream<List<CommunityEvent>> watchPublished() {
    return _col
        .where('status', isEqualTo: EventStatus.published.name)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => CommunityEvent.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort(_soonestFirst);
      return items;
    });
  }

  static int _soonestFirst(CommunityEvent a, CommunityEvent b) =>
      a.startAt.compareTo(b.startAt);

  Future<String> save({
    String? id,
    required String title,
    required String description,
    required EventCategory category,
    required String location,
    required DateTime startAt,
    DateTime? endAt,
    UploadPayload? image,
    bool removeImage = false,
    required EventStatus status,
    String? registrationInfo,
    String? contact,
    required String authorId,
    required String authorName,
    String? barangay,
  }) async {
    final ref = id == null ? _col.doc() : _col.doc(id);
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': category.name,
      'location': location.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
      'status': status.name,
      'registrationInfo': registrationInfo?.trim(),
      'contact': contact?.trim(),
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

  Future<void> setStatus(String id, EventStatus status) {
    return _col.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
