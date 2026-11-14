import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
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
  bool _pendingOnly = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Waste validation',
              subtitle: 'Review the waste residents upload before collection.',
              onBack: () => context.go('/admin-dashboard'),
              actions: const [NotificationBell()],
            ),
            StreamBuilder<List<WasteSubmission>>(
              stream: _service.watchAll(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const <WasteSubmission>[];
                final pending =
                    all.where((w) => w.status == WasteStatus.pending).length;
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
                        onSelected: (value) =>
                            setState(() => _pendingOnly = value),
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
                  var items = snapshot.data ?? const <WasteSubmission>[];
                  if (_pendingOnly) {
                    items = items
                        .where((w) => w.status == WasteStatus.pending)
                        .toList(growable: false);
                  }
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Nothing to validate',
                      message:
                          'New waste photos appear here as soon as residents upload them.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _WasteCard(
                        submission: item,
                        onTap: () => _openDetail(context, item),
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
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(18)),
            child: submission.images.isEmpty
                ? Container(
                    width: 96,
                    height: 116,
                    color: AppColors.lightGreen,
                    child: const Icon(Icons.image_not_supported_outlined,
                        size: 24, color: AppColors.inkMuted),
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
                      Icon(submission.category.icon,
                          size: 11, color: submission.category.color),
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
                      const Icon(Icons.scale_outlined,
                          size: 11, color: AppColors.inkMuted),
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
    final pointsController = TextEditingController(text: '10');
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
                  : 'Approve the waste and decide how many points to credit. '
                      'Enter 0 to approve without points.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            if (!isReject)
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Points to credit',
                  helperText: 'Credited only once per submission',
                ),
              ),
            if (!isReject) const SizedBox(height: 10),
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

    final points = isReject ? 0 : (int.tryParse(pointsController.text.trim()) ?? 0);
    if (!isReject && points < 0) {
      AppFeedback.error(context, 'Points cannot be negative.');
      return;
    }

    setState(() => _busy = true);
    try {
      final awarded = await _service.validate(
        submission: _submission,
        status: status,
        actorId: widget.staffId,
        actorName: widget.staffName,
        remarks: controller.text.trim(),
        points: points,
      );
      if (!mounted) return;
      setState(() => _submission = WasteSubmission(
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
            pointsAwarded: awarded,
            createdAt: _submission.createdAt,
            updatedAt: DateTime.now(),
          ));
      AppFeedback.success(
        context,
        awarded > 0
            ? 'Approved · $awarded points credited'
            : 'Submission ${status.label.toLowerCase()}',
      );
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
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
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
