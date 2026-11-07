import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_event.dart';
import '../../../core/utils/image_payload.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
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
      if (status == EventStatus.published) {
        await _notifications.notifyResidents(
          title: 'New community event',
          body: title.trim(),
          type: AppNotificationType.event,
          data: {'eventId': ref.id},
        );
      }
    } else {
      await ref.update(data);
    }
    return ref.id;
  }

  Future<void> setStatus(String id, EventStatus status) async {
    await _col.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == EventStatus.published) {
      final snap = await _col.doc(id).get();
      final item = CommunityEvent.fromDoc(id, snap.data() ?? const {});
      await _notifications.notifyResidents(
        title: 'New community event',
        body: item.title,
        type: AppNotificationType.event,
        data: {'eventId': id},
      );
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
