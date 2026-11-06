import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drop_off.dart';

class RecyclingException implements Exception {
  const RecyclingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Barangay recycling drop-off station + resident points wallet.
///
/// Points live on `users/{uid}.points` and every credit also writes an
/// immutable `dropOffs/{id}` ledger entry, so the balance can always be
/// reconciled against the station's records.
class RecyclingService {
  static final RecyclingService _instance = RecyclingService._internal();
  factory RecyclingService() => _instance;
  RecyclingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _dropOffs =>
      _db.collection('dropOffs');

  /// Looks a resident up by account ID (uid) or email — the two values a
  /// scanned QR code or a printed barangay ID would carry.
  Future<Map<String, dynamic>?> findResident(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return null;

    final byId = await _users.doc(query).get();
    if (byId.exists) {
      final data = byId.data() ?? <String, dynamic>{};
      if (data['role'] == 'user') return {'uid': byId.id, ...data};
      return null;
    }

    for (final candidate in {query, query.toLowerCase()}) {
      final byEmail = await _users
          .where('email', isEqualTo: candidate)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        final data = doc.data();
        if (data['role'] == 'user') return {'uid': doc.id, ...data};
      }
    }
    return null;
  }

  /// Credits [weightKg] of [material] to a resident in one transaction.
  Future<int> recordDropOff({
    required String residentId,
    required String residentName,
    String? residentEmail,
    required String staffId,
    required String staffName,
    required RecyclableMaterial material,
    required double weightKg,
  }) async {
    if (weightKg <= 0) {
      throw const RecyclingException('Enter a weight greater than zero.');
    }

    final points = DropOff.pointsFor(material, weightKg);
    if (points <= 0) {
      throw const RecyclingException('This weight is too small to earn points.');
    }

    final userRef = _users.doc(residentId);
    final dropRef = _dropOffs.doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw const RecyclingException('Resident account no longer exists.');
      }
      if (userSnap.data()?['role'] != 'user') {
        throw const RecyclingException(
          'Points can only be credited to resident accounts.',
        );
      }

      tx.set(dropRef, {
        'residentId': residentId,
        'residentName': residentName,
        'residentEmail': residentEmail,
        'staffId': staffId,
        'staffName': staffName,
        'material': material.name,
        'weightKg': weightKg,
        'points': points,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {
        'points': FieldValue.increment(points),
        'pointsUpdatedAt': FieldValue.serverTimestamp(),
      });
    });

    return points;
  }

  Stream<int> watchResidentPoints(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['points'];
      return raw is num ? raw.toInt() : 0;
    });
  }

  Stream<List<DropOff>> watchResidentDropOffs(String uid) {
    return _dropOffs
        .where('residentId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => DropOff.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
      return items;
    });
  }

  /// Latest station activity, for the staff screen.
  Stream<List<DropOff>> watchRecentDropOffs() {
    return _dropOffs.limit(50).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => DropOff.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
      return items.take(10).toList();
    });
  }
}
