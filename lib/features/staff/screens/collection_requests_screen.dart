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
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';

/// Staff desk for every resident and government collection request.
class CollectionRequestsScreen extends StatefulWidget {
  const CollectionRequestsScreen({super.key});

  @override
  State<CollectionRequestsScreen> createState() =>
      _CollectionRequestsScreenState();
}

class _CollectionRequestsScreenState extends State<CollectionRequestsScreen> {
  final _service = CollectionRequestService();
  final _search = TextEditingController();

  RequestStatus? _status;
  String _barangay = '';
  int _days = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Collection requests',
              subtitle: 'Review, schedule and dispatch resident requests.',
              onBack: () => context.go('/admin-dashboard'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by requester or title',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _StatusFilterBar(
              selected: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<CollectionRequest>>(
                stream: _service.watchAll(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading requests');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final all = snapshot.data ?? const <CollectionRequest>[];
                  final barangays = all
                      .map((r) => r.requesterBarangay?.trim() ?? '')
                      .where((b) => b.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  final items = _applyFilters(all);
                  return Column(
                    children: [
                      _FilterSummary(
                        total: all.length,
                        shown: items.length,
                        barangays: barangays,
                        selectedBarangay: _barangay,
                        days: _days,
                        onBarangay: (value) =>
                            setState(() => _barangay = value),
                        onDays: (value) => setState(() => _days = value),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const EmptyState(
                                icon: Icons.inbox_outlined,
                                title: 'No requests match',
                                message:
                                    'Try clearing the status, barangay or date filter.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 4, 18, 24),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final request = items[i];
                                  return _RequestCard(
                                    request: request,
                                    onTap: () => _openDetail(context, request),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CollectionRequest> _applyFilters(List<CollectionRequest> all) {
    final query = _search.text.trim().toLowerCase();
    final cutoff = _days == 0
        ? null
        : DateTime.now().subtract(Duration(days: _days));
    return all.where((request) {
      if (_status != null && request.status != _status) return false;
      if (_barangay.isNotEmpty &&
          (request.requesterBarangay ?? '').trim() != _barangay) {
        return false;
      }
      if (cutoff != null) {
        final created = request.createdAt;
        if (created == null || created.isBefore(cutoff)) return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${request.title} ${request.requesterName} ${request.location}'
                .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _openDetail(
    BuildContext context,
    CollectionRequest request,
  ) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestDetailSheet(
        request: request,
        staffId: user.uid,
        staffName: user.displayName ?? 'Barangay staff',
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final RequestStatus? selected;
  final ValueChanged<RequestStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _chip('All', selected == null, () => onChanged(null)),
          for (final status in RequestStatus.values)
            _chip(status.label, selected == status, () => onChanged(status)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.darkGreen,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.total,
    required this.shown,
    required this.barangays,
    required this.selectedBarangay,
    required this.days,
    required this.onBarangay,
    required this.onDays,
  });

  final int total;
  final int shown;
  final List<String> barangays;
  final String selectedBarangay;
  final int days;
  final ValueChanged<String> onBarangay;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 12, 8),
      child: Row(
        children: [
          Text(
            '$shown of $total requests',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: 'Date',
            onSelected: onDays,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Any date')),
              PopupMenuItem(value: 1, child: Text('Last 24 hours')),
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
            child: _filterPill(
              days == 0 ? 'Any date' : 'Last $days days',
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Barangay',
            onSelected: onBarangay,
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All barangays')),
              for (final barangay in barangays)
                PopupMenuItem(value: barangay, child: Text(barangay)),
            ],
            child: _filterPill(
              selectedBarangay.isEmpty ? 'All barangays' : selectedBarangay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded,
              size: 13, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

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
                  label: 'Government',
                  color: Color(0xFF1565C0),
                  icon: Icons.badge_outlined,
                ),
              const Spacer(),
              Text(
                timeAgo(request.createdAt),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.requesterName} · ${request.requesterBarangay ?? 'Barangay'}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip(request.category.icon, request.category.shortLabel),
              _miniChip(Icons.scale_outlined, request.estimatedQuantity),
              _miniChip(
                Icons.event_outlined,
                dateLabel(request.preferredDate),
              ),
            ],
          ),
          if (request.assignedDriverName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Assigned to ${request.assignedDriverName}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestDetailSheet extends StatefulWidget {
  const _RequestDetailSheet({
    required this.request,
    required this.staffId,
    required this.staffName,
  });

  final CollectionRequest request;
  final String staffId;
  final String staffName;

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  final _service = CollectionRequestService();
  late CollectionRequest _request = widget.request;
  bool _busy = false;

  Future<void> _apply(RequestStatus status, {String? note}) async {
    setState(() => _busy = true);
    try {
      await _service.updateStatus(
        request: _request,
        status: status,
        actorId: widget.staffId,
        actorName: widget.staffName,
        note: note,
        rejectionReason: status == RequestStatus.rejected ? note : null,
      );
      if (!mounted) return;
      setState(() => _request = _request.copyWith(status: status));
      AppFeedback.success(
        context,
        'Request marked ${status.label.toLowerCase()}',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell the resident why so they can correct the request.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Incomplete address or wrong waste category',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _apply(
      RequestStatus.rejected,
      note: controller.text.trim().isEmpty
          ? 'The request did not meet the barangay collection requirements.'
          : controller.text.trim(),
    );
  }

  Future<void> _assign() async {
    final assignment = await showModalBottomSheet<_Assignment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignSheet(request: _request),
    );
    if (assignment == null) return;

    setState(() => _busy = true);
    try {
      await _service.assignDriver(
        request: _request,
        driverId: assignment.driverId,
        driverName: assignment.driverName,
        scheduledAt: assignment.scheduledAt,
        actorId: widget.staffId,
        actorName: widget.staffName,
      );
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(
          status: RequestStatus.assigned,
          assignedDriverId: assignment.driverId,
          assignedDriverName: assignment.driverName,
          scheduledAt: assignment.scheduledAt,
        );
      });
      AppFeedback.success(context, 'Driver assigned and resident notified');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
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
                  label: 'Special · government',
                  color: Color(0xFF1565C0),
                  icon: Icons.badge_outlined,
                ),
              const Spacer(),
              Text(
                timeAgo(request.createdAt),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request.description,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.65,
              color: AppColors.textDark,
            ),
          ),
          if (request.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _bytes(request.images[i].dataUrl),
                    width: 150,
                    height: 116,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Requester'),
          _row(Icons.person_outline_rounded, request.requesterName),
          if (request.requesterPhone?.isNotEmpty == true)
            _row(Icons.call_outlined, request.requesterPhone!),
          _row(
            Icons.location_on_outlined,
            request.requesterBarangay ?? 'Barangay not set',
          ),
          const SizedBox(height: 14),
          _sectionTitle('Collection details'),
          _row(request.category.icon, request.category.label),
          _row(Icons.scale_outlined, 'Quantity: ${request.estimatedQuantity}'),
          _row(Icons.place_outlined, request.location),
          _row(Icons.event_outlined, 'Preferred: ${dateLabel(request.preferredDate)}'),
          if (request.scheduledAt != null)
            _row(Icons.event_available_rounded,
                'Scheduled: ${dateTimeLabel(request.scheduledAt)}'),
          if (request.assignedDriverName != null)
            _row(Icons.person_pin_circle_outlined,
                'Driver: ${request.assignedDriverName}'),
          if (request.remarks?.trim().isNotEmpty == true)
            _row(Icons.notes_rounded, request.remarks!),
          if (request.staffNote?.trim().isNotEmpty == true)
            _row(Icons.support_agent_rounded, 'Staff note: ${request.staffNote}'),
          if (request.history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Activity'),
            for (final entry in request.history.reversed.take(5))
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
                          Text(
                            [
                              timeAgo(entry.at),
                              if (entry.byName != null) entry.byName!,
                              if (entry.note != null) entry.note!,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.45,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 22),
          ..._actions(request),
        ],
      ),
    );
  }

  List<Widget> _actions(CollectionRequest request) {
    if (_busy) {
      return const [
        Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    final buttons = <Widget>[];
    switch (request.status) {
      case RequestStatus.pending:
        buttons.add(
          _action('Review request', Icons.search_rounded, () {
            _apply(RequestStatus.underReview);
          }, outlined: true),
        );
        buttons.add(_action('Approve', Icons.check_rounded, () {
          _apply(RequestStatus.approved);
        }));
        buttons.add(_action('Reject', Icons.close_rounded, _reject, danger: true));
      case RequestStatus.underReview:
        buttons.add(_action('Approve', Icons.check_rounded, () {
          _apply(RequestStatus.approved);
        }));
        buttons.add(_action('Reject', Icons.close_rounded, _reject, danger: true));
      case RequestStatus.approved:
        buttons.add(_action('Assign driver', Icons.person_add_alt_1_rounded, _assign));
        buttons.add(_action('Reject', Icons.close_rounded, _reject, danger: true));
      case RequestStatus.assigned:
        buttons.add(_action('Start collection', Icons.local_shipping_rounded, () {
          _apply(RequestStatus.inProgress);
        }));
        buttons.add(_action('Mark collected', Icons.inventory_2_outlined, () {
          _apply(RequestStatus.collected);
        }, outlined: true));
      case RequestStatus.inProgress:
        buttons.add(_action('Mark collected', Icons.inventory_2_outlined, () {
          _apply(RequestStatus.collected);
        }));
      case RequestStatus.collected:
        buttons.add(_action('Complete request', Icons.task_alt_rounded, () {
          _apply(RequestStatus.completed);
        }));
      case RequestStatus.completed:
      case RequestStatus.rejected:
        buttons.add(
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'This request is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
          ),
        );
    }
    return [
      for (var i = 0; i < buttons.length; i++) ...[
        if (i > 0) const SizedBox(height: 9),
        buttons[i],
      ],
    ];
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool outlined = false,
    bool danger = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Text(label),
      ],
    );
    return SizedBox(
      height: 46,
      child: outlined
          ? OutlinedButton(onPressed: onTap, child: child)
          : FilledButton(
              onPressed: onTap,
              style: danger
                  ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                  : null,
              child: child,
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.darkGreen,
        ),
      ),
    );
  }
}

class _Assignment {
  const _Assignment({
    required this.driverId,
    required this.driverName,
    required this.scheduledAt,
  });

  final String driverId;
  final String driverName;
  final DateTime scheduledAt;
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.request});

  final CollectionRequest request;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late Future<List<Map<String, dynamic>>> _drivers;
  Map<String, dynamic>? _selected;
  late DateTime _scheduledAt = widget.request.preferredDate.isAfter(DateTime.now())
      ? widget.request.preferredDate
      : DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _drivers = context.read<AuthProvider>().getDrivers();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign a driver',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'The resident and the driver both receive a notification.',
                    style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _drivers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading drivers');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final drivers = snapshot.data ?? const [];
                  if (drivers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.no_transfer_outlined,
                      title: 'No active drivers',
                      message:
                          'Approve a driver account before assigning collection requests.',
                      compact: true,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final driver = drivers[i];
                      final uid = driver['uid'] as String;
                      final selected = _selected?['uid'] == uid;
                      return InkWell(
                        onTap: () => setState(() => _selected = driver),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.lightGreen
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.sage,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.lightGreen,
                                child: Text(
                                  ((driver['name'] as String?) ?? 'D')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (driver['name'] as String?) ?? 'Driver',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      '${(driver['barangay'] as String?) ?? 'Barangay not set'} · ${(driver['phone'] as String?) ?? 'No contact'}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_circle_rounded,
                                    size: 19, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.sage),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Collection schedule',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              Text(
                                dateTimeLabel(_scheduledAt),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_outlined,
                              size: 17, color: AppColors.inkMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selected == null
                          ? null
                          : () => Navigator.of(context).pop(
                                _Assignment(
                                  driverId: _selected!['uid'] as String,
                                  driverName:
                                      (_selected!['name'] as String?) ??
                                          'Driver',
                                  scheduledAt: _scheduledAt,
                                ),
                              ),
                      child: const Text('Assign driver'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
