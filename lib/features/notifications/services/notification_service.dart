import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/area_match.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Stream<List<AppNotification>> watch(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items =
          snap.docs
              .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
              .toList()
            ..sort(newestFirst);
      return collapseDuplicates(items);
    });
  }

  /// Newest first. A notification written with `serverTimestamp()` has a null
  /// [AppNotification.createdAt] until the server responds; treating it as
  /// "now" keeps a fresh alert at the top instead of pushing it to the bottom
  /// of the list for a second.
  static int newestFirst(AppNotification a, AppNotification b) {
    final now = DateTime.now();
    final aDate = a.createdAt ?? now;
    final bDate = b.createdAt ?? now;
    return bDate.compareTo(aDate);
  }

  /// Hides identical rows that were already written before dedupe keys
  /// existed. The newest copy is kept; older duplicates disappear from the
  /// list without deleting the underlying records.
  static List<AppNotification> collapseDuplicates(List<AppNotification> items) {
    final seen = <String>{};
    final out = <AppNotification>[];
    for (final item in items) {
      final key = '${item.userId}|${item.type.name}|${item.title}|${item.body}';
      if (!seen.add(key)) continue;
      out.add(item);
    }
    return out;
  }

  /// Document ids cannot contain a slash, and a key must be stable across
  /// retries, so it is normalised before it becomes part of an id.
  static String _safeKey(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');

  /// Writes [data] once for a deterministic document id.
  ///
  /// A retry, a double tap or two screens reacting to the same event all
  /// produce the same document id. The first write is a create and lands; a
  /// repeat hits the existing document, where the security rules only allow
  /// `read` to change, so it is refused and the alert is not duplicated.
  /// Returns true only when a new document was created.
  ///
  /// This deliberately avoids a transaction: reading a notification that does
  /// not exist yet is refused by the rules, which made every keyed alert —
  /// including the manual request sent to the Iswim desk — silently vanish.
  Future<bool> _writeOnce({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _col.doc(docId).set(data);
      return true;
    } catch (error) {
      AppLogger.error('Notification write failed', error);
      return false;
    }
  }

  Stream<int> watchUnreadCount(String userId) {
    return watch(userId).map((items) => items.where((n) => !n.read).length);
  }

  /// Returns whether the notification was written, so callers that rate-limit
  /// can avoid counting a failed send. Most callers ignore the result.
  ///
  /// Pass [dedupeKey] for anything that can fire more than once for the same
  /// event (a publish retry, two screens listening to the same action). The
  /// key makes the write idempotent.
  Future<bool> push({
    required String userId,
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
    String? dedupeKey,
  }) async {
    if (userId.isEmpty) return false;
    final payload = {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': data,
    };
    if (dedupeKey == null || dedupeKey.isEmpty) {
      try {
        await _col.add(payload);
        return true;
      } catch (error) {
        AppLogger.error('Notification write failed', error);
        return false;
      }
    }
    return _writeOnce(
      docId: '${_safeKey(userId)}__${_safeKey(dedupeKey)}',
      data: payload,
    );
  }

  /// Staff channel id. Operational alerts are written once to a shared
  /// channel instead of fanning out to every staff profile, because residents
  /// and drivers must not be able to read the user directory.
  static const staffChannel = 'staff';

  /// City Hall / DSQC desk channel. Complaints and manual submissions are
  /// addressed here because a resident cannot read the user directory to find
  /// individual City Hall accounts.
  static const cityHallChannel = 'cityHall';

  /// Iswim desk channel, used for manual requests from City Hall.
  static const iswimChannel = 'iswim';

  /// Writes an alert to the shared barangay staff channel.
  Future<void> notifyStaff({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
    String? dedupeKey,
  }) => _notifyChannel(
    channel: staffChannel,
    title: title,
    body: body,
    type: type,
    data: data,
    label: 'Staff',
    dedupeKey: dedupeKey,
  );

  /// Writes an alert to the City Hall / DSQC desk.
  Future<void> notifyCityHall({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
    String? dedupeKey,
  }) => _notifyChannel(
    channel: cityHallChannel,
    title: title,
    body: body,
    type: type,
    data: data,
    label: 'City Hall',
    dedupeKey: dedupeKey,
  );

  /// Writes an alert to the Iswim desk.
  Future<void> notifyIswim({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
    String? dedupeKey,
  }) => _notifyChannel(
    channel: iswimChannel,
    title: title,
    body: body,
    type: type,
    data: data,
    label: 'Iswim',
    dedupeKey: dedupeKey,
  );

  Future<void> _notifyChannel({
    required String channel,
    required String title,
    required String body,
    required AppNotificationType type,
    required Map<String, dynamic> data,
    required String label,
    String? dedupeKey,
  }) async {
    final payload = {
      'userId': channel,
      'title': title,
      'body': body,
      'type': type.name,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': data,
    };
    if (dedupeKey != null && dedupeKey.isNotEmpty) {
      await _writeOnce(
        docId: '${_safeKey(channel)}__${_safeKey(dedupeKey)}',
        data: payload,
      );
      return;
    }
    try {
      await _col.add(payload);
    } catch (error) {
      AppLogger.error('$label notification write failed', error);
    }
  }

  static const _batchLimit = 400;

  /// Fans a notice out to every active resident. Only staff can read the user
  /// directory, so this is a staff-only action; failures stay silent because
  /// the announcement itself has already been saved.
  ///
  /// Pass [onlyAreas] for anything tied to a collection route: the notice then
  /// goes to the residents whose registered subdivision is one of those areas,
  /// and to nobody else. A resident whose area is unknown is left out — a
  /// schedule for another village is worse than no alert at all.
  ///
  /// Returns how many residents were addressed, so a caller can tell "nobody
  /// lives on this route" from "the write failed".
  Future<int> notifyResidents({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
    String? dedupeKey,
    Iterable<String>? onlyAreas,
  }) async {
    try {
      final users = await _db
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();

      final wanted = onlyAreas == null
          ? null
          : {
              for (final area in onlyAreas)
                if (normalizeAreaName(area).isNotEmpty) normalizeAreaName(area),
            };
      // An area-scoped notice with no usable area must reach nobody: falling
      // back to everyone is exactly the bug this filter exists to stop.
      if (wanted != null && wanted.isEmpty) return 0;

      final targets = wanted == null
          ? users.docs
          : users.docs
                .where(
                  (user) => wanted.contains(
                    normalizeAreaName(
                      (user.data()['subdivision'] as String?) ?? '',
                    ),
                  ),
                )
                .toList(growable: false);

      // A batch holds at most 500 writes, so a large barangay is split. Each
      // batch is isolated: one failure must not drop everyone after it.
      var sent = 0;
      for (var i = 0; i < targets.length; i += _batchLimit) {
        final chunk = targets.skip(i).take(_batchLimit).toList();
        final batch = _db.batch();
        for (final user in chunk) {
          final ref = (dedupeKey == null || dedupeKey.isEmpty)
              ? _col.doc()
              : _col.doc('${_safeKey(user.id)}__${_safeKey(dedupeKey)}');
          batch.set(ref, {
            'userId': user.id,
            'title': title,
            'body': body,
            'type': type.name,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'data': data,
          });
        }
        try {
          await batch.commit();
          sent += chunk.length;
        } catch (error) {
          AppLogger.error('Resident notification batch failed', error);
        }
      }
      if (sent < targets.length) {
        AppLogger.error(
          'Resident notice missed ${targets.length - sent} of '
          '${targets.length} residents',
        );
      }
      return sent;
    } catch (error) {
      AppLogger.error('Resident notification fan-out failed', error);
      return 0;
    }
  }

  /// Staff see their own notifications plus the shared channel.
  Stream<List<AppNotification>> watchForStaff(String userId) {
    return _col
        .where('userId', whereIn: [userId, staffChannel])
        .snapshots()
        .map((snap) {
          final items =
              snap.docs
                  .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
                  .toList()
                ..sort(newestFirst);
          return collapseDuplicates(items);
        });
  }

  Stream<int> watchUnreadCountForStaff(String userId) =>
      watchForStaff(userId).map((items) => items.where((n) => !n.read).length);

  /// Marks both personal and shared staff alerts as read.
  Future<void> markAllReadForStaff(String userId) =>
      markAllReadForDesk(userId, staffChannel);

  /// Personal alerts plus one shared desk channel (City Hall or Iswim).
  Stream<List<AppNotification>> watchForDesk(String userId, String channel) {
    return _col.where('userId', whereIn: [userId, channel]).snapshots().map((
      snap,
    ) {
      final items =
          snap.docs
              .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
              .toList()
            ..sort(newestFirst);
      return collapseDuplicates(items);
    });
  }

  Stream<int> watchUnreadCountForDesk(String userId, String channel) =>
      watchForDesk(
        userId,
        channel,
      ).map((items) => items.where((n) => !n.read).length);

  /// Marks personal and shared desk alerts as read.
  Future<void> markAllReadForDesk(String userId, String channel) async {
    final all = await _col.where('userId', whereIn: [userId, channel]).get();
    final unread = all.docs.where((doc) => doc.data()['read'] != true).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(String userId) async {
    // Single-field query only: avoids needing a composite index.
    final all = await _col.where('userId', isEqualTo: userId).get();
    final unread = all.docs.where((doc) => doc.data()['read'] != true).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
