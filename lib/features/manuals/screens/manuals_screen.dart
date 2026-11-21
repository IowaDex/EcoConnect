import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/assignment_manual.dart';
import '../models/manual.dart';
import '../services/assignment_manual_service.dart';
import '../services/manual_pdf.dart';
import '../services/manual_service.dart';

/// Manual library. Iswim publishes revisions here; City Hall reads and
/// acknowledges them. No other role has access.
class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  final _search = TextEditingController();
  String _query = '';
  ManualStatus? _statusFilter;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Manual> _filter(List<Manual> manuals) {
    final q = _query.trim().toLowerCase();
    return manuals.where((manual) {
      if (_statusFilter != null && manual.status != _statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return manual.title.toLowerCase().contains(q) ||
          manual.summary.toLowerCase().contains(q) ||
          manual.category.label.toLowerCase().contains(q) ||
          'v${manual.version}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;

    return EcoPageScaffold(
      eyebrow: isIswim ? 'ISWIM · MANUALS' : 'CITY HALL · MANUALS',
      title: isIswim ? 'Manuals' : 'Manual library',
      subtitle: 'The procedures both desks follow, versioned and signed off.',
      onBack: () => ecoBack(context, isIswim ? '/iswim' : '/cityhall'),
      actions: [
        EcoIconAction(
          icon: Icons.inbox_outlined,
          tooltip: 'Manual requests',
          onTap: () => context.push('/manual-requests'),
        ),
      ],
      fab: isIswim
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text(
                'New manual',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: StreamBuilder<List<Manual>>(
        stream: ManualService().watchManuals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load manuals',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final manuals = snapshot.data ?? const <Manual>[];
          final filtered = _filter(manuals);
          final page = clampPage(_page, filtered.length, _pageSize);
          final visible = pageSlice(filtered, page, _pageSize);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, isIswim ? 88 : 20),
                  children: [
                    // Every manual lives here, signed or not, on both desks.
                    const _CollectionManualsSection(),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Uploaded library',
                      subtitle: isIswim
                          ? 'The PDFs Iswim sends to City Hall for '
                                'acknowledgement.'
                          : 'The PDFs Iswim has submitted for review.',
                    ),
                    const SizedBox(height: 8),
                    EcoSearchField(
                      controller: _search,
                      hint: 'Search title, category, version',
                      onChanged: (value) => setState(() {
                        _query = value;
                        _page = 0;
                      }),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final option in <ManualStatus?>[
                            null,
                            ...ManualStatus.values,
                          ]) ...[
                            ChoiceChip(
                              label: Text(
                                option?.label ?? 'All',
                                style: const TextStyle(fontSize: 10),
                              ),
                              selected: _statusFilter == option,
                              onSelected: (_) => setState(() {
                                _statusFilter = option;
                                _page = 0;
                              }),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (manuals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: EmptyState(
                          compact: true,
                          icon: Icons.menu_book_outlined,
                          title: 'No uploaded manuals yet',
                          message: isIswim
                              ? 'Upload the first manual. It is sent straight '
                                    'to City Hall.'
                              : 'Iswim has not submitted a manual yet. You can '
                                    'request one.',
                          actionLabel: isIswim
                              ? 'Upload a manual'
                              : 'Request a manual',
                          onAction: () => isIswim
                              ? _openCreate(context)
                              : context.push('/manual-requests'),
                        ),
                      )
                    else if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'No manuals match your filters.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      )
                    else
                      for (final manual in visible) ...[
                        _ManualCard(manual: manual),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
              if (filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: filtered.length,
                    onPageChanged: (next) => setState(() => _page = next),
                    onPageSizeChanged: (size) => setState(() {
                      _pageSize = size;
                      _page = 0;
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ManualForm(byId: user.uid, byName: user.displayName ?? 'Iswim'),
    );
  }
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({required this.manual});

  final Manual manual;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: () => context.push('/manuals/${manual.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  manual.category.icon,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manual.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${manual.category.label} · v${manual.version}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.moss,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusBadge(
                label: manual.status.label,
                color: manual.status.color,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(manual.updatedAt ?? manual.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          if (manual.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              manual.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every collection manual Iswim has built, waiting for City Hall or signed.
///
/// This is the roster itself, not the uploaded PDFs below it: the manual is
/// what generated the trip ticket, so it stays listed whether the approval has
/// landed or not.
class _CollectionManualsSection extends StatelessWidget {
  const _CollectionManualsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AssignmentManual>>(
      stream: AssignmentManualService().watchAll(),
      builder: (context, snapshot) {
        // Pending first: that is the row the desk has to act on. Within each
        // group the newest change leads.
        final items = [...(snapshot.data ?? const <AssignmentManual>[])]
          ..sort((a, b) {
            if (a.isApproved != b.isApproved) return a.isApproved ? 1 : -1;
            final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
            final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
            return right.compareTo(left);
          });
        final pending = items.where((manual) => !manual.isApproved).length;
        final subtitle = items.isEmpty
            ? 'The schedules Iswim builds for City Hall approval.'
            : pending == 0
            ? '${items.length} manual${items.length == 1 ? '' : 's'} · all '
                  'approved'
            : '${items.length} total · $pending waiting for City Hall';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Collection manuals',
              subtitle: subtitle,
              actionLabel: 'Schedules',
              onAction: () => context.push('/assignments'),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting &&
                items.isEmpty)
              const LinearProgressIndicator(minHeight: 2)
            else if (items.isEmpty)
              const Text(
                'No collection manual yet. Create one from a City Hall '
                'request and it is listed here straight away.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                _CollectionManualCard(manual: items[i]),
                if (i < items.length - 1) const SizedBox(height: 9),
              ],
          ],
        );
      },
    );
  }
}

class _CollectionManualCard extends StatelessWidget {
  const _CollectionManualCard({required this.manual});

  final AssignmentManual manual;

  @override
  Widget build(BuildContext context) {
    final pending = !manual.isApproved;
    final ticketId = manual.ticketId;

    return EcoCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 12),
      onTap: ticketId == null || ticketId.isEmpty
          ? null
          : () => context.push('/tickets/$ticketId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  size: 17,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manual.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${manual.driverName} · ${manual.plateNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              StatusBadge(
                label: manual.status.label,
                color: pending ? AppColors.warning : AppColors.primary,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  manual.routesLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _export(context),
                tooltip: 'Export PDF',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 16,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${manual.scheduleLabel} · ${timeAgo(manual.updatedAt ?? manual.createdAt)}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final saved = await exportManualPdfFromRecord(manual);
    if (!context.mounted) return;
    if (saved) {
      AppFeedback.success(context, 'Manual PDF generated');
    } else {
      AppFeedback.error(
        context,
        'PDF download is only available in the browser build.',
      );
    }
  }
}

/// Create the first version of a manual.
class _ManualForm extends StatefulWidget {
  const _ManualForm({required this.byId, required this.byName});

  final String byId;
  final String byName;

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _notes = TextEditingController();

  ManualCategory _category = ManualCategory.collection;
  UploadPayload? _file;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final file = _file;
    if (file == null) {
      AppFeedback.error(context, 'Attach the manual file first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ManualService().createManual(
        title: _title.text,
        category: _category,
        summary: _summary.text,
        notes: _notes.text,
        file: file,
        byId: widget.byId,
        byName: widget.byName,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Manual sent to City Hall');
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
                'New manual',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is sent directly to City Hall. District officers and the '
                'barangay are not part of this workflow.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Manual title'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ManualCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in ManualCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summary,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                  hintText: 'What this manual covers',
                ),
                validator: (value) => (value ?? '').trim().length < 10
                    ? 'Add a short description'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Version notes',
                  hintText: 'What changed in this revision',
                ),
              ),
              const SizedBox(height: 14),
              ImagePickerField(
                value: _file,
                onChanged: (value) => setState(() => _file = value),
                label: 'Manual file',
                helper: 'JPG, PNG or PDF · compressed automatically',
                documentMode: true,
                previewHeight: 130,
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
                    'Send to City Hall',
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
