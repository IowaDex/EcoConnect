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

/// DSQC / City Hall complaint desk. Complaints arrive here directly from
/// residents; the barangay does not receive a copy in this workflow.
class ComplaintDeskScreen extends StatefulWidget {
  const ComplaintDeskScreen({super.key, this.initialComplaintId});

  /// Opened from a complaint notification: show this complaint's details as
  /// soon as the list has loaded.
  final String? initialComplaintId;

  @override
  State<ComplaintDeskScreen> createState() => _ComplaintDeskScreenState();
}

class _ComplaintDeskScreenState extends State<ComplaintDeskScreen> {
  bool _openOnly = true;
  String _query = '';
  bool _openedInitial = false;

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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final byName = user?.displayName ?? 'City Hall';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/cityhall'),
        ),
        title: const Text(
          'Complaints · DSQC',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: ComplaintService().watchAll(),
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
          final all = snapshot.data ?? const <Complaint>[];
          _openInitial(all, byName);
          final open = all.where((c) => c.status.isOpen).length;
          final items = all
              .where((complaint) {
                if (_openOnly && !complaint.status.isOpen) return false;
                if (_query.trim().isEmpty) return true;
                final query = _query.toLowerCase();
                return complaint.title.toLowerCase().contains(query) ||
                    complaint.referenceNo.toLowerCase().contains(query) ||
                    complaint.residentName.toLowerCase().contains(query);
              })
              .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    _stat('$open', 'Open', AppColors.warning),
                    const SizedBox(width: 8),
                    _stat('${all.length}', 'Total', AppColors.primary),
                    const Spacer(),
                    FilterChip(
                      label: const Text('Open only'),
                      selected: _openOnly,
                      onSelected: (value) => setState(() => _openOnly = value),
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search reference, title or resident',
                    prefixIcon: Icon(Icons.search_rounded, size: 19),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No complaints match',
                        message:
                            'New complaints from residents appear here immediately.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _DeskCard(
                          complaint: items[i],
                          onTap: () => _open(context, items[i], byName),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

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
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({required this.complaint, required this.onTap});

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
          const SizedBox(height: 3),
          Text(
            '${complaint.residentName}'
            '${complaint.residentBarangay == null ? '' : ' · ${complaint.residentBarangay}'}'
            ' · ${timeAgo(complaint.createdAt)}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(complaint.category.icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                complaint.category.label,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${complaint.responses.length} replies',
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
