import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../dashboard/widgets/quick_action_grid.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../../fleet/widgets/fleet_truck_tile.dart';
import '../../manuals/models/manual.dart';
import '../../manuals/services/manual_service.dart';
import '../../manuals/widgets/shift_calendar_card.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../../tickets/widgets/ticket_card.dart';

/// Iswim's console: issues the tickets, signs them, and keeps the per-truck
/// history the barangay and City Hall both read.
///
/// One scroll view holds the hero, the operations shortcuts and whichever
/// desk the bottom bar has selected, so the header and the counters never
/// disappear when the officer switches between tickets and the fleet.
class IswimDashboardScreen extends StatefulWidget {
  const IswimDashboardScreen({super.key});

  @override
  State<IswimDashboardScreen> createState() => _IswimDashboardScreenState();
}

class _IswimDashboardScreenState extends State<IswimDashboardScreen> {
  /// 0 = overview, 1 = tickets, 2 = fleet. The console opens on the overview:
  /// the ticket list is one tap away, not already open.
  int _tab = 0;

  List<TripTicket> _tickets = const [];
  bool _loaded = false;
  StreamSubscription<List<TripTicket>>? _ticketSub;

  /// One request stream feeds the badge on the shortcut and the section below
  /// it, so a rebuild never resubscribes to Firestore.
  late final Stream<List<ManualRequest>> _requests = ManualService()
      .watchRequests();

