import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_detail_sheet.dart';

/// The resident's own complaints. A resident can never read another
/// resident's thread: the query is scoped to their uid and the rules repeat
/// the same check server-side.
class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final _search = TextEditingController();
  String _query = '';
  ComplaintStatus? _statusFilter;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Complaint> _filter(List<Complaint> items) {
    final q = _query.trim().toLowerCase();
    return items.where((c) {
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return c.referenceNo.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          (c.location ?? '').toLowerCase().contains(q) ||
          c.category.label.toLowerCase().contains(q) ||
          c.status.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/user'),
        ),
        title: const Text(
          'My complaints',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/complaints/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New complaint',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/new'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.report_outlined, size: 18),
        label: const Text(
          'Complain',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: ComplaintService().watchMine(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load complaints',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final all = snapshot.data ?? const <Complaint>[];
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.report_outlined,
              title: 'No complaints yet',
              message:
                  'Complaints go straight to DSQC / City Hall, separate from '
                  'collection requests and Wave 2 reports.',
              actionLabel: 'File a complaint',
              onAction: () => context.push('/complaints/new'),
            );
          }

          final items = _filter(all);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                child: EcoSearchField(
                  controller: _search,
                  hint: 'Search reference no., title, status',
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 0;
                  }),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    for (final option in <ComplaintStatus?>[
                      null,
                      ...ComplaintStatus.values,
                    ]) ...[
                      ChoiceChip(
                        label: Text(
                          option?.label ?? 'All',
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: _statusFilter == option,
                        onSelected: (_) => setState(() {
                          _statusFilter = option;
                          _page = 0;
                        }),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'No complaints match your filters.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ComplaintCard(
                          complaint: visible[i],
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => ComplaintDetailSheet(
                              complaint: visible[i],
                              canRespond: false,
                              byName: user.displayName ?? 'Resident',
                            ),
                          ),
                        ),
                      ),
              ),
              if (items.isNotEmpty)
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
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.onTap});

  final Complaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                complaint.referenceNo,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.moss,
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            complaint.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${complaint.category.label} · ${timeAgo(complaint.createdAt)}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
          if (complaint.responses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.lightGreen.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      complaint.responses.last.message.isEmpty
                          ? 'Status updated by City Hall'
                          : complaint.responses.last.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.4,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
