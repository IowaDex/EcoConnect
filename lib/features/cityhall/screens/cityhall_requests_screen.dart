import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';

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

class _CityHallRequestsScreenState extends State<CityHallRequestsScreen> {
  bool _openOnly = true;

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
          'Resident requests',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<CollectionRequest>>(
        stream: CollectionRequestService().watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load requests',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final all = snapshot.data ?? const <CollectionRequest>[];
          final items = _openOnly
              ? all.where((r) => r.status.isOpen).toList(growable: false)
              : all;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
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
                    Text(
                      '${items.length} shown',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No requests',
                        message:
                            'Resident requests appear here. Reply here and the '
                            'resident and barangay both see the response.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _RequestTile(
                          request: items[i],
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
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            request.title,
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
            '${request.requesterName}'
            '${request.requesterBarangay == null ? '' : ' · ${request.requesterBarangay}'}'
            ' · ${request.location}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.forum_outlined, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                request.responses.isEmpty
                    ? 'No City Hall reply yet'
                    : '${request.responses.length} replies',
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
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Row(
            children: [
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
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
            '${request.requesterName}'
            '${request.requesterBarangay == null ? '' : ' · ${request.requesterBarangay}'}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          Text(
            request.description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.65,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _row(Icons.place_outlined, request.location),
          _row(
            Icons.event_outlined,
            'Preferred: ${dateLabel(request.preferredDate)}',
          ),
          if (request.isWave2)
            _row(
              Icons.layers_outlined,
              'Wave 2 · City Hall status: ${request.cityHallStatus}',
            ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Shared conversation'),
          const SizedBox(height: 8),
          if (request.responses.isEmpty)
            const Text(
              'No replies yet. The first reply is visible to the resident and '
              'the barangay.',
              style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
            )
          else
            for (final response in request.responses) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: response.byRole == 'cityHall'
                      ? Colors.white
                      : AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.message,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.55,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${response.byName} · ${timeAgo(response.at)}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 16),
          TextField(
            controller: _reply,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reply to the resident',
              hintText: 'This is also visible to the barangay staff',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
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
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                'Send reply',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
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
