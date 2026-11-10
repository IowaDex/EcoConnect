import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  /// Bumped after this device joins or leaves an event, so headcount chips can
  /// refresh without every card holding a live listener on the whole roster.
  static final ValueNotifier<int> membershipVersion = ValueNotifier<int>(0);

  // Anonymous per-street counters. Residents may read only these, never the
  // sign-up rows (names and streets), which the rules keep to the owner and
  // staff.
  CollectionReference<Map<String, dynamic>> _streets(String eventId) =>
      _col.doc(eventId).collection('streets');

  /// Live per-street headcount, biggest street first.
  Stream<List<StreetCount>> watchStreetCounts(String eventId) {
    return _streets(eventId).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => StreetCount.fromDoc(doc.id, doc.data()))
          .where((c) => c.count > 0)
          .toList()
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.label.compareTo(b.label);
        });
      return items;
    });
  }

  /// Headcount for one event: the sum of its street counters.
  Future<int> participantCount(String eventId) async {
    final snap = await _streets(eventId).get();
    return snap.docs.fold<int>(
      0,
      (total, doc) => total + ((doc.data()['count'] as num?)?.toInt() ?? 0),
    );
  }

  /// Whether this resident is already on the list.
  Stream<bool> watchJoined(String eventId, String uid) =>
      _participants(eventId).doc(uid).snapshots().map((doc) => doc.exists);

  /// Everyone signed up, grouped by street. Staff only: the rules keep these
  /// rows (names, streets) away from other residents, who read [watchStreetCounts].
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

  // Mirrors the limits in firestore.rules.
  static String _clip(String? value, int max) {
    final text = (value ?? '').trim();
    return text.length <= max ? text : text.substring(0, max);
  }

  /// Signs the resident up. A resident already on the list is left alone, so
  /// the street and join time recorded at the first sign-up never change. The
  /// row and the street counter are written in one transaction, which is the
  /// only way the rules let the counter move.
  Future<void> join({
    required String eventId,
    required String uid,
    required String name,
    String? street,
    String? barangay,
  }) async {
    final ref = _participants(eventId).doc(uid);
    final cleanStreet = _clip(street, 160);
    final key = _clip(streetKeyOf(cleanStreet), 160);
    final counter = _streets(eventId).doc(StreetCount.bucketOf(key));

    try {
      await _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return;
        final existing = await tx.get(counter);
        tx.set(ref, {
          'uid': uid,
          'name': _clip(name, 120),
          'street': cleanStreet,
          'streetKey': key,
          'barangay': _clip(barangay, 120),
          'joinedAt': FieldValue.serverTimestamp(),
        });
        if (existing.exists) {
          tx.update(counter, {'count': FieldValue.increment(1)});
        } else {
          tx.set(counter, {
            'label': cleanStreet.isEmpty ? 'Street not set' : cleanStreet,
            'count': 1,
          });
        }
      });
    } on FirebaseException catch (e) {
      // Already on the list (a raced second tap): that is still signed up.
      if (e.code == 'permission-denied' && (await ref.get()).exists) return;
      rethrow;
    }
    membershipVersion.value++;
  }

  Future<void> leave(String eventId, String uid) async {
    final ref = _participants(eventId).doc(uid);
    await _db.runTransaction((tx) async {
      final mine = await tx.get(ref);
      if (!mine.exists) return;
      // The counter is keyed by the key stored on the row, which is also what
      // the rules compare against.
      final key = (mine.data()?['streetKey'] as String?) ?? '';
      final counter = _streets(eventId).doc(StreetCount.bucketOf(key));
      final existing = await tx.get(counter);
      tx.delete(ref);
      if (!existing.exists) return;
      final count = (existing.data()?['count'] as num?)?.toInt() ?? 0;
      if (count <= 1) {
        tx.delete(counter);
      } else {
        tx.update(counter, {'count': FieldValue.increment(-1)});
      }
    });
    membershipVersion.value++;
  }

  /// Staff-only: makes the public street counters match the real roster, for
  /// events that had sign-ups before the counters existed or after a roster
  /// row was removed by hand. Best effort, so a failed repair never blocks the
  /// overview.
  Future<void> _repairCounters(
    String eventId,
    QuerySnapshot<Map<String, dynamic>> roster,
    QuerySnapshot<Map<String, dynamic>> counters,
  ) async {
    final wanted = <String, ({String label, int count})>{};
    for (final doc in roster.docs) {
      final data = doc.data();
      final key = StreetCount.bucketOf((data['streetKey'] as String?) ?? '');
      final street = ((data['street'] as String?) ?? '').trim();
      final current = wanted[key];
      wanted[key] = (
        label: current?.label ?? (street.isEmpty ? 'Street not set' : street),
        count: (current?.count ?? 0) + 1,
      );
    }
    final have = {for (final doc in counters.docs) doc.id: doc.data()};

    final batch = _db.batch();
    var writes = 0;
    for (final entry in wanted.entries) {
      final stored = have[entry.key];
      final sameCount = (stored?['count'] as num?)?.toInt() == entry.value.count;
      if (stored != null && sameCount) continue;
      batch.set(_streets(eventId).doc(entry.key), {
        'label': stored?['label'] ?? entry.value.label,
        'count': entry.value.count,
      });
      writes++;
    }
    for (final id in have.keys) {
      if (wanted.containsKey(id)) continue;
      batch.delete(_streets(eventId).doc(id));
      writes++;
    }
    if (writes == 0) return;
    try {
      await batch.commit();
    } catch (_) {
      // Not staff, or offline: the next visit tries again.
    }
  }

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

    // Every roster (and counter list) is read at once instead of one round
    // trip per event.
    final rosters = await Future.wait(
      events.docs.map((event) => _participants(event.id).get()),
    );
    final counters = await Future.wait(
      events.docs.map((event) => _streets(event.id).get()),
    );

    final repairs = <Future<void>>[];
    for (var i = 0; i < events.docs.length; i++) {
      final event = events.docs[i];
      final snap = rosters[i];
      items.add(CommunityEvent.fromDoc(event.id, event.data()));
      counts[event.id] = snap.docs.length;
      repairs.add(_repairCounters(event.id, snap, counters[i]));
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

    await Future.wait(repairs);
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
