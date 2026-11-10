import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One active sign-in per account: the newest login owns `sessions/{uid}` and
/// every other device notices that its own session id no longer matches.
///
/// The server enforces it too: the session records the sign-in time of the
/// newest login (`authTime`) and the Firestore rules refuse any token issued
/// before it. A replaced device, even one that was offline or modified, loses
/// access to the data the moment it next talks to Firestore. Its login itself
/// stays valid in Firebase Auth, but that no longer reaches any data.
class SessionService {
  /// `_authTime` returns the sign-in time (epoch seconds) of the current login
  /// token, which the rules compare against.
  SessionService(this._authTime, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _prefix = 'session_id_';

  final FirebaseFirestore _firestore;
  final Future<int> Function() _authTime;
  bool _claiming = false;

  /// True while a login is writing its session, so the watcher is not started
  /// before this device's id exists.
  bool get isClaiming => _claiming;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('sessions').doc(uid);

  /// Makes this device the account's only active session.
  Future<void> claim(String uid) async {
    _claiming = true;
    try {
      final id = _newId();
      await _doc(uid).set({
        'sessionId': id,
        'startedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
        'authTime': await _authTime(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$uid', id);
    } finally {
      _claiming = false;
    }
  }

  /// Forgets this device's session (sign-out).
  Future<void> forget(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$uid');
  }

  /// Emits false as soon as another device signs in to [uid]. Cancelling the
  /// subscription stops the Firestore listener at once.
  Stream<bool> watch(String uid) {
    var cancelled = false;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    late final StreamController<bool> out;

    // The rules refuse a replaced device's token, which is the same answer as
    // seeing another session id.
    void fail(Object error) {
      if (cancelled) return;
      if (error is FirebaseException && error.code == 'permission-denied') {
        out.add(false);
      } else {
        out.addError(error);
      }
    }

    Future<void> onSnapshot(
      SharedPreferences prefs,
      DocumentSnapshot<Map<String, dynamic>> snap,
    ) async {
      if (cancelled || snap.metadata.hasPendingWrites) return;
      try {
        final remote = snap.data()?['sessionId'] as String?;
        final local = prefs.getString('$_prefix$uid');
        if (remote == null) {
          // Nothing recorded yet: a session that predates this feature claims
          // it (first device to open wins). With a local id the document was
          // lost, so put it back.
          if (local == null) {
            await claim(uid);
          } else {
            await _doc(uid).set({
              'sessionId': local,
              'startedAt': FieldValue.serverTimestamp(),
              'platform': defaultTargetPlatform.name,
              'authTime': await _authTime(),
            });
          }
          if (!cancelled) out.add(true);
          return;
        }
        if (!cancelled) out.add(remote == local);
      } catch (error) {
        fail(error);
      }
    }

    out = StreamController<bool>(
      onListen: () async {
        final prefs = await SharedPreferences.getInstance();
        if (cancelled) return;
        sub = _doc(uid).snapshots().listen(
              (snap) => onSnapshot(prefs, snap),
              onError: fail,
            );
      },
      onCancel: () {
        cancelled = true;
        return sub?.cancel();
      },
    );
    return out.stream;
  }

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
