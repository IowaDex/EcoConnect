import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Which slice of the feed is on screen.
enum _Feed { all, unread }

/// In-app notification centre shared by residents, drivers and staff.
///
/// Same shell as every other desk page: three figures, one search + view
/// switch, a result line, then records on a rail card. The rail carries the
/// notification type, so a verification alert reads the same colour here as
/// it does on the verification desk.
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
  _Feed _feed = _Feed.all;

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

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _homeFor(UserRole role) => switch (role) {
    UserRole.admin => '/admin-dashboard',
    UserRole.driver => '/driver',
    UserRole.user => '/user',
    UserRole.iswim => '/iswim',
    UserRole.cityHall => '/cityhall',
    UserRole.auditor => '/audit-log',
  };

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

    return EcoPageScaffold(
      eyebrow: 'ALERT CENTRE',
      title: 'Notifications',
      subtitle: 'Route, request and verification updates.',
      onBack: () => context.go(_homeFor(user.role)),
      actions: [
        EcoIconAction(
          icon: Icons.done_all_rounded,
          tooltip: 'Mark all read',
          onTap: () => _markAllRead(context, service, user.uid, deskChannel),
        ),
      ],
      body: StreamBuilder<List<AppNotification>>(
        stream: deskChannel == null
            ? service.watch(user.uid)
            : service.watchForDesk(user.uid, deskChannel),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Loading notifications');
          }
          if (snapshot.hasError) {
            return ErrorView(message: AppFeedback.describe(snapshot.error!));
          }

          final items = snapshot.data ?? const <AppNotification>[];
          final unread = items.where((n) => !n.read).toList(growable: false);
          final base = _feed == _Feed.unread ? unread : items;
          final filtered = _filter(base);
          final page = clampPage(_page, filtered.length, _pageSize);
          final visible = pageSlice(filtered, page, _pageSize);

          final today = visible
              .where((n) => _isToday(n.createdAt))
              .toList(growable: false);
          final earlier = visible
              .where((n) => !_isToday(n.createdAt))
              .toList(growable: false);

          // One flat list of headers and records, because DeskQueueView pages
          // a single index range. The header rows travel with their group.
          final entries = <_FeedEntry>[
            if (today.isNotEmpty) _FeedEntry.header('Today', today.length),
            ...today.map(_FeedEntry.item),
            if (earlier.isNotEmpty)
              _FeedEntry.header('Earlier', earlier.length),
            ...earlier.map(_FeedEntry.item),
          ];

          final todayTotal = items.where((n) => _isToday(n.createdAt)).length;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.mark_email_unread_outlined,
                label: 'Unread',
                value: '${unread.length}',
                accent: AppColors.primary,
                highlight: unread.isNotEmpty,
              ),
              DeskMetric(
                icon: Icons.today_outlined,
                label: 'Today',
                value: '$todayTotal',
                accent: const Color(0xFF1565C0),
              ),
              DeskMetric(
                icon: Icons.inbox_outlined,
                label: 'All alerts',
                value: '${items.length}',
                accent: AppColors.forest,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search alerts',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_Feed>(
              value: _feed,
              onChanged: (next) => setState(() {
                _feed = next;
                _page = 0;
              }),
              segments: [
                DeskSegment<_Feed>(
                  value: _Feed.all,
                  label: 'All',
                  count: items.length,
                ),
                DeskSegment<_Feed>(
                  value: _Feed.unread,
                  label: 'Unread',
                  count: unread.length,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: filtered.length == items.length
                  ? '${items.length} ${items.length == 1 ? 'alert' : 'alerts'}'
                  : 'Showing ${filtered.length} of ${items.length}',
              onClear: _query.isEmpty && _feed == _Feed.all
                  ? null
                  : () => setState(() {
                      _search.clear();
                      _query = '';
                      _feed = _Feed.all;
                      _page = 0;
                    }),
            ),
            empty: items.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.notifications_none_rounded,
                    title: 'You are all caught up',
                    message:
                        'Route changes, approvals and announcements land here '
                        'the moment a desk acts on them.',
                    steps: [
                      'A desk approves, assigns or rejects something',
                      'An alert is written to your feed',
                      'Tap it to open the record it came from',
                    ],
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No alert matches',
                    message:
                        'Nothing in this view matches "$_query". Try a shorter '
                        'word, or switch back to All.',
                    actionLabel: 'Show all alerts',
                    actionIcon: Icons.inbox_outlined,
                    onAction: () => setState(() {
                      _search.clear();
                      _query = '';
                      _feed = _Feed.all;
                      _page = 0;
                    }),
                  ),
            itemCount: entries.length,
            separator: 8,
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry.label != null) {
                return _FeedHeader(label: entry.label!, count: entry.count);
              }
              final item = entry.notification!;
              return _NotificationTile(
                notification: item,
                onTap: () => _open(context, item, user.role),
                onDelete: () => _delete(context, item),
              );
            },
            pagination: filtered.isEmpty
                ? null
                : EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: filtered.length,
                    onPageChanged: (next) => setState(() => _page = next),
                    onPageSizeChanged: (size) => setState(() {
                      _pageSize = size;
                      _page = 0;
                    }),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(
    BuildContext context,
    NotificationService service,
    String uid,
    String? deskChannel,
  ) async {
    try {
      await (deskChannel == null
          ? service.markAllRead(uid)
          : service.markAllReadForDesk(uid, deskChannel));
      if (context.mounted) {
        AppFeedback.success(context, 'All notifications read');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, AppFeedback.describe(e));
      }
    }
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
      if (kind == 'manualApprovedCopy') {
        context.push(role == UserRole.admin ? '/assignments' : '/cityhall');
        return;
      }
      if (kind == 'manualApprovedSchedule') {
        // Residents read the approved manual, not the trip ticket.
        context.push('/schedule');
        return;
      }
      if (kind.startsWith('manual') &&
          ticketId is String &&
          ticketId.isNotEmpty) {
        context.push('/tickets/$ticketId');
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

/// One row of the flat feed: either a day header or a notification.
class _FeedEntry {
  const _FeedEntry.header(this.label, this.count) : notification = null;
  const _FeedEntry.item(this.notification) : label = null, count = 0;

  final String? label;
  final int count;
  final AppNotification? notification;
}

/// `TODAY · 4` with a hairline filling the rest of the row.
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
      child: Row(
        children: [
          Text(
            '$label · $count',
            style: EcoType.eyebrow(context, color: AppColors.inkMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.sage.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
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
    final accent = notification.type.color;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: DeskRailCard(
        railColor: unread ? accent : accent.withValues(alpha: 0.35),
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(15, 12, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EcoRadius.sm),
                  ),
                  child: Icon(notification.type.icon, size: 16, color: accent),
                ),
                const SizedBox(width: EcoSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.cardTitle(
                          context,
                          color: AppColors.textDark,
                          weight: unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${notification.type.label.toUpperCase()} · '
                        '${timeAgo(notification.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.meta(context, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    height: 7,
                    width: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            if (notification.body.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: EcoType.bodySmall(context, color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
