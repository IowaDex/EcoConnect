import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/motion.dart';
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
    return EcoPageScaffold(
      eyebrow: 'FLEET · TRIP LOG',
      title: 'Truck history',
      subtitle: 'Every trip ticket issued for one plate, newest first.',
      onBack: () => ecoBack(context, '/iswim'),
      actions: const [NotificationBell()],
      body: StreamBuilder<List<TripTicket>>(
        stream: TicketService().watchForTruck(widget.truckId),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final tickets = snapshot.data ?? const <TripTicket>[];
          final completed = tickets
              .where((t) => t.status == TicketStatus.completed)
              .length;
          final missed = tickets
              .where((t) => t.status == TicketStatus.missed)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              if (_truck != null) ...[
                FadeSlideIn(index: 0, child: _TruckHero(truck: _truck!)),
                const SizedBox(height: EcoSpace.md),
              ],
              FadeSlideIn(
                index: 1,
                child: DeskMetricRow(
                  metrics: [
                    DeskMetric(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Tickets',
                      value: loading ? '—' : '${tickets.length}',
                      accent: AppColors.forest,
                    ),
                    DeskMetric(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed',
                      value: loading ? '—' : '$completed',
                      accent: AppColors.moss,
                    ),
                    DeskMetric(
                      icon: Icons.error_outline_rounded,
                      label: 'Missed',
                      value: loading ? '—' : '$missed',
                      accent: AppColors.error,
                      highlight: missed > 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: EcoSpace.lg),
              if (snapshot.hasError)
                EcoBanner(
                  message: AppFeedback.describe(snapshot.error!),
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.error,
                )
              else if (loading)
                const SkeletonCardList(count: 3)
              else if (tickets.isEmpty)
                const DeskEmptyQueue(
                  icon: Icons.confirmation_number_outlined,
                  title: 'No trip tickets yet',
                  message:
                      'Tickets issued to this plate appear here once ISWIM '
                      'creates them.',
                  steps: [
                    'ISWIM assigns the plate to a route plan',
                    'The crew opens and closes the ticket on the road',
                    'Each round lands here with its outcome',
                  ],
                )
              else ...[
                DeskResultLine(
                  label:
                      '${tickets.length} '
                      '${tickets.length == 1 ? 'ticket' : 'tickets'}',
                ),
                const SizedBox(height: EcoSpace.sm),
                for (var i = 0; i < tickets.length; i++) ...[
                  FadeSlideIn(
                    index: i + 2,
                    child: TicketCard(
                      ticket: tickets[i],
                      onTap: () => context.push('/tickets/${tickets[i].id}'),
                    ),
                  ),
                  if (i < tickets.length - 1)
                    const SizedBox(height: EcoSpace.sm),
                ],
              ],
            ],
          );
        },
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
                  style: EcoType.eyebrow(
                    context,
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
