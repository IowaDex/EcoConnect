import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../manuals/widgets/shift_calendar_card.dart';
import '../../memos/services/memo_service.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../models/desk_document.dart';
import '../services/desk_directory_service.dart';
import '../widgets/desk_document_card.dart';
import '../widgets/desk_filters.dart';
import '../widgets/desk_tools.dart';

/// City Hall — the DSQC and the super admin.
///
/// The page is a document desk: every trip ticket and memo that reaches City
/// Hall is grouped into **For Signature** (what still needs the last
/// signature) and **Received** (what has already arrived). Both sections
/// filter by originating office and search across the real record, and every
/// card opens the underlying document so the existing signing flows stay the
/// only place a signature is written.
class CityHallDashboardScreen extends StatefulWidget {
  const CityHallDashboardScreen({super.key});

  @override
  State<CityHallDashboardScreen> createState() =>
      _CityHallDashboardScreenState();
}

class _CityHallDashboardScreenState extends State<CityHallDashboardScreen> {
  int _tab = 0;

  SignatureFilter _signatureFilter = SignatureFilter.awaiting;
  DeskCategory? _signatureCategory;
  DeskCategory? _receivedCategory;

  final TextEditingController _signatureSearch = TextEditingController();
  final TextEditingController _receivedSearch = TextEditingController();
  String _signatureQuery = '';
  String _receivedQuery = '';

  // Cached so switching tabs or typing in the search box never resubscribes
  // and flashes a loading state.
  late final Stream<List<TripTicket>> _tickets;
  late final Stream<List<Memo>> _memos;
  late final Stream<Map<String, DeskPerson>> _people;

  @override
  void initState() {
    super.initState();
    _tickets = TicketService().watchAll();
    _memos = MemoService().watchForChannel('cityHall');
    _people = DeskDirectoryService().watchPeople();
  }

  @override
  void dispose() {
    _signatureSearch.dispose();
    _receivedSearch.dispose();
    super.dispose();
  }

  void _clearSignatureFilters() {
    _signatureSearch.clear();
    setState(() {
      _signatureQuery = '';
      _signatureCategory = null;
      _signatureFilter = SignatureFilter.awaiting;
    });
  }

