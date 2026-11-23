import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
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
/// The page is a document desk. It opens with who you are and the one thing
/// the desk exists to do: sign the next document. The queue follows straight
/// away, because that is the work. The twelve shortcuts and the shift roster
/// are reference, so they sit around the queue rather than on top of it.
///
/// Every figure on the page has one home: the totals live in the hero, the
/// list sizes live in the segmented control, and the facet counts live on the
/// filters that produce them. Nothing repeats a number the officer has just
/// read.
class CityHallDashboardScreen extends StatefulWidget {
  const CityHallDashboardScreen({super.key});

  @override
  State<CityHallDashboardScreen> createState() =>
      _CityHallDashboardScreenState();
}

/// The two lists the desk works through.
enum _DeskTab { signature, received }

class _CityHallDashboardScreenState extends State<CityHallDashboardScreen> {
  _DeskTab _tab = _DeskTab.signature;

  SignatureFilter _signatureFilter = SignatureFilter.awaiting;
  DeskCategory? _signatureCategory;
  DeskCategory? _receivedCategory;

  final TextEditingController _signatureSearch = TextEditingController();
  final TextEditingController _receivedSearch = TextEditingController();
  String _signatureQuery = '';
  String _receivedQuery = '';

  // Both lists page in place. The Received list grows for the life of the
  // deployment, so it must never render as one endless column.
  int _signaturePage = 0;
  int _receivedPage = 0;
  int _pageSize = 10;

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
      _signaturePage = 0;
    });
  }

  void _clearReceivedFilters() {
    _receivedSearch.clear();
    setState(() {
      _receivedQuery = '';
      _receivedCategory = null;
      _receivedPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<AuthProvider>().currentUser?.displayName ?? 'City Hall';

    return Scaffold(
      backgroundColor: AppColors.creamBright,
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            FadeSlideIn(index: 0, child: _hero(userName, documents)),
            const SizedBox(height: EcoSpace.lg),
            FadeSlideIn(
              index: 1,
              child: DeskTools(pendingSignatures: documents.pendingSignatures),
            ),
            const SizedBox(height: EcoSpace.xl),
            FadeSlideIn(
              index: 2,
              child: _queue(documents, loading: loading, error: error),
            ),
            const SizedBox(height: EcoSpace.xl),
            // The roster is reference, not work: it sits under the queue and
            // opens collapsed so it never pushes the queue off the first
            // screen.
            const FadeSlideIn(
              index: 3,
              child: ShiftCalendarCard(collapsible: true),
            ),
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
    final next = _nextToSign(documents);

    return RoleHero(
      icon: Icons.account_balance_rounded,
      eyebrow: 'CITY HALL · DOCUMENT DESK',
      greeting: greeting(),
      title: firstName,
      subtitle: pending > 0
          ? 'Everything addressed to the DSQC is in one queue below. '
                'Start with the next one — it is already open for your signature.'
          : 'Nothing is waiting for you. The queue below keeps every document '
                'you have signed or received.',
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
      actions: [
        if (next != null)
          _HeroPrimary(
            label: next.kind == DeskDocumentKind.tripTicket
                ? 'Sign next document'
                : 'Acknowledge next',
            icon: Icons.draw_rounded,
            onTap: () => context.push(_signRoute(next)),
          )
        else
          const _HeroPrimary(
            label: 'Nothing to sign',
            icon: Icons.check_circle_rounded,
          ),
        _HeroGhost(
          label: 'New memo',
          icon: Icons.edit_note_rounded,
          onTap: () => context.push('/memos/new'),
        ),
      ],
    );
  }

  /// The document the officer should open first: the oldest one that is
  /// genuinely waiting for this desk, falling back to the head of the list.
  static DeskDocument? _nextToSign(CityHallDocuments documents) {
    final signable = documents.forSignature
        .where((document) => document.canSign)
        .toList(growable: false);
    if (signable.isNotEmpty) return signable.first;
    return documents.forSignature.isEmpty ? null : documents.forSignature.first;
  }

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  Widget _queue(
    CityHallDocuments documents, {
    required bool loading,
    required Object? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskSegmented<_DeskTab>(
          segments: [
            DeskSegment(
              value: _DeskTab.signature,
              label: 'For signature',
              icon: Icons.draw_outlined,
              count: documents.pendingSignatures,
            ),
            DeskSegment(
              value: _DeskTab.received,
              label: 'Received',
              icon: Icons.inbox_outlined,
              count: documents.received.length,
            ),
          ],
          value: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
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
        else if (_tab == _DeskTab.signature)
          ..._signatureSection(documents)
        else
          ..._receivedSection(documents),
      ],
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

    // The category row counts within the active status, so its numbers always
    // describe the list that is on screen.
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

    // A busy desk can hold hundreds of signed documents; the list pages in
    // place instead of scrolling forever.
    final page = clampPage(_signaturePage, visible.length, _pageSize);
    final pageItems = pageSlice(visible, page, _pageSize);
    final paged = visible.length > _pageSize;

    return [
      DeskFilterPanel(
        padding: EdgeInsets.zero,
        search: EcoSearchField(
          controller: _signatureSearch,
          hint: 'Search document, driver name, or reference number…',
          onChanged: (value) => setState(() {
            _signatureQuery = value;
            _signaturePage = 0;
          }),
        ),
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeskSegmented<SignatureFilter>(
              segments: [
                for (final filter in SignatureFilter.values)
                  DeskSegment(value: filter, label: filter.shortLabel),
              ],
              value: _signatureFilter,
              onChanged: (filter) => setState(() {
                _signatureFilter = filter;
                _signaturePage = 0;
              }),
            ),
            const SizedBox(height: EcoSpace.sm),
            DeskCategoryBar(
              selected: _signatureCategory,
              counts: categoryCounts,
              onChanged: (category) => setState(() {
                _signatureCategory = category;
                _signaturePage = 0;
              }),
            ),
          ],
        ),
      ),
      // The count describes what is actually listed. When the active status
      // has nothing in it the empty state explains why, so the line is hidden
      // rather than claiming "2 documents" above an empty list. While paging,
      // the pagination bar owns the total and this line only carries the
      // clear-filters link.
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        const SizedBox(height: EcoSpace.sm),
        DeskResultLine(
          label: paged ? '' : _countLabel(visible.length, 'document'),
          onClear: filtered ? _clearSignatureFilters : null,
        ),
      ],
      const SizedBox(height: EcoSpace.sm),
      if (visible.isEmpty)
        _signatureEmpty(hasAny: all.isNotEmpty, filtered: filtered)
      else ...[
        ..._documentList(pageItems),
        if (paged) ...[
          const SizedBox(height: EcoSpace.xs),
          EcoPaginationBar(
            page: page,
            pageSize: _pageSize,
            total: visible.length,
            onPageChanged: (next) => setState(() => _signaturePage = next),
            onPageSizeChanged: (size) => setState(() {
              _pageSize = size;
              _signaturePage = 0;
              _receivedPage = 0;
            }),
          ),
        ],
      ],
    ];
  }

  Widget _signatureEmpty({required bool hasAny, required bool filtered}) {
    if (filtered && hasAny) {
      return EmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: 'No documents match your filters',
        message: 'Try another office or status, or clear the search term.',
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

    // The Received list only ever grows — every signed ticket and acknowledged
    // memo ends up here. It pages in place so the desk never turns into one
    // endless column.
    final page = clampPage(_receivedPage, visible.length, _pageSize);
    final pageItems = pageSlice(visible, page, _pageSize);
    final paged = visible.length > _pageSize;

    return [
      DeskFilterPanel(
        padding: EdgeInsets.zero,
        search: EcoSearchField(
          controller: _receivedSearch,
          hint: 'Search received documents…',
          onChanged: (value) => setState(() {
            _receivedQuery = value;
            _receivedPage = 0;
          }),
        ),
        filters: DeskCategoryBar(
          selected: _receivedCategory,
          counts: categoryCounts,
          onChanged: (category) => setState(() {
            _receivedCategory = category;
            _receivedPage = 0;
          }),
        ),
      ),
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        const SizedBox(height: EcoSpace.sm),
        DeskResultLine(
          label: paged ? '' : _countLabel(visible.length, 'document'),
          onClear: filtered ? _clearReceivedFilters : null,
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
              ? 'Try another office or a different search term.'
              : 'Completed trip tickets and memos addressed to City Hall are '
                    'listed here as soon as they arrive.',
          actionLabel: filtered ? 'Clear filters' : null,
          onAction: filtered ? _clearReceivedFilters : null,
        )
      else ...[
        ..._documentList(pageItems),
        if (paged) ...[
          const SizedBox(height: EcoSpace.xs),
          EcoPaginationBar(
            page: page,
            pageSize: _pageSize,
            total: visible.length,
            onPageChanged: (next) => setState(() => _receivedPage = next),
            onPageSizeChanged: (size) => setState(() {
              _pageSize = size;
              _receivedPage = 0;
              _signaturePage = 0;
            }),
          ),
        ],
      ],
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
          style: EcoType.eyebrow(context, color: AppColors.inkMuted),
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

/// The filled call to action inside the hero.
///
/// White on the forest gradient so it reads as the one thing to press, and
/// greyed out when there is nothing to sign — the label still explains why.
class _HeroPrimary extends StatefulWidget {
  const _HeroPrimary({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_HeroPrimary> createState() => _HeroPrimaryState();
}

class _HeroPrimaryState extends State<_HeroPrimary> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final lit = _hovered && enabled;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(EcoRadius.pill),
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: enabled ? AppColors.darkGreen : Colors.white,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  color: enabled ? AppColors.darkGreen : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quiet secondary action beside [_HeroPrimary].
class _HeroGhost extends StatefulWidget {
  const _HeroGhost({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_HeroGhost> createState() => _HeroGhostState();
}

class _HeroGhostState extends State<_HeroGhost> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(EcoRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
