import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../../../core/utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Stream<List<AppNotification>> watch(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return watch(userId).map((items) => items.where((n) => !n.read).length);
  }

  /// Returns whether the notification was written, so callers that rate-limit
  /// can avoid counting a failed send. Most callers ignore the result.
  Future<bool> push({
    required String userId,
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
  }) async {
    if (userId.isEmpty) return false;
    try {
      await _col.add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': data,
      });
      return true;
    } catch (error) {
      // Notifications are secondary: a rules or network failure must never
      // roll back the action that triggered them.
      AppLogger.error('Notification write failed', error);
      return false;
    }
  }

  /// Staff channel id. Operational alerts are written once to a shared
  /// channel instead of fanning out to every staff profile, because residents
  /// and drivers must not be able to read the user directory.
  static const staffChannel = 'staff';

  /// Writes an alert to the shared barangay staff channel.
  Future<void> notifyStaff({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await _col.add({
        'userId': staffChannel,
        'title': title,
        'body': body,
        'type': type.name,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': data,
      });
    } catch (error) {
      AppLogger.error('Staff notification write failed', error);
    }
  }

  static const _batchLimit = 400;

  /// Fans a notice out to every active resident. Only staff can read the user
  /// directory, so this is a staff-only action; failures stay silent because
  /// the announcement itself has already been saved.
  Future<void> notifyResidents({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.system,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final users =
          await _db.collection('users').where('role', isEqualTo: 'user').get();
      // A batch holds at most 500 writes, so a large barangay is split. Each
      // batch is isolated: one failure must not drop everyone after it.
      var missed = 0;
      for (var i = 0; i < users.docs.length; i += _batchLimit) {
        final chunk = users.docs.skip(i).take(_batchLimit).toList();
        final batch = _db.batch();
        for (final user in chunk) {
          batch.set(_col.doc(), {
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
        } catch (error) {
          missed += chunk.length;
          AppLogger.error('Resident notification batch failed', error);
        }
      }
      if (missed > 0) {
        AppLogger.error(
            'Resident notice missed $missed of ${users.docs.length} residents');
      }
    } catch (error) {
      AppLogger.error('Resident notification fan-out failed', error);
    }
  }

  /// Staff see their own notifications plus the shared channel.
  Stream<List<AppNotification>> watchForStaff(String userId) {
    return _col
        .where('userId', whereIn: [userId, staffChannel])
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  Stream<int> watchUnreadCountForStaff(String userId) => watchForStaff(userId)
      .map((items) => items.where((n) => !n.read).length);

  /// Marks both personal and shared staff alerts as read.
  Future<void> markAllReadForStaff(String userId) async {
    final all = await _col
        .where('userId', whereIn: [userId, staffChannel])
        .get();
    final unread = all.docs.where((doc) => doc.data()['read'] != true).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> markRead(String id) =>
      _col.doc(id).update({'read': true});

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
