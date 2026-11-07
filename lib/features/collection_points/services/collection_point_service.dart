import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_point.dart';
import '../../../core/models/waste_category.dart';

class CollectionPointService {
  static final CollectionPointService _instance =
      CollectionPointService._internal();
  factory CollectionPointService() => _instance;
  CollectionPointService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
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
    return ref.id;
  }

  Future<void> toggleStatus(CollectionPoint point) {
    return _col.doc(point.id).update({
      'status': point.isActive
          ? CollectionPointStatus.inactive.name
          : CollectionPointStatus.active.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
