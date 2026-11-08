import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
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
              label: const Text('New announcement'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Announcements',
              subtitle: isStaff
                  ? 'Publish schedules and reminders for your barangay.'
                  : 'Updates from your barangay team.',
              onBack: () => context.go(
                isStaff ? '/admin-dashboard' : '/user',
              ),
              actions: const [NotificationBell()],
            ),
            _CategoryFilter(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: StreamBuilder<List<Announcement>>(
                stream: isStaff
                    ? _service.watchAll()
                    : _service.watchPublished(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading announcements');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  var items = snapshot.data ?? const <Announcement>[];
                  if (_filter != null) {
                    items = items
                        .where((a) => a.category == _filter)
                        .toList(growable: false);
                  }
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.campaign_outlined,
                      title: isStaff
                          ? 'No announcements yet'
                          : 'No announcements right now',
                      message: isStaff
                          ? 'Publish a collection schedule or community reminder so residents stay informed.'
                          : 'Your barangay will post schedules and reminders here.',
                      actionLabel: isStaff ? 'Create announcement' : null,
                      onAction:
                          isStaff ? () => _openEditor(context) : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _AnnouncementCard(
                        announcement: item,
                        canManage: isStaff,
                        onTap: () => _openDetail(context, item, isStaff),
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
      message:
          '"${item.title}" will be removed from every resident dashboard.',
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
  const _CategoryFilter({required this.selected, required this.onChanged});

  final AnnouncementCategory? selected;
  final ValueChanged<AnnouncementCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _chip(context, 'All', selected == null, () => onChanged(null)),
          for (final category in AnnouncementCategory.values)
            _chip(
              context,
              category.shortLabel,
              selected == category,
              () => onChanged(category),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.darkGreen,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
                height: 132,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                    const SizedBox(width: 6),
                    if (canManage && !announcement.isPublished)
                      const StatusBadge(
                        label: 'Draft',
                        color: AppColors.inkMuted,
                      ),
                    const Spacer(),
                    if (canManage)
                      PopupMenuButton<String>(
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
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              announcement.isPublished
                                  ? 'Unpublish'
                                  : 'Publish',
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
                const SizedBox(height: 10),
                Text(
                  announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  announcement.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.55,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo(
                        announcement.publishAt ?? announcement.createdAt,
                      ),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      announcement.authorName ?? 'Barangay',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
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
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          StatusBadge(
            label: announcement.category.label,
            color: announcement.category.color,
            icon: announcement.category.icon,
          ),
          const SizedBox(height: 14),
          Text(
            announcement.title,
            style: const TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posted by ${announcement.authorName ?? 'Barangay staff'} · ${timeAgo(announcement.publishAt ?? announcement.createdAt)}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          if (image.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_bytes(image), fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            announcement.body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppColors.textDark,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit announcement'),
            ),
          ],
        ],
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
                validator: (value) => (value == null || value.trim().length < 10)
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
                  _removeImage = value == null && widget.existing?.image != null;
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
                      const Icon(Icons.event_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publication date',
                            style: TextStyle(
                              fontSize: 9,
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
                      const Icon(Icons.edit_calendar_outlined,
                          size: 17, color: AppColors.inkMuted),
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
                  style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
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
