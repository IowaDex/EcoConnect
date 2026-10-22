// Test fakes implement Firestore types Firestore marks @sealed/@immutable;
// fine here, since only LocationRepository's own calls are exercised.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/core/database/local_database.dart';
import 'package:eco_connect/core/repositories/location_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

// Minimal in-memory stand-ins: only the calls LocationRepository makes.
class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String? get displayName => 'Ana';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSnapshot(this._data);
  final Map<String, dynamic>? _data;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  bool get exists => _data != null;
}

class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? data;
  Completer<void>? pendingDelete;
  Completer<DocumentSnapshot<Map<String, dynamic>>>? pendingGet;
  Object? deleteError;
  Object? setError;
  int setCalls = 0;
  int getCalls = 0;

  @override
  Future<void> delete() {
    if (deleteError != null) return Future.error(deleteError!);
    return pendingDelete?.future ?? Future.value();
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    setCalls++;
    return setError != null ? Future.error(setError!) : Future.value();
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    getCalls++;
    return pendingGet?.future ?? Future.value(_FakeSnapshot(data));
  }
}

class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this._doc);
  final _FakeDoc _doc;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _doc;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final shared = _FakeDoc();
  final profile = _FakeDoc()..data = {'name': 'Ana', 'role': 'user'};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(path == 'users' ? profile : shared);
}

class _FakeDatabase extends Fake implements LocalDatabase {}

void main() {
  late _FakeFirestore firestore;
  late LocationRepository repo;
  final position = Position(
    latitude: 1,
    longitude: 2,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  setUp(() async {
    firestore = _FakeFirestore();
    repo = LocationRepository(
      auth: _FakeAuth(),
      firestore: firestore,
      database: _FakeDatabase(),
    );
    await repo.setSharingEnabled(true);
  });

  test('no publish lands while turning sharing off is still in flight', () async {
    firestore.shared.pendingDelete = Completer<void>();
    final turningOff = repo.setSharingEnabled(false);

    await repo.publishSharedLocation(position);
    expect(firestore.shared.setCalls, 0);

    firestore.shared.pendingDelete!.complete();
    expect(await turningOff, isTrue);
  });

  test('reset (logout) during a profile load stops that publish', () async {
    firestore.profile.pendingGet = Completer();
    final publishing = repo.publishSharedLocation(position);

    repo.reset();
    firestore.profile.pendingGet!.complete(
      _FakeSnapshot({'name': 'Ana', 'role': 'user'}),
    );
    await publishing;
    expect(firestore.shared.setCalls, 0);
  });

  test('a failed delete keeps sharing on and reports the error', () async {
    firestore.shared.deleteError = Exception('permission-denied');
    await expectLater(repo.setSharingEnabled(false), throwsException);
    expect(repo.sharingEnabled, isTrue);
  });

  test('a failed publish re-reads the profile (role may have changed)', () async {
    firestore.shared.setError = Exception('permission-denied');
    await expectLater(repo.publishSharedLocation(position), throwsException);

    firestore.shared.setError = null;
    await repo.publishSharedLocation(position);
    expect(firestore.profile.getCalls, 2);
    expect(firestore.shared.setCalls, 2);
  });
}
