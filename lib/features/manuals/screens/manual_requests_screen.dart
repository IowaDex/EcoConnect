import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
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
import '../../../core/widgets/desk_ui.dart';
import '../models/manual.dart';
import '../services/manual_service.dart';

/// City Hall asks Iswim for a manual; Iswim answers by linking a submitted
/// manual to the request.
class ManualRequestsScreen extends StatefulWidget {
  const ManualRequestsScreen({super.key});

  @override
  State<ManualRequestsScreen> createState() => _ManualRequestsScreenState();
}

class _ManualRequestsScreenState extends State<ManualRequestsScreen> {
  final _search = TextEditingController();
  String _query = '';
  ManualRequestStatus? _status;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ManualRequest> _filter(List<ManualRequest> requests) {
    final q = _query.trim().toLowerCase();
    return requests.where((r) {
      if (_status != null && r.status != _status) return false;
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          r.details.toLowerCase().contains(q) ||
          r.requestedByName.toLowerCase().contains(q);
    }).toList();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _status = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;

    return EcoPageScaffold(
      eyebrow: 'MANUALS · REQUESTS',
      title: 'Manual requests',
      subtitle:
          'A procedure that is missing or out of date. Iswim answers by '
          'linking the manual to the request.',
      onBack: () => ecoBack(context, isIswim ? '/iswim' : '/cityhall'),
      fab: isIswim
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openRequest(context),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text(
                'Request manual',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
      body: StreamBuilder<List<ManualRequest>>(
        stream: ManualService().watchRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading manual requests');
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load requests',
              message: AppFeedback.describe(snapshot.error!),
            );
          }

          final requests = snapshot.data ?? const <ManualRequest>[];
          final items = _filter(requests);
          final page = clampPage(_page, items.length, _pageSize);
          final visible = pageSlice(items, page, _pageSize);
          final pending = requests
              .where((r) => r.status == ManualRequestStatus.pending)
              .length;
          final fulfilled = requests
              .where((r) => r.status == ManualRequestStatus.fulfilled)
              .length;
          final approved = requests
              .where((r) => r.status == ManualRequestStatus.approved)
              .length;
          final filtered = _query.trim().isNotEmpty || _status != null;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.mark_email_unread_outlined,
                label: 'Waiting',
                value: '$pending',
                accent: AppColors.warning,
                highlight: pending > 0,
              ),
              DeskMetric(
                icon: Icons.task_alt_rounded,
                label: 'Submitted',
                value: '$fulfilled',
              ),
              DeskMetric(
                icon: Icons.verified_rounded,
                label: 'Approved',
                value: '$approved',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search title, code or requester',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<ManualRequestStatus?>(
              value: _status,
              onChanged: (value) => setState(() {
                _status = value;
                _page = 0;
              }),
              segments: [
                DeskSegment(value: null, label: 'All', count: requests.length),
                DeskSegment(
                  value: ManualRequestStatus.pending,
                  label: 'Waiting',
                  count: pending,
                ),
                DeskSegment(
                  value: ManualRequestStatus.fulfilled,
                  label: 'Submitted',
                  count: fulfilled,
                ),
                DeskSegment(
                  value: ManualRequestStatus.approved,
                  label: 'Approved',
                  count: approved,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: filtered
                  ? 'Showing ${items.length} of ${requests.length}'
                  : '${requests.length} '
                        '${requests.length == 1 ? 'request' : 'requests'}',
              onClear: filtered ? _clear : null,
            ),
            empty: requests.isEmpty
                ? DeskEmptyQueue(
                    icon: Icons.menu_book_outlined,
                    title: 'No manual requests yet',
                    message: isIswim
                        ? 'When City Hall needs a procedure that is missing or '
                              'out of date, the request lands here.'
                        : 'Ask Iswim for a procedure that is missing or out of '
                              'date. The finished manual is linked back to the '
                              'request.',
                    steps: const [
                      'City Hall asks for a manual',
                      'Iswim uploads it and links it',
                      'The request closes with the manual attached',
                    ],
                    actionLabel: isIswim ? null : 'Request a manual',
                    actionIcon: Icons.add_rounded,
                    onAction: isIswim ? null : () => _openRequest(context),
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No request matches',
                    message:
                        'Try another title, code or requester, or clear '
                        'the status filter.',
                    actionLabel: 'Clear filters',
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: _clear,
                  ),
            itemCount: visible.length,
            listPadding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
            itemBuilder: (context, i) =>
                _RequestCard(request: visible[i], isIswim: isIswim),
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

  Future<void> _openRequest(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestForm(byName: user.displayName ?? 'City Hall'),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.isIswim});

  final ManualRequest request;
  final bool isIswim;

  Future<void> _createManual(BuildContext context) async {
    final title = Uri.encodeComponent(request.title);
    final query = StringBuffer('/assignment-manuals/new?title=$title');
    query.write('&requestId=${request.id}');
    context.push(query.toString());
  }

  Future<void> _fulfill(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final manuals = await ManualService().watchManuals().first;
    if (!context.mounted) return;
    if (manuals.isEmpty) {
      AppFeedback.error(
        context,
        'Upload a manual first, then link it to this request.',
      );
      return;
    }
    final manual = await showModalBottomSheet<Manual>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickManualSheet(manuals: manuals),
    );
    if (manual == null || !context.mounted) return;
    try {
      await ManualService().fulfillRequest(
        request: request,
        manual: manual,
        byName: user.displayName ?? 'Iswim',
      );
      if (context.mounted) {
        AppFeedback.success(context, 'Request marked as submitted');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Cancel this request?',
      message:
          '"${request.title}" is withdrawn and Iswim no longer sees it in '
          'their queue.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep it',
      destructive: true,
      icon: Icons.close_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await ManualService().cancelRequest(request);
      if (context.mounted) AppFeedback.success(context, 'Request cancelled');
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: request.status.color,
      padding: const EdgeInsets.fromLTRB(17, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(EcoRadius.sm - 2),
                ),
                child: Text(
                  request.code,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitle(context, color: AppColors.darkGreen),
          ),
          if (request.details.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              DeskInitialAvatar(name: request.requestedByName, size: 24),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Requested by ${request.requestedByName} · '
                  '${timeAgo(request.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              if (request.neededBy != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Text(
                    'By ${dateLabel(request.neededBy)}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB26A00),
                    ),
                  ),
                ),
            ],
          ),
          if (request.fulfilledAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Submitted by ${request.fulfilledByName ?? 'Iswim'} · '
                    '${timeAgo(request.fulfilledAt)}',
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
          if (request.ticketId != null ||
              request.manualId != null ||
              (isIswim && request.status == ManualRequestStatus.pending) ||
              (!isIswim && request.status == ManualRequestStatus.pending)) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                if (request.ticketId != null)
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/tickets/${request.ticketId}'),
                        icon: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 14,
                        ),
                        label: const Text(
                          'Open trip ticket',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ),
                  )
                else if (request.manualId != null)
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/manuals/${request.manualId}'),
                        icon: const Icon(Icons.menu_book_outlined, size: 14),
                        label: const Text(
                          'Open manual',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ),
                  ),
                if ((request.ticketId != null || request.manualId != null) &&
                    isIswim &&
                    request.status == ManualRequestStatus.pending)
                  const SizedBox(width: 8),
                if (isIswim && request.status == ManualRequestStatus.pending)
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: () => _createManual(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          textStyle: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Create manual'),
                      ),
                    ),
                  ),
                if (!isIswim && request.status == ManualRequestStatus.pending)
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () => _cancel(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          textStyle: const TextStyle(fontSize: 10.5),
                        ),
                        child: const Text('Cancel request'),
                      ),
                    ),
                  ),
              ],
            ),
            if (isIswim && request.status == ManualRequestStatus.pending) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _fulfill(context),
                  icon: const Icon(Icons.link_rounded, size: 14),
                  label: const Text(
                    'Link an uploaded manual instead',
                    style: TextStyle(fontSize: 9.5),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PickManualSheet extends StatelessWidget {
  const _PickManualSheet({required this.manuals});

  final List<Manual> manuals;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 460),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Link a submitted manual',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'The request closes as soon as a manual is linked.',
            style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: manuals.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final manual = manuals[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(EcoRadius.sm),
                    ),
                    child: Icon(
                      manual.category.icon,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    manual.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'v${manual.version} · ${manual.status.label}',
                    style: const TextStyle(fontSize: 9.5),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.moss,
                  ),
                  onTap: () => Navigator.of(context).pop(manual),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.byName});

  final String byName;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  DateTime? _neededBy;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      await ManualService().requestManual(
        title: _title.text,
        details: _details.text,
        byName: widget.byName,
        byUid: uid,
        neededBy: _neededBy,
      );
      if (!mounted) return;
      AppFeedback.success(context, 'Request sent to Iswim');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppColors.sage,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              gradient: AppColors.forestGradient,
                              borderRadius: BorderRadius.circular(EcoRadius.md),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request a manual from Iswim',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Iswim links the finished manual to this '
                                  'request.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Manual needed',
                          hintText: 'e.g. Segregation guide for barangay crews',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter the manual title'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _details,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText:
                              'Why City Hall needs it, or which sections to '
                              'include',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sage),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Needed by (optional)',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                    Text(
                                      _neededBy == null
                                          ? 'No deadline set'
                                          : dateLabel(_neededBy),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.edit_calendar_outlined,
                                size: 17,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _submit,
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
                            'Send request',
                            style: TextStyle(
                              fontSize: 12.5,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
