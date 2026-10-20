import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../database/local_database.dart';
import '../models/location_record.dart';
import '../models/shared_location.dart';

enum LocationSyncState { synced, pending, syncing, offline, failed }

class LocationRepository {
  LocationRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LocalDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? LocalDatabase.instance;

  static const _minimumDistanceMeters = 20.0;
  static const _minimumInterval = Duration(seconds: 30);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalDatabase _database;
  bool _sharingEnabled = false;

  String? get currentUserId => _auth.currentUser?.uid;

  LocationRecord? _lastSaved;
  String? _lastSavedUserId;

  Future<bool> savePosition(Position position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    if (_lastSavedUserId != userId) {
      _lastSaved = null;
      _lastSavedUserId = userId;
    }
    if (!_shouldSave(position)) return false;

    final recordedAt = position.timestamp.toUtc();
    final id = '${userId}_${recordedAt.microsecondsSinceEpoch}_'
        '${position.latitude}_${position.longitude}';
    final record = LocationRecord(
      id: id,
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      recordedAt: recordedAt,
    );

    await _database.enqueueLocation(record);
    _lastSaved = record;
    return true;
  }

  bool _shouldSave(Position position) {
    final previous = _lastSaved;
    if (previous == null) return true;

    final elapsed = position.timestamp.difference(previous.recordedAt);
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    return elapsed >= _minimumInterval || distance >= _minimumDistanceMeters;
  }

  Future<int> pendingCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;
    return _database.pendingCount(userId);
  }

  Future<int> syncPending() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    final records = await _database.pendingLocations(userId);
    var uploaded = 0;
    for (var offset = 0; offset < records.length; offset += 400) {
      final batchRecords = records.skip(offset).take(400).toList();
      final batch = _firestore.batch();
      for (final record in batchRecords) {
        final reference = _firestore
            .collection('users')
            .doc(userId)
            .collection('locations')
            .doc(record.id);
        batch.set(reference, {
          'latitude': record.latitude,
          'longitude': record.longitude,
          'accuracy': record.accuracy,
          'recordedAt': Timestamp.fromDate(record.recordedAt),
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      }
      try {
        await batch.commit();
      } catch (_) {
        await _database.incrementRetryCount(
          batchRecords.map((record) => record.id),
        );
        rethrow;
      }
      await _database.deleteLocations(batchRecords.map((record) => record.id));
      uploaded += batchRecords.length;
    }
    return uploaded;
  }

  Stream<List<SharedLocation>> watchSharedLocations() {
    return _firestore.collection('shared_locations').snapshots().map(
          (snapshot) => snapshot.docs
              .map(SharedLocation.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> setSharingEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reference = _firestore.collection('shared_locations').doc(user.uid);
    if (!enabled) {
      await reference.delete();
    }
    _sharingEnabled = enabled;
  }

  Future<void> publishSharedLocation(Position position) async {
    if (!_sharingEnabled) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final profileData = profile.data() ?? const <String, dynamic>{};

    await _firestore.collection('shared_locations').doc(user.uid).set({
      'displayName': profileData['name'] as String? ??
          user.displayName ??
          'EcoConnect user',
      'role': profileData['role'] as String? ?? 'user',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'recordedAt': Timestamp.fromDate(position.timestamp.toUtc()),
    });
  }
}
