import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../models/waste_submission.dart';
import '../services/waste_service.dart';

/// Which validation states are on screen.
enum _WasteView { all, pending, approved, rejected }

/// The resident's own waste uploads and their validation status.
///
/// Reads as a queue, not a gallery: the rail colour is the validation state,
/// so a resident scans for the orange "waiting" rows first.
class WasteHistoryScreen extends StatefulWidget {
  const WasteHistoryScreen({super.key});

  @override
  State<WasteHistoryScreen> createState() => _WasteHistoryScreenState();
}

class _WasteHistoryScreenState extends State<WasteHistoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 0;
  int _pageSize = 10;
  _WasteView _view = _WasteView.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WasteSubmission> _filter(List<WasteSubmission> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((w) {
      return w.category.label.toLowerCase().contains(q) ||
          w.location.toLowerCase().contains(q) ||
          w.description.toLowerCase().contains(q) ||
          w.status.label.toLowerCase().contains(q);
    }).toList();
  }

  bool _matches(WasteSubmission item, _WasteView view) => switch (view) {
    _WasteView.all => true,
    _WasteView.pending => item.status == WasteStatus.pending,
    _WasteView.approved =>
      item.status == WasteStatus.approved ||
          item.status == WasteStatus.scheduled ||
          item.status == WasteStatus.collected,
    _WasteView.rejected => item.status == WasteStatus.rejected,
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading your uploads'));
    }

    return EcoPageScaffold(
      eyebrow: 'RESIDENT · WASTE',
      title: 'My waste uploads',
      subtitle: 'Track validation and collection status.',
      onBack: () => ecoBack(context, '/user'),
      actions: [
        EcoIconAction(
          icon: Icons.add_a_photo_outlined,
          tooltip: 'New upload',
          onTap: () => context.push('/waste-upload'),
        ),
      ],
      body: StreamBuilder<List<WasteSubmission>>(
        stream: WasteService().watchMine(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Loading your uploads');
          }
          if (snapshot.hasError) {
            return ErrorView(message: AppFeedback.describe(snapshot.error!));
          }

          final all = snapshot.data ?? const <WasteSubmission>[];
          final inView = all.where((w) => _matches(w, _view)).toList();
          final items = _filter(inView);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          final pending = all
              .where((w) => w.status == WasteStatus.pending)
              .length;
          final approved = all
              .where((w) => _matches(w, _WasteView.approved))
              .length;
          final rejected = all
              .where((w) => w.status == WasteStatus.rejected)
              .length;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.hourglass_empty_rounded,
                label: 'In review',
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
                icon: Icons.inventory_2_outlined,
                label: 'Uploads',
                value: '${all.length}',
                accent: AppColors.forest,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search waste type, place or status',
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
                  value: _WasteView.all,
                  label: 'All',
                  count: all.length,
                ),
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
              ],
            ),
            resultLine: DeskResultLine(
              label: items.length == all.length
                  ? '${all.length} ${all.length == 1 ? 'upload' : 'uploads'}'
                  : 'Showing ${items.length} of ${all.length}',
              onClear: _query.isEmpty && _view == _WasteView.all
                  ? null
                  : () => setState(() {
                      _search.clear();
                      _query = '';
                      _view = _WasteView.all;
                      _page = 0;
                    }),
            ),
            empty: all.isEmpty
                ? DeskEmptyQueue(
                    icon: Icons.add_a_photo_outlined,
                    title: 'No uploads yet',
                    message:
                        'Photograph your segregated waste and send it in. '
                        'Barangay staff validate the photo before pickup.',
                    steps: const [
                      'Snap a clear photo of the sorted waste',
                      'Add the quantity and the pickup spot',
                      'Wait for the validated badge, then set it out',
                    ],
                    actionLabel: 'Upload waste',
                    actionIcon: Icons.add_a_photo_outlined,
                    onAction: () => context.push('/waste-upload'),
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing in this view',
                    message: _query.trim().isEmpty
                        ? 'No upload is at this stage right now. Switch back to '
                              'All to see the full history.'
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
            itemBuilder: (context, i) => _WasteHistoryCard(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          children: [
            const SizedBox(height: EcoSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${submission.category.label} waste',
                    style: EcoType.panelTitle(
                      context,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
                StatusBadge(
                  label: submission.status.label,
                  color: submission.status.color,
                  icon: submission.status.icon,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Submitted ${timeAgo(submission.createdAt)} · '
              '${submission.quantity}',
              style: EcoType.meta(context, color: AppColors.inkMuted),
            ),
            if (submission.images.isNotEmpty) ...[
              const SizedBox(height: EcoSpace.md),
              SizedBox(
                height: 180,
                child: PageView.builder(
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
            EcoCard(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHAT YOU SENT',
                    style: EcoType.eyebrow(context, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  Text(
                    submission.description,
                    style: EcoType.body(context, color: AppColors.textDark),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  DeskFact(
                    icon: Icons.scale_outlined,
                    text: 'Quantity · ${submission.quantity}',
                  ),
                  const SizedBox(height: 5),
                  DeskFact(
                    icon: Icons.place_outlined,
                    text: submission.location,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 5),
                  DeskFact(
                    icon: Icons.schedule_rounded,
                    text: 'Submitted ${dateTimeLabel(submission.createdAt)}',
                  ),
                ],
              ),
            ),
            if (submission.remarks?.trim().isNotEmpty == true) ...[
              const SizedBox(height: EcoSpace.md),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                decoration: BoxDecoration(
                  color: submission.status.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                  border: Border.all(
                    color: submission.status.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: submission.status.color,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Staff remarks: ${submission.remarks}',
                        style: EcoType.bodySmall(
                          context,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One upload in the history: cover photo, what was sent, and where it stands.
class _WasteHistoryCard extends StatelessWidget {
  const _WasteHistoryCard({required this.submission, required this.onTap});

  final WasteSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: submission.status.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(submission: submission),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${submission.category.label} waste',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(
                        context,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      submission.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              StatusBadge(
                label: submission.status.label,
                color: submission.status.color,
                icon: submission.status.icon,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${submission.quantity} · ${timeAgo(submission.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
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

/// The cover photo, or the category mark when the upload has none.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.submission});

  final WasteSubmission submission;

  @override
  Widget build(BuildContext context) {
    const size = 58.0;
    final category = submission.category;

    if (submission.images.isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(EcoRadius.sm + 1),
        ),
        child: Icon(category.icon, size: 22, color: category.color),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(EcoRadius.sm + 1),
      child: Image.memory(
        _bytes(submission.coverUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: size,
          width: size,
          color: AppColors.lightGreen,
          child: Icon(category.icon, size: 20, color: category.color),
        ),
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
