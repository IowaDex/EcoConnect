import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/notification_service.dart';

/// The one notification bell for every screen. It opens the notification
/// centre and shows the signed-in user's unread count (staff also count the
/// shared staff channel), so a screen only needs `NotificationBell()`.
///
/// With no [circleColor] it is a plain icon button for page headers; with one
/// it is a round button for the dark hero headers.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.color,
    this.iconSize,
    this.circleColor,
    this.circleSize = 38,
  });

  final Color? color;
  final double? iconSize;
  final Color? circleColor;
  final double circleSize;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Stream<int>? _stream;
  String? _streamKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final staff = user?.role == UserRole.admin;
    final key = user == null ? null : '${user.uid}:$staff';
    if (key == _streamKey) return;
    _streamKey = key;
    // Kept in state so a rebuild never resubscribes to Firestore.
    _stream = user == null
        ? null
        : staff
            ? NotificationService().watchUnreadCountForStaff(user.uid)
            : NotificationService().watchUnreadCount(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        final icon = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              unread > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: widget.iconSize,
              color: widget.color,
            ),
            if (unread > 0)
              Positioned(
                right: -5,
                top: -4,
                child: _Badge(count: unread),
              ),
          ],
        );
        void open() => context.push('/notifications');

        final circle = widget.circleColor;
        if (circle == null) {
          return IconButton(
            onPressed: open,
            tooltip: 'Notifications',
            icon: icon,
          );
        }
        return InkWell(
          onTap: open,
          customBorder: const CircleBorder(),
          child: Container(
            height: widget.circleSize,
            width: widget.circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
            child: icon,
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 8,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
