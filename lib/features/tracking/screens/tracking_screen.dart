import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../route/models/collection_route.dart';
import '../../route/models/route_plan.dart';
import '../../location/providers/location_provider.dart';
import '../../route/services/route_service.dart';
import '../../route/screens/route_map_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../user/widgets/profile_sheet.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  static const _fallback = BatasanHills.center;
  final _mapController = MapController();
  final _routeService = RouteService();
  late final Stream<CollectionRoute?> _routeStream;
  StreamSubscription<RoutePlan?>? _planSub;
  RoutePlan? _plan;
  String? _planId;
  bool _centeredOnUser = false;

  @override
  void initState() {
    super.initState();
    _routeStream = _routeService.watchActiveRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationProvider>();
      if (!location.hasLocation) location.getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Follows the assignment behind the live route so the planned stops can be
  /// drawn for residents. Resubscribes only when the plan actually changes.
  void _syncPlan(String? planId) {
    if (planId == _planId) return;
    _planId = planId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _planSub?.cancel();
      _planSub = null;
      if (!mounted) return;
      if (planId == null) {
        setState(() => _plan = null);
        return;
      }
      _planSub = _routeService.watchPlan(planId).listen((plan) {
        if (mounted) setState(() => _plan = plan);
      }, onError: (_) {});
    });
  }

  LatLng _residentPoint(LocationProvider location) {
    if (!location.hasLocation) return _fallback;
    return LatLng(location.latitude!, location.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final restricted =
        context.watch<AuthProvider>().currentUser?.isRestrictedResident ??
        false;
    final resident = _residentPoint(location);

    // Recentre the map the first time a real GPS fix arrives.
    if (location.hasLocation && !_centeredOnUser) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(resident, 16);
      });
    }

    return StreamBuilder<CollectionRoute?>(
      stream: _routeStream,
      builder: (context, snapshot) {
        final route = snapshot.data;
        _syncPlan(route?.planId);
        final truckPoint = (route?.latitude != null && route?.longitude != null)
            ? LatLng(route!.latitude!, route.longitude!)
            : null;
        final stops = _plan?.mappedStops ?? const <RouteStop>[];
        final stopPoints = <LatLng>[
          for (final stop in stops) LatLng(stop.latitude!, stop.longitude!),
        ];

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: BatasanHills.options(center: truckPoint ?? resident),
                  children: [
                    BatasanHills.tiles(),
                    BatasanHills.boundaryLayer(),
                    // The planned path, so residents know the streets the
                    // truck will take before it arrives.
                    if (stopPoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: stopPoints,
                            strokeWidth: 4,
                            color: AppColors.forest.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    if (location.currentPosition?.accuracy != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: resident,
                            radius: location.currentPosition!.accuracy,
                            useRadiusInMeter: true,
                            color: AppColors.forest.withValues(alpha: 0.10),
                            borderColor: AppColors.forest.withValues(
                              alpha: 0.35,
                            ),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < stops.length; i++)
                          Marker(
                            point: LatLng(
                              stops[i].latitude!,
                              stops[i].longitude!,
                            ),
                            width: 24,
                            height: 24,
                            child: _StopPin(index: i + 1),
                          ),
                        // Only pin the device once we actually have a fix —
                        // never draw the fallback city as the user's position.
                        if (location.hasLocation)
                          Marker(
                            point: resident,
                            width: 44,
                            height: 44,
                            child: const _ResidentPin(),
                          ),
                        if (truckPoint != null)
                          Marker(
                            point: truckPoint,
                            width: 52,
                            height: 52,
                            child: const _TruckMarker(),
                          ),
                      ],
                    ),
                    // The driver sheet covers the bottom of the map.
                    const OsmAttribution(alignment: Alignment.centerRight),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _CircleIcon(
                          icon: Icons.arrow_back_ios_new_rounded,
                          // Back to the dashboard the map was opened from. A
                          // deep link has nothing to pop, so it lands home.
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/user'),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.creamBright,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.forest.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const BrandWordmark(fontSize: 9.5),
                        ),
                        const Spacer(),
                        _CircleIcon(
                          icon: Icons.my_location_rounded,
                          onTap: () =>
                              _mapController.move(truckPoint ?? resident, 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _DriverSheet(
                  route: route,
                  plan: _plan,
                  location: location,
                  restricted: restricted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.forest,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        index.toString(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ResidentPin extends StatelessWidget {
  const _ResidentPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE23B3B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Container(
          width: 3,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFFE23B3B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _TruckMarker extends StatelessWidget {
  const _TruckMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.forest,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.forest),
      ),
    );
  }
}

class _DriverSheet extends StatelessWidget {
  const _DriverSheet({
    required this.route,
    required this.plan,
    required this.location,
    this.restricted = false,
  });

  final CollectionRoute? route;
  final RoutePlan? plan;
  final LocationProvider location;

  /// A resident whose ID is still being checked may only track the truck.
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final live = route != null;
    final stale = route?.isStale ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 4,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(
                        live ? Icons.person : Icons.local_shipping_rounded,
                        size: 24,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            live ? route!.driverName : 'No active collection',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (live && route!.phone != null) ...[
                                Text(
                                  route!.phone!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _dot(),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                !live
                                    ? 'Check back during collection hours'
                                    : stale
                                    ? 'Signal lost · ${_lastSeen(route!.lastSeenAt)}'
                                    : (route!.etaMinutes != null
                                          ? '${route!.etaMinutes} mins away'
                                          : 'On the way'),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: !live
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : stale
                                      ? const Color(0xFFF2B441)
                                      : AppColors.lime,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (live) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: route!.status.color.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: route!.status.color.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              child: Text(
                                stale ? 'Offline' : route!.status.label,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: stale
                                      ? const Color(0xFFF2B441)
                                      : route!.status.color,
                                ),
                              ),
                            ),
                          ],
                          if (plan != null && plan!.stops.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RouteMapScreen(
                                    title: 'Truck route',
                                    stops: plan!.stops,
                                    truck:
                                        route?.latitude != null &&
                                            route?.longitude != null
                                        ? LatLng(
                                            route!.latitude!,
                                            route!.longitude!,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Route · ${plan!.stops.take(3).map((s) => s.name).join(' → ')}'
                                      '${plan!.stops.length > 3 ? ' +${plan!.stops.length - 3} more' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.map_outlined,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Map',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (live)
                      Container(
                        height: 46,
                        width: 54,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 26,
                          color: AppColors.forest,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _LocationStatus(location: location),
              ],
            ),
          ),
          AppBottomNav(
            // The map is opened from Home, so Home stays lit. It used to say
            // 1, which highlighted Requests and made the page look like the
            // wrong tab had been opened.
            currentIndex: 0,
            dark: true,
            disabledIndexes: restricted ? const {2} : const {},
            askAiLocked: restricted,
            onTap: (i) {
              switch (i) {
                case 0:
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/user');
                  }
                case 1:
                  context.go('/my-requests');
                case 2:
                  if (restricted) {
                    AppFeedback.info(
                      context,
                      'You need to verify your account first before you can '
                      'open the community. Upload your ID on your dashboard '
                      'and barangay staff will unlock it.',
                    );
                    return;
                  }
                  context.go('/community');
                case 3:
                  showProfileSheet(context);
              }
            },
            onAskAi: restricted
                ? () => AppFeedback.info(
                    context,
                    'You need to verify your account first before you can use '
                    'the Eco assistant. Upload your ID on your dashboard and '
                    'barangay staff will unlock it.',
                  )
                : () => context.push('/ask-ai'),
          ),
        ],
      ),
    );
  }

  String _lastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return 'no recent update';
    final minutes = DateTime.now().difference(lastSeenAt).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes == 1) return '1 min ago';
    return '$minutes min ago';
  }

  Widget _dot() => Container(
    height: 3,
    width: 3,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
  );
}