  @override
  void initState() {
    super.initState();
    // One subscription feeds both the hero counters and the ticket list.
    _ticketSub = TicketService().watchAll().listen(
      (tickets) {
        if (!mounted) return;
        setState(() {
          _tickets = tickets;
          _loaded = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loaded = true);
      },
    );
  }

  @override
  void dispose() {
    _ticketSub?.cancel();
    super.dispose();
  }

  int get _waiting => _tickets.where((ticket) => ticket.needsDriver).length;
  int get _running => _tickets.where((ticket) => ticket.canStartTrip).length;
  int get _toSign => _tickets
      .where((ticket) => ticket.status == TicketStatus.barangaySigned)
      .length;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      // The trip ticket is no longer issued by hand: submitting a collection
      // manual generates it, so the dashboard has no "add ticket" button.
      // The nav lives in the Scaffold slot, not inside the body, so the page
      // content never hides behind it.
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          currentIndex: _tab,
          onTap: (index) => setState(() => _tab = index),
          items: const [
            (icon: Icons.space_dashboard_outlined, label: 'Overview'),
            (icon: Icons.confirmation_number_outlined, label: 'Tickets'),
            (icon: Icons.local_shipping_outlined, label: 'Fleet'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoleTopBar(onLogout: () => confirmAndLogout(context)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    children: [
                      FadeSlideIn(
                        index: 0,
                        child: RoleHero(
                          icon: Icons.business_center_rounded,
                          eyebrow: 'ISWIM · OPERATIONS',
                          greeting: greeting(),
                          title: user?.displayName ?? 'ISWIM',
                          subtitle:
                              'Build the collection manuals, sign the trip '
                              'tickets they generate, and keep the fleet '
                              'history the barangay and City Hall both read.',
                          chip: _toSign > 0
                              ? RoleChip(
                                  label: '$_toSign to sign',
                                  icon: Icons.draw_rounded,
                                  tone: AppColors.warning,
                                )
                              : null,
                          stats: [
                            RoleStat(
                              icon: Icons.hourglass_empty_rounded,
                              label: 'Waiting driver',
                              value: _waiting,
                              accent: AppColors.warning,
                            ),
                            RoleStat(
                              icon: Icons.local_shipping_rounded,
                              label: 'Running',
                              value: _running,
                            ),
                            RoleStat(
                              icon: Icons.draw_rounded,
                              label: 'To sign',
                              value: _toSign,
                              accent: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.lg),
                      // The overview holds the shortcuts, the roster and the
                      // requests; the two tabs below carry their own list.
                      if (_tab == 0) ...[
                        FadeSlideIn(
                          index: 1,
                          child: StreamBuilder<List<ManualRequest>>(
                            stream: _requests,
                            builder: (context, snapshot) {
                              final pending =
                                  (snapshot.data ?? const <ManualRequest>[])
                                      .where(
                                        (request) =>
                                            request.status ==
                                            ManualRequestStatus.pending,
                                      )
                                      .length;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionLabel('OPERATIONS'),
                                  const SizedBox(height: EcoSpace.sm),
                                  QuickActionGrid(
                                    actions: _operations(pending),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: EcoSpace.xl),
                        const FadeSlideIn(index: 2, child: ShiftCalendarCard()),
                        const SizedBox(height: EcoSpace.xl),
                        FadeSlideIn(index: 3, child: _manualRequestSection()),
                      ] else
                        FadeSlideIn(
                          index: 1,
                          child: _tab == 1 ? _ticketSection() : _fleetSection(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<QuickAction> _operations(int pendingManuals) => [
    const QuickAction(
      label: 'Assign route',
      icon: Icons.route_rounded,
      route: '/routes',
    ),
    const QuickAction(
      label: 'New manual',
      icon: Icons.assignment_ind_outlined,
      route: '/assignment-manuals/new',
    ),
    const QuickAction(
      label: 'Delay report',
      icon: Icons.timer_outlined,
      route: '/delays/new',
    ),
    const QuickAction(
      label: 'Delay list',
      icon: Icons.receipt_long_outlined,
      route: '/delays',
    ),
    const QuickAction(
      label: 'Memo to City Hall',
      icon: Icons.mail_outline_rounded,
      route: '/memos/new',
    ),
    const QuickAction(
      label: 'Manuals',
      icon: Icons.menu_book_outlined,
      route: '/manuals',
    ),
    QuickAction(
      label: 'Manual requests',
      icon: Icons.mark_email_unread_outlined,
      route: '/manual-requests',
      badge: pendingManuals,
    ),
    const QuickAction(
      label: 'Schedules',
      icon: Icons.calendar_month_outlined,
      route: '/assignments',
    ),
    const QuickAction(
      label: 'Memos',
      icon: Icons.inbox_outlined,
      route: '/memos/iswim',
    ),
    const QuickAction(
      label: 'Fleet',
      icon: Icons.local_shipping_outlined,
      route: '/fleet',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Manual requests from City Hall
  // ---------------------------------------------------------------------------

  /// The DSQC's manual requests land here as soon as they are filed, so Iswim
  /// does not have to open the request desk to notice one.
  Widget _manualRequestSection() {
    return StreamBuilder<List<ManualRequest>>(
      stream: _requests,
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? const <ManualRequest>[])
            .where((request) => request.status == ManualRequestStatus.pending)
            .toList(growable: false);
        if (pending.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              'MANUAL REQUESTS',
              action: 'View all',
              onAction: () => context.push('/manual-requests'),
            ),
            const SizedBox(height: EcoSpace.xs),
            Text(
              pending.length == 1
                  ? 'City Hall is waiting for one manual.'
                  : 'City Hall is waiting for ${pending.length} manuals.',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: EcoSpace.sm),
            for (var i = 0; i < pending.length && i < 3; i++) ...[
              _ManualRequestCard(request: pending[i]),
              if (i < pending.length - 1 && i < 2)
                const SizedBox(height: EcoSpace.sm),
            ],
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tickets
  // ---------------------------------------------------------------------------

  Widget _ticketSection() {
    final manuals = _tickets
        .where((ticket) => ticket.isAssignment)
        .toList(growable: false);
    final forApproval = manuals
        .where((ticket) => ticket.approvalPending)
        .toList(growable: false);
    final approved = manuals
        .where((ticket) => !ticket.approvalPending)
        .toList(growable: false);
    // Older wave tickets are not manuals; they keep their own group so nothing
    // disappears from the desk.
    final others = _tickets
        .where((ticket) => !ticket.isAssignment)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('TRIP TICKETS'),
        const SizedBox(height: EcoSpace.xs),
        Text(
          '${manuals.length} manual${manuals.length == 1 ? '' : 's'} · '
          '${forApproval.length} waiting for City Hall',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: EcoSpace.md),
        if (!_loaded)
          const _TicketSkeleton()
        else if (_tickets.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.confirmation_number_outlined,
            title: 'No tickets yet',
            message:
                'Trip tickets are generated by the collection manual: create '
                'one and City Hall signs it before the schedule goes live.',
          )
        else ...[
          _TicketGroup(
            title: 'FOR APPROVAL',
            emptyLabel: 'Nothing waiting for City Hall.',
            tickets: forApproval,
          ),
          const SizedBox(height: EcoSpace.lg),
          _TicketGroup(
            title: 'APPROVED',
            emptyLabel: 'No approved manual yet.',
            tickets: approved,
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: EcoSpace.lg),
            _TicketGroup(
              title: 'OTHER TICKETS',
              emptyLabel: '',
              tickets: others,
            ),
          ],
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fleet
  // ---------------------------------------------------------------------------

  Widget _fleetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('FLEET'),
        const SizedBox(height: EcoSpace.xs),
        const Text(
          'Every truck has a permanent driver. Tap a plate to see all of the '
          'trip tickets for that truck.',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: EcoSpace.sm),
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/fleet'),
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: const Text(
              'Manage fleet (add / edit trucks)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.sage),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: EcoSpace.md),
        const _FleetList(),
      ],
    );
  }
}

/// Truck rows for the fleet tab. Rendered as a column because the page owns
/// the only scroll view.
class _FleetList extends StatelessWidget {
  const _FleetList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GarbageTruck>>(
      stream: FleetService().watchTrucks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _FleetSkeleton();

        final trucks = snapshot.data ?? const <GarbageTruck>[];
        if (trucks.isEmpty) {
          return const EmptyState(
            compact: true,
            icon: Icons.local_shipping_outlined,
            title: 'No trucks registered',
            message:
                'Add a truck to the fleet and pair it with its permanent '
                'driver before issuing a trip ticket.',
          );
        }

        return Column(
          children: [
            for (var i = 0; i < trucks.length; i++) ...[
              FleetTruckTile(
                truck: trucks[i],
                onTap: () => context.push('/trucks/${trucks[i].id}/history'),
              ),
              if (i < trucks.length - 1) const SizedBox(height: EcoSpace.sm),
            ],
          ],
        );
      },
    );
  }
}

/// One City Hall manual request, surfaced on the Iswim dashboard.
class _ManualRequestCard extends StatelessWidget {
  const _ManualRequestCard({required this.request});

  final ManualRequest request;

  @override
  Widget build(BuildContext context) {
    final title = Uri.encodeComponent(request.title);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 17,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.code} · requested by ${request.requestedByName}',
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
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: () => context.push(
                '/assignment-manuals/new?title=$title&requestId=${request.id}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Create manual'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One heading plus its tickets, e.g. "FOR APPROVAL" or "APPROVED".
class _TicketGroup extends StatelessWidget {
  const _TicketGroup({
    required this.title,
    required this.emptyLabel,
    required this.tickets,
  });

  final String title;
  final String emptyLabel;
  final List<TripTicket> tickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tickets.length}',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tickets.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          )
        else
          for (var i = 0; i < tickets.length; i++) ...[
            TicketCard(
              ticket: tickets[i],
              onTap: () => context.push('/tickets/${tickets[i].id}'),
            ),
            if (i < tickets.length - 1) const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) {
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
                    SkeletonBox(width: 62, height: 15, radius: 7),
                    SizedBox(width: 8),
                    SkeletonBox(width: 46, height: 15, radius: 7),
                  ],
                ),
                SizedBox(height: 11),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 130, height: 10, radius: 5),
              ],
            ),
          ),
          if (i < 2) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _FleetSkeleton extends StatelessWidget {
  const _FleetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 62,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 36, height: 36, radius: 18),
                SizedBox(width: 11),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 90, height: 12),
                    SizedBox(height: 7),
                    SkeletonBox(width: 150, height: 10, radius: 5),
                  ],
                ),
              ],
            ),
          ),
          if (i < 3) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
