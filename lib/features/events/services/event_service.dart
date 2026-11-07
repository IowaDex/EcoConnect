import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_event.dart';
import '../models/event_participant.dart';
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

  // ---------------------------------------------------------------------------
  // Sign-ups
  //
  // Stored as a subcollection so a resident can write their own row without
  // being able to touch the event itself, and so the roster can carry the
  // street the resident had at join time.
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _participants(String eventId) =>
      _col.doc(eventId).collection('participants');

  /// Live headcount for one event.
  Stream<int> watchParticipantCount(String eventId) =>
      _participants(eventId).snapshots().map((snap) => snap.docs.length);

  /// Whether this resident is already on the list.
  Stream<bool> watchJoined(String eventId, String uid) =>
      _participants(eventId).doc(uid).snapshots().map((doc) => doc.exists);

  /// Everyone signed up, grouped by street.
  Stream<List<EventParticipant>> watchParticipants(String eventId) {
    return _participants(eventId).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => EventParticipant.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byStreet = a.streetKey.compareTo(b.streetKey);
          return byStreet != 0 ? byStreet : a.name.compareTo(b.name);
        });
      return items;
    });
  }

  Future<void> join({
    required String eventId,
    required String uid,
    required String name,
    String? street,
    String? barangay,
  }) async {
    await _participants(eventId).doc(uid).set({
      'uid': uid,
      'name': name,
      'street': (street ?? '').trim(),
      'streetKey': streetKeyOf(street),
      'barangay': (barangay ?? '').trim(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leave(String eventId, String uid) =>
      _participants(eventId).doc(uid).delete();

  /// Every event's headcount plus the per-street ranking, in one pass.
  ///
  /// One read per event is fine at barangay scale (a handful of events) and
  /// keeps the rules simple — a collection-group query would need its own rule
  /// block and an index.
  Future<ParticipationOverview> loadParticipationOverview() async {
    final events = await _col.get();
    final counts = <String, int>{};
    final buckets = <String, _StreetBucket>{};
    final items = <CommunityEvent>[];

    for (final event in events.docs) {
      items.add(CommunityEvent.fromDoc(event.id, event.data()));
      final snap = await _participants(event.id).get();
      counts[event.id] = snap.docs.length;
      for (final doc in snap.docs) {
        final person = EventParticipant.fromDoc(doc.id, doc.data());
        if (person.streetKey.isEmpty) continue;
        final bucket = buckets.putIfAbsent(
          person.streetKey,
          () => _StreetBucket(person.streetKey, person.streetLabel),
        );
        bucket.uids.add(person.uid);
        bucket.attendances++;
        bucket.events.add(event.id);
      }
    }

    items.sort(_soonestFirst);

    final standings = buckets.values
        .map(
          (b) => StreetStanding(
            key: b.key,
            label: b.label,
            residents: b.uids.length,
            attendances: b.attendances,
            events: b.events.length,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        return byPoints != 0 ? byPoints : a.label.compareTo(b.label);
      });

    return ParticipationOverview(
      events: items,
      countsByEvent: counts,
      standings: standings,
    );
  }
}

/// Result of [EventService.loadParticipationOverview].
class ParticipationOverview {
  const ParticipationOverview({
    required this.events,
    required this.countsByEvent,
    required this.standings,
  });

  /// Every event, soonest first.
  final List<CommunityEvent> events;

  /// Event id → number of residents signed up.
  final Map<String, int> countsByEvent;

  /// Streets, best first.
  final List<StreetStanding> standings;

  int countFor(String eventId) => countsByEvent[eventId] ?? 0;

  /// Every sign-up across every event.
  int get totalSignUps =>
      countsByEvent.values.fold<int>(0, (total, value) => total + value);
}

class _StreetBucket {
  _StreetBucket(this.key, this.label);

  final String key;
  String label;
  final Set<String> uids = <String>{};
  final Set<String> events = <String>{};
  int attendances = 0;
}
