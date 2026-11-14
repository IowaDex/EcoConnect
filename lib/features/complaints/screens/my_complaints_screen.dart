import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_detail_sheet.dart';

/// The resident's own complaints. A resident can never read another
/// resident's thread: the query is scoped to their uid and the rules repeat
/// the same check server-side.
class MyComplaintsScreen extends StatelessWidget {
  const MyComplaintsScreen({super.key});

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
          onPressed: () => context.canPop() ? context.pop() : context.go('/user'),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load complaints',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final items = snapshot.data ?? const <Complaint>[];
          if (items.isEmpty) {
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ComplaintCard(
              complaint: items[i],
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ComplaintDetailSheet(
                  complaint: items[i],
                  canRespond: false,
                  byName: user.displayName ?? 'Resident',
                ),
              ),
            ),
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
                  const Icon(Icons.support_agent_rounded,
                      size: 13, color: AppColors.primary),
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
