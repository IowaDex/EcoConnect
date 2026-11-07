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
import '../models/collection_request.dart';
import '../services/collection_request_service.dart';

/// The resident's collection request history.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  bool _openOnly = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading requests'));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'My requests',
              subtitle: 'Track approval, scheduling and collection.',
              onBack: () => context.go('/user'),
              actions: [
                IconButton(
                  onPressed: () => context.go('/request-collection'),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'New request',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
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
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/request-collection'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New request'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CollectionRequest>>(
                stream: CollectionRequestService().watchMine(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading requests');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  var items = snapshot.data ?? const <CollectionRequest>[];
                  if (_openOnly) {
                    items = items
                        .where((r) => r.status.isOpen)
                        .toList(growable: false);
                  }
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No requests yet',
                      message:
                          'Ask the barangay to collect bulky or special waste.',
                      actionLabel: 'Create a request',
                      onAction: () => context.go('/request-collection'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _RequestHistoryCard(
                      request: items[i],
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
    CollectionRequest request,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          children: [
            Row(
              children: [
                StatusBadge(
                  label: request.status.label,
                  color: request.status.color,
                  icon: request.status.icon,
                ),
                const SizedBox(width: 6),
                if (request.isSpecial)
                  const StatusBadge(
                    label: 'Special',
                    color: Color(0xFF1565C0),
                    icon: Icons.badge_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Submitted ${timeAgo(request.createdAt)}',
              style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
            ),
            if (request.images.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 150,
                child: PageView.builder(
                  itemCount: request.images.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _bytes(request.images[i].dataUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _row(Icons.notes_rounded, request.description),
            _row(request.category.icon, request.category.label),
            _row(Icons.scale_outlined, 'Quantity: ${request.estimatedQuantity}'),
            _row(Icons.place_outlined, request.location),
            _row(
              Icons.event_outlined,
              'Preferred: ${dateLabel(request.preferredDate)}',
            ),
            if (request.scheduledAt != null)
              _row(
                Icons.event_available_rounded,
                'Scheduled: ${dateTimeLabel(request.scheduledAt)}',
              ),
            if (request.assignedDriverName != null)
              _row(
                Icons.person_pin_circle_outlined,
                'Collector: ${request.assignedDriverName}',
              ),
            if (request.staffNote?.trim().isNotEmpty == true)
              _row(Icons.support_agent_rounded, request.staffNote!),
            if (request.history.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: 'Progress'),
              const SizedBox(height: 8),
              for (final entry in request.history.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: entry.status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.status.label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (entry.note?.trim().isNotEmpty == true)
                              Text(
                                entry.note!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  height: 1.45,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        timeAgo(entry.at),
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
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

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.request, required this.onTap});

  final CollectionRequest request;
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
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                icon: request.status.icon,
              ),
              const SizedBox(width: 6),
              if (request.isSpecial)
                const StatusBadge(
                  label: 'Special',
                  color: Color(0xFF1565C0),
                  icon: Icons.badge_outlined,
                  compact: true,
                ),
              const Spacer(),
              Text(
                timeAgo(request.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(request.category.icon,
                  size: 12, color: request.category.color),
              const SizedBox(width: 4),
              Text(
                request.category.shortLabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.event_outlined,
                  size: 12, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              Text(
                dateLabel(request.preferredDate),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          if (request.assignedDriverName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Collector: ${request.assignedDriverName}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
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
