import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  static const _minimumMovingInterval = Duration(seconds: 5);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalDatabase _database;
  bool _sharingEnabled = false;
  Map<String, dynamic>? _profile;

  bool get sharingEnabled => _sharingEnabled;

  LocationRecord? _lastSaved;

  /// Forgets everything tied to the previous signed-in account.
  void reset() {
    _sharingEnabled = false;
    _profile = null;
    _lastSaved = null;
  }

  Future<bool> savePosition(Position position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    if (!shouldSave(
      _lastSaved,
      position.latitude,
      position.longitude,
      position.timestamp,
    )) {
      return false;
    }

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

  @visibleForTesting
  static bool shouldSave(
    LocationRecord? previous,
    double latitude,
    double longitude,
    DateTime at,
  ) {
    if (previous == null) return true;

    final elapsed = at.difference(previous.recordedAt);
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      latitude,
      longitude,
    );
    // Moving fast still saves at most every 5 s, to keep Firestore costs bounded.
    return elapsed >= _minimumInterval ||
        (distance >= _minimumDistanceMeters &&
            elapsed >= _minimumMovingInterval);
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
              .map((doc) => SharedLocation.tryParse(doc.id, doc.data()))
              .whereType<SharedLocation>()
              .toList(growable: false),
        );
  }

  /// Reads whether this account is already sharing, e.g. after an app restart.
  /// Throws if the read fails; the flag then keeps its current value.
  Future<bool> loadSharingEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc =
        await _firestore.collection('shared_locations').doc(user.uid).get();
    if (_auth.currentUser?.uid == user.uid) _sharingEnabled = doc.exists;
    return _sharingEnabled;
  }

  /// Returns false when turning sharing off could only be queued (offline):
  /// Firestore sends the delete once the phone reconnects.
  Future<bool> setSharingEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return true;

    // Flip the flag first so no publish can land after the delete.
    _sharingEnabled = enabled;
    if (enabled) return true;
    try {
      await _firestore
          .collection('shared_locations')
          .doc(user.uid)
          .delete()
          .timeout(const Duration(seconds: 5));
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      // Not deleted: keep publishing so the visible pin doesn't freeze.
      _sharingEnabled = true;
      rethrow;
    }
  }

  Future<void> publishSharedLocation(Position position) async {
    if (!_sharingEnabled) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final profileData = _profile ??=
        (await _firestore.collection('users').doc(user.uid).get()).data() ??
            const <String, dynamic>{};
    // Sharing may have been turned off while the profile was loading.
    if (!_sharingEnabled || _auth.currentUser?.uid != user.uid) return;

    try {
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
    } catch (_) {
      // The cached role may be stale (an admin changed it); re-read next time.
      _profile = null;
      rethrow;
    }
  }
}
