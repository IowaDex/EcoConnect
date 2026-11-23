import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../models/community_event.dart';
import '../models/event_participant.dart';
import '../services/event_service.dart';

/// Which half of the calendar is on screen.
enum _EventTab { upcoming, completed }

/// Community events feed with staff management and resident browsing.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _service = EventService();
  final _search = TextEditingController();
  _EventTab _tab = _EventTab.upcoming;
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CommunityEvent> _filter(List<CommunityEvent> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.location.toLowerCase().contains(q) ||
              e.category.label.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isStaff = user?.role == UserRole.admin;

    return EcoPageScaffold(
      eyebrow: 'COMMUNITY · EVENTS',
      title: 'Community events',
      subtitle: isStaff
          ? 'Organise clean-ups, tree planting and recycling drives.'
          : 'Join programs that keep your barangay green.',
      onBack: () => ecoBack(context, isStaff ? '/admin-dashboard' : '/user'),
      actions: [
        if (isStaff)
          EcoIconAction(
            icon: Icons.add_rounded,
            tooltip: 'New event',
            onTap: () => _openEditor(context),
          ),
        const NotificationBell(),
      ],
      body: StreamBuilder<List<CommunityEvent>>(
        stream: isStaff ? _service.watchAll() : _service.watchPublished(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Loading events');
          }
          if (snapshot.hasError) {
            return ErrorView(message: AppFeedback.describe(snapshot.error!));
          }

          final all = snapshot.data ?? const <CommunityEvent>[];
          final upcoming = all.where((e) => e.isUpcoming).length;
          final completed = all.where((e) => e.isCompleted).length;
          final inTab = all
              .where(
                (e) =>
                    _tab == _EventTab.upcoming ? e.isUpcoming : e.isCompleted,
              )
              .toList(growable: false);
          final items = _filter(inTab);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.event_available_outlined,
                label: 'Upcoming',
                value: '$upcoming',
                accent: AppColors.primary,
                highlight: upcoming > 0,
              ),
              DeskMetric(
                icon: Icons.task_alt_rounded,
                label: 'Completed',
                value: '$completed',
                accent: AppColors.moss,
              ),
              DeskMetric(
                icon: Icons.event_outlined,
                label: 'Events',
                value: '${all.length}',
                accent: AppColors.forest,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search title, place or kind',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_EventTab>(
              value: _tab,
              onChanged: (next) => setState(() {
                _tab = next;
                _page = 0;
              }),
              segments: [
                DeskSegment<_EventTab>(
                  value: _EventTab.upcoming,
                  label: 'Upcoming',
                  count: upcoming,
                ),
                DeskSegment<_EventTab>(
                  value: _EventTab.completed,
                  label: 'Completed',
                  count: completed,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: items.length == inTab.length
                  ? '${inTab.length} '
                        '${inTab.length == 1 ? 'event' : 'events'}'
                  : 'Showing ${items.length} of ${inTab.length}',
              onClear: _query.isEmpty
                  ? null
                  : () => setState(() {
                      _search.clear();
                      _query = '';
                      _page = 0;
                    }),
            ),
            empty: inTab.isEmpty
                ? DeskEmptyQueue(
                    icon: Icons.event_outlined,
                    title: _tab == _EventTab.upcoming
                        ? 'No upcoming events'
                        : 'No completed events yet',
                    message: isStaff
                        ? 'Create an event and publish it so residents can join.'
                        : 'Check back soon for clean-up drives and community '
                              'programs.',
                    steps: isStaff
                        ? const [
                            'Create the event with a date and place',
                            'Publish it to the community calendar',
                            'Watch the sign-ups per street',
                          ]
                        : const [
                            'The barangay posts a program',
                            'Join it from the event page',
                            'Turn up on the day — that is it',
                          ],
                    actionLabel: isStaff ? 'New event' : null,
                    actionIcon: Icons.add_rounded,
                    onAction: isStaff ? () => _openEditor(context) : null,
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No event matches',
                    message: 'Nothing in this tab matches "$_query".',
                    actionLabel: 'Clear search',
                    actionIcon: Icons.refresh_rounded,
                    onAction: () => setState(() {
                      _search.clear();
                      _query = '';
                      _page = 0;
                    }),
                  ),
            itemCount: visible.length,
            separator: 10,
            itemBuilder: (context, i) {
              final item = visible[i];
              return _EventCard(
                event: item,
                canManage: isStaff,
                onTap: () => _openDetail(context, item, isStaff, user),
                onEdit: () => _openEditor(context, existing: item),
                onToggle: () => _toggle(context, item),
                onDelete: () => _delete(context, item),
              );
            },
            pagination: items.isEmpty
                ? null
                : EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: items.length,
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

  Future<void> _toggle(BuildContext context, CommunityEvent item) async {
    try {
      await _service.setStatus(
        item.id,
        item.isPublished ? EventStatus.draft : EventStatus.published,
      );
      if (!context.mounted) return;
      AppFeedback.success(
        context,
        item.isPublished ? 'Moved back to drafts' : 'Event published',
      );
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _delete(BuildContext context, CommunityEvent item) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Delete event?',
      message: '"${item.title}" will be removed from the community calendar.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await _service.delete(item.id);
      if (context.mounted) AppFeedback.success(context, 'Event deleted');
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _openDetail(
    BuildContext context,
    CommunityEvent item,
    bool canManage,
    AppUser? user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (ctx) => _EventDetail(
        event: item,
        canManage: canManage,
        user: user,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openEditor(context, existing: item);
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    CommunityEvent? existing,
  }) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditor(
        existing: existing,
        authorId: user.uid,
        authorName: user.displayName ?? 'Barangay staff',
        barangay: user.barangay,
      ),
    );
  }
}

/// One event: the date block, the facts, and where it stands.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final CommunityEvent event;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = event.imageUrl;

    return DeskRailCard(
      railColor: event.category.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: event.startAt, completed: event.isCompleted),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(
                        context,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EcoType.meta(
                              context,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${timeLabel(event.startAt)} · '
                      '${relativeDay(event.startAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                    if (event.isUpcoming) ...[
                      const SizedBox(height: 5),
                      _ParticipantCount(eventId: event.id),
                    ],
                  ],
                ),
              ),
              if (image.isNotEmpty) ...[
                const SizedBox(width: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                  child: Image.memory(
                    _bytes(image),
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              StatusBadge(
                label: event.category.label,
                color: event.category.color,
                icon: event.category.icon,
                compact: true,
              ),
              if (canManage && !event.isPublished) ...[
                const SizedBox(width: 5),
                const StatusBadge(
                  label: 'Draft',
                  color: AppColors.inkMuted,
                  compact: true,
                ),
              ],
              const Spacer(),
              if (canManage)
                _ManageMenu(
                  published: event.isPublished,
                  onEdit: onEdit,
                  onToggle: onToggle,
                  onDelete: onDelete,
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 28px overflow menu the announcements desk also uses.
class _ManageMenu extends StatelessWidget {
  const _ManageMenu({
    required this.published,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final bool published;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: 'Manage event',
        icon: const Icon(Icons.more_horiz_rounded, color: AppColors.inkMuted),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'toggle':
              onToggle();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'toggle',
            child: Text(published ? 'Unpublish' : 'Publish'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

/// "12 going" chip on an event card.
class _ParticipantCount extends StatefulWidget {
  const _ParticipantCount({required this.eventId});

  final String eventId;

  @override
  State<_ParticipantCount> createState() => _ParticipantCountState();
}

class _ParticipantCountState extends State<_ParticipantCount> {
  late Future<int> _count;

  @override
  void initState() {
    super.initState();
    _count = EventService().participantCount(widget.eventId);
    EventService.membershipVersion.addListener(_refresh);
  }

  // The list shows a plain headcount, so it is counted on the server and
  // refreshed when this device joins or leaves, not streamed live per card.
  void _refresh() {
    if (!mounted) return;
    // The callback must not return the assigned Future, or setState throws.
    setState(() {
      _count = EventService().participantCount(widget.eventId);
    });
  }

  @override
  void dispose() {
    EventService.membershipVersion.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _count,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_rounded,
              size: 12,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$count going',
              style: EcoType.meta(
                context,
                color: AppColors.primary,
                weight: FontWeight.w700,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.completed});

  final DateTime date;
  final bool completed;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: 46,
      decoration: BoxDecoration(
        color: completed
            ? AppColors.inkMuted.withValues(alpha: 0.1)
            : AppColors.lightGreen,
        borderRadius: BorderRadius.circular(EcoRadius.sm + 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _months[date.month - 1],
            style: EcoType.micro(
              context,
              color: completed ? AppColors.inkMuted : AppColors.primary,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 19,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: completed ? AppColors.inkMuted : AppColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}

class _EventDetail extends StatefulWidget {
  const _EventDetail({
    required this.event,
    required this.canManage,
    required this.user,
    required this.onEdit,
  });

  final CommunityEvent event;
  final bool canManage;

  /// Passed in rather than read from the provider: the sheet lives on its own
  /// route, and the caller already has the signed-in resident.
  final AppUser? user;

  final VoidCallback onEdit;

  @override
  State<_EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<_EventDetail> {
  final _service = EventService();
  bool _busy = false;

  Future<void> _toggleJoin(AppUser user, bool joined) async {
    setState(() => _busy = true);
    try {
      if (joined) {
        await _service.leave(widget.event.id, user.uid);
      } else {
        await _service.join(
          eventId: widget.event.id,
          uid: user.uid,
          name: user.displayName ?? 'Resident',
          street: user.houseStreet,
          barangay: user.barangay,
        );
      }
      if (!mounted) return;
      AppFeedback.success(
        context,
        joined ? 'You left this event' : "You're signed up — see you there!",
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final user = widget.user;
    final image = event.imageUrl;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const SizedBox(height: EcoSpace.md),
          if (image.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              child: Image.memory(
                _bytes(image),
                height: 168,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: EcoSpace.md),
          ],
          Row(
            children: [
              StatusBadge(
                label: event.category.label,
                color: event.category.color,
                icon: event.category.icon,
              ),
              const Spacer(),
              if (event.isCompleted)
                const StatusBadge(
                  label: 'Completed',
                  color: AppColors.inkMuted,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Text(
            event.title,
            style: EcoType.panelTitle(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: EcoSpace.md),
          _DetailRow(
            icon: Icons.event_rounded,
            text: dateTimeLabel(event.startAt),
          ),
          if (event.endAt != null)
            _DetailRow(
              icon: Icons.event_available_rounded,
              text: 'Ends ${dateTimeLabel(event.endAt)}',
            ),
          _DetailRow(icon: Icons.place_outlined, text: event.location),
          if (event.registrationInfo?.trim().isNotEmpty == true)
            _DetailRow(
              icon: Icons.how_to_reg_outlined,
              text: event.registrationInfo!,
            ),
          if (event.contact?.trim().isNotEmpty == true)
            _DetailRow(icon: Icons.call_outlined, text: event.contact!),
          const SizedBox(height: EcoSpace.sm),
          Text(
            event.description,
            style: EcoType.body(context, color: AppColors.textDark),
          ),
          const SizedBox(height: EcoSpace.lg),
          _ParticipantsPanel(
            eventId: event.id,
            currentUid: user?.uid,
            canJoin: !widget.canManage && event.isUpcoming,
            busy: _busy,
            onToggle: user == null
                ? null
                : (joined) => _toggleJoin(user, joined),
          ),
          if (widget.canManage) ...[
            const SizedBox(height: EcoSpace.md),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  'Edit event',
                  style: EcoType.action(context, color: AppColors.forest),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.forest, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EcoRadius.sm),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Headcount, the join button, and where the crowd is coming from.
///
/// The count and the street breakdown come from the anonymous street counters,
/// and the join state from the resident's own sign-up row; other residents'
/// rows (names, streets) are private and never read here. The streams are held
/// in the state — building them in `build` would resubscribe on every rebuild
/// and blank the panel out.
class _ParticipantsPanel extends StatefulWidget {
  const _ParticipantsPanel({
    required this.eventId,
    required this.currentUid,
    required this.canJoin,
    required this.busy,
    required this.onToggle,
  });

  final String eventId;
  final String? currentUid;
  final bool canJoin;
  final bool busy;
  final ValueChanged<bool>? onToggle;

  @override
  State<_ParticipantsPanel> createState() => _ParticipantsPanelState();
}

class _ParticipantsPanelState extends State<_ParticipantsPanel> {
  late final Stream<List<StreetCount>> _counts = EventService()
      .watchStreetCounts(widget.eventId);
  late final Stream<bool> _joined = widget.currentUid == null
      ? Stream<bool>.value(false)
      : EventService().watchJoined(widget.eventId, widget.currentUid!);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StreetCount>>(
      stream: _counts,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const <StreetCount>[];
        final total = counts.fold<int>(0, (sum, c) => sum + c.count);
        // Biggest street first. Residents with no street count towards the
        // total but have no street row.
        final top = [
          for (final c in counts)
            if (c.key != StreetCount.noStreetKey) MapEntry(c.label, c.count),
        ];
        final maxCount = top.isEmpty ? 1 : top.first.value;

        return StreamBuilder<bool>(
          stream: _joined,
          builder: (context, joinedSnapshot) {
            final joined = joinedSnapshot.data ?? false;
            return Container(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.lg),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.8),
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$total ${total == 1 ? 'resident' : 'residents'} '
                          'going',
                          style: EcoType.cardTitle(
                            context,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ),
                      if (joined)
                        const StatusBadge(
                          label: "You're in",
                          color: AppColors.primary,
                          icon: Icons.check_circle_rounded,
                          compact: true,
                        ),
                    ],
                  ),
                  if (top.isNotEmpty) ...[
                    const SizedBox(height: EcoSpace.md),
                    Text(
                      'BY STREET',
                      style: EcoType.eyebrow(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in top.take(4))
                      _streetRow(entry.key, entry.value, maxCount),
                    if (top.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+${top.length - 4} more '
                          '${top.length - 4 == 1 ? 'street' : 'streets'}',
                          style: EcoType.meta(
                            context,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                  ],
                  if (widget.canJoin) ...[
                    const SizedBox(height: EcoSpace.md),
                    if (joined)
                      SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: widget.busy
                              ? null
                              : () => widget.onToggle?.call(true),
                          icon: const Icon(Icons.event_busy_rounded, size: 16),
                          label: Text(
                            'Cancel my spot',
                            style: EcoType.action(
                              context,
                              color: AppColors.forest,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side: const BorderSide(
                              color: AppColors.forest,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EcoRadius.sm),
                            ),
                          ),
                        ),
                      )
                    else
                      PrimaryButton(
                        label: 'Join this event',
                        height: 46,
                        loading: widget.busy,
                        onPressed: () => widget.onToggle?.call(false),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _streetRow(String label, int count, int max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EcoType.bodySmall(context, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 62, child: GrowBar(value: count / max, height: 5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: EcoType.meta(
                context,
                color: AppColors.darkGreen,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({
    this.existing,
    required this.authorId,
    required this.authorName,
    this.barangay,
  });

  final CommunityEvent? existing;
  final String authorId;
  final String authorName;
  final String? barangay;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  final _formKey = GlobalKey<FormState>();
  final _service = EventService();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _registration;
  late final TextEditingController _contact;
  late EventCategory _category;
  late EventStatus _status;
  late DateTime _startAt;
  DateTime? _endAt;
  UploadPayload? _image;
  bool _removeImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _registration = TextEditingController(
      text: existing?.registrationInfo ?? '',
    );
    _contact = TextEditingController(text: existing?.contact ?? '');
    _category = existing?.category ?? EventCategory.cleanup;
    _status = existing?.status ?? EventStatus.published;
    _startAt = existing?.startAt ?? DateTime.now().add(const Duration(days: 7));
    _endAt = existing?.endAt;
    _image = existing?.image;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _location,
      _registration,
      _contact,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      AppFeedback.error(context, 'The end time must be after the start time.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.save(
        id: widget.existing?.id,
        title: _title.text,
        description: _description.text,
        category: _category,
        location: _location.text,
        startAt: _startAt,
        endAt: _endAt,
        image: _image,
        removeImage: _removeImage,
        status: _status,
        registrationInfo: _registration.text,
        contact: _contact.text,
        authorId: widget.authorId,
        authorName: widget.authorName,
        barangay: widget.barangay,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(
        context,
        widget.existing == null ? 'Event created' : 'Event updated',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: EcoSpace.md),
                Text(
                  widget.existing == null
                      ? 'New community event'
                      : 'Edit event',
                  style: EcoType.panelTitle(
                    context,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upcoming events appear on every resident dashboard.',
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
                const SizedBox(height: EcoSpace.md),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Event title',
                    hintText: 'e.g. Barangay clean-up drive',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 4)
                      ? 'Please enter an event title'
                      : null,
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What will happen and who can join?',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                      ? 'Please describe the event'
                      : null,
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                DropdownButtonFormField<EventCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in EventCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                TextFormField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Barangay hall, covered court, etc.',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter the event location'
                      : null,
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                _dateTile(
                  label: 'Starts',
                  value: dateTimeLabel(_startAt),
                  onTap: () async {
                    final picked = await _pickDateTime(_startAt);
                    if (picked != null) setState(() => _startAt = picked);
                  },
                ),
                const SizedBox(height: EcoSpace.sm),
                _dateTile(
                  label: 'Ends (optional)',
                  value: _endAt == null ? 'Not set' : dateTimeLabel(_endAt),
                  onTap: () async {
                    final picked = await _pickDateTime(
                      _endAt ?? _startAt.add(const Duration(hours: 3)),
                    );
                    if (picked != null) setState(() => _endAt = picked);
                  },
                  onClear: _endAt == null
                      ? null
                      : () => setState(() => _endAt = null),
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                TextFormField(
                  controller: _registration,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Registration information (optional)',
                    hintText: 'Where or how residents can sign up',
                  ),
                ),
                const SizedBox(height: EcoSpace.sm + 2),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number (optional)',
                    hintText: '09XX XXX XXXX',
                  ),
                ),
                const SizedBox(height: EcoSpace.md),
                ImagePickerField(
                  value: _image,
                  label: 'Event poster (optional)',
                  helper: 'JPG, PNG or WebP',
                  previewHeight: 140,
                  onChanged: (value) => setState(() {
                    _image = value;
                    _removeImage =
                        value == null && widget.existing?.image != null;
                  }),
                ),
                const SizedBox(height: EcoSpace.xs),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _status == EventStatus.published,
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'Publish event',
                    style: EcoType.bodyStrong(
                      context,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off to keep this as a draft.',
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                  onChanged: (value) => setState(
                    () => _status = value
                        ? EventStatus.published
                        : EventStatus.draft,
                  ),
                ),
                const SizedBox(height: EcoSpace.sm),
                PrimaryButton(
                  label: widget.existing == null
                      ? 'Create event'
                      : 'Save changes',
                  loading: _saving,
                  height: 50,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EcoRadius.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(EcoRadius.sm),
              ),
              child: const Icon(
                Icons.event_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: EcoSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: EcoType.eyebrow(context, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EcoType.bodyStrong(
                      context,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                color: AppColors.inkMuted,
                visualDensity: VisualDensity.compact,
              )
            else
              const Icon(
                Icons.edit_calendar_outlined,
                size: 16,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}
