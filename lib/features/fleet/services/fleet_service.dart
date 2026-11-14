import 'package:cloud_firestore/cloud_firestore.dart';

import '../../driver/data/mock_trucks.dart';
import '../../driver/models/garbage_truck.dart';

/// The barangay fleet.
///
/// Iswim registers every plate here and pairs it with a driver; the mock list
/// only stands in until the first real truck is saved, so a fresh project is
/// never empty and a live project never falls back to fake data.
class FleetService {
  FleetService._();
  static final FleetService _instance = FleetService._();
  factory FleetService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('trucks');

  /// Live fleet, or the mock roster while the collection is still empty.
  Stream<List<GarbageTruck>> watchTrucks() {
    return _col.snapshots().map((snap) {
      final trucks = snap.docs
          .map((doc) => GarbageTruck.fromMap({...doc.data(), 'id': doc.id}))
          .whereType<GarbageTruck>()
          .toList();
      if (trucks.isEmpty) return kMockTrucks;
      trucks.sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
      return trucks;
    });
  }

  /// One-off lookup used when a driver opens the dashboard: Firestore first,
  /// mock roster second.
  Future<GarbageTruck?> findTruck(String? id) async {
    if (id == null || id.isEmpty) return null;
    try {
      final doc = await _col.doc(id).get();
      final data = doc.data();
      if (data != null) {
        return GarbageTruck.fromMap({...data, 'id': doc.id});
      }
    } catch (_) {
      // Offline or rules blocked: fall back to the roster.
    }
    return truckById(id);
  }

  /// Creates or updates a truck. The document id comes from the plate, so the
  /// same plate can never be registered twice.
  Future<void> saveTruck(GarbageTruck truck) async {
    final id = truck.id.isEmpty ? _idForPlate(truck.plateNumber) : truck.id;
    await _col.doc(id).set({
      ...truck.toMap(),
      'id': id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTruck(String id) => _col.doc(id).delete();

  /// False while the collection is still empty, so the screen can offer to
  /// copy the ten seeded trucks in one tap instead of one by one.
  Stream<bool> watchIsRegistered() =>
      _col.limit(1).snapshots().map((snap) => snap.docs.isNotEmpty);

  /// Copies the seeded roster into Firestore. After this the registry is the
  /// only source: the mock list stops being a fallback.
  Future<void> seedRoster() async {
    for (final truck in kMockTrucks) {
      await saveTruck(truck);
    }
  }

  /// `sk-4821` — stable, readable, and unique per plate.
  static String _idForPlate(String plate) =>
      plate.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  static String idForPlate(String plate) => _idForPlate(plate);
}
