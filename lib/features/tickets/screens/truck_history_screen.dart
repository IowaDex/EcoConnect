import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// Every trip ticket ever issued against one plate.
///
/// Iswim, the barangay and City Hall all open this screen: it is the record of
/// how many rounds the truck actually did.
class TruckHistoryScreen extends StatefulWidget {
  const TruckHistoryScreen({super.key, required this.truckId});

  final String truckId;

  @override
  State<TruckHistoryScreen> createState() => _TruckHistoryScreenState();
}

class _TruckHistoryScreenState extends State<TruckHistoryScreen> {
  GarbageTruck? _truck;

  @override
  void initState() {
    super.initState();
    // The plate may live only in the registry, so ask Firestore first instead
    // of assuming the seeded roster still describes it.
    FleetService().findTruck(widget.truckId).then((truck) {
      if (!mounted || truck == null) return;
      setState(() => _truck = truck);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: StreamBuilder<List<TripTicket>>(
              stream: TicketService().watchForTruck(widget.truckId),
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                final tickets = snapshot.data ?? const <TripTicket>[];
                final completed = tickets
                    .where((t) => t.status == TicketStatus.completed)
                    .length;
                final missed = tickets
                    .where((t) => t.status == TicketStatus.missed)
                    .length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                  children: [
                    AppPageHeader(
                      title: 'Truck history',
                      subtitle:
                          'Every trip ticket issued for one plate, newest '
                          'first.',
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/iswim'),
                      actions: const [NotificationBell()],
                    ),
                    const SizedBox(height: EcoSpace.xs),
                    if (_truck != null) ...[
                      FadeSlideIn(index: 0, child: _TruckHero(truck: _truck!)),
                      const SizedBox(height: EcoSpace.md),
                    ],
                    FadeSlideIn(
                      index: 1,
                      child: _MetricRow(
                        tickets: tickets.length,
                        completed: completed,
                        missed: missed,
                        loading: loading,
                      ),
                    ),
                    const SizedBox(height: EcoSpace.lg),
                    const SectionLabel('TRIP TICKETS'),
                    const SizedBox(height: EcoSpace.sm),
                    if (snapshot.hasError)
                      EcoBanner(
                        message: AppFeedback.describe(snapshot.error!),
                        icon: Icons.cloud_off_rounded,
                        color: AppColors.error,
                      )
                    else if (loading)
                      const _HistorySkeleton()
                    else if (tickets.isEmpty)
                      const EmptyState(
                        icon: Icons.confirmation_number_outlined,
                        title: 'No trip tickets yet',
                        message:
                            'Tickets issued to this plate will appear here '
                            'once ISWIM creates them.',
                        compact: true,
                      )
                    else
                      for (var i = 0; i < tickets.length; i++) ...[
                        FadeSlideIn(
                          index: i + 2,
                          child: TicketCard(
                            ticket: tickets[i],
                            onTap: () =>
                                context.push('/tickets/${tickets[i].id}'),
                          ),
                        ),
                        if (i < tickets.length - 1)
                          const SizedBox(height: EcoSpace.sm),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Identity block: the plate, its body, the zone it covers and its driver.
class _TruckHero extends StatelessWidget {
  const _TruckHero({required this.truck});

  final GarbageTruck truck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EcoSpace.lg),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(EcoRadius.hero),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDeep.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLATE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: EcoSpace.xxs),
                Text(
                  truck.plateNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: EcoSpace.xs),
                Text(
                  '${truck.description} · ${truck.zone}',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: EcoSpace.sm),
                Wrap(
                  spacing: EcoSpace.xs,
                  runSpacing: EcoSpace.xs,
                  children: [
                    _HeroPill(
                      icon: Icons.person_outline_rounded,
                      label: truck.driverName,
                    ),
                    _HeroPill(
                      icon: Icons.place_outlined,
                      label: truck.barangay,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EcoSpace.sm),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(EcoRadius.md),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EcoSpace.sm,
        vertical: EcoSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: EcoSpace.xxs + 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.tickets,
    required this.completed,
    required this.missed,
    required this.loading,
  });

  final int tickets;
  final int completed;
  final int missed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Metric(
          icon: Icons.confirmation_number_outlined,
          label: 'Tickets',
          value: loading ? '—' : '$tickets',
        ),
        const SizedBox(width: EcoSpace.sm),
        _Metric(
          icon: Icons.check_circle_outline_rounded,
          label: 'Completed',
          value: loading ? '—' : '$completed',
          accent: AppColors.moss,
        ),
        const SizedBox(width: EcoSpace.sm),
        _Metric(
          icon: Icons.error_outline_rounded,
          label: 'Missed',
          value: loading ? '—' : '$missed',
          accent: AppColors.error,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.forest,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: EcoSpace.sm,
          vertical: EcoSpace.sm + 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(height: EcoSpace.xs),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(EcoSpace.md),
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
          if (i < 2) const SizedBox(height: EcoSpace.sm),
        ],
      ],
    );
  }
}