/// The resident's own GPS state, and the one control that fixes it.
///
/// It used to read "Locating your position…" forever: a failed fix showed the
/// same sentence as a fix that was still on its way, and there was no way to
/// ask again. Each state now says what it is, and the button offers the next
/// step — go live, or retry.
class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.location});

  final LocationProvider location;

  @override
  Widget build(BuildContext context) {
    final hasFix = location.hasLocation;
    final tracking = location.isTracking;
    final busy = location.isLoading;
    final accuracy = location.currentPosition?.accuracy;

    final icon = hasFix
        ? Icons.gps_fixed_rounded
        : busy
        ? Icons.my_location_rounded
        : tracking
        ? Icons.gps_not_fixed_rounded
        : Icons.gps_off_rounded;
    final tint = hasFix
        ? AppColors.moss
        : busy
        ? AppColors.moss
        : tracking
        ? AppColors.warning
        : AppColors.inkMuted;
    final label = hasFix
        ? tracking
              ? 'Live · accuracy ±${accuracy?.round() ?? 0} m'
              : 'Position ready · accuracy ±${accuracy?.round() ?? 0} m'
        : busy
        ? 'Locating your position…'
        : tracking
        ? 'Waiting for a GPS fix…'
        : 'Location is off';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (!hasFix && location.error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    AppFeedback.describe(location.error!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.35,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ] else if (hasFix && !tracking) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Turn on real-time tracking to keep this pin moving.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.35,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!tracking)
            TextButton(
              onPressed: () => location.startTracking(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.forest,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Go live',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            )
          else if (!hasFix)
            TextButton(
              onPressed: busy ? null : () => location.getCurrentLocation(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.forest,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
