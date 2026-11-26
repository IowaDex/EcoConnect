import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/assignment_manual.dart';
import '../models/manual.dart';
import '../services/assignment_manual_service.dart';
import '../services/manual_pdf.dart';
import '../services/manual_service.dart';
import '../widgets/manual_preview_sheet.dart';

/// Manual library. Iswim publishes revisions here; City Hall reads and
/// acknowledges them. No other role has access.
///
/// Two different things used to share one scrolling page: the PDFs Iswim
/// uploads, and the per-driver collection manuals those uploads describe. They
/// are now one list at a time behind a switch, so the search box and the
/// status filter always apply to what is on screen.
class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

/// Which of the two libraries is open.
enum _ManualTab { library, collection }

/// The states a collection manual can be in on this desk.
enum _CollectionFilter { all, waiting, approved, rejected }

extension on _CollectionFilter {
  String get label => switch (this) {
    _CollectionFilter.all => 'All',
    _CollectionFilter.waiting => 'Waiting',
    _CollectionFilter.approved => 'Approved',
    _CollectionFilter.rejected => 'Rejected',
  };

  bool matches(AssignmentManual manual) => switch (this) {
    _CollectionFilter.all => true,
    _CollectionFilter.waiting => manual.awaitsApproval,
    _CollectionFilter.approved => manual.isApproved,
    _CollectionFilter.rejected => manual.isRejected,
  };
}

class _ManualsScreenState extends State<ManualsScreen> {
  final _search = TextEditingController();

  _ManualTab _tab = _ManualTab.library;
  String _query = '';
  ManualStatus? _statusFilter;
  _CollectionFilter _collectionFilter = _CollectionFilter.all;

  int _page = 0;
  int _pageSize = 10;

  late final Stream<List<Manual>> _manuals;
  late final Stream<List<AssignmentManual>> _collection;

