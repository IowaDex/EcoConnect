import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_detail_sheet.dart';

/// DSQC / City Hall complaint desk. Complaints arrive here directly from
/// residents; the barangay does not receive a copy in this workflow.
///
/// The desk is one queue: three figures at the top, one search box, one status
/// switch, then the complaints. The switch groups the four stored statuses
/// into the three things an officer actually asks — is it still open, was it
/// resolved, was it rejected — so the row never grows past what a phone can
/// show.
class ComplaintDeskScreen extends StatefulWidget {
  const ComplaintDeskScreen({super.key, this.initialComplaintId});

  /// Opened from a complaint notification: show this complaint's details as
  /// soon as the list has loaded.
  final String? initialComplaintId;

  @override
  State<ComplaintDeskScreen> createState() => _ComplaintDeskScreenState();
}

/// The three ways a complaint can sit on this desk. `open` covers both
/// [ComplaintStatus.pending] and [ComplaintStatus.underReview].
enum _ComplaintFilter { all, open, resolved, rejected }

extension on _ComplaintFilter {
  String get label => switch (this) {
    _ComplaintFilter.all => 'All',
    _ComplaintFilter.open => 'Open',
    _ComplaintFilter.resolved => 'Resolved',
    _ComplaintFilter.rejected => 'Rejected',
  };

  bool matches(Complaint complaint) => switch (this) {
    _ComplaintFilter.all => true,
    _ComplaintFilter.open => complaint.status.isOpen,
    _ComplaintFilter.resolved => complaint.status == ComplaintStatus.resolved,
    _ComplaintFilter.rejected => complaint.status == ComplaintStatus.rejected,
  };
}

class _ComplaintDeskScreenState extends State<ComplaintDeskScreen> {
  _ComplaintFilter _filter = _ComplaintFilter.open;
  String _query = '';
  int _page = 0;
  int _pageSize = 10;
  bool _openedInitial = false;

  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens the notified complaint once, after the first snapshot arrives.
  void _openInitial(List<Complaint> all, String byName) {
    final id = widget.initialComplaintId;
    if (_openedInitial || id == null) return;
    _openedInitial = true;
    final match = all.where((c) => c.id == id);
    if (match.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(context, match.first, byName);
    });
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = _ComplaintFilter.open;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final byName = user?.displayName ?? 'City Hall';

    return EcoPageScaffold(
      eyebrow: 'CITY HALL · DSQC DESK',
      title: 'Complaints',
      subtitle:
          'Every complaint filed against a collection run, newest first. '
          'Open one to reply and change its status.',
      icon: Icons.report_outlined,
      onBack: () => ecoBack(context, '/cityhall'),
      body: StreamBuilder<List<Complaint>>(
        stream: ComplaintService().watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load complaints',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          if (!snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading complaints');
          }

          final all = snapshot.data ?? const <Complaint>[];
          _openInitial(all, byName);

          final searched = all
              .where((complaint) => _matchesQuery(complaint, _query))
              .toList(growable: false);
          final items = searched
              .where((complaint) => _filter.matches(complaint))
              .toList(growable: false);

          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          final open = all.where((c) => c.status.isOpen).length;
          final underReview = all
              .where((c) => c.status == ComplaintStatus.underReview)
              .length;
          final resolved = all
              .where((c) => c.status == ComplaintStatus.resolved)
              .length;
          final filtered =
              _query.trim().isNotEmpty || _filter != _ComplaintFilter.open;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.mark_email_unread_rounded,
                label: 'Open',
                value: '$open',
                accent: AppColors.warning,
                highlight: open > 0,
              ),
              DeskMetric(
                icon: Icons.visibility_outlined,
                label: 'Under review',
                value: '$underReview',
                accent: const Color(0xFF1565C0),
              ),
              DeskMetric(
                icon: Icons.check_circle_outline_rounded,
                label: 'Resolved',
                value: '$resolved',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search reference, title or resident',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_ComplaintFilter>(
              value: _filter,
              onChanged: (value) => setState(() {
                _filter = value;
                _page = 0;
              }),
              segments: [
                for (final filter in _ComplaintFilter.values)
                  DeskSegment(
                    value: filter,
                    label: filter.label,
                    count: searched.where(filter.matches).length,
                  ),
              ],
            ),
            resultLine: DeskResultLine(
              label: filtered
                  ? 'Showing ${items.length} of ${_count(all.length, 'complaint')}'
                  : _count(all.length, 'complaint'),
              onClear: filtered ? _clear : null,
            ),
            empty: all.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No complaints on file',
                    message:
                        'Residents file complaints straight to this desk, so '
                        'an empty queue means nothing has been reported.',
                    steps: [
                      'A resident files a complaint',
                      'The DSQC reviews and replies',
                      'Resolving it closes the complaint',
                    ],
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No complaint matches',
                    message:
                        'Try another status, a different reference, or clear '
                        'the search term.',
                    actionLabel: 'Clear filters',
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: _clear,
                  ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _ComplaintTile(
              complaint: visible[i],
              onTap: () => _open(context, visible[i], byName),
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

  static bool _matchesQuery(Complaint complaint, String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return true;
    return complaint.title.toLowerCase().contains(query) ||
        complaint.referenceNo.toLowerCase().contains(query) ||
        complaint.residentName.toLowerCase().contains(query);
  }

  static String _count(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';

  Future<void> _open(
    BuildContext context,
    Complaint complaint,
    String byName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ComplaintDetailSheet(
        complaint: complaint,
        canRespond: true,
        byName: byName,
      ),
    );
  }
}

/// One complaint in the queue.
///
/// Built on [DeskRailCard] so the rail carries the status colour, exactly like
/// an incident or a delay report: a clerk scans the queue by colour before
/// reading a single word.
class _ComplaintTile extends StatelessWidget {
  const _ComplaintTile({required this.complaint, required this.onTap});

  final Complaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: complaint.status.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complaint.referenceNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.eyebrow(context, color: AppColors.moss),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            complaint.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              DeskInitialAvatar(name: complaint.residentName, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${complaint.residentName}'
                  '${complaint.residentBarangay == null ? '' : ' · ${complaint.residentBarangay}'}'
                  ' · ${timeAgo(complaint.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              Icon(complaint.category.icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              // Expanded, not Flexible: the label takes the whole remaining
              // width so the chevron lands on the card's right edge in every
              // row instead of drifting with the length of the category name.
              Expanded(
                child: Text(
                  complaint.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.chip(context, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 11,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 3),
              Text(
                '${complaint.responses.length}',
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
              const SizedBox(width: 6),
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