  void _clearReceivedFilters() {
    _receivedSearch.clear();
    setState(() {
      _receivedQuery = '';
      _receivedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<AuthProvider>().currentUser?.displayName ?? 'City Hall';

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/memos/new'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoRadius.lg),
        ),
        icon: const Icon(Icons.edit_note_rounded, size: 19),
        label: const Text(
          'New memo',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            RoleTopBar(onLogout: () => confirmAndLogout(context)),
            Expanded(
              child: StreamBuilder<List<TripTicket>>(
                stream: _tickets,
                builder: (context, ticketSnapshot) {
                  return StreamBuilder<List<Memo>>(
                    stream: _memos,
                    builder: (context, memoSnapshot) {
                      return StreamBuilder<Map<String, DeskPerson>>(
                        stream: _people,
                        builder: (context, peopleSnapshot) {
                          final documents = buildCityHallDocuments(
                            tickets:
                                ticketSnapshot.data ?? const <TripTicket>[],
                            memos: memoSnapshot.data ?? const <Memo>[],
                            people:
                                peopleSnapshot.data ??
                                const <String, DeskPerson>{},
                          );

                          final loading =
                              !ticketSnapshot.hasData &&
                              ticketSnapshot.connectionState !=
                                  ConnectionState.done &&
                              !ticketSnapshot.hasError;

                          return _content(
                            userName: userName,
                            documents: documents,
                            loading: loading,
                            error: ticketSnapshot.error ?? memoSnapshot.error,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content({
    required String userName,
    required CityHallDocuments documents,
    required bool loading,
    required Object? error,
  }) {
    // A wide desktop window would stretch a document card across the whole
    // screen. The desk keeps a comfortable reading measure and centres it.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            FadeSlideIn(index: 0, child: _hero(userName, documents)),
            const SizedBox(height: EcoSpace.lg),
            FadeSlideIn(
              index: 1,
              child: DeskTools(pendingSignatures: documents.pendingSignatures),
            ),
            const SizedBox(height: EcoSpace.lg),
            const FadeSlideIn(index: 2, child: ShiftCalendarCard()),
            const SizedBox(height: EcoSpace.lg),
            FadeSlideIn(index: 3, child: _tabs(documents)),
            const SizedBox(height: EcoSpace.md),
            if (error != null) ...[
              EcoBanner(
                message: AppFeedback.describe(error),
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
            ],
            if (loading)
              _deskSkeleton()
            else if (_tab == 0)
              ..._signatureSection(documents)
            else
              ..._receivedSection(documents),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero(String userName, CityHallDocuments documents) {
    final pending = documents.pendingSignatures;
    final signed = documents.forSignature
        .where((document) => document.status == DeskDocumentStatus.signed)
        .length;
    final firstName = userName.trim().split(RegExp(r'\s+')).first;

    return RoleHero(
      icon: Icons.account_balance_rounded,
      eyebrow: 'CITY HALL · DOCUMENT DESK',
      greeting: greeting(),
      title: firstName,
      subtitle:
          'Review, sign and acknowledge everything addressed to the DSQC.',
      chip: pending > 0
          ? RoleChip(
              label: '$pending awaiting',
              icon: Icons.draw_rounded,
              tone: AppColors.warning,
            )
          : const RoleChip(
              label: 'All clear',
              icon: Icons.check_circle_rounded,
            ),
      stats: [
        RoleStat(
          icon: Icons.draw_rounded,
          label: 'Awaiting',
          value: pending,
          accent: AppColors.warning,
        ),
        RoleStat(
          icon: Icons.inbox_rounded,
          label: 'Received',
          value: documents.received.length,
          accent: Colors.white,
        ),
        RoleStat(icon: Icons.verified_rounded, label: 'Signed', value: signed),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _tabs(CityHallDocuments documents) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              // The pill slides between the two halves, so switching tabs
              // reads as one surface moving rather than two colours swapping.
              AnimatedPositioned(
                duration: EcoMotion.base,
                curve: EcoMotion.enter,
                left: _tab * segment,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.forestGradient,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _tabSegment(
                      0,
                      'For signature',
                      documents.pendingSignatures,
                      Icons.draw_outlined,
                    ),
                  ),
                  Expanded(
                    child: _tabSegment(
                      1,
                      'Received',
                      documents.received.length,
                      Icons.inbox_outlined,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabSegment(int index, String label, int count, IconData icon) {
    final selected = _tab == index;
    final foreground = selected ? Colors.white : AppColors.inkMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = index),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: EcoMotion.fast,
                curve: EcoMotion.enter,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: EcoMotion.fast,
              curve: EcoMotion.enter,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.24)
                    : AppColors.cream,
                borderRadius: BorderRadius.circular(EcoRadius.pill),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // For signature
  // ---------------------------------------------------------------------------

  List<Widget> _signatureSection(CityHallDocuments documents) {
    final all = documents.forSignature;
    final searched = all
        .where((document) => document.matchesSearch(_signatureQuery))
        .toList(growable: false);

    // Facet counts: the status row counts within the selected category, the
    // category row counts within the selected status. Both respect search, so
    // the numbers always describe what is actually on screen.
    final statusCounts = <SignatureFilter, int>{
      for (final filter in SignatureFilter.values)
        filter: searched
            .where(
              (document) =>
                  document.matchesCategory(_signatureCategory) &&
                  document.matchesSignatureFilter(filter),
            )
            .length,
    };
    final categoryCounts = <DeskCategory?, int>{
      null: searched
          .where(
            (document) => document.matchesSignatureFilter(_signatureFilter),
          )
          .length,
      for (final category in DeskCategory.values)
        category: searched
            .where(
              (document) =>
                  document.matchesSignatureFilter(_signatureFilter) &&
                  document.matchesCategory(category),
            )
            .length,
    };

    final visible = searched
        .where(
          (document) =>
              document.matchesCategory(_signatureCategory) &&
              document.matchesSignatureFilter(_signatureFilter),
        )
        .toList(growable: false);

    final filtered =
        _signatureCategory != null ||
        _signatureQuery.trim().isNotEmpty ||
        _signatureFilter != SignatureFilter.awaiting;

    return [
      _sectionIntro(
        icon: _signatureFilter.status.icon,
        title: _signatureFilter.label,
        subtitle: switch (_signatureFilter) {
          SignatureFilter.awaiting =>
            'Documents waiting for the City Hall signature.',
          SignatureFilter.signed => 'Documents already signed at this desk.',
          SignatureFilter.rejected => 'Documents rejected at this desk.',
          SignatureFilter.returned =>
            'Documents sent back for revision by this desk.',
        },
        count: visible.length,
      ),
      const SizedBox(height: EcoSpace.sm),
      DeskSignatureBar(
        selected: _signatureFilter,
        counts: statusCounts,
        onChanged: (filter) => setState(() => _signatureFilter = filter),
      ),
      const SizedBox(height: EcoSpace.sm),
      _filterCard(
        search: EcoSearchField(
          controller: _signatureSearch,
          hint: 'Search document, driver name, or reference number...',
          onChanged: (value) => setState(() => _signatureQuery = value),
        ),
        categories: DeskCategoryBar(
          selected: _signatureCategory,
          counts: categoryCounts,
          onChanged: (category) =>
              setState(() => _signatureCategory = category),
        ),
      ),
      // The count describes what is actually listed. When the active status
      // has nothing in it the empty state explains why, so the line is hidden
      // rather than claiming "2 documents" above an empty list.
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        const SizedBox(height: EcoSpace.sm),
        _resultLine(
          'document',
          visible.length,
          all.length,
          filtered: visible.length != all.length,
        ),
      ],
      const SizedBox(height: EcoSpace.sm),
      if (visible.isEmpty)
        _signatureEmpty(hasAny: all.isNotEmpty, filtered: filtered)
      else
        ..._documentList(visible),
    ];
  }

  Widget _signatureEmpty({required bool hasAny, required bool filtered}) {
    if (filtered && hasAny) {
      return EmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: 'No documents match your filters',
        message: 'Try another category or status, or clear the search term.',
        actionLabel: 'Clear filters',
        onAction: _clearSignatureFilters,
      );
    }
    return EmptyState(
      compact: true,
      icon: Icons.draw_outlined,
      title: switch (_signatureFilter) {
        SignatureFilter.awaiting => 'Nothing is waiting for your signature',
        SignatureFilter.signed => 'No signed documents yet',
        SignatureFilter.rejected => 'No rejected documents',
        SignatureFilter.returned => 'No documents were returned',
      },
      message: switch (_signatureFilter) {
        SignatureFilter.awaiting =>
          'Trip tickets arrive here once the barangay and ISWIM have signed '
              'them. Memos appear as soon as they are addressed to City Hall.',
        SignatureFilter.signed =>
          'Every document you sign stays here for reference.',
        SignatureFilter.rejected =>
          'Documents rejected at this desk stay on record with the reason.',
        SignatureFilter.returned =>
          'Documents sent back to the barangay or ISWIM are listed here.',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Received
  // ---------------------------------------------------------------------------

  List<Widget> _receivedSection(CityHallDocuments documents) {
    final all = documents.received;
    final searched = all
        .where((document) => document.matchesSearch(_receivedQuery))
        .toList(growable: false);

    final categoryCounts = <DeskCategory?, int>{
      null: searched.length,
      for (final category in DeskCategory.values)
        category: searched
            .where((document) => document.matchesCategory(category))
            .length,
    };

    final visible = searched
        .where((document) => document.matchesCategory(_receivedCategory))
        .toList(growable: false);

    final filtered =
        _receivedCategory != null || _receivedQuery.trim().isNotEmpty;

    return [
      _sectionIntro(
        icon: Icons.inbox_outlined,
        title: 'Received',
        subtitle:
            'Everything delivered to City Hall from the barangay, ISWIM and the fleet.',
        count: visible.length,
      ),
      const SizedBox(height: EcoSpace.sm),
      _filterCard(
        search: EcoSearchField(
          controller: _receivedSearch,
          hint: 'Search received documents...',
          onChanged: (value) => setState(() => _receivedQuery = value),
        ),
        categories: DeskCategoryBar(
          selected: _receivedCategory,
          counts: categoryCounts,
          onChanged: (category) => setState(() => _receivedCategory = category),
        ),
      ),
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        const SizedBox(height: EcoSpace.sm),
        _resultLine(
          'document',
          visible.length,
          all.length,
          filtered: visible.length != all.length,
        ),
      ],
      const SizedBox(height: EcoSpace.sm),
      if (visible.isEmpty)
        EmptyState(
          compact: true,
          icon: filtered ? Icons.search_off_rounded : Icons.inbox_outlined,
          title: filtered
              ? 'No documents match your search'
              : 'No documents received yet',
          message: filtered
              ? 'Try another category or a different search term.'
              : 'Completed trip tickets and memos addressed to City Hall are '
                    'listed here as soon as they arrive.',
          actionLabel: filtered ? 'Clear filters' : null,
          onAction: filtered ? _clearReceivedFilters : null,
        )
      else
        ..._documentList(visible),
    ];
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  /// Groups the visible documents by the day they reached this section and
  /// separates the groups with a dated rule, so a long queue reads as a
  /// chronology instead of one undifferentiated stack.
  List<Widget> _documentList(List<DeskDocument> visible) {
    final children = <Widget>[];
    String? lastKey;

    for (var i = 0; i < visible.length; i++) {
      final document = visible[i];
      final key = document.date == null ? 'undated' : dayKey(document.date!);

      if (key != lastKey) {
        lastKey = key;
        if (i > 0) children.add(const SizedBox(height: EcoSpace.sm));
        children.add(_dayHeader(document.date));
        children.add(const SizedBox(height: EcoSpace.xs));
      }

      children.add(
        DeskDocumentCard(
          document: document,
          index: i > 6 ? 6 : i,
          onOpen: () => context.push(document.openRoute),
          onSign: document.canSign
              ? () => context.push(_signRoute(document))
              : null,
        ),
      );
      children.add(const SizedBox(height: 9));
    }

    return children;
  }

  Widget _dayHeader(DateTime? date) {
    return Row(
      children: [
        Text(
          _dayLabel(date),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.sage.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  static String _dayLabel(DateTime? date) {
    if (date == null) return 'UNDATED';
    final relative = relativeDay(date);
    if (relative == 'Today' || relative == 'Yesterday') {
      return relative.toUpperCase();
    }
    return dateLabel(date).toUpperCase();
  }

  Widget _sectionIntro({
    required IconData icon,
    required String title,
    required String subtitle,
    int? count,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
          ),
          child: Icon(icon, size: 17, color: AppColors.forest),
        ),
        const SizedBox(width: EcoSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(EcoRadius.pill),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Search and office filters live on one surface: they belong together and
  /// always apply to the same list.
  Widget _filterCard({required Widget search, required Widget categories}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          search,
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.sage.withValues(alpha: 0.55)),
          const SizedBox(height: 9),
          categories,
        ],
      ),
    );
  }

  Widget _resultLine(
    String noun,
    int visible,
    int total, {
    required bool filtered,
  }) {
    final label = filtered
        ? 'Showing $visible of ${_countLabel(total, noun)}'
        : _countLabel(total, noun);
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: AppColors.inkMuted,
          ),
        ),
        const Spacer(),
        if (filtered)
          GestureDetector(
            onTap: _tab == 0 ? _clearSignatureFilters : _clearReceivedFilters,
            child: const Text(
              'Clear filters',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _deskSkeleton() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 64, height: 16, radius: 8),
                    SizedBox(width: 8),
                    SkeletonBox(width: 48, height: 16, radius: 8),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(width: double.infinity, height: 13),
                SizedBox(height: 9),
                SkeletonBox(width: 150, height: 10, radius: 5),
                SizedBox(height: 14),
                SkeletonBox(width: double.infinity, height: 34, radius: 9),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _countLabel(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';

  static String _signRoute(DeskDocument document) =>
      '${document.openRoute}?sign=1';
}
