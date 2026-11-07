import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_point.dart';
import '../../../core/models/waste_category.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

class CollectionPointService {
  static final CollectionPointService _instance =
      CollectionPointService._internal();
  factory CollectionPointService() => _instance;
  CollectionPointService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('collectionPoints');

  Stream<List<CollectionPoint>> watchAll() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => CollectionPoint.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// Active points assigned to one driver, alphabetically. Single-field query
  /// so no composite index is needed.
  Stream<List<CollectionPoint>> watchForDriver(String driverId) {
    return _col
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map(_activeSorted);
  }

  /// One-shot variant used when a driver opens an ad-hoc route.
  Future<List<CollectionPoint>> forDriver(String driverId) async {
    final snap = await _col.where('driverId', isEqualTo: driverId).get();
    return _activeSorted(snap);
  }

  List<CollectionPoint> _activeSorted(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map((doc) => CollectionPoint.fromDoc(doc.id, doc.data()))
        .where((point) => point.isActive)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<String> save({
    String? id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? barangay,
    String? zone,
    String? driverId,
    String? driverName,
    List<String> scheduleDays = const [],
    String? scheduleTime,
    WasteCategory? category,
    required CollectionPointStatus status,
    String? notes,
  }) async {
    final ref = id == null ? _col.doc() : _col.doc(id);

    // Previous state, so a re-assignment can be announced to the new driver
    // and a removal to the old one.
    var previousDriverId = '';
    var previousName = '';
    if (id != null) {
      final previous = (await ref.get()).data();
      if (previous != null) {
        previousDriverId = (previous['driverId'] as String?) ?? '';
        previousName = (previous['name'] as String?)?.trim() ?? '';
      }
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'address': address.trim(),
      'lat': latitude,
      'lng': longitude,
      'barangay': barangay,
      'zone': zone,
      'driverId': driverId,
      'driverName': driverName,
      'scheduleDays': scheduleDays,
      'scheduleTime': scheduleTime,
      'category': category?.name,
      'status': status.name,
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(data);
    } else {
      await ref.update(data);
    }
    await _announceAssignment(
      pointId: ref.id,
      name: name.trim(),
      address: address.trim(),
      driverId: driverId ?? '',
      previousDriverId: previousDriverId,
      previousName: previousName,
    );
    return ref.id;
  }

  /// Tells the driver when a point lands on, or leaves, their route. Failures
  /// are already swallowed by [NotificationService.push] so saving a point
  /// never fails because of a notification.
  Future<void> _announceAssignment({
    required String pointId,
    required String name,
    required String address,
    required String driverId,
    required String previousDriverId,
    required String previousName,
  }) async {
    final label = address.isEmpty ? name : '$name · $address';
    if (driverId.isNotEmpty && driverId != previousDriverId) {
      await _notifications.push(
        userId: driverId,
        title: 'New stop on your route',
        body: '$label was added by barangay staff.',
        type: AppNotificationType.route,
        data: {'pointId': pointId},
      );
    }
    if (previousDriverId.isNotEmpty && previousDriverId != driverId) {
      await _notifications.push(
        userId: previousDriverId,
        title: 'Stop removed from your route',
        body: '${previousName.isEmpty ? name : previousName} is no longer '
            'assigned to you.',
        type: AppNotificationType.route,
        data: {'pointId': pointId},
      );
    }
  }

  Future<void> toggleStatus(CollectionPoint point) async {
    final next = point.isActive
        ? CollectionPointStatus.inactive
        : CollectionPointStatus.active;
    await _col.doc(point.id).update({
      'status': next.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final driverId = point.driverId ?? '';
    if (driverId.isEmpty) return;
    final active = next == CollectionPointStatus.active;
    await _notifications.push(
      userId: driverId,
      title: active ? 'Stop back on your route' : 'Stop removed from your route',
      body: active
          ? '${point.name} is active again.'
          : '${point.name} is now inactive.',
      type: AppNotificationType.route,
      data: {'pointId': point.id},
    );
  }

  Future<void> delete(String id) async {
    final ref = _col.doc(id);
    final data = (await ref.get()).data();
    await ref.delete();

    final driverId = (data?['driverId'] as String?) ?? '';
    if (driverId.isEmpty) return;
    final name = (data?['name'] as String?)?.trim();
    await _notifications.push(
      userId: driverId,
      title: 'Stop removed from your route',
      body: '${name == null || name.isEmpty ? 'A collection point' : name} '
          'was removed by barangay staff.',
      type: AppNotificationType.route,
      data: {'pointId': id},
    );
  }
}
