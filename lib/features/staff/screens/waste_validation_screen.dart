import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../waste/models/waste_submission.dart';
import '../../waste/services/waste_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Staff review queue for waste photos uploaded by residents.
class WasteValidationScreen extends StatefulWidget {
  const WasteValidationScreen({super.key});

  @override
  State<WasteValidationScreen> createState() => _WasteValidationScreenState();
}

class _WasteValidationScreenState extends State<WasteValidationScreen> {
  final _service = WasteService();
  final _search = TextEditingController();
  bool _pendingOnly = true;
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Keeps the uploads whose resident, place or description matches the box.
  List<WasteSubmission> _filter(List<WasteSubmission> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((w) {
      return w.userName.toLowerCase().contains(q) ||
          w.location.toLowerCase().contains(q) ||
          w.description.toLowerCase().contains(q) ||
          w.category.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'BARANGAY STAFF · WASTE DESK',
      title: 'Waste validation',
      subtitle: 'Review the waste residents upload before collection.',
      onBack: () => ecoBack(context, '/admin-dashboard'),
      actions: const [NotificationBell()],
      body: Column(
        children: [
          StreamBuilder<List<WasteSubmission>>(
            stream: _service.watchAll(),
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <WasteSubmission>[];
              final pending = all
                  .where((w) => w.status == WasteStatus.pending)
                  .length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    _stat('$pending', 'Pending', AppColors.warning),
                    const SizedBox(width: 8),
                    _stat(
                      '${all.where((w) => w.status == WasteStatus.approved).length}',
                      'Approved',
                      AppColors.primary,
                    ),
                    const Spacer(),
                    FilterChip(
                      label: const Text('Pending only'),
                      selected: _pendingOnly,
                      onSelected: (value) => setState(() {
                        _pendingOnly = value;
                        _page = 0;
                      }),
                      selectedColor: AppColors.lightGreen,
                      checkmarkColor: AppColors.primary,
                      labelStyle: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: EcoSearchField(
              controller: _search,
              hint: 'Search resident, place or waste type',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<WasteSubmission>>(
              stream: _service.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(label: 'Loading submissions');
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: AppFeedback.describe(snapshot.error!),
                  );
                }
                final all = snapshot.data ?? const <WasteSubmission>[];
                var items = all;
                if (_pendingOnly) {
                  items = items
                      .where((w) => w.status == WasteStatus.pending)
                      .toList(growable: false);
                }
                items = _filter(items);
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Nothing to validate',
                    message:
                        'New waste photos appear here as soon as residents upload them.',
                  );
                }
                final page = clampPage(_page, items.length, _pageSize);
                final visible = pageSlice(items, page, _pageSize);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                      child: EcoResultCount(
                        shown: items.length,
                        total: all.length,
                        singular: 'submission',
                        plural: 'submissions',
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = visible[i];
                          return _WasteCard(
                            submission: item,
                            onTap: () => _openDetail(context, item),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
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
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WasteSubmission submission,
  ) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WasteDetail(
        submission: submission,
        staffId: staff.uid,
        staffName: staff.displayName ?? 'Barangay staff',
      ),
    );
  }
}

class _WasteCard extends StatelessWidget {
  const _WasteCard({required this.submission, required this.onTap});

  final WasteSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(18),
            ),
            child: submission.images.isEmpty
                ? Container(
                    width: 96,
                    height: 116,
                    color: AppColors.lightGreen,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 24,
                      color: AppColors.inkMuted,
                    ),
                  )
                : Image.memory(
                    _bytes(submission.coverUrl),
                    width: 96,
                    height: 116,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 96,
                      height: 116,
                      color: AppColors.lightGreen,
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(
                        label: submission.status.label,
                        color: submission.status.color,
                        compact: true,
                      ),
                      const Spacer(),
                      Text(
                        timeAgo(submission.createdAt),
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    submission.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    submission.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.4,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        submission.category.icon,
                        size: 11,
                        color: submission.category.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        submission.category.shortLabel,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: submission.category.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.scale_outlined,
                        size: 11,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        submission.quantity,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteDetail extends StatefulWidget {
  const _WasteDetail({
    required this.submission,
    required this.staffId,
    required this.staffName,
  });

  final WasteSubmission submission;
  final String staffId;
  final String staffName;

  @override
  State<_WasteDetail> createState() => _WasteDetailState();
}

class _WasteDetailState extends State<_WasteDetail> {
  final _service = WasteService();
  late WasteSubmission _submission = widget.submission;
  bool _busy = false;

  Future<void> _validate(WasteStatus status) async {
    final controller = TextEditingController();
    final isReject = status == WasteStatus.rejected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReject ? 'Reject submission?' : 'Approve submission?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReject
                  ? 'Explain what needs to be fixed. The resident sees this message.'
                  : 'Approve the waste upload once you have checked the photo '
                        'and the segregation.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isReject ? 'Rejection reason' : 'Remarks',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isReject
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(isReject ? 'Reject' : 'Approve'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.validate(
        submission: _submission,
        status: status,
        actorId: widget.staffId,
        actorName: widget.staffName,
        remarks: controller.text.trim(),
      );
      if (!mounted) return;
      setState(
        () => _submission = WasteSubmission(
          id: _submission.id,
          userId: _submission.userId,
          userName: _submission.userName,
          description: _submission.description,
          category: _submission.category,
          quantity: _submission.quantity,
          location: _submission.location,
          barangay: _submission.barangay,
          images: _submission.images,
          status: status,
          remarks: controller.text.trim(),
          validatedBy: widget.staffName,
          validatedAt: DateTime.now(),
          createdAt: _submission.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      AppFeedback.success(context, 'Submission ${status.label.toLowerCase()}');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = _submission;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          Row(
            children: [
              StatusBadge(
                label: submission.status.label,
                color: submission.status.color,
                icon: submission.status.icon,
              ),
              const Spacer(),
              Text(
                timeAgo(submission.createdAt),
                style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${submission.category.label} waste',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded by ${submission.userName}',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          if (submission.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.9),
                itemCount: submission.images.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _bytes(submission.images[i].dataUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _row(Icons.notes_rounded, submission.description),
          _row(Icons.scale_outlined, 'Quantity: ${submission.quantity}'),
          _row(Icons.place_outlined, submission.location),
          if (submission.barangay != null)
            _row(Icons.map_outlined, submission.barangay!),
          if (submission.remarks?.trim().isNotEmpty == true)
            _row(Icons.support_agent_rounded, submission.remarks!),
          if (submission.validatedBy != null)
            _row(
              Icons.verified_user_outlined,
              'Validated by ${submission.validatedBy} · ${timeAgo(submission.validatedAt)}',
            ),
          const SizedBox(height: 22),
          if (_busy)
            const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (submission.status == WasteStatus.pending) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () => _validate(WasteStatus.approved),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve waste'),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _validate(WasteStatus.rejected),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject with reason'),
              ),
            ),
          ] else
            const Text(
              'This submission has already been reviewed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
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

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
