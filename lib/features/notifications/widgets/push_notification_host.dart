import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/push_notification_service.dart';

/// Keeps the device token tied to the signed-in account.
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

  @override
  void initState() {
    super.initState();
    PushNotificationService().initialize();
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
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
