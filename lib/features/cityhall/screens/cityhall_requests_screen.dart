import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';
import '../../../core/widgets/desk_ui.dart';

/// City Hall's resident-request desk.
///
/// A reply written here is appended to the request and is visible to both the
/// requesting resident and the concerned barangay staff, as required by the
/// shared-response rule.
class CityHallRequestsScreen extends StatefulWidget {
  const CityHallRequestsScreen({super.key});

  @override
  State<CityHallRequestsScreen> createState() => _CityHallRequestsScreenState();
}

/// A request still needs an answer when no City Hall reply exists yet —
/// a barangay note in the same thread does not count.
bool _needsReply(CollectionRequest request) =>
    request.responses.every((response) => response.byRole != 'cityHall');

/// The three ways a request can sit on this desk. The desk opens on
/// [needsReply], because that is the work; the other two are the record.
enum _RequestFilter { needsReply, answered, all }

extension on _RequestFilter {
  String get label => switch (this) {
    _RequestFilter.needsReply => 'Need reply',
    _RequestFilter.answered => 'Answered',
    _RequestFilter.all => 'All',
  };

  bool matches(CollectionRequest request) => switch (this) {
    _RequestFilter.needsReply => _needsReply(request),
    _RequestFilter.answered => !_needsReply(request),
    _RequestFilter.all => true,
  };
}