  @override
  void initState() {
    super.initState();
    // Subscribed once and shared: the switch and the list must not open two
    // Firestore listeners over the same query.
    _manuals = ManualService().watchManuals();
    _collection = AssignmentManualService().watchAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _statusFilter = null;
      _collectionFilter = _CollectionFilter.all;
      _page = 0;
    });
  }

  void _switchTab(_ManualTab tab) {
    if (tab == _tab) return;
    _search.clear();
    setState(() {
      _tab = tab;
      _query = '';
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;

    return EcoPageScaffold(
      eyebrow: isIswim ? 'ISWIM · MANUALS' : 'CITY HALL · MANUALS',
      title: isIswim ? 'Manuals' : 'Manual library',
      icon: Icons.menu_book_outlined,
      subtitle: 'The procedures both desks follow, versioned and signed off.',
      onBack: () => ecoBack(context, isIswim ? '/iswim' : '/cityhall'),
      actions: [
        if (isIswim)
          _HeaderAction(
            label: 'New manual',
            icon: Icons.upload_file_rounded,
            onTap: () => _openCreate(context),
          ),
        EcoIconAction(
          icon: Icons.inbox_outlined,
          tooltip: 'Manual requests',
          onTap: () => context.push('/manual-requests'),
        ),
      ],
      body: StreamBuilder<List<Manual>>(
        stream: _manuals,
        builder: (context, librarySnapshot) {
          return StreamBuilder<List<AssignmentManual>>(
            stream: _collection,
            builder: (context, collectionSnapshot) {
              final manuals = librarySnapshot.data ?? const <Manual>[];
              final collection =
                  collectionSnapshot.data ?? const <AssignmentManual>[];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: DeskSegmented<_ManualTab>(
                      value: _tab,
                      onChanged: _switchTab,
                      segments: [
                        DeskSegment(
                          value: _ManualTab.library,
                          label: 'Uploaded PDFs',
                          icon: Icons.picture_as_pdf_outlined,
                          count: manuals.length,
                        ),
                        DeskSegment(
                          value: _ManualTab.collection,
                          label: 'Collection',
                          icon: Icons.assignment_ind_outlined,
                          count: collection.length,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tab == _ManualTab.library
                        ? _library(context, isIswim, manuals, librarySnapshot)
                        : _collectionList(
                            context,
                            collection,
                            collectionSnapshot,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Uploaded PDFs
  // ---------------------------------------------------------------------------

  Widget _library(
    BuildContext context,
    bool isIswim,
    List<Manual> all,
    AsyncSnapshot<List<Manual>> snapshot,
  ) {
    if (snapshot.hasError) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load manuals',
        message: AppFeedback.describe(snapshot.error!),
      );
    }
    if (!snapshot.hasData) {
      return const EcoLoadingView(label: 'Loading manuals');
    }

    final searched = all
        .where((manual) => _matchesQuery(manual, _query))
        .toList(growable: false);
    final items = searched
        .where(
          (manual) => _statusFilter == null || manual.status == _statusFilter,
        )
        .toList(growable: false);
    final page = clampPage(_page, items.length, _pageSize);
    final visible = pageSlice(items, page, _pageSize);
    final filtered = _query.trim().isNotEmpty || _statusFilter != null;

    return DeskQueueView(
      search: EcoSearchField(
        controller: _search,
        hint: 'Search title, category or version',
        onChanged: (value) => setState(() {
          _query = value;
          _page = 0;
        }),
      ),
      filters: DeskSegmented<ManualStatus?>(
        value: _statusFilter,
        onChanged: (value) => setState(() {
          _statusFilter = value;
          _page = 0;
        }),
        segments: [
          DeskSegment(value: null, label: 'All', count: searched.length),
          for (final status in ManualStatus.values)
            DeskSegment(
              value: status,
              label: status.shortLabel,
              count: searched.where((m) => m.status == status).length,
            ),
        ],
      ),
      resultLine: DeskResultLine(
        label: items.length == all.length
            ? _count(all.length, 'manual')
            : 'Showing ${items.length} of ${_count(all.length, 'manual')}',
        onClear: filtered ? _clear : null,
      ),
      empty: all.isEmpty
          ? DeskEmptyQueue(
              icon: Icons.menu_book_outlined,
              title: 'No uploaded manuals yet',
              message: isIswim
                  ? 'Upload the first manual. It is sent straight to City '
                        'Hall for acknowledgement.'
                  : 'Iswim has not submitted a manual yet. Ask for one and '
                        'the finished file is linked back to the request.',
              steps: const [
                'Iswim uploads the PDF',
                'City Hall reads and acknowledges it',
                'The manual stays on record, versioned',
              ],
              actionLabel: isIswim ? 'Upload a manual' : 'Request a manual',
              actionIcon: isIswim
                  ? Icons.upload_file_rounded
                  : Icons.add_rounded,
              onAction: () => isIswim
                  ? _openCreate(context)
                  : context.push('/manual-requests'),
            )
          : DeskEmptyQueue(
              icon: Icons.search_off_rounded,
              title: 'No manual matches',
              message:
                  'Try another title, category or version, or clear the '
                  'status filter.',
              actionLabel: 'Clear filters',
              actionIcon: Icons.filter_alt_off_outlined,
              onAction: _clear,
            ),
      itemCount: visible.length,
      itemBuilder: (context, i) => _ManualCard(manual: visible[i]),
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
  }

  static bool _matchesQuery(Manual manual, String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return true;
    return manual.title.toLowerCase().contains(query) ||
        manual.summary.toLowerCase().contains(query) ||
        manual.category.label.toLowerCase().contains(query) ||
        'v${manual.version}'.contains(query);
  }

  // ---------------------------------------------------------------------------
  // Collection manuals
  // ---------------------------------------------------------------------------

  Widget _collectionList(
    BuildContext context,
    List<AssignmentManual> all,
    AsyncSnapshot<List<AssignmentManual>> snapshot,
  ) {
    if (snapshot.hasError) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load collection manuals',
        message: AppFeedback.describe(snapshot.error!),
      );
    }
    if (!snapshot.hasData) {
      return const EcoLoadingView(label: 'Loading collection manuals');
    }

    // Only Iswim rewrites a manual City Hall sent back; the desk that approved
    // it opens the same card read-only.
    final canEdit =
        context.read<AuthProvider>().currentUser?.role == UserRole.iswim;

    // Pending first: that is the row the desk has to act on. Within each group
    // the newest change leads.
    final ordered = [...all]
      ..sort((a, b) {
        if (a.isApproved != b.isApproved) return a.isApproved ? 1 : -1;
        final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return right.compareTo(left);
      });

    final searched = ordered
        .where((manual) => _matchesCollectionQuery(manual, _query))
        .toList(growable: false);
    final items = searched
        .where(_collectionFilter.matches)
        .toList(growable: false);
    final page = clampPage(_page, items.length, _pageSize);
    final visible = pageSlice(items, page, _pageSize);
    final filtered =
        _query.trim().isNotEmpty || _collectionFilter != _CollectionFilter.all;

    return DeskQueueView(
      search: EcoSearchField(
        controller: _search,
        hint: 'Search manual, driver or plate',
        onChanged: (value) => setState(() {
          _query = value;
          _page = 0;
        }),
      ),
      filters: DeskSegmented<_CollectionFilter>(
        value: _collectionFilter,
        onChanged: (value) => setState(() {
          _collectionFilter = value;
          _page = 0;
        }),
        segments: [
          for (final filter in _CollectionFilter.values)
            DeskSegment(
              value: filter,
              label: filter.label,
              count: searched.where(filter.matches).length,
            ),
        ],
      ),
      resultLine: DeskResultLine(
        label: items.length == all.length
            ? _count(all.length, 'manual')
            : 'Showing ${items.length} of ${_count(all.length, 'manual')}',
        onClear: filtered ? _clear : null,
      ),
      empty: all.isEmpty
          ? const DeskEmptyQueue(
              icon: Icons.assignment_ind_outlined,
              title: 'No collection manual yet',
              message:
                  'A collection manual is the schedule Iswim builds for a '
                  'driver. Create one and it is listed here straight away.',
              steps: [
                'Iswim builds the schedule',
                'City Hall approves it',
                'The crew runs the routes on the ticket',
              ],
            )
          : DeskEmptyQueue(
              icon: Icons.search_off_rounded,
              title: 'No manual matches',
              message:
                  'Try another driver, plate or manual name, or clear the '
                  'filter.',
              actionLabel: 'Clear filters',
              actionIcon: Icons.filter_alt_off_outlined,
              onAction: _clear,
            ),
      itemCount: visible.length,
      itemBuilder: (context, i) =>
          _CollectionManualCard(manual: visible[i], canEdit: canEdit),
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
  }

  static bool _matchesCollectionQuery(AssignmentManual manual, String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return true;
    return manual.title.toLowerCase().contains(query) ||
        manual.driverName.toLowerCase().contains(query) ||
        manual.plateNumber.toLowerCase().contains(query) ||
        manual.allRoutes.join(' ').toLowerCase().contains(query);
  }

  static String _count(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';

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

/// The filled create action in the page header.
///
/// A header pill rather than a floating button: the FAB sat on top of the
/// pagination bar and forced the list to reserve 88px of empty space at the
/// bottom.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// One uploaded revision of a manual.
class _ManualCard extends StatelessWidget {
  const _ManualCard({required this.manual});

  final Manual manual;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: manual.status.color,
      onTap: () => context.push('/manuals/${manual.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  manual.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitleLarge(
                    context,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.xs + 1),
          Row(
            children: [
              StatusBadge(
                label: manual.status.label,
                color: manual.status.color,
                compact: true,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${manual.category.label} · v${manual.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              Text(
                timeAgo(manual.updatedAt ?? manual.createdAt),
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          if (manual.summary.trim().isNotEmpty) ...[
            const SizedBox(height: EcoSpace.xs),
            Text(
              manual.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// One collection manual: the schedule a crew runs, not the PDF above it.
class _CollectionManualCard extends StatelessWidget {
  const _CollectionManualCard({required this.manual, this.canEdit = false});

  final AssignmentManual manual;

  /// Only Iswim rewrites a manual City Hall sent back.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final rejected = manual.isRejected;
    final pending = manual.awaitsApproval;
    final railColor = rejected
        ? AppColors.error
        : pending
        ? AppColors.warning
        : AppColors.primary;
    final ticketId = manual.ticketId;
    final reason = (manual.rejectionReason ?? '').trim();

    return DeskRailCard(
      railColor: railColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      onTap: rejected
          ? () => _preview(context)
          : ticketId == null || ticketId.isEmpty
          ? null
          : () => context.push('/tickets/$ticketId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                ),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  size: 16,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  manual.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitleLarge(
                    context,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              StatusBadge(
                label: manual.status.label,
                color: railColor,
                compact: true,
              ),
            ],
          ),
          if (rejected && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Reason: $reason',
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: EcoSpace.xs + 1),
          // Every driver on the roster, not just the first one.
          for (final row in manual.allAssignments)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 13,
                    color: AppColors.moss,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row.driverName} · ${row.plateNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EcoType.bodyStrong(
                            context,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        Text(
                          row.routesLabel.isEmpty ? '—' : row.routesLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: EcoType.bodySmall(
                            context,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Valid until ${dateLabel(manual.validUntil)}',
            style: EcoType.meta(
              context,
              color: AppColors.moss,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${manual.scheduleLabel} · '
                  '${timeAgo(manual.updatedAt ?? manual.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: TextButton.icon(
                  onPressed: () => _preview(context),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                child: TextButton.icon(
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  label: const Text(
                    'PDF',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          if (rejected && canEdit) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/assignment-manuals/new?editId=${manual.id}',
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  'Edit & resubmit',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _preview(BuildContext context) {
    return ManualPreviewSheet.show(
      context,
      title: manual.title,
      assignments: manual.allAssignments,
      statusLabel: manual.status.label,
      statusColor: manual.isRejected
          ? AppColors.error
          : manual.isApproved
          ? AppColors.primary
          : AppColors.warning,
      reason: manual.rejectionReason,
      note: manual.isRejected
          ? 'Edit the roster below and submit it again for approval.'
          : null,
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
