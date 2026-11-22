import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Shared announcement feed. Residents see published posts; barangay staff
/// see every post plus the create, edit, publish and delete controls.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = AnnouncementService();
  AnnouncementCategory? _filter;
  int _page = 0;
  int _pageSize = 10;

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
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text(
                'New announcement',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                AppPageHeader(
                  title: 'Announcements',
                  subtitle: isStaff
                      ? 'Publish schedules and reminders for your barangay.'
                      : 'Updates from your barangay team.',
                  onBack: () =>
                      context.go(isStaff ? '/admin-dashboard' : '/user'),
                  actions: const [NotificationBell()],
                ),
                Expanded(
                  child: StreamBuilder<List<Announcement>>(
                    stream: isStaff
                        ? _service.watchAll()
                        : _service.watchPublished(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(
                          label: 'Loading announcements',
                        );
                      }
                      if (snapshot.hasError) {
                        return ErrorView(
                          message: AppFeedback.describe(snapshot.error!),
                        );
                      }

                      final all = snapshot.data ?? const <Announcement>[];
                      final items = _filter == null
                          ? all
                          : all
                                .where((a) => a.category == _filter)
                                .toList(growable: false);
                      final page = clampPage(_page, items.length, _pageSize);
                      final visible = pageSlice(items, page, _pageSize);
                      final published = all.where((a) => a.isPublished).length;
                      final drafts = all.length - published;

                      return Column(
                        children: [
                          if (isStaff)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: DeskMetricRow(
                                metrics: [
                                  DeskMetric(
                                    icon: Icons.campaign_outlined,
                                    label: 'Published',
                                    value: '$published',
                                  ),
                                  DeskMetric(
                                    icon: Icons.edit_note_rounded,
                                    label: 'Drafts',
                                    value: '$drafts',
                                    accent: AppColors.warning,
                                    highlight: drafts > 0,
                                  ),
                                  DeskMetric(
                                    icon: Icons.feed_outlined,
                                    label: 'Total',
                                    value: '${all.length}',
                                  ),
                                ],
                              ),
                            ),
                          _CategoryFilter(
                            all: all,
                            selected: _filter,
                            onChanged: (value) => setState(() {
                              _filter = value;
                              _page = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: items.isEmpty
                                ? DeskEmptyQueue(
                                    icon: Icons.campaign_outlined,
                                    title: isStaff
                                        ? 'No announcements yet'
                                        : 'No announcements right now',
                                    message: isStaff
                                        ? 'Publish a collection schedule or '
                                              'community reminder so residents '
                                              'stay informed.'
                                        : 'Your barangay will post schedules '
                                              'and reminders here.',
                                    actionLabel: _filter == null
                                        ? null
                                        : 'Show all categories',
                                    actionIcon: Icons.filter_alt_off_outlined,
                                    onAction: _filter == null
                                        ? null
                                        : () => setState(() {
                                            _filter = null;
                                            _page = 0;
                                          }),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      6,
                                      20,
                                      10,
                                    ),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, i) {
                                      final item = visible[i];
                                      return _AnnouncementCard(
                                        announcement: item,
                                        canManage: isStaff,
                                        onTap: () =>
                                            _openDetail(context, item, isStaff),
                                        onEdit: () => _openEditor(
                                          context,
                                          existing: item,
                                        ),
                                        onToggle: () => _toggle(context, item),
                                        onDelete: () => _delete(context, item),
                                      );
                                    },
                                  ),
                          ),
                          if (items.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: EcoPaginationBar(
                                page: page,
                                pageSize: _pageSize,
                                total: items.length,
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
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, Announcement item) async {
    try {
      await _service.setStatus(
        item.id,
        item.isPublished
            ? AnnouncementStatus.draft
            : AnnouncementStatus.published,
      );
      if (!context.mounted) return;
      AppFeedback.success(
        context,
        item.isPublished ? 'Moved back to drafts' : 'Announcement published',
      );
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _delete(BuildContext context, Announcement item) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Delete announcement?',
      message: '"${item.title}" will be removed from every resident dashboard.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await _service.delete(item.id);
      if (context.mounted) {
        AppFeedback.success(context, 'Announcement deleted');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _openDetail(
    BuildContext context,
    Announcement item,
    bool canManage,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AnnouncementDetail(
        announcement: item,
        canManage: canManage,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openEditor(context, existing: item);
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    Announcement? existing,
  }) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AnnouncementEditor(
        existing: existing,
        authorId: user.uid,
        authorName: user.displayName ?? 'Barangay staff',
        barangay: user.barangay,
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.all,
    required this.selected,
    required this.onChanged,
  });

  final List<Announcement> all;
  final AnnouncementCategory? selected;
  final ValueChanged<AnnouncementCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final category in AnnouncementCategory.values)
        if (all.any((a) => a.category == category)) category,
    ];

    // A wrapping row rather than a horizontal scroller: six categories fit in
    // two lines on a phone, and every filter stays visible instead of the
    // last one being clipped at the edge of the screen.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          _chip(context, 'All', all.length, selected == null, null, () {
            onChanged(null);
          }),
          for (final category in categories)
            _chip(
              context,
              category.shortLabel,
              all.where((a) => a.category == category).length,
              selected == category,
              category,
              () => onChanged(category),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    int count,
    bool active,
    AnnouncementCategory? category,
    VoidCallback onTap,
  ) {
    final color = category?.color ?? AppColors.forest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? AppColors.forestGradient : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(EcoRadius.pill),
            border: Border.all(
              color: active
                  ? AppColors.forest
                  : AppColors.sage.withValues(alpha: 0.85),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category != null) ...[
                Icon(
                  category.icon,
                  size: 12,
                  color: active ? Colors.white : color,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: EcoType.label(
                  context,
                  color: active ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.24)
                      : AppColors.cream,
                  borderRadius: BorderRadius.circular(EcoRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: EcoType.micro(
                    context,
                    color: active ? Colors.white : AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Announcement announcement;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = announcement.imageUrl;
    final hasImage = image.isNotEmpty;

    return EcoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  Image.memory(
                    _bytes(image),
                    height: 168,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CoverFallback(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.22),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        _GlassBadge(
                          label: announcement.category.shortLabel,
                          icon: announcement.category.icon,
                          color: announcement.category.color,
                        ),
                        if (canManage && !announcement.isPublished) ...[
                          const SizedBox(width: 6),
                          const _GlassBadge(
                            label: 'Draft',
                            icon: Icons.edit_note_rounded,
                            color: Color(0xFF6B6B6B),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canManage)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _ManageMenu(
                          isPublished: announcement.isPublished,
                          onEdit: onEdit,
                          onToggle: onToggle,
                          onDelete: onDelete,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  Row(
                    children: [
                      StatusBadge(
                        label: announcement.category.shortLabel,
                        color: announcement.category.color,
                        icon: announcement.category.icon,
                      ),
                      const SizedBox(width: 6),
                      if (canManage && !announcement.isPublished)
                        const StatusBadge(
                          label: 'Draft',
                          color: AppColors.inkMuted,
                        ),
                      const Spacer(),
                      if (canManage)
                        _ManageMenu(
                          isPublished: announcement.isPublished,
                          onEdit: onEdit,
                          onToggle: onToggle,
                          onDelete: onDelete,
                        ),
                    ],
                  ),
                Text(
                  announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitleLarge(
                    context,
                    color: AppColors.darkGreen,
                  ),
                ),
                if (announcement.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    announcement.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: EcoType.body(context, color: AppColors.inkMuted),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      DeskInitialAvatar(
                        name: announcement.authorName ?? 'Barangay',
                        size: 24,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${announcement.authorName ?? 'Barangay'} · '
                          '${timeAgo(announcement.publishAt ?? announcement.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EcoType.meta(
                            context,
                            color: AppColors.inkMuted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.moss,
                      ),
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

/// The staff overflow menu. It sits in the badge row on a text card and on a
/// white disc over the cover photo, so the three actions never move.
class _ManageMenu extends StatelessWidget {
  const _ManageMenu({
    required this.isPublished,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final bool isPublished;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 19,
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
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(isPublished ? 'Unpublish' : 'Publish'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

/// A translucent pill for a badge sitting on top of a photo.
class _GlassBadge extends StatelessWidget {
  const _GlassBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: EcoType.chip(context, color: color, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Shown when a stored cover photo cannot be decoded.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F2E7), Color(0xFFF1F8E9)],
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 26,
            color: AppColors.moss,
          ),
          SizedBox(height: 6),
          Text(
            'Cover photo unavailable',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
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

class _AnnouncementDetail extends StatelessWidget {
  const _AnnouncementDetail({
    required this.announcement,
    required this.canManage,
    required this.onEdit,
  });

  final Announcement announcement;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final image = announcement.imageUrl;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 30),
            children: [
              StatusBadge(
                label: announcement.category.label,
                color: announcement.category.color,
                icon: announcement.category.icon,
              ),
              const SizedBox(height: 12),
              Text(
                announcement.title,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DeskInitialAvatar(
                    name: announcement.authorName ?? 'Barangay',
                    size: 30,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.authorName ?? 'Barangay staff',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Posted '
                          '${timeAgo(announcement.publishAt ?? announcement.createdAt)}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (image.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _bytes(image),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CoverFallback(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                announcement.body,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.textDark,
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Edit announcement',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementEditor extends StatefulWidget {
  const _AnnouncementEditor({
    this.existing,
    required this.authorId,
    required this.authorName,
    this.barangay,
  });

  final Announcement? existing;
  final String authorId;
  final String authorName;
  final String? barangay;

  @override
  State<_AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<_AnnouncementEditor> {
  final _formKey = GlobalKey<FormState>();
  final _service = AnnouncementService();

  late final TextEditingController _title;
  late final TextEditingController _body;
  late AnnouncementCategory _category;
  late AnnouncementStatus _status;
  late DateTime _publishAt;
  UploadPayload? _image;
  bool _removeImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _body = TextEditingController(text: existing?.body ?? '');
    _category = existing?.category ?? AnnouncementCategory.schedule;
    _status = existing?.status ?? AnnouncementStatus.published;
    _publishAt = existing?.publishAt ?? DateTime.now();
    _image = existing?.image;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _publishAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishAt),
    );
    setState(() {
      _publishAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _publishAt.hour,
        time?.minute ?? _publishAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        id: widget.existing?.id,
        title: _title.text,
        body: _body.text,
        category: _category,
        image: _image,
        removeImage: _removeImage,
        status: _status,
        publishAt: _publishAt,
        authorId: widget.authorId,
        authorName: widget.authorName,
        barangay: widget.barangay,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(
        context,
        widget.existing == null
            ? 'Announcement created'
            : 'Announcement updated',
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
                widget.existing == null
                    ? 'New announcement'
                    : 'Edit announcement',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Residents see published posts on their dashboard immediately.',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Collection schedule for Barangay San Isidro',
                ),
                validator: (value) => (value == null || value.trim().length < 4)
                    ? 'Please enter a clear title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                minLines: 5,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'What should residents know?',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    (value == null || value.trim().length < 10)
                    ? 'Please write the announcement content'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AnnouncementCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in AnnouncementCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 14),
              ImagePickerField(
                value: _image,
                label: 'Cover photo (optional)',
                helper: 'JPG, PNG or WebP',
                previewHeight: 140,
                onChanged: (value) => setState(() {
                  _image = value;
                  _removeImage =
                      value == null && widget.existing?.image != null;
                }),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publication date',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          Text(
                            dateTimeLabel(_publishAt),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_calendar_outlined,
                        size: 17,
                        color: AppColors.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _status == AnnouncementStatus.published,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Publish now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                subtitle: const Text(
                  'Turn off to keep this as a draft.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
                onChanged: (value) => setState(
                  () => _status = value
                      ? AnnouncementStatus.published
                      : AnnouncementStatus.draft,
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
                          widget.existing == null
                              ? 'Publish announcement'
                              : 'Save changes',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
