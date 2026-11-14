import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/community_event.dart';
import '../models/event_participant.dart';
import '../services/event_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Community events feed with staff management and resident browsing.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _service = EventService();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isStaff = user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New event'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Community events',
              subtitle: isStaff
                  ? 'Organise clean-ups, tree planting and recycling drives.'
                  : 'Join programs that keep your barangay green.',
              onBack: () => context.go(isStaff ? '/admin-dashboard' : '/user'),
              actions: const [NotificationBell()],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Row(
                  children: [
                    _tabButton('Upcoming', 0),
                    _tabButton('Completed', 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<CommunityEvent>>(
                stream: isStaff ? _service.watchAll() : _service.watchPublished(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading events');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final all = snapshot.data ?? const <CommunityEvent>[];
                  final items = all
                      .where((e) => _tab == 0 ? e.isUpcoming : e.isCompleted)
                      .toList(growable: false);
                  if (items.isEmpty) {
                    // No action button here on purpose: the FAB above already
                    // does the same job, and two buttons with one behaviour on
                    // the same screen just looks like a bug.
                    return EmptyState(
                      icon: Icons.event_outlined,
                      title: _tab == 0
                          ? 'No upcoming events'
                          : 'No completed events yet',
                      message: isStaff
                          ? 'Create an event and publish it so residents can join.'
                          : 'Check back soon for clean-up drives and community programs.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _EventCard(
                        event: item,
                        canManage: isStaff,
                        onTap: () => _openDetail(context, item, isStaff, user),
                        onEdit: () => _openEditor(context, existing: item),
                        onToggle: () => _toggle(context, item),
                        onDelete: () => _delete(context, item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.inkMuted,
            ),
          ),
        ),
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
      builder: (_) => _EventEditor(
        existing: existing,
        authorId: user.uid,
        authorName: user.displayName ?? 'Barangay staff',
        barangay: user.barangay,
      ),
    );
  }
}

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
    return EcoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.memory(
                _bytes(image),
                height: 124,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBlock(date: event.startAt, completed: event.isCompleted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: event.category.label,
                            color: event.category.color,
                            icon: event.category.icon,
                            compact: true,
                          ),
                          const SizedBox(width: 5),
                          if (canManage && !event.isPublished)
                            const StatusBadge(
                              label: 'Draft',
                              color: AppColors.inkMuted,
                              compact: true,
                            ),
                          const Spacer(),
                          if (canManage)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: AppColors.inkMuted,
                              ),
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
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    event.isPublished ? 'Unpublish' : 'Publish',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: AppColors.inkMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: AppColors.inkMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${timeLabel(event.startAt)} · ${relativeDay(event.startAt)}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      if (event.isUpcoming) ...[
                        const SizedBox(height: 6),
                        _ParticipantCount(eventId: event.id),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          children: [
            const Icon(Icons.groups_rounded,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '$count going',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 50,
      decoration: BoxDecoration(
        color: completed
            ? AppColors.inkMuted.withValues(alpha: 0.12)
            : AppColors.lightGreen,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _months[date.month - 1],
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: completed ? AppColors.inkMuted : AppColors.primary,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w700,
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
      initialChildSize: 0.76,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          if (image.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(_bytes(image), fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          StatusBadge(
            label: event.category.label,
            color: event.category.color,
            icon: event.category.icon,
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow(Icons.event_rounded, dateTimeLabel(event.startAt)),
          if (event.endAt != null)
            _detailRow(Icons.event_available_rounded,
                'Ends ${dateTimeLabel(event.endAt)}'),
          _detailRow(Icons.place_outlined, event.location),
          if (event.registrationInfo?.trim().isNotEmpty == true)
            _detailRow(Icons.how_to_reg_outlined, event.registrationInfo!),
          if (event.contact?.trim().isNotEmpty == true)
            _detailRow(Icons.call_outlined, event.contact!),
          const SizedBox(height: 16),
          Text(
            event.description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 22),
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
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit event'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
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
  late final Stream<List<StreetCount>> _counts =
      EventService().watchStreetCounts(widget.eventId);
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sage),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '$total ${total == 1 ? 'resident' : 'residents'} going',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const Spacer(),
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
                    const SizedBox(height: 14),
                    const Text(
                      'BY STREET',
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
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
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                  ],
                  if (widget.canJoin) ...[
                    const SizedBox(height: 14),
                    if (joined)
                      OutlinedButton.icon(
                        onPressed:
                            widget.busy ? null : () => widget.onToggle?.call(true),
                        icon: const Icon(Icons.event_busy_rounded, size: 16),
                        label: const Text('Cancel my spot'),
                      )
                    else
                      FilledButton.icon(
                        onPressed:
                            widget.busy ? null : () => widget.onToggle?.call(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        icon: widget.busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.how_to_reg_rounded, size: 17),
                        label: const Text('Join this event'),
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
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: GrowBar(value: count / max, height: 5),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
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
    _startAt = existing?.startAt ??
        DateTime.now().add(const Duration(days: 7));
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
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New community event' : 'Edit event',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upcoming events appear on every resident dashboard.',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Event title',
                  hintText: 'e.g. Barangay clean-up drive',
                ),
                validator: (value) => (value == null || value.trim().length < 4)
                    ? 'Please enter an event title'
                    : null,
              ),
              const SizedBox(height: 12),
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
                validator: (value) => (value == null || value.trim().length < 10)
                    ? 'Please describe the event'
                    : null,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _dateTile(
                label: 'Starts',
                value: dateTimeLabel(_startAt),
                onTap: () async {
                  final picked = await _pickDateTime(_startAt);
                  if (picked != null) setState(() => _startAt = picked);
                },
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _registration,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Registration information (optional)',
                  hintText: 'Where or how residents can sign up',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number (optional)',
                  hintText: '09XX XXX XXXX',
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _status == EventStatus.published,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Publish event',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: const Text(
                  'Turn off to keep this as a draft.',
                  style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
                ),
                onChanged: (value) => setState(
                  () => _status =
                      value ? EventStatus.published : EventStatus.draft,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing == null ? 'Create event' : 'Save changes',
                        ),
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                color: AppColors.inkMuted,
                visualDensity: VisualDensity.compact,
              )
            else
              const Icon(Icons.edit_calendar_outlined,
                  size: 17, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
