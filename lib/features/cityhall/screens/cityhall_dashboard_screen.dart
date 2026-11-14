import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../memos/services/memo_service.dart';
import '../../notifications/widgets/notification_bell.dart';
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
  State<CityHallDashboardScreen> createState() => _CityHallDashboardScreenState();
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

  Future<void> _logout() async {
    final confirmed = await confirmLogout(context);
    if (!confirmed || !mounted) return;
    final auth = context.read<AuthProvider>();
    await context.read<LocationProvider>().endSession();
    await auth.logout();
    if (mounted) context.go('/login');
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
        icon: const Icon(Icons.edit_note_rounded, size: 18),
        label: const Text(
          'Memo',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
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
                            people: peopleSnapshot.data ??
                                const <String, DeskPerson>{},
                          );

                          final loading = !ticketSnapshot.hasData &&
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const BrandWordmark(fontSize: 10.5),
          const Spacer(),
          const NotificationBell(iconSize: 19, color: AppColors.inkMuted),
          const SizedBox(width: 2),
          InkWell(
            onTap: _logout,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
          children: [
            _header(userName, documents),
            const SizedBox(height: 16),
            DeskTools(pendingSignatures: documents.pendingSignatures),
            const SizedBox(height: 18),
            _tabs(documents),
            const SizedBox(height: 14),
            if (error != null) ...[
              EcoBanner(
                message: AppFeedback.describe(error),
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else if (_tab == 0)
              ..._signatureSection(documents)
            else
              ..._receivedSection(documents),
          ],
        ),
      ),
    );
  }

  Widget _header(String userName, CityHallDocuments documents) {
    final pending = documents.pendingSignatures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CITY HALL · DSQC',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppColors.moss,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Document desk',
                style: TextStyle(
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(width: 10),
              _PendingPill(count: pending),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$userName — review, sign and acknowledge everything sent to City Hall.',
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.55,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _tabs(CityHallDocuments documents) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabSegment(
              0,
              'For signature',
              documents.pendingSignatures,
              Icons.draw_outlined,
            ),
          ),
          const SizedBox(width: 4),
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
    );
  }

  Widget _tabSegment(int index, String label, int count, IconData icon) {
    final selected = _tab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : AppColors.inkMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.cream,
                borderRadius: BorderRadius.circular(20),
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
            .where((document) =>
                document.matchesCategory(_signatureCategory) &&
                document.matchesSignatureFilter(filter))
            .length,
    };
    final categoryCounts = <DeskCategory?, int>{
      null: searched
          .where((document) => document.matchesSignatureFilter(_signatureFilter))
          .length,
      for (final category in DeskCategory.values)
        category: searched
            .where((document) =>
                document.matchesSignatureFilter(_signatureFilter) &&
                document.matchesCategory(category))
            .length,
    };

    final visible = searched
        .where((document) =>
            document.matchesCategory(_signatureCategory) &&
            document.matchesSignatureFilter(_signatureFilter))
        .toList(growable: false);

    final filtered = _signatureCategory != null ||
        _signatureQuery.trim().isNotEmpty ||
        _signatureFilter != SignatureFilter.awaiting;

    return [
      _sectionHeader(
        title: _signatureFilter.label,
        subtitle: switch (_signatureFilter) {
          SignatureFilter.awaiting =>
            'Documents waiting for the City Hall signature.',
          SignatureFilter.signed => 'Documents already signed at this desk.',
          SignatureFilter.rejected => 'Documents rejected at this desk.',
          SignatureFilter.returned =>
            'Documents sent back for revision by this desk.',
        },
      ),
      const SizedBox(height: 10),
      DeskSignatureBar(
        selected: _signatureFilter,
        counts: statusCounts,
        onChanged: (filter) => setState(() => _signatureFilter = filter),
      ),
      const SizedBox(height: 11),
      DeskSearchField(
        controller: _signatureSearch,
        hintText: 'Search document, driver name, or reference number...',
        onChanged: (value) => setState(() => _signatureQuery = value),
      ),
      const SizedBox(height: 10),
      DeskCategoryBar(
        selected: _signatureCategory,
        counts: categoryCounts,
        onChanged: (category) => setState(() => _signatureCategory = category),
      ),
      const SizedBox(height: 14),
      // The count describes what is actually listed. When the active status
      // has nothing in it the empty state explains why, so the line is hidden
      // rather than claiming "2 documents" above an empty list.
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        _resultLine(
          'document',
          visible.length,
          all.length,
          filtered: visible.length != all.length,
        ),
        const SizedBox(height: 9),
      ],
      if (visible.isEmpty)
        _signatureEmpty(hasAny: all.isNotEmpty, filtered: filtered)
      else
        for (var i = 0; i < visible.length; i++) ...[
          DeskDocumentCard(
            document: visible[i],
            index: i,
            onOpen: () => context.push(visible[i].openRoute),
            onSign: visible[i].canSign
                ? () => context.push(_signRoute(visible[i]))
                : null,
          ),
          const SizedBox(height: 9),
        ],
    ];
  }

  Widget _signatureEmpty({required bool hasAny, required bool filtered}) {
    if (filtered && hasAny) {
      return DeskEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No documents match your filters',
        message: 'Try another category or status, or clear the search term.',
        actionLabel: 'Clear filters',
        onAction: _clearSignatureFilters,
      );
    }
    return DeskEmptyState(
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
        category:
            searched.where((document) => document.matchesCategory(category)).length,
    };

    final visible = searched
        .where((document) => document.matchesCategory(_receivedCategory))
        .toList(growable: false);

    final filtered =
        _receivedCategory != null || _receivedQuery.trim().isNotEmpty;

    return [
      _sectionHeader(
        title: 'Received',
        subtitle:
            'Everything delivered to City Hall from the barangay, ISWIM and the fleet.',
      ),
      const SizedBox(height: 11),
      DeskSearchField(
        controller: _receivedSearch,
        hintText: 'Search received documents...',
        onChanged: (value) => setState(() => _receivedQuery = value),
      ),
      const SizedBox(height: 10),
      DeskCategoryBar(
        selected: _receivedCategory,
        counts: categoryCounts,
        onChanged: (category) => setState(() => _receivedCategory = category),
      ),
      const SizedBox(height: 14),
      if (all.isNotEmpty && visible.isNotEmpty) ...[
        _resultLine(
          'document',
          visible.length,
          all.length,
          filtered: visible.length != all.length,
        ),
        const SizedBox(height: 9),
      ],
      if (visible.isEmpty)
        DeskEmptyState(
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
        for (var i = 0; i < visible.length; i++) ...[
          DeskDocumentCard(
            document: visible[i],
            index: i,
            onOpen: () => context.push(visible[i].openRoute),
            onSign: visible[i].canSign
                ? () => context.push(_signRoute(visible[i]))
                : null,
          ),
          const SizedBox(height: 9),
        ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 9.5,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
      ],
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
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: AppColors.inkMuted,
          ),
        ),
        const Spacer(),
        if (filtered)
          GestureDetector(
            onTap:
                _tab == 0 ? _clearSignatureFilters : _clearReceivedFilters,
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  static String _countLabel(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';

  static String _signRoute(DeskDocument document) =>
      '${document.openRoute}?sign=1';
}

/// The count of documents still waiting for the last signature.
class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.draw_rounded, size: 12, color: AppColors.textDark),
          const SizedBox(width: 5),
          Text(
            '$count awaiting',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// The desk's twelve shortcuts now live in [DeskTools], a responsive grid that
/// never scrolls sideways.
