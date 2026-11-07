import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Shows a sliding banner whenever a new notification lands while the app is
/// open. The stream is already realtime, so nothing polls and no refresh is
/// needed: a staff approval, a driver broadcast or an announcement appears
/// within a second of being written.
class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  StreamSubscription<List<AppNotification>>? _sub;
  Timer? _hideTimer;

  /// Ids already present when the stream first attached. Those are history,
  /// not new events, so they never trigger a banner.
  final Set<String> _known = {};
  bool _primed = false;
  String? _userId;
  bool _staff = false;

  AppNotification? _current;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final staff = user?.role == UserRole.admin;
    if (user?.uid == _userId && staff == _staff) return;

    _userId = user?.uid;
    _staff = staff;
    _primed = false;
    _known.clear();
    _sub?.cancel();
    _sub = null;

    if (user == null) {
      if (_current != null) setState(() => _current = null);
      return;
    }

    final service = NotificationService();
    _sub = (staff ? service.watchForStaff(user.uid) : service.watch(user.uid))
        .listen(_onItems, onError: (_) {});
  }

  void _onItems(List<AppNotification> items) {
    if (!_primed) {
      _primed = true;
      _known.addAll(items.map((n) => n.id));
      return;
    }

    final fresh = items
        .where((n) => !n.read && !_known.contains(n.id))
        .toList(growable: false);
    _known.addAll(items.map((n) => n.id));
    if (fresh.isEmpty || !mounted) return;

    // The stream is sorted newest-first.
    setState(() => _current = fresh.first);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 6), _dismiss);
  }

  void _dismiss() {
    _hideTimer?.cancel();
    if (mounted && _current != null) setState(() => _current = null);
  }

  void _open(AppNotification item) {
    _dismiss();
    try {
      GoRouter.of(context).push('/notifications');
    } catch (_) {
      // Without a router (tests) the banner is still allowed to close.
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: item == null ? const Offset(0, -1.2) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: item == null ? 0 : 1,
                child: item == null
                    ? const SizedBox(height: 1)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: _Banner(item: item, onTap: () => _open(item)),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.creamBright.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.type.icon,
                  size: 17,
                  color: AppColors.creamBright,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.35,
                        color: AppColors.creamBright.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.creamBright,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
