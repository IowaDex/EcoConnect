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
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/collection_request.dart';
import '../services/collection_request_service.dart';

/// Which requests are on screen.
enum _RequestView { all, open, closed }

/// The resident's collection request history.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _search = TextEditingController();
  String _query = '';
  _RequestView _view = _RequestView.all;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CollectionRequest> _filter(List<CollectionRequest> items) {
    final q = _query.trim().toLowerCase();
    return items.where((r) {
      if (_view == _RequestView.open && !r.status.isOpen) return false;
      if (_view == _RequestView.closed && r.status.isOpen) return false;
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          r.status.label.toLowerCase().contains(q) ||
          (r.assignedDriverName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading requests'));
    }

    return EcoPageScaffold(
      eyebrow: 'RESIDENT · REQUESTS',
      title: 'My requests',
      subtitle: 'Track approval, scheduling and collection.',
      onBack: () => ecoBack(context, '/user'),
      actions: [
        EcoIconAction(
          icon: Icons.add_rounded,
          tooltip: 'New request',
          onTap: () => context.push('/request-collection'),
        ),
      ],
      body: StreamBuilder<List<CollectionRequest>>(
        stream: CollectionRequestService().watchMine(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _RequestsSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorView(message: AppFeedback.describe(snapshot.error!));
          }

          final all = snapshot.data ?? const <CollectionRequest>[];
          final open = all.where((r) => r.status.isOpen).length;
          final closed = all.length - open;
          final items = _filter(all);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.pending_actions_outlined,
                label: 'Open',
                value: '$open',
                accent: AppColors.warning,
                highlight: open > 0,
              ),
              DeskMetric(
                icon: Icons.task_alt_rounded,
                label: 'Closed',
                value: '$closed',
                accent: AppColors.primary,
              ),
              DeskMetric(
                icon: Icons.assignment_outlined,
                label: 'Requests',
                value: '${all.length}',
                accent: AppColors.forest,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search title, location, status',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_RequestView>(
              value: _view,
              onChanged: (next) => setState(() {
                _view = next;
                _page = 0;
              }),
              segments: [
                DeskSegment<_RequestView>(
                  value: _RequestView.all,
                  label: 'All',
                  count: all.length,
                ),
                DeskSegment<_RequestView>(
                  value: _RequestView.open,
                  label: 'Open',
                  count: open,
                ),
                DeskSegment<_RequestView>(
                  value: _RequestView.closed,
                  label: 'Closed',
                  count: closed,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: items.length == all.length
                  ? '${all.length} '
                        '${all.length == 1 ? 'request' : 'requests'}'
                  : 'Showing ${items.length} of ${all.length}',
              onClear: _query.isEmpty && _view == _RequestView.all
                  ? null
                  : () => setState(() {
                      _search.clear();
                      _query = '';
                      _view = _RequestView.all;
                      _page = 0;
                    }),
            ),
            empty: all.isEmpty
                ? DeskEmptyQueue(
                    icon: Icons.assignment_outlined,
                    title: 'No requests yet',
                    message:
                        'Ask the barangay to collect bulky or special waste '
                        'that the regular route does not take.',
                    steps: const [
                      'Send the request with a photo and quantity',
                      'The barangay desk approves and schedules it',
                      'Track the crew here until it is collected',
                    ],
                    actionLabel: 'Create a request',
                    actionIcon: Icons.add_rounded,
                    onAction: () => context.push('/request-collection'),
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing in this view',
                    message: _query.trim().isEmpty
                        ? 'No request is at this stage right now. Switch back '
                              'to All to see the full history.'
                        : 'No request matches "$_query" at this stage.',
                    actionLabel: 'Show all requests',
                    actionIcon: Icons.inbox_outlined,
                    onAction: () => setState(() {
                      _search.clear();
                      _query = '';
                      _view = _RequestView.all;
                      _page = 0;
                    }),
                  ),
            itemCount: visible.length,
            separator: 10,
            itemBuilder: (context, i) => _RequestHistoryCard(
              request: visible[i],
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
    CollectionRequest request,
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
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          children: [
            const SizedBox(height: EcoSpace.md),
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
              ],
            ),
            const SizedBox(height: EcoSpace.sm),
            Text(
              request.title,
              style: EcoType.panelTitle(context, color: AppColors.darkGreen),
            ),
            const SizedBox(height: 3),
            Text(
              'Submitted ${timeAgo(request.createdAt)}',
              style: EcoType.meta(context, color: AppColors.inkMuted),
            ),
            if (request.images.isNotEmpty) ...[
              const SizedBox(height: EcoSpace.md),
              SizedBox(
                height: 150,
                child: PageView.builder(
                  itemCount: request.images.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(EcoRadius.md),
                      child: Image.memory(
                        _bytes(request.images[i].dataUrl),
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
                    'WHAT YOU ASKED FOR',
                    style: EcoType.eyebrow(context, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  Text(
                    request.description,
                    style: EcoType.body(context, color: AppColors.textDark),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  _SheetRow(
                    icon: request.category.icon,
                    text:
                        '${request.category.label} · '
                        '${request.estimatedQuantity}',
                  ),
                  const SizedBox(height: 5),
                  _SheetRow(icon: Icons.place_outlined, text: request.location),
                  const SizedBox(height: 5),
                  _SheetRow(
                    icon: Icons.event_outlined,
                    text: 'Preferred ${dateLabel(request.preferredDate)}',
                  ),
                  if (request.isWave2) ...[
                    const SizedBox(height: 5),
                    _SheetRow(
                      icon: Icons.layers_outlined,
                      text: 'Wave 2 · ${request.wave2StageLabel}',
                    ),
                  ],
                  if (request.scheduledAt != null) ...[
                    const SizedBox(height: 5),
                    _SheetRow(
                      icon: Icons.event_available_rounded,
                      text: 'Scheduled ${dateTimeLabel(request.scheduledAt)}',
                    ),
                  ],
                  if (request.assignedDriverName != null) ...[
                    const SizedBox(height: 5),
                    _SheetRow(
                      icon: Icons.person_pin_circle_outlined,
                      text: 'Collector ${request.assignedDriverName}',
                    ),
                  ],
                ],
              ),
            ),
            if (request.staffNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: EcoSpace.md),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                decoration: BoxDecoration(
                  color: request.status.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                  border: Border.all(
                    color: request.status.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 15,
                      color: request.status.color,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Desk note: ${request.staffNote}',
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
            if (request.responses.isNotEmpty) ...[
              const SizedBox(height: EcoSpace.lg),
              DeskSectionHeader(
                icon: Icons.forum_outlined,
                title: 'City Hall responses',
                count: request.responses.length,
              ),
              const SizedBox(height: EcoSpace.sm),
              for (final response in request.responses) ...[
                DeskRailCard(
                  railColor: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(15, 12, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        response.message,
                        style: EcoType.body(context, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${response.byName} · ${timeAgo(response.at)}',
                        style: EcoType.meta(context, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EcoSpace.sm),
              ],
            ],
            if (request.history.isNotEmpty) ...[
              const SizedBox(height: EcoSpace.lg),
              const DeskSectionHeader(
                icon: Icons.timeline_rounded,
                title: 'Progress',
                subtitle: 'Newest first.',
              ),
              const SizedBox(height: EcoSpace.sm),
              for (final entry in request.history.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
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
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.status.label,
                              style: EcoType.bodyStrong(
                                context,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (entry.note?.trim().isNotEmpty == true)
                              Text(
                                entry.note!,
                                style: EcoType.meta(
                                  context,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(entry.at),
                        style: EcoType.meta(context, color: AppColors.inkMuted),
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

/// A labelled fact inside the detail sheet.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: EcoType.bodySmall(context, color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// A compact fact on the card's second line.
class _CardFact extends StatelessWidget {
  const _CardFact({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: tint),
        const SizedBox(width: 4),
        Text(text, style: EcoType.meta(context, color: tint)),
      ],
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.request, required this.onTap});

  final CollectionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: request.status.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitle(context, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                icon: request.status.icon,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 3,
            children: [
              _CardFact(
                icon: request.category.icon,
                text: request.category.shortLabel,
                color: request.category.color,
              ),
              _CardFact(
                icon: Icons.event_outlined,
                text: dateLabel(request.preferredDate),
              ),
              if (request.isSpecial)
                const _CardFact(
                  icon: Icons.badge_outlined,
                  text: 'Special',
                  color: Color(0xFF1565C0),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: request.assignedDriverName == null
                    ? Text(
                        'Submitted ${timeAgo(request.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.meta(context, color: AppColors.inkMuted),
                      )
                    : _CardFact(
                        icon: Icons.person_pin_circle_outlined,
                        text: 'Collector ${request.assignedDriverName}',
                        color: AppColors.primary,
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

class _RequestsSkeleton extends StatelessWidget {
  const _RequestsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 10, radius: 5),
          SizedBox(height: 14),
          SkeletonCardList(count: 4),
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
