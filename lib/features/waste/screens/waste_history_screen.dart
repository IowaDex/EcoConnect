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
import '../models/waste_submission.dart';
import '../services/waste_service.dart';

/// The resident's own waste uploads and their validation status.
class WasteHistoryScreen extends StatelessWidget {
  const WasteHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading your uploads'));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'My waste uploads',
              subtitle: 'Track validation and collection status.',
              onBack: () => context.go('/user'),
              actions: [
                IconButton(
                  onPressed: () => context.go('/waste-upload'),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  tooltip: 'New upload',
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<WasteSubmission>>(
                stream: WasteService().watchMine(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading your uploads');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final items = snapshot.data ?? const <WasteSubmission>[];
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.add_a_photo_outlined,
                      title: 'No uploads yet',
                      message:
                          'Photograph your segregated waste and submit it for validation.',
                      actionLabel: 'Upload waste',
                      onAction: () => context.go('/waste-upload'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _WasteHistoryCard(
                      submission: items[i],
                      onTap: () => _openDetail(context, items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          children: [
            StatusBadge(
              label: submission.status.label,
              color: submission.status.color,
              icon: submission.status.icon,
            ),
            const SizedBox(height: 12),
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
              'Submitted ${timeAgo(submission.createdAt)}',
              style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
            ),
            if (submission.images.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 160,
                child: PageView.builder(
                  itemCount: submission.images.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
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
            if (submission.remarks?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: submission.status.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: submission.status.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Staff remarks: ${submission.remarks}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ],
        ),
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

class _WasteHistoryCard extends StatelessWidget {
  const _WasteHistoryCard({required this.submission, required this.onTap});

  final WasteSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(18)),
            child: submission.images.isEmpty
                ? Container(
                    width: 84,
                    height: 96,
                    color: AppColors.lightGreen,
                  )
                : Image.memory(
                    _bytes(submission.coverUrl),
                    width: 84,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84,
                      height: 96,
                      color: AppColors.lightGreen,
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: submission.status.label,
                    color: submission.status.color,
                    icon: submission.status.icon,
                    compact: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    submission.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${submission.category.label} · ${submission.quantity} · ${timeAgo(submission.createdAt)}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 8),
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
