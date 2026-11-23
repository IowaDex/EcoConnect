import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';

/// Wave 2 approvals: the barangay reviews first, City Hall approves.
///
/// One screen, two faces — the barangay sees requests it can pass up, City Hall
/// sees the queue it has to decide on. The resident sees the outcome on the
/// request thread either way.
class WaveApprovalScreen extends StatefulWidget {
  const WaveApprovalScreen({super.key, required this.forCityHall});

  final bool forCityHall;

  @override
  State<WaveApprovalScreen> createState() => _WaveApprovalScreenState();
}

class _WaveApprovalScreenState extends State<WaveApprovalScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _showDecided = false;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CollectionRequest> _filter(List<CollectionRequest> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          r.requesterName.toLowerCase().contains(q) ||
          r.status.label.toLowerCase().contains(q);
    }).toList();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final forCityHall = widget.forCityHall;
    final service = CollectionRequestService();

    return EcoPageScaffold(
      eyebrow: forCityHall ? 'CITY HALL · WAVE 2' : 'BARANGAY · WAVE 2',
      title: forCityHall ? 'Wave 2 approvals' : 'Pass to City Hall',
      subtitle: forCityHall
          ? 'Uncollected garbage the barangay verified. Approve it to put the '
                'address back on a collection round.'
          : 'Uncollected garbage the crew missed. Verify the report, then pass '
                'it to City Hall for approval.',
      onBack: () =>
          ecoBack(context, forCityHall ? '/cityhall' : '/admin-dashboard'),
      body: StreamBuilder<List<CollectionRequest>>(
        stream: service.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const EcoLoadingView(label: 'Loading Wave 2 requests');
          }

          final all = snapshot.data ?? const <CollectionRequest>[];
          final base = all
              .where((r) => r.kind == RequestKind.uncollected)
              .toList(growable: false);
          final queue = base
              .where(
                (r) => forCityHall
                    ? r.cityHallStatus == 'pending'
                    : r.cityHallStatus == 'none' &&
                          r.status != RequestStatus.completed &&
                          r.status != RequestStatus.rejected,
              )
              .toList(growable: false);
          final decided = base
              .where(
                (r) =>
                    r.cityHallStatus == 'approved' ||
                    r.cityHallStatus == 'rejected',
              )
              .toList(growable: false);

          // Oldest first: the truck missed them days ago, so the resident has
          // waited longest. Decisions read newest first instead.
          queue.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(2000);
            final bDate = b.createdAt ?? DateTime(2000);
            return aDate.compareTo(bDate);
          });
          decided.sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

          final source = _showDecided ? decided : queue;
          final items = _filter(source);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);

          final oldest = queue.isEmpty
              ? null
              : queue
                    .map((r) => r.createdAt)
                    .whereType<DateTime>()
                    .fold<DateTime?>(
                      null,
                      (min, date) =>
                          min == null || date.isBefore(min) ? date : min,
                    );
          final oldestDays = oldest == null
              ? '—'
              : '${DateTime.now().difference(oldest).inDays}d';

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: forCityHall
                    ? Icons.pending_actions_rounded
                    : Icons.outbox_rounded,
                label: forCityHall ? 'Awaiting you' : 'Ready to pass',
                value: '${queue.length}',
                accent: AppColors.warning,
                highlight: queue.isNotEmpty,
              ),
              DeskMetric(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Oldest wait',
                value: oldestDays,
                accent: queue.isEmpty ? AppColors.inkMuted : AppColors.error,
              ),
              DeskMetric(
                icon: Icons.task_alt_rounded,
                label: 'Decided',
                value: '${decided.length}',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search title, requester, location',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<bool>(
              value: _showDecided,
              onChanged: (value) => setState(() {
                _showDecided = value;
                _page = 0;
              }),
              segments: [
                DeskSegment(
                  value: false,
                  label: forCityHall ? 'Awaiting you' : 'Ready to pass',
                  count: queue.length,
                  icon: Icons.layers_outlined,
                ),
                DeskSegment(
                  value: true,
                  label: 'Decided',
                  count: decided.length,
                  icon: Icons.fact_check_outlined,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: _query.trim().isEmpty
                  ? '${items.length} '
                        '${items.length == 1 ? 'request' : 'requests'}'
                  : 'Showing ${items.length} of ${source.length}',
              onClear: _query.trim().isNotEmpty ? _clear : null,
            ),
            empty: _query.trim().isNotEmpty
                ? DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No request matches',
                    message: 'Try another title, requester or street.',
                    actionLabel: 'Clear search',
                    actionIcon: Icons.search_off_rounded,
                    onAction: _clear,
                  )
                : _showDecided
                ? const DeskEmptyQueue(
                    icon: Icons.fact_check_outlined,
                    title: 'No decision yet',
                    message:
                        'Approved and declined Wave 2 reports stay here on '
                        'record.',
                  )
                : DeskEmptyQueue(
                    icon: Icons.layers_outlined,
                    title: forCityHall
                        ? 'Nothing waiting for approval'
                        : 'Nothing ready to pass',
                    message: forCityHall
                        ? 'The barangay has not passed a Wave 2 report yet. It '
                              'appears here the moment they do.'
                        : 'Wave 2 reports appear once a resident marks a round '
                              'as uncollected.',
                    steps: forCityHall
                        ? const [
                            'Resident reports an uncollected round',
                            'Barangay verifies it and passes it up',
                            'City Hall approves the return',
                          ]
                        : const [
                            'Resident reports an uncollected round',
                            'Staff verify it on the ground',
                            'Pass it to City Hall for approval',
                          ],
                  ),
            itemCount: visible.length,
            listPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            itemBuilder: (context, i) => _RequestCard(
              request: visible[i],
              forCityHall: forCityHall,
              decided: _showDecided,
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
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.forCityHall,
    required this.decided,
  });

  final CollectionRequest request;
  final bool forCityHall;
  final bool decided;

  Future<void> _pass(BuildContext context) async {
    final name = context.read<AuthProvider>().currentUser?.displayName;
    await CollectionRequestService().passToCityHall(request.id, byName: name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Passed to City Hall for approval'),
          backgroundColor: AppColors.forest,
        ),
      );
  }

  Future<void> _decide(BuildContext context, bool approve) async {
    final ok = await AppFeedback.confirm(
      context,
      title: approve ? 'Approve this collection?' : 'Decline this collection?',
      message: approve
          ? '"${request.title}" goes back on a collection round and the '
                'resident is told it was approved.'
          : '"${request.title}" is declined and the resident sees the '
                'decision on the request thread.',
      confirmLabel: approve ? 'Approve' : 'Decline',
      destructive: !approve,
      icon: approve ? Icons.check_circle_outline_rounded : Icons.block_rounded,
    );
    if (!ok || !context.mounted) return;

    await CollectionRequestService().cityHallDecision(
      request.id,
      approve: approve,
      note: approve ? null : 'Rejected by City Hall',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Approved by City Hall' : 'Declined by City Hall',
          ),
          backgroundColor: approve ? AppColors.forest : AppColors.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final rejected = request.cityHallStatus == 'rejected';
    final railColor = decided
        ? (rejected ? AppColors.error : AppColors.primary)
        : const Color(0xFF6A1B9A);

    return DeskRailCard(
      railColor: railColor,
      padding: const EdgeInsets.fromLTRB(17, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusBadge(
                label: 'Wave 2',
                color: Color(0xFF6A1B9A),
                icon: Icons.layers_outlined,
                compact: true,
              ),
              const SizedBox(width: 6),
              StatusBadge(
                label: decided ? request.wave2StageLabel : request.status.label,
                color: decided
                    ? (rejected ? AppColors.error : AppColors.primary)
                    : request.status.color,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(request.createdAt),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              DeskInitialAvatar(name: request.requesterName, size: 26),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.textDark,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      request.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _MiniChip(
                icon: Icons.event_outlined,
                label: 'Missed ${dateLabel(request.preferredDate)}',
              ),
              if (request.estimatedQuantity.trim().isNotEmpty)
                _MiniChip(
                  icon: Icons.scale_outlined,
                  label: request.estimatedQuantity,
                ),
              if (decided && request.updatedAt != null)
                _MiniChip(
                  icon: Icons.gavel_rounded,
                  label: 'Decided ${timeAgo(request.updatedAt)}',
                ),
            ],
          ),
          if (!decided) ...[
            const SizedBox(height: 12),
            if (!forCityHall)
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _pass(context),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.primary),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: const Text('Verify & pass to City Hall'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => _decide(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: () => _decide(context, true),
                        icon: const Icon(Icons.check_rounded, size: 15),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        label: const Text('Approve'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(label, style: EcoType.meta(context, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}
