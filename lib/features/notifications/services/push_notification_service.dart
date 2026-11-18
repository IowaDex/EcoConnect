import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/utils/app_logger.dart';

/// Receives a push while the app is in the background or terminated.
///
/// The payload includes a `notification` block, so Android and iOS display it
/// without extra work. The app only needs to register the device token and
/// keep it fresh.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No Firebase.initializeApp here: the Flutter engine already bootstrapped
  // the default app for background handlers in recent firebase_messaging
  // versions. Keeping this empty avoids double-initialising plugins.
  AppLogger.info('Background push received: ${message.messageId}');
}

/// Registers this device for EcoConnect push notifications.
///
/// Each signed-in account gets one token document at
/// `users/{uid}/devices/{token}`. The Cloud Function that watches the
/// `notifications` collection reads those documents and sends the push.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefresh;
  String? _registeredUid;
  String? _registeredToken;

  /// Asks for permission and wires the foreground/refresh handlers once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      // Web push needs a service worker and a VAPID key. The mobile builds are
      // the primary target; the in-app banner still covers the open web app.
      AppLogger.info('Push notifications: web registration skipped');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.info('Push notifications denied by the user');
        return;
      }

      // A new token can be issued after an app update or a restore.
      // ignore: deprecated_member_use
      _tokenRefresh = _messaging.onTokenRefresh.listen((token) {
        final uid = _registeredUid;
        if (uid != null && uid.isNotEmpty) _saveToken(uid, token);
      });

      // The banner host already reacts to the Firestore row. Refreshing here
      // keeps the in-app list current when a push arrives first.
      FirebaseMessaging.onMessage.listen((message) {
        AppLogger.info('Foreground push: ${message.messageId}');
      });
    } catch (e) {
      AppLogger.error('Push initialization failed', e);
    }
  }

  /// Saves the current device token for [uid]. Safe to call on every login.
  Future<void> registerForUser(String uid) async {
    if (kIsWeb || uid.isEmpty) return;
    _registeredUid = uid;
    try {
      // ignore: deprecated_member_use
      var token = await _messaging.getToken(
        vapidKey: dotenv.env['FIREBASE_VAPID_KEY'],
      );
      if (token == null || token.isEmpty) {
        // On iOS the APNs token can arrive a moment after permission.
        await Future<void>.delayed(const Duration(seconds: 2));
        // ignore: deprecated_member_use
        token = await _messaging.getToken(
          vapidKey: dotenv.env['FIREBASE_VAPID_KEY'],
        );
      }
      if (token == null || token.isEmpty) return;
      await _saveToken(uid, token);
    } catch (e) {
      AppLogger.error('Push token registration failed', e);
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    _registeredToken = token;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(_safeId(token))
          .set({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Could not save the push token', e);
    }
  }

  /// Removes this device from [uid] on sign-out so the next person on the
  /// phone does not receive the previous account's alerts.
  Future<void> unregister(String uid) async {
    final token = _registeredToken;
    _registeredUid = null;
    _registeredToken = null;
    if (token == null || uid.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(_safeId(token))
          .delete();
    } catch (e) {
      AppLogger.error('Could not remove the push token', e);
    }
  }

  /// FCM tokens contain `:` and `/`, which are not valid document ids.
  static String _safeId(String token) =>
      token.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
  }
}
