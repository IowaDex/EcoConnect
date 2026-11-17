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
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../../tickets/widgets/ticket_card.dart';
import '../../tickets/widgets/ticket_flow_filter.dart';

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
  int _tab = 0;

  /// `null` means All.
  TicketFlowStage? _stage;

  List<TripTicket> _tickets = const [];
  bool _loaded = false;
  StreamSubscription<List<TripTicket>>? _ticketSub;

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
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/iswim/new-ticket'),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text(
                'Trip ticket',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      // The nav lives in the Scaffold slot, not inside the body, so the
      // "Trip ticket" button floats above it instead of covering the Fleet tab.
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          currentIndex: _tab,
          onTap: (index) => setState(() => _tab = index),
          items: const [
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
                              'Issue trip tickets, sign them, and keep the fleet '
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
                      const FadeSlideIn(
                        index: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel('OPERATIONS'),
                            SizedBox(height: EcoSpace.sm),
                            QuickActionGrid(actions: _operations),
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      FadeSlideIn(
                        index: 2,
                        child: _tab == 0 ? _ticketSection() : _fleetSection(),
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

  static const _operations = <QuickAction>[
    QuickAction(
      label: 'New ticket',
      icon: Icons.note_add_outlined,
      route: '/iswim/new-ticket',
    ),
    QuickAction(
      label: 'Delay report',
      icon: Icons.timer_outlined,
      route: '/delays/new',
    ),
    QuickAction(
      label: 'Delay list',
      icon: Icons.receipt_long_outlined,
      route: '/delays',
    ),
    QuickAction(
      label: 'Memo to City Hall',
      icon: Icons.mail_outline_rounded,
      route: '/memos/new',
    ),
    QuickAction(
      label: 'Manuals',
      icon: Icons.menu_book_outlined,
      route: '/manuals',
    ),
    QuickAction(
      label: 'Manual requests',
      icon: Icons.mark_email_unread_outlined,
      route: '/manual-requests',
    ),
    QuickAction(
      label: 'Memos',
      icon: Icons.inbox_outlined,
      route: '/memos/iswim',
    ),
    QuickAction(
      label: 'Fleet',
      icon: Icons.local_shipping_outlined,
      route: '/fleet',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Tickets
  // ---------------------------------------------------------------------------

  Widget _ticketSection() {
    final visible = ticketsInStage(_tickets, _stage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'TICKETS',
          action: _stage == null ? null : 'Show all',
          onAction: _stage == null ? null : () => setState(() => _stage = null),
        ),
        const SizedBox(height: EcoSpace.xs),
        Text(
          _stage == null
              ? '${_tickets.length} total'
              : '${visible.length} of ${_tickets.length} in '
                    '${_stage!.label.toLowerCase()}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: EcoSpace.sm),
        TicketFlowFilterBar(
          selected: _stage,
          counts: ticketStageCounts(_tickets),
          total: _tickets.length,
          onChanged: (stage) => setState(() => _stage = stage),
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
                'Tap "Trip ticket" to create one — pick a truck and its driver '
                'is included automatically.',
          )
        else if (visible.isEmpty)
          EmptyState(
            compact: true,
            icon: _stage!.icon,
            title: 'No tickets in ${_stage!.label.toLowerCase()}',
            message: _stage!.description,
            actionLabel: 'Show all tickets',
            onAction: () => setState(() => _stage = null),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            TicketCard(
              ticket: visible[i],
              onTap: () => context.push('/tickets/${visible[i].id}'),
            ),
            if (i < visible.length - 1) const SizedBox(height: 9),
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
