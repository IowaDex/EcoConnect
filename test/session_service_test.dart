// Test fakes implement Firestore types Firestore marks @sealed/@immutable;
// fine here, since only SessionService's own calls are exercised.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/features/auth/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
}

class _FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeSnapshot(this._data);
  final Map<String, dynamic>? _data;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  SnapshotMetadata get metadata => _FakeMetadata();
}

class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  final changes =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  Map<String, dynamic>? stored;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      changes.stream;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    stored = data;
  }

  void remote(Map<String, dynamic>? data) => changes.add(_FakeSnapshot(data));
}

class _FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this._doc);
  final _FakeDoc _doc;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _doc;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final sessionDoc = _FakeDoc();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _FakeCollection(sessionDoc);
}

void main() {
  late _FakeFirestore firestore;
  late SessionService service;

  Future<void> setUpWith([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    firestore = _FakeFirestore();
    service = SessionService(() async => 1700, firestore: firestore);
  }

  test('claiming writes a session id and remembers it on this device', () async {
    await setUpWith();
    await service.claim('u1');

    final id = firestore.sessionDoc.stored!['sessionId'] as String;
    expect(id.length, 32);
    expect(firestore.sessionDoc.stored!['authTime'], 1700);
    expect((await SharedPreferences.getInstance()).getString('session_id_u1'),
        id);
    expect(service.isClaiming, isFalse);
  });

  test('two claims produce different ids', () async {
    await setUpWith();
    await service.claim('u1');
    final first = firestore.sessionDoc.stored!['sessionId'];
    await service.claim('u1');
    expect(firestore.sessionDoc.stored!['sessionId'], isNot(first));
  });

  test('stays active while the recorded id is this device\'s', () async {
    await setUpWith({'session_id_u1': 'mine'});
    final results = <bool>[];
    final sub = service.watch('u1').listen(results.add);
    await Future<void>.delayed(Duration.zero);

    firestore.sessionDoc.remote({'sessionId': 'mine'});
    await Future<void>.delayed(Duration.zero);
    expect(results, [true]);
    await sub.cancel();
  });

  test('another device signing in ends this session', () async {
    await setUpWith({'session_id_u1': 'mine'});
    final results = <bool>[];
    final sub = service.watch('u1').listen(results.add);
    await Future<void>.delayed(Duration.zero);

    firestore.sessionDoc.remote({'sessionId': 'mine'});
    firestore.sessionDoc.remote({'sessionId': 'other-device'});
    await Future<void>.delayed(Duration.zero);
    expect(results, [true, false]);
    await sub.cancel();
  });

  test('a device with no saved id loses to a recorded session', () async {
    await setUpWith();
    final results = <bool>[];
    final sub = service.watch('u1').listen(results.add);
    await Future<void>.delayed(Duration.zero);

    firestore.sessionDoc.remote({'sessionId': 'other-device'});
    await Future<void>.delayed(Duration.zero);
    expect(results, [false]);
    await sub.cancel();
  });

  test('a signed-in device from before this feature claims the account',
      () async {
    await setUpWith();
    final results = <bool>[];
    final sub = service.watch('u1').listen(results.add);
    await Future<void>.delayed(Duration.zero);

    firestore.sessionDoc.remote(null);
    await Future<void>.delayed(Duration.zero);
    expect(results, [true]);
    expect(firestore.sessionDoc.stored!['sessionId'], isA<String>());

    // The echo of our own write must not end the session.
    firestore.sessionDoc.remote({'sessionId': firestore.sessionDoc.stored!['sessionId']});
    await Future<void>.delayed(Duration.zero);
    expect(results, [true, true]);
    await sub.cancel();
  });

  test('a refused token (replaced device) reads as signed out', () async {
    await setUpWith({'session_id_u1': 'mine'});
    final results = <bool>[];
    final sub = service.watch('u1').listen(results.add);
    await Future<void>.delayed(Duration.zero);

    firestore.sessionDoc.changes.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(results, [false]);
    await sub.cancel();
  });

  test('forget clears the saved id', () async {
    await setUpWith({'session_id_u1': 'mine'});
    await service.forget('u1');
    expect((await SharedPreferences.getInstance()).getString('session_id_u1'),
        isNull);
  });
}
