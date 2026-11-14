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
import '../models/manual.dart';
import '../services/manual_service.dart';

/// City Hall asks Iswim for a manual; Iswim answers by linking a submitted
/// manual to the request.
class ManualRequestsScreen extends StatelessWidget {
  const ManualRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(isIswim ? '/iswim' : '/cityhall'),
        ),
        title: const Text(
          'Manual requests',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      floatingActionButton: isIswim
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openRequest(context),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Request manual',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
      body: StreamBuilder<List<ManualRequest>>(
        stream: ManualService().watchRequests(),
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
          final requests = snapshot.data ?? const <ManualRequest>[];
          if (requests.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No manual requests',
              message: isIswim
                  ? 'City Hall has not requested a manual yet.'
                  : 'Ask Iswim for a manual that is not in the library.',
              actionLabel: isIswim ? null : 'Request a manual',
              onAction: isIswim ? null : () => _openRequest(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
            children: [
              for (final request in requests) ...[
                _RequestCard(
                  request: request,
                  isIswim: isIswim,
                ),
                const SizedBox(height: 10),
              ],
            ],
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
      builder: (_) => _RequestForm(
        byName: user.displayName ?? 'City Hall',
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.isIswim});

  final ManualRequest request;
  final bool isIswim;

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
    try {
      await ManualService().cancelRequest(request);
      if (context.mounted) AppFeedback.success(context, 'Request cancelled');
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                request.code,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.moss,
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
          const SizedBox(height: 7),
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          if (request.details.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.details,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Requested by ${request.requestedByName} · '
            '${timeAgo(request.createdAt)}'
            '${request.neededBy == null ? '' : ' · needed by ${dateLabel(request.neededBy!)}'}',
            style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
          ),
          if (request.fulfilledAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Submitted by ${request.fulfilledByName ?? 'Iswim'} · '
                    '${timeAgo(request.fulfilledAt)}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (request.manualId != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/manuals/${request.manualId}'),
                    icon: const Icon(Icons.menu_book_outlined, size: 15),
                    label: const Text(
                      'Open manual',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              if (request.manualId != null) const SizedBox(width: 8),
              if (isIswim && request.status == ManualRequestStatus.pending)
                Expanded(
                  child: FilledButton(
                    onPressed: () => _fulfill(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Submit manual'),
                  ),
                ),
              if (!isIswim && request.status == ManualRequestStatus.pending)
                Expanded(
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
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 10),
          for (final manual in manuals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(manual.category.icon, color: AppColors.primary),
              title: Text(
                manual.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'v${manual.version} · ${manual.status.label}',
                style: const TextStyle(fontSize: 9),
              ),
              onTap: () => Navigator.of(context).pop(manual),
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
      await ManualService().requestManual(
        title: _title.text,
        details: _details.text,
        byName: widget.byName,
        neededBy: _neededBy,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Request sent to Iswim');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                'Request a manual from Iswim',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Manual needed'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the manual title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Why City Hall needs it, or which sections to include',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _neededBy == null
                      ? 'Set a needed-by date (optional)'
                      : 'Needed by ${dateLabel(_neededBy!)}',
                  style: const TextStyle(fontSize: 10.5),
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
    );
  }
}
