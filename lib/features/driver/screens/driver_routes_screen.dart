import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../collection_points/models/collection_point.dart';
import '../../collection_points/services/collection_point_service.dart';
import '../../location/providers/location_provider.dart';
import '../../route/models/route_plan.dart';
import '../../route/screens/route_map_screen.dart';
import '../../route/services/route_service.dart';
import '../widgets/driver_nav_bar.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Everything the driver is scheduled to do today: the assignment, its stops
/// and any collection points staff pinned to them.
class DriverRoutesScreen extends StatelessWidget {
  const DriverRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final location = context.watch<LocationProvider>();
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading your route'));
    }

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Row(
                children: [
                  BrandWordmark(fontSize: 10.5),
                  Spacer(),
                  NotificationBell(iconSize: 19, color: AppColors.inkMuted),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My routes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<RoutePlan?>(
                stream: RouteService().watchTodayPlan(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Loading your route');
                  }
                  final plan = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      if (plan == null)
                        const EmptyState(
                          icon: Icons.route_outlined,
                          title: 'No route assigned today',
                          message:
                              'Start an ad-hoc route from the Home tab, or wait for '
                              'barangay staff to schedule one.',
                          compact: true,
                        )
                      else
                        _PlanCard(
                          plan: plan,
                          truck: location.hasLocation
                              ? LatLng(location.latitude!, location.longitude!)
                              : null,
                        ),
                      const SizedBox(height: 18),
                      const _PinnedStops(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverNavBar(currentIndex: 1),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, this.truck});

  final RoutePlan plan;
  final LatLng? truck;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: plan.status.label,
                color: plan.status.color,
                icon: Icons.route_rounded,
                compact: true,
              ),
              const Spacer(),
              Text(
                plan.date,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.zone,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.windowLabel} · ${plan.stops.length} '
            '${plan.stops.length == 1 ? 'stop' : 'stops'}',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          if (plan.stops.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < plan.stops.length; i++)
              _StopRow(index: i + 1, stop: plan.stops[i]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RouteMapScreen(
                      title: plan.zone,
                      stops: plan.stops,
                      truck: truck,
                      openSteps: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('Open navigation map'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.index, required this.stop});

  final int index;
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 20,
            width: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (stop.address != null)
                  Text(
                    stop.address!,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.inkMuted,
                    ),
                  ),
                if (stop.schedule != null)
                  Text(
                    stop.schedule!,
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedStops extends StatelessWidget {
  const _PinnedStops();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<List<CollectionPoint>>(
      stream: CollectionPointService().watchForDriver(user.uid),
      builder: (context, snapshot) {
        final points = snapshot.data ?? const <CollectionPoint>[];
        if (points.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ASSIGNED COLLECTION POINTS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            for (final point in points) ...[
              EcoCard(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.lightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.place_outlined,
                          size: 16, color: AppColors.forest),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            point.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          if (point.scheduleTime != null)
                            Text(
                              point.scheduleDays.isEmpty
                                  ? point.scheduleTime!
                                  : '${point.scheduleDays.join(', ')} · '
                                      '${point.scheduleTime}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${point.latitude.toStringAsFixed(4)}, '
                      '${point.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 7.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
