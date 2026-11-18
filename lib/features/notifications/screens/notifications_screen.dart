import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// In-app notification centre shared by residents, drivers and staff.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Keeps the alerts whose title, body or kind matches the search box.
  List<AppNotification> _filter(List<AppNotification> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q) ||
          n.type.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading notifications'));
    }
    final service = NotificationService();
    final deskChannel = switch (user.role) {
      UserRole.admin => NotificationService.staffChannel,
      UserRole.cityHall => NotificationService.cityHallChannel,
      UserRole.iswim => NotificationService.iswimChannel,
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Notifications',
              subtitle: 'Route, request and verification updates.',
              onBack: () => context.go(switch (user.role) {
                UserRole.admin => '/admin-dashboard',
                UserRole.driver => '/driver',
                UserRole.user => '/user',
                UserRole.iswim => '/iswim',
                UserRole.cityHall => '/cityhall',
                UserRole.auditor => '/audit-log',
              }),
              actions: [
                IconButton(
                  onPressed: () async {
                    try {
                      await (deskChannel == null
                          ? service.markAllRead(user.uid)
                          : service.markAllReadForDesk(user.uid, deskChannel));
                      if (context.mounted) {
                        AppFeedback.success(context, 'All notifications read');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppFeedback.error(context, AppFeedback.describe(e));
                      }
                    }
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  tooltip: 'Mark all read',
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: deskChannel == null
                    ? service.watch(user.uid)
                    : service.watchForDesk(user.uid, deskChannel),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading notifications');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final items = snapshot.data ?? const <AppNotification>[];
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'You are all caught up',
                      message:
                          'Route changes, approvals and announcements will appear here.',
                    );
                  }
                  final filtered = _filter(items);
                  final page = clampPage(_page, filtered.length, _pageSize);
                  final visible = pageSlice(filtered, page, _pageSize);
                  final today = visible
                      .where((n) => _isToday(n.createdAt))
                      .toList();
                  final earlier = visible
                      .where((n) => !_isToday(n.createdAt))
                      .toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                        child: EcoSearchField(
                          controller: _search,
                          hint: 'Search alerts',
                          onChanged: (value) => setState(() {
                            _query = value;
                            _page = 0;
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                        child: EcoResultCount(
                          shown: filtered.length,
                          total: items.length,
                          singular: 'alert',
                          plural: 'alerts',
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                    'No alert matches your search.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  10,
                                ),
                                children: [
                                  if (today.isNotEmpty) ...[
                                    const SectionHeader(title: 'Today'),
                                    const SizedBox(height: 8),
                                    for (final item in today)
                                      _NotificationTile(
                                        notification: item,
                                        onTap: () =>
                                            _open(context, item, user.role),
                                        onDelete: () => _delete(context, item),
                                      ),
                                  ],
                                  if (earlier.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    const SectionHeader(title: 'Earlier'),
                                    const SizedBox(height: 8),
                                    for (final item in earlier)
                                      _NotificationTile(
                                        notification: item,
                                        onTap: () =>
                                            _open(context, item, user.role),
                                        onDelete: () => _delete(context, item),
                                      ),
                                  ],
                                ],
                              ),
                      ),
                      if (filtered.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                          child: EcoPaginationBar(
                            page: page,
                            pageSize: _pageSize,
                            total: filtered.length,
                            onPageChanged: (next) =>
                                setState(() => _page = next),
                            onPageSizeChanged: (size) => setState(() {
                              _pageSize = size;
                              _page = 0;
                            }),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _delete(BuildContext context, AppNotification item) async {
    try {
      await NotificationService().delete(item.id);
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _open(
    BuildContext context,
    AppNotification item,
    UserRole role,
  ) async {
    try {
      if (!item.read) await NotificationService().markRead(item.id);
    } catch (_) {
      // Navigation matters more than the read receipt.
    }
    if (!context.mounted) return;

    // A memo alert carries the document id, so the recipient lands on the
    // memo itself instead of the dashboard root. This applies to every desk:
    // City Hall, Iswim and the barangay all read memos.
    final memoId = item.data['memoId'];
    if (item.data['kind'] == 'memo' && memoId is String && memoId.isNotEmpty) {
      context.push('/memo/$memoId');
      return;
    }

    // Some alerts carry a kind that points at a specific record. Routing on
    // the kind is more precise than routing on the notification type alone.
    final kind = item.data['kind'];
    if (kind is String) {
      final ticketId = item.data['ticketId'];
      if (kind.startsWith('ticket') &&
          ticketId is String &&
          ticketId.isNotEmpty) {
        context.push('/tickets/$ticketId');
        return;
      }
      if (kind == 'incident') {
        context.push('/incidents');
        return;
      }
      if (kind == 'complaintFiled' || kind == 'complaintResponse') {
        // The alert carries the complaint id, so the reader lands on that
        // thread instead of the top of the list.
        final complaintId = item.data['complaintId'] as String?;
        final cityHall = role == UserRole.cityHall;
        context.push(
          cityHall
              ? (complaintId == null
                    ? '/complaints'
                    : '/complaints?id=$complaintId')
              : (complaintId == null
                    ? '/my-complaints'
                    : '/my-complaints?id=$complaintId'),
        );
        return;
      }
      if (kind == 'planAssigned' || kind == 'planCancelled') {
        context.push(role == UserRole.driver ? '/driver-routes' : '/routes');
        return;
      }
      if (kind.startsWith('delay')) {
        context.push('/delays');
        return;
      }
      if (kind.startsWith('manual')) {
        context.push(
          kind.toLowerCase().contains('request')
              ? '/manual-requests'
              : '/manuals',
        );
        return;
      }
    }

    // Desk roles have their own destinations; residents and drivers keep the
    // original routes.
    if (role == UserRole.cityHall || role == UserRole.iswim) {
      final cityHall = role == UserRole.cityHall;
      switch (item.type) {
        case AppNotificationType.request:
          context.push(cityHall ? '/cityhall-requests' : '/manuals');
        case AppNotificationType.waste:
          context.push(cityHall ? '/cityhall' : '/iswim');
        case AppNotificationType.verification:
          context.push(cityHall ? '/cityhall' : '/iswim');
        case AppNotificationType.account:
          // Iswim runs the account desk; City Hall provisions from its own
          // dashboard.
          context.push(cityHall ? '/cityhall' : '/accounts');
        case AppNotificationType.route:
          context.push(cityHall ? '/cityhall' : '/iswim');
        case AppNotificationType.announcement:
          context.push('/announcements');
        case AppNotificationType.event:
          context.push('/events');
        case AppNotificationType.system:
        case AppNotificationType.complaint:
          context.push(cityHall ? '/cityhall' : '/iswim');
      }
      return;
    }

    final isStaff = role == UserRole.admin;
    // A delay alert names a desk, not a record; the barangay reads delays on
    // its own board.
    if (isStaff && item.data['delayId'] != null) {
      context.push('/delays');
      return;
    }
    switch (item.type) {
      case AppNotificationType.request:
        context.push(isStaff ? '/staff-requests' : '/my-requests');
      case AppNotificationType.waste:
        context.push(isStaff ? '/waste-validation' : '/waste-history');
      case AppNotificationType.verification:
        context.push(isStaff ? '/verification' : '/user');
      case AppNotificationType.route:
        // The barangay no longer dispatches or watches routes; Iswim and City
        // Hall do. A stale notification just lands on their desk.
        context.push(isStaff ? '/admin-dashboard' : '/driver');
      case AppNotificationType.announcement:
        context.push('/announcements');
      case AppNotificationType.event:
        context.push('/events');
      case AppNotificationType.account:
        // "New resident registration" and other account notices land on the
        // residents desk, which is where the barangay reviews them.
        if (isStaff) context.push('/verification');
      case AppNotificationType.complaint:
      case AppNotificationType.system:
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: unread ? Colors.white : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unread
                      ? notification.type.color.withValues(alpha: 0.45)
                      : AppColors.sage.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: notification.type.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.type.icon,
                      size: 17,
                      color: notification.type.color,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Text(
                              timeAgo(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.45,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unread)
                    Container(
                      margin: const EdgeInsets.only(left: 6, top: 4),
                      height: 7,
                      width: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
