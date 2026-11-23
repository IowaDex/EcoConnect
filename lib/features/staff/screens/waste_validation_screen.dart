import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../waste/models/waste_submission.dart';
import '../../waste/services/waste_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Which validation states the desk is looking at.
enum _WasteView { all, pending, approved, rejected }

/// Staff review queue for waste photos uploaded by residents.
class WasteValidationScreen extends StatefulWidget {
  const WasteValidationScreen({super.key});

  @override
  State<WasteValidationScreen> createState() => _WasteValidationScreenState();
}

class _WasteValidationScreenState extends State<WasteValidationScreen> {
  final _service = WasteService();
  final _search = TextEditingController();
  _WasteView _view = _WasteView.pending;
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

  bool _matches(WasteSubmission item, _WasteView view) => switch (view) {
    _WasteView.all => true,
    _WasteView.pending => item.status == WasteStatus.pending,
    _WasteView.approved => item.status == WasteStatus.approved,
    _WasteView.rejected => item.status == WasteStatus.rejected,
  };

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'BARANGAY STAFF · WASTE DESK',
      title: 'Waste validation',
      subtitle: 'Review the waste residents upload before collection.',
      onBack: () => ecoBack(context, '/admin-dashboard'),
      actions: const [NotificationBell()],
      // One listener for the whole page: the header counts and the list used to
      // subscribe to the same query twice.
      body: StreamBuilder<List<WasteSubmission>>(
        stream: _service.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Loading submissions');
          }
          if (snapshot.hasError) {
            return ErrorView(message: AppFeedback.describe(snapshot.error!));
          }

          final all = snapshot.data ?? const <WasteSubmission>[];
          final pending = all
              .where((w) => w.status == WasteStatus.pending)
              .length;
          final approved = all
              .where((w) => w.status == WasteStatus.approved)
              .length;
          final rejected = all
              .where((w) => w.status == WasteStatus.rejected)
              .length;

          final inView = all
              .where((w) => _matches(w, _view))
              .toList(growable: false);
          final items = _filter(inView);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.hourglass_empty_rounded,
                label: 'Pending',
                value: '$pending',
                accent: AppColors.warning,
                highlight: pending > 0,
              ),
              DeskMetric(
                icon: Icons.verified_outlined,
                label: 'Approved',
                value: '$approved',
                accent: AppColors.primary,
              ),
              DeskMetric(
                // Was "Uploads" (every submission), which just repeated
                // Pending + Approved. Rejected is the one state the desk had
                // no number for, and it completes the row.
                icon: Icons.cancel_outlined,
                label: 'Rejected',
                value: '$rejected',
                accent: AppColors.inkMuted,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search resident, place or waste type',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_WasteView>(
              value: _view,
              onChanged: (next) => setState(() {
                _view = next;
                _page = 0;
              }),
              segments: [
                DeskSegment<_WasteView>(
                  value: _WasteView.pending,
                  label: 'Pending',
                  count: pending,
                ),
                DeskSegment<_WasteView>(
                  value: _WasteView.approved,
                  label: 'Approved',
                  count: approved,
                ),
                DeskSegment<_WasteView>(
                  value: _WasteView.rejected,
                  label: 'Rejected',
                  count: rejected,
                ),
                DeskSegment<_WasteView>(
                  value: _WasteView.all,
                  label: 'All',
                  count: all.length,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: items.length == all.length
                  ? '${all.length} '
                        '${all.length == 1 ? 'submission' : 'submissions'}'
                  : 'Showing ${items.length} of ${all.length}',
              onClear: _query.isEmpty && _view == _WasteView.pending
                  ? null
                  : () => setState(() {
                      _search.clear();
                      _query = '';
                      _view = _WasteView.pending;
                      _page = 0;
                    }),
            ),
            empty: all.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.inventory_2_outlined,
                    title: 'Nothing to validate',
                    message:
                        'New waste photos appear here as soon as residents '
                        'upload them.',
                    steps: [
                      'A resident photographs the sorted waste',
                      'The upload lands in this queue as Pending',
                      'Approve it or send it back with a reason',
                    ],
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing in this view',
                    message: _query.trim().isEmpty
                        ? 'No upload is at this stage right now. Switch to All '
                              'to see the whole queue.'
                        : 'No upload matches "$_query" at this stage.',
                    actionLabel: 'Show all uploads',
                    actionIcon: Icons.inbox_outlined,
                    onAction: () => setState(() {
                      _search.clear();
                      _query = '';
                      _view = _WasteView.all;
                      _page = 0;
                    }),
                  ),
            itemCount: visible.length,
            separator: 10,
            itemBuilder: (context, i) => _WasteCard(
              submission: visible[i],
              onTap: () => _openDetail(context, visible[i]),
            ),
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

  Future<void> _openDetail(
    BuildContext context,
    WasteSubmission submission,
  ) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (_) => _WasteDetail(
        submission: submission,
        staffId: staff.uid,
        staffName: staff.displayName ?? 'Barangay staff',
      ),
    );
  }
}

/// One upload. The photo fills the card's full height on the left, so a long
/// description never leaves a white notch under it.
class _WasteCard extends StatelessWidget {
  const _WasteCard({required this.submission, required this.onTap});

  final WasteSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, bottom: 0, width: 92, child: _photo()),
          Padding(
            padding: const EdgeInsets.fromLTRB(92 + 13, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: submission.status.label,
                      color: submission.status.color,
                      icon: submission.status.icon,
                      compact: true,
                    ),
                    const Spacer(),
                    const SizedBox(width: 6),
                    Text(
                      timeAgo(submission.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  submission.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitle(context, color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  submission.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.bodySmall(context, color: AppColors.inkMuted),
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
                    Flexible(
                      child: Text(
                        submission.category.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.meta(
                          context,
                          color: submission.category.color,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.scale_outlined,
                      size: 11,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        submission.quantity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.meta(context, color: AppColors.inkMuted),
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

  Widget _photo() {
    if (submission.images.isEmpty) {
      return Container(
        color: submission.category.color.withValues(alpha: 0.1),
        alignment: Alignment.center,
        child: Icon(
          submission.category.icon,
          size: 26,
          color: submission.category.color,
        ),
      );
    }
    return Image.memory(
      _bytes(submission.coverUrl),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.lightGreen,
        alignment: Alignment.center,
        child: Icon(
          submission.category.icon,
          size: 24,
          color: submission.category.color,
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const SizedBox(height: EcoSpace.md),
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
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Text(
            '${submission.category.label} waste',
            style: EcoType.panelTitle(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 3),
          Text(
            'Uploaded by ${submission.userName}',
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
          if (submission.images.isNotEmpty) ...[
            const SizedBox(height: EcoSpace.md),
            SizedBox(
              height: 170,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.9),
                itemCount: submission.images.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(EcoRadius.md),
                    child: Image.memory(
                      _bytes(submission.images[i].dataUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: EcoSpace.md),
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
              'Validated by ${submission.validatedBy} · '
              '${timeAgo(submission.validatedAt)}',
            ),
          const SizedBox(height: EcoSpace.lg),
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
                label: Text(
                  'Approve waste',
                  style: EcoType.action(context, color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                ),
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
            Text(
              'This submission has already been reviewed.',
              textAlign: TextAlign.center,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
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
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
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