class _CityHallRequestsScreenState extends State<CityHallRequestsScreen> {
  final _search = TextEditingController();
  _RequestFilter _filter = _RequestFilter.needsReply;
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CollectionRequest> _searchIn(List<CollectionRequest> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.requesterName.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q);
    }).toList();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = _RequestFilter.needsReply;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final byName = user?.displayName ?? 'City Hall';

    return EcoPageScaffold(
      eyebrow: 'CITY HALL · RESIDENT REQUESTS',
      title: 'Resident requests',
      icon: Icons.forum_outlined,
      subtitle:
          'Answer the barangay’s escalated requests. Your reply is visible to '
          'the resident and the concerned staff.',
      onBack: () => ecoBack(context, '/cityhall'),
      body: StreamBuilder<List<CollectionRequest>>(
        stream: CollectionRequestService().watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EcoLoadingView(label: 'Loading resident requests');
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load requests',
              message: AppFeedback.describe(snapshot.error!),
            );
          }

          final all = snapshot.data ?? const <CollectionRequest>[];
          final searched = _searchIn(all);
          final items = searched.where(_filter.matches).toList(growable: false);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);
          final needsReply = all.where(_needsReply).length;
          final answered = all.length - needsReply;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.mark_email_unread_outlined,
                label: 'Need a reply',
                value: '$needsReply',
                accent: AppColors.warning,
                highlight: needsReply > 0,
              ),
              DeskMetric(
                icon: Icons.forum_outlined,
                label: 'Answered',
                value: '$answered',
              ),
              DeskMetric(
                icon: Icons.inbox_outlined,
                label: 'Total',
                value: '${all.length}',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search requester, title or place',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_RequestFilter>(
              value: _filter,
              onChanged: (value) => setState(() {
                _filter = value;
                _page = 0;
              }),
              segments: [
                for (final filter in _RequestFilter.values)
                  DeskSegment(
                    value: filter,
                    label: filter.label,
                    count: searched.where(filter.matches).length,
                  ),
              ],
            ),
            resultLine: DeskResultLine(
              label:
                  '${items.length} '
                  '${items.length == 1 ? 'request' : 'requests'}',
              onClear:
                  _query.trim().isNotEmpty ||
                      _filter != _RequestFilter.needsReply
                  ? _clearFilters
                  : null,
            ),
            empty: all.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.forum_outlined,
                    title: 'No resident requests yet',
                    message:
                        'Requests the barangay escalates to City Hall '
                        'appear here. Answer one and both the resident and the '
                        'barangay see it.',
                    steps: [
                      'Barangay escalates a request',
                      'City Hall writes the reply',
                      'Resident and staff see the same thread',
                    ],
                  )
                : _query.trim().isNotEmpty
                ? DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No request matches',
                    message:
                        'Try another word, or clear the search to see '
                        'every request on this desk.',
                    actionLabel: 'Clear search',
                    actionIcon: Icons.search_off_rounded,
                    onAction: _clearFilters,
                  )
                // Nothing is waiting for a reply. Offer the record instead of
                // a filter reset — the queue is empty because the work is done.
                : DeskEmptyQueue(
                    icon: Icons.task_alt_rounded,
                    title: 'Every request is answered',
                    message:
                        'Nothing is waiting for a City Hall reply. Answered '
                        'requests stay on record.',
                    actionLabel: 'Show answered requests',
                    actionIcon: Icons.forum_outlined,
                    onAction: () => setState(() {
                      _filter = _RequestFilter.answered;
                      _page = 0;
                    }),
                  ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _RequestTile(
              request: visible[i],
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

  Future<void> _open(
    BuildContext context,
    CollectionRequest request,
    String byName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReplySheet(request: request, byName: byName),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onTap});

  final CollectionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needsReply = _needsReply(request);
    final barangay = request.requesterBarangay;

    return DeskRailCard(
      railColor: request.status.color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                icon: request.status.icon,
                compact: true,
              ),
              const SizedBox(width: 6),
              if (request.isWave2)
                const StatusBadge(
                  label: 'Wave 2',
                  color: Color(0xFF6A1B9A),
                  compact: true,
                ),
              const Spacer(),
              Text(
                timeAgo(request.createdAt),
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              DeskInitialAvatar(name: request.requesterName, size: 22),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodyStrong(
                        context,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      [
                        if (barangay != null && barangay.isNotEmpty) barangay,
                        request.location,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              // Expanded keeps the chevron on the card's right edge no matter
              // how long the reply chip is.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ReplyChip(
                    awaiting: needsReply,
                    count: request.responses.length,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({required this.awaiting, required this.count});

  final bool awaiting;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = awaiting ? AppColors.warning : AppColors.primary;
    final label = awaiting
        ? 'Needs reply'
        : count == 1
        ? '1 reply'
        : '$count replies';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            awaiting ? Icons.mark_chat_unread_outlined : Icons.forum_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(label, style: EcoType.chip(context, color: color)),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.request, required this.byName});

  final CollectionRequest request;
  final String byName;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.isEmpty) {
      AppFeedback.error(context, 'Write a reply first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await CollectionRequestService().addCityHallResponse(
        request: widget.request,
        message: message,
        byName: widget.byName,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(
        context,
        'Reply sent to the resident and the barangay',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 30),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: request.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                ),
                child: Icon(
                  request.category.icon,
                  size: 19,
                  color: request.category.color,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        StatusBadge(
                          label: request.status.label,
                          color: request.status.color,
                          compact: true,
                        ),
                        if (request.isWave2) ...[
                          const SizedBox(width: 5),
                          const StatusBadge(
                            label: 'Wave 2',
                            color: Color(0xFF6A1B9A),
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DeskInitialAvatar(name: request.requesterName, size: 30),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.requesterName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${request.requesterBarangay ?? 'Batasan Hills'} · '
                            'submitted ${timeAgo(request.createdAt)}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  request.description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                _Fact(icon: Icons.place_outlined, text: request.location),
                _Fact(
                  icon: Icons.event_outlined,
                  text: 'Preferred: ${dateLabel(request.preferredDate)}',
                ),
                _Fact(
                  icon: Icons.scale_outlined,
                  text:
                      '${request.category.label} · ${request.estimatedQuantity}',
                ),
                if (request.isWave2)
                  _Fact(
                    icon: Icons.layers_outlined,
                    text: 'Wave 2 · ${request.wave2StageLabel}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'SHARED CONVERSATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.sage.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${request.responses.length}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (request.responses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.md),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.7),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: AppColors.inkMuted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No replies yet. The first reply is visible to the '
                      'resident and the barangay.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final response in request.responses)
              _ResponseBubble(response: response),
          const SizedBox(height: 16),
          const Text(
            'Your reply',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _reply,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Answer the resident. The barangay staff sees this too.',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                'Send reply',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseBubble extends StatelessWidget {
  const _ResponseBubble({required this.response});

  final RequestResponse response;

  @override
  Widget build(BuildContext context) {
    final fromCityHall = response.byRole == 'cityHall';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        mainAxisAlignment: fromCityHall
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromCityHall) ...[
            DeskInitialAvatar(name: response.byName, size: 24),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: fromCityHall ? AppColors.forest : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(fromCityHall ? 14 : 4),
                  bottomRight: Radius.circular(fromCityHall ? 4 : 14),
                ),
                border: Border.all(
                  color: fromCityHall
                      ? AppColors.forest
                      : AppColors.sage.withValues(alpha: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response.message,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      color: fromCityHall ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${fromCityHall ? 'City Hall' : response.byName} · '
                    '${timeAgo(response.at)}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: fromCityHall
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppColors.inkMuted,
                    ),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
