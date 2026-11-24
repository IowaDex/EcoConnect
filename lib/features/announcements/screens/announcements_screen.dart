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
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
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

/// What the staff desk is looking at. Residents only ever see published posts,
/// so the control is hidden for them.
enum _AnnouncementView { all, published, drafts }

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = AnnouncementService();
  final _search = TextEditingController();

  _AnnouncementView _view = _AnnouncementView.all;
  AnnouncementCategory? _category;
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _category != null ||
      _query.trim().isNotEmpty ||
      _view != _AnnouncementView.all;

  void _clear() {
    _search.clear();
    setState(() {
      _category = null;
      _query = '';
      _view = _AnnouncementView.all;
      _page = 0;
    });
  }

  static bool _matches(Announcement item, String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.title.toLowerCase().contains(query) ||
        item.body.toLowerCase().contains(query) ||
        (item.authorName ?? '').toLowerCase().contains(query) ||
        item.category.label.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isStaff = user?.role == UserRole.admin;
    final fallback = switch (user?.role) {
      UserRole.admin => '/admin-dashboard',
      UserRole.cityHall => '/cityhall',
      UserRole.iswim => '/iswim',
      UserRole.driver => '/driver',
      _ => '/user',
    };

    return EcoPageScaffold(
      eyebrow: isStaff ? 'BARANGAY · ANNOUNCEMENTS' : 'YOUR BARANGAY · UPDATES',
      title: 'Announcements',
      subtitle: isStaff
          ? 'Publish schedules and reminders for your barangay.'
          : 'Updates from your barangay team.',
      onBack: () => ecoBack(context, fallback),
      actions: [
        const NotificationBell(),
        if (isStaff) _PostAction(onTap: () => _openEditor(context)),
      ],
      body: StreamBuilder<List<Announcement>>(
        stream: isStaff ? _service.watchAll() : _service.watchPublished(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading announcements');
          }
          if (snapshot.hasError) {
            return DeskEmptyQueue(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load announcements',
              message: AppFeedback.describe(snapshot.error!),
            );
          }

          final all = snapshot.data ?? const <Announcement>[];
          final published = all.where((a) => a.isPublished).length;
          final drafts = all.length - published;

          final inView = switch (_view) {
            _AnnouncementView.all => all,
            _AnnouncementView.published =>
              all.where((a) => a.isPublished).toList(growable: false),
            _AnnouncementView.drafts =>
              all.where((a) => !a.isPublished).toList(growable: false),
          };
          final inCategory = _category == null
              ? inView
              : inView
                    .where((a) => a.category == _category)
                    .toList(growable: false);
          final items = _query.trim().isEmpty
              ? inCategory
              : inCategory
                    .where((a) => _matches(a, _query))
                    .toList(growable: false);

          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          final categories = [
            for (final category in AnnouncementCategory.values)
              if (inView.any((a) => a.category == category)) category,
          ];

          return Column(
            children: [
              if (isStaff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: DeskSegmented<_AnnouncementView>(
                    value: _view,
                    onChanged: (value) => setState(() {
                      _view = value;
                      _page = 0;
                    }),
                    segments: [
                      DeskSegment(
                        value: _AnnouncementView.all,
                        label: 'All',
                        count: all.length,
                      ),
                      DeskSegment(
                        value: _AnnouncementView.published,
                        label: 'Published',
                        count: published,
                      ),
                      DeskSegment(
                        value: _AnnouncementView.drafts,
                        label: 'Drafts',
                        count: drafts,
                      ),
                    ],
                  ),
                ),
              if (isStaff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: EcoSearchField(
                    controller: _search,
                    hint: 'Search title, content or author',
                    onChanged: (value) => setState(() {
                      _query = value;
                      _page = 0;
                    }),
                  ),
                ),
              _CategoryBar(
                categories: categories,
                counts: {
                  for (final category in categories)
                    category: inView
                        .where((a) => a.category == category)
                        .length,
                },
                total: inView.length,
                selected: _category,
                onChanged: (value) => setState(() {
                  _category = value;
                  _page = 0;
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: DeskResultLine(
                  label: _resultLabel(items.length, all.length),
                  onClear: _filtered ? _clear : null,
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? DeskEmptyQueue(
                        icon: Icons.campaign_outlined,
                        title: _filtered
                            ? 'No announcement matches'
                            : isStaff
                            ? 'No announcements yet'
                            : 'No announcements right now',
                        message: _filtered
                            ? 'Nothing here fits the filters you picked. Clear '
                                  'them to see every post again.'
                            : isStaff
                            ? 'Publish a collection schedule or community '
                                  'reminder so residents stay informed.'
                            : 'Your barangay will post schedules and reminders '
                                  'here.',
                        steps: _filtered || !isStaff
                            ? const []
                            : const [
                                'Write the post and pick a category',
                                'Publish it for the barangay',
                                'Residents see it on their dashboard',
                              ],
                        actionLabel: _filtered
                            ? 'Clear filters'
                            : isStaff
                            ? 'Write an announcement'
                            : null,
                        actionIcon: _filtered
                            ? Icons.filter_alt_off_outlined
                            : Icons.edit_note_rounded,
                        onAction: _filtered
                            ? _clear
                            : isStaff
                            ? () => _openEditor(context)
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: EcoSpace.sm),
                        itemBuilder: (context, i) {
                          final item = visible[i];
                          return FadeSlideIn(
                            index: i > 6 ? 6 : i,
                            offset: 10,
                            child: _AnnouncementCard(
                              announcement: item,
                              canManage: isStaff,
                              onTap: () => _openDetail(context, item, isStaff),
                              onEdit: () =>
                                  _openEditor(context, existing: item),
                              onToggle: () => _toggle(context, item),
                              onDelete: () => _delete(context, item),
                            ),
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
                    onPageChanged: (next) => setState(() => _page = next),
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
    );
  }

  String _resultLabel(int visible, int total) {
    if (_filtered) return 'Showing $visible of $total';
    return '$total ${total == 1 ? 'announcement' : 'announcements'}';
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

/// The category chips on one horizontal row.
///
/// A wrapping row stacked seven pills over three lines and pushed the feed
/// itself below the fold, so the row now scrolls sideways instead and never
/// takes more than its 34px height.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.counts,
    required this.total,
    required this.selected,
    required this.onChanged,
  });

  final List<AnnouncementCategory> categories;
  final Map<AnnouncementCategory, int> counts;

  /// How many posts the current view holds, for the "All" chip.
  final int total;

  final AnnouncementCategory? selected;
  final ValueChanged<AnnouncementCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              if (i == 0) {
                return DeskFilterChip(
                  label: 'All',
                  count: total,
                  selected: selected == null,
                  onTap: () => onChanged(null),
                );
              }
              final category = categories[i - 1];
              return DeskFilterChip(
                label: category.shortLabel,
                count: counts[category],
                selected: selected == category,
                // Tapping the active chip again lifts the filter.
                onTap: () => onChanged(selected == category ? null : category),
              );
            },
          ),
          // Fades the last few pixels so a half-scrolled chip reads as "there
          // is more to the right" instead of a pill cut in half. When the row
          // is scrolled to its end the strip's own 20px padding sits here, so
          // nothing is dimmed.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Post" action in the page header.
///
/// A header pill rather than a floating button: the FAB sat over the
/// pagination bar and forced the list to reserve space under it.
class _PostAction extends StatelessWidget {
  const _PostAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text(
          'Post',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// One announcement in the feed.
///
/// A compact news row rather than a full-width cover: a photo card spent 168px
/// on the image alone, so three announcements filled the screen and the rest
/// needed a long scroll. The cover now rides as a 76px thumbnail and the rail
/// carries the category colour.
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
    final scheduled = announcement.isPublished && !announcement.isLive;

    return DeskRailCard(
      railColor: announcement.category.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 10, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: announcement.category.shortLabel,
                color: announcement.category.color,
                icon: announcement.category.icon,
              ),
              if (!announcement.isPublished) ...[
                const SizedBox(width: 5),
                const StatusBadge(
                  label: 'Draft',
                  color: AppColors.inkMuted,
                  icon: Icons.edit_note_rounded,
                ),
              ] else if (scheduled) ...[
                const SizedBox(width: 5),
                const StatusBadge(
                  label: 'Scheduled',
                  color: AppColors.warning,
                  icon: Icons.schedule_rounded,
                ),
              ],
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
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      const SizedBox(height: 4),
                      Text(
                        announcement.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.bodySmall(
                          context,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                  child: Image.memory(
                    _bytes(image),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      color: AppColors.mint,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 18,
                        color: AppColors.moss,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          // The footer spans the whole card, so the chevron sits in the same
          // bottom-right corner whether or not the post has a thumbnail.
          Row(
            children: [
              DeskInitialAvatar(
                name: announcement.authorName ?? 'Barangay',
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${announcement.authorName ?? 'Barangay'} · '
                  '${timeAgo(announcement.publishAt ?? announcement.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.inkMuted,
              ),
            ],
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
    // A 28px box keeps the menu from stretching the badge row to the 48px tap
    // target of a default icon button.
    return SizedBox(
      height: 28,
      width: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: 'Manage',
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
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'toggle',
            child: Text(isPublished ? 'Unpublish' : 'Publish'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                style: EcoType.panelTitle(context, color: AppColors.darkGreen),
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
                          style: EcoType.bodyStrong(
                            context,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Posted '
                          '${timeAgo(announcement.publishAt ?? announcement.createdAt)}',
                          style: EcoType.meta(
                            context,
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
              SelectableText(
                announcement.body,
                style: EcoType.body(
                  context,
                  color: AppColors.textDark,
                ).copyWith(height: 1.75),
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
                  hintText:
                      'e.g. Collection schedule for Barangay Batasan Hills',
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
