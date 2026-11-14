import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../fleet/services/fleet_service.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../models/garbage_truck.dart';
import '../models/truck_crew_role.dart';
import '../models/truck_status.dart';
import '../providers/truck_provider.dart';
import '../widgets/driver_nav_bar.dart';
import '../widgets/truck_card.dart';

/// First screen after a driver or guide signs in.
///
/// The barangay assigns the truck, so the crew does not type anything: they
/// pick their plate from the fleet list and the dashboard opens for that
/// vehicle. Each card carries the truck's status, so the guide can see at a
/// glance which plates have a ticket waiting, which are on the road and which
/// are parked without a driver.
class TruckPickerScreen extends StatefulWidget {
  const TruckPickerScreen({super.key});

  @override
  State<TruckPickerScreen> createState() => _TruckPickerScreenState();
}

class _TruckPickerScreenState extends State<TruckPickerScreen> {
  // Three sources, one listener each: the roster, the trucks reporting a live
  // position, and the tickets that make a truck ready to run.
  late final Stream<List<GarbageTruck>> _fleet;
  late final Stream<List<CollectionRoute>> _liveRoutes;
  late final Stream<List<TripTicket>> _tickets;

  @override
  void initState() {
    super.initState();
    _fleet = FleetService().watchTrucks();
    _liveRoutes = RouteService().watchLiveRoutes();
    _tickets = TicketService().watchAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TruckProvider>().restore();
    });
  }

  Future<void> _open(GarbageTruck truck) async {
    final trucks = context.read<TruckProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final role = user?.crewRole ?? TruckCrewRole.driver;
    // Re-opening the truck already on this phone must not page the driver
    // again, so the notice only goes out when the plate actually changes.
    final switching = trucks.selectedTruck?.id != truck.id;

    await trucks.select(truck);

    // A guide holds the device for a driver who has no phone, so the driver
    // only learns he has company if we tell him.
    if (switching && role == TruckCrewRole.guide && user != null) {
      final driverId = truck.driverAccountId;
      if (driverId != null && driverId.isNotEmpty && driverId != user.uid) {
        await NotificationService().push(
          userId: driverId,
          title: 'You have a truck guide',
          body: '${user.displayName ?? 'Your guide'} is your truck guide for '
              '${truck.plateNumber}.',
          // Drivers may only send route or collection alerts; a guide shares
          // the driver role, so this keeps the write inside the rules.
          type: AppNotificationType.route,
          data: {
            'kind': 'truckGuide',
            'truckId': truck.id,
            'plateNumber': truck.plateNumber,
            'guideUid': user.uid,
          },
        );
      }
    }

    if (!mounted) return;
    context.go('/driver');
  }

  Future<void> _logout() async {
    final confirmed = await confirmLogout(
      context,
      message: 'You can sign back in with the same account any time.',
    );
    if (!confirmed || !mounted) return;
    final trucks = context.read<TruckProvider>();
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    await trucks.clear();
    await location.endSession();
    await auth.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trucks = context.watch<TruckProvider>();
    final user = auth.currentUser;
    final role = user?.crewRole ?? TruckCrewRole.driver;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  const NotificationBell(
                    iconSize: 19,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<GarbageTruck>>(
                stream: _fleet,
                builder: (context, fleetSnap) {
                  final fleet = fleetSnap.data ?? const <GarbageTruck>[];
                  return StreamBuilder<List<CollectionRoute>>(
                    stream: _liveRoutes,
                    builder: (context, liveSnap) {
                      final moving = _platesOnTheRoad(liveSnap.data);
                      return StreamBuilder<List<TripTicket>>(
                        stream: _tickets,
                        builder: (context, ticketSnap) {
                          final ready = _trucksWithTickets(ticketSnap.data);
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                            children: [
                              _RoleBadge(role: role),
                              const SizedBox(height: 16),
                              const Text(
                                'Select your truck',
                                style: TextStyle(
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppColors.forest,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${fleet.length} trucks assigned by Barangay '
                                'Batasan Hills. Tap your plate to open the trip '
                                'dashboard.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 18),
                              for (final truck in fleet) ...[
                                TruckCard(
                                  truck: truck,
                                  selected: trucks.selectedTruck?.id == truck.id,
                                  status: TruckStatusX.resolve(
                                    truck: truck,
                                    inTransit: moving.contains(truck.plateNumber),
                                    hasTicket: ready.contains(truck.id),
                                  ),
                                  onTap: () => _open(truck),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
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
      bottomNavigationBar: const DriverNavBar(currentIndex: 0),
    );
  }

  /// Plates that are reporting a live position. A run whose phone went silent
  /// is left out: the truck is not on the move, it is just stale.
  static Set<String> _platesOnTheRoad(List<CollectionRoute>? routes) {
    if (routes == null) return const {};
    return {
      for (final route in routes)
        if (!route.isStale && (route.truckPlate ?? '').isNotEmpty)
          route.truckPlate!,
    };
  }

  /// Truck ids with a ticket the crew can act on: issued, accepted or already
  /// running. Finished paperwork does not keep a plate "ready".
  static Set<String> _trucksWithTickets(List<TripTicket>? tickets) {
    if (tickets == null) return const {};
    return {
      for (final ticket in tickets)
        if (ticket.status == TicketStatus.issued ||
            ticket.status == TicketStatus.accepted ||
            ticket.status == TicketStatus.running)
          ticket.truckId,
    };
  }
}

/// Names who is holding the device. Both roles run the same dashboard.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final TruckCrewRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Icon(role.icon, size: 15, color: AppColors.forest),
          const SizedBox(width: 9),
          Text(
            role.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}
