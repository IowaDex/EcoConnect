import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/push_notification_service.dart';

/// Keeps the device token tied to the signed-in account and opens the record a
/// push points at when the notification is tapped.
///
/// Lives just inside the app builder so every role gets push, and so a
/// sign-out removes the token before another person uses the phone.
class PushNotificationHost extends StatefulWidget {
  const PushNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  State<PushNotificationHost> createState() => _PushNotificationHostState();
}

class _PushNotificationHostState extends State<PushNotificationHost> {
  String? _uid;
  StreamSubscription<RemoteMessage>? _openedSub;
  RemoteMessage? _pendingInitial;

  @override
  void initState() {
    super.initState();
    PushNotificationService().initialize();
    _listenForOpenedPushes();
  }

  /// A tap on a push (from the background or from a terminated app) should
  /// land on the incident or record named in its data, not on a generic list.
  Future<void> _listenForOpenedPushes() async {
    if (kIsWeb) return;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null && mounted) {
        _pendingInitial = initial;
        _tryOpenInitial();
      }
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (mounted) _open(message);
      });
    } catch (error) {
      debugPrint('Push open handling unavailable: $error');
    }
  }

  /// The initial push can arrive before the saved session is restored. Wait
  /// for the signed-in account so the redirect does not bounce the incident.
  void _tryOpenInitial() {
    final message = _pendingInitial;
    if (message == null) return;
    if (context.read<AuthProvider>().currentUser == null) return;
    _pendingInitial = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(message);
    });
  }

  void _open(RemoteMessage message) {
    final data = message.data;
    final sosId = data['sosId'];
    final route = data['route'];
    try {
      final router = GoRouter.of(context);
      if (sosId is String && sosId.isNotEmpty) {
        router.push('/sos/$sosId');
      } else if (route is String && route.startsWith('/')) {
        router.push(route);
      } else {
        router.push('/notifications');
      }
    } catch (_) {
      // The router may not be attached yet in tests.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == _uid) return;
    final previous = _uid;
    _uid = uid;
    if (previous != null) {
      PushNotificationService().unregister(previous);
    }
    if (uid != null) {
      PushNotificationService().registerForUser(uid);
      _tryOpenInitial();
    }
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
