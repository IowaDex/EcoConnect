import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/utils/app_logger.dart';
import '../database/local_database.dart';
import '../models/location_record.dart';

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

  /// The signed-in account, so callers never touch Firebase Auth themselves.
  String? get currentUserId => _auth.currentUser?.uid;

  Stream<String?> get userIdChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  /// True for failures that just mean "no network right now".
  static bool isOfflineError(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed';
    }
    return false;
  }

  LocationRecord? _lastSaved;

  /// Forgets everything tied to the previous signed-in account.
  void reset() {
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

  /// Purges a location document published by an older app version, which
  /// others could once read. Call it while still signed in, before sign-out.
  /// Returns false if it could not be removed (e.g. offline).
  Future<bool> removeSharedLocation() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return true;
    try {
      await _firestore
          .collection('shared_locations')
          .doc(userId)
          .delete()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      AppLogger.error('Could not remove shared location on logout', e);
      return false;
    }
  }

  /// Deletes everything location-related stored for [userId] (admin cleanup).
  Future<void> deleteAllFor(String userId) async {
    final history =
        _firestore.collection('users').doc(userId).collection('locations');
    while (true) {
      final page = await history.limit(400).get();
      if (page.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _firestore.collection('shared_locations').doc(userId).delete();
  }
}
