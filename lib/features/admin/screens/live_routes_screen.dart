import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/collection_route.dart';
import '../../../core/models/route_plan.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/app_colors.dart';

const _fallbackCentre = LatLng(14.5995, 120.9842);

/// One colour per driver, cycled so routes stay distinguishable.
const _driverColours = <Color>[
  AppColors.forest,
  Color(0xFFC9822E),
  AppColors.moss,
  Color(0xFF3F7D6A),
  Color(0xFF8A6BBE),
];

/// Full-screen live map for barangay staff: every collecting driver, today's
/// planned routes and a dispatch list at the bottom.
class LiveRoutesScreen extends StatefulWidget {
  const LiveRoutesScreen({super.key});

  @override
  State<LiveRoutesScreen> createState() => _LiveRoutesScreenState();
}

class _LiveRoutesScreenState extends State<LiveRoutesScreen> {
  final _map = MapController();
  final _routeService = RouteService();

  late final Stream<List<CollectionRoute>> _routesStream;
  late final Stream<List<RoutePlan>> _plansStream;

  String _sector = 'All sectors';
  bool _framed = false;

  @override
  void initState() {
    super.initState();
    _routesStream = _routeService.watchLiveRoutes();
    _plansStream = _routeService.watchPlansForToday();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  static RoutePlan? _planFor(List<RoutePlan> plans, String? planId) {
    if (planId == null) return null;
    for (final plan in plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  static Color _colourFor(int index) =>
      _driverColours[index % _driverColours.length];

  static LatLng _point(CollectionRoute route) =>
      LatLng(route.latitude!, route.longitude!);

  /// Frames every live driver and planned stop the first time data lands.
  void _frameOnce(List<LatLng> points) {
    if (_framed || points.isEmpty) return;
    _framed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _map.move(points.first, 16);
      } else {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(60, 140, 60, 280),
            maxZoom: 16,
          ),
        );
      }
    });
  }

  void _focus(CollectionRoute route) {
    if (route.latitude == null || route.longitude == null) return;
    _map.move(_point(route), 16.5);
  }

  void _zoomBy(double delta) {
    final camera = _map.camera;
    _map.move(
      camera.center,
      (camera.zoom + delta).clamp(5.0, 19.0),
    );
  }

  void _centreOnDrivers(List<CollectionRoute> routes) {
    for (final route in routes) {
      if (route.latitude != null && route.longitude != null) {
        _map.move(_point(route), 16);
        return;
      }
    }
    _map.move(_fallbackCentre, 14);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: StreamBuilder<List<CollectionRoute>>(
        stream: _routesStream,
        builder: (context, routeSnapshot) {
          final allRoutes = routeSnapshot.data ?? const <CollectionRoute>[];
          return StreamBuilder<List<RoutePlan>>(
            stream: _plansStream,
            builder: (context, planSnapshot) {
              final plans = planSnapshot.data ?? const <RoutePlan>[];

              final sectors = <String>{
                for (final route in allRoutes)
                  if ((route.zone ?? '').trim().isNotEmpty) route.zone!.trim(),
                for (final plan in plans)
                  if (plan.zone.trim().isNotEmpty) plan.zone.trim(),
              }.toList()
                ..sort();

              final routes = _sector == 'All sectors'
                  ? allRoutes
                  : allRoutes.where((r) => r.zone == _sector).toList();
              final visiblePlans = _sector == 'All sectors'
                  ? plans
                  : plans.where((p) => p.zone == _sector).toList();

              _frameOnce([
                for (final route in allRoutes)
                  if (route.latitude != null && route.longitude != null)
                    _point(route),
                for (final plan in plans)
                  for (final stop in plan.mappedStops)
                    LatLng(stop.latitude!, stop.longitude!),
              ]);

              return Stack(
                children: [
                  Positioned.fill(child: _mapView(routes, visiblePlans)),
                  _topBar(routes.length, sectors),
                  _mapControls(routes),
                  _sheet(routes, plans),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _mapView(List<CollectionRoute> routes, List<RoutePlan> plans) {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    // Today's planned routes, dotted.
    for (var i = 0; i < plans.length; i++) {
      final stops = plans[i].mappedStops;
      if (stops.length < 2) continue;
      final points = [
        for (final stop in stops) LatLng(stop.latitude!, stop.longitude!),
      ];
      polylines.addAll(
        _dashed(points, _colourFor(i).withValues(alpha: 0.5), 2.5),
      );
      for (final stop in stops) {
        markers.add(
          Marker(
            point: LatLng(stop.latitude!, stop.longitude!),
            width: 14,
            height: 14,
            child: _StopDot(colour: _colourFor(i)),
          ),
        );
      }
    }

    // Live drivers: solid line from the truck through the remaining stops.
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final colour = _colourFor(i);
      final plan = _planFor(plans, route.planId);
      final hasFix = route.latitude != null && route.longitude != null;

      if (hasFix) {
        final points = <LatLng>[
          _point(route),
          if (plan != null)
            for (final stop in plan.mappedStops)
              LatLng(stop.latitude!, stop.longitude!),
        ];
        if (points.length > 1) {
          polylines.add(
            Polyline(points: points, strokeWidth: 4, color: colour),
          );
        }
        markers.add(
          Marker(
            point: _point(route),
            width: 46,
            height: 46,
            child: _TruckBadge(colour: colour),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _map,
      options: const MapOptions(
        initialCenter: _fallbackCentre,
        initialZoom: 14,
        minZoom: 5,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ecoconnect',
          maxZoom: 19,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  /// flutter_map 6 has no dash pattern, so segments are split by hand.
  List<Polyline> _dashed(List<LatLng> points, Color colour, double width) {
    const dash = 0.14;
    const gap = 0.1;
    final out = <Polyline>[];

    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      var t = 0.0;
      while (t < 1) {
        final end = math.min(t + dash, 1.0);
        out.add(
          Polyline(
            points: [_lerp(from, to, t), _lerp(from, to, end)],
            strokeWidth: width,
            color: colour,
          ),
        );
        t = end + gap;
      }
    }
    return out;
  }

  LatLng _lerp(LatLng from, LatLng to, double t) => LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );

  Widget _topBar(int liveCount, List<String> sectors) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: _close,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _StatusPill(count: liveCount)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final sector in ['All sectors', ...sectors])
                      _SectorChip(
                        label: sector,
                        selected: _sector == sector,
                        onTap: () => setState(() => _sector = sector),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapControls(List<CollectionRoute> routes) {
    return Positioned(
      right: 16,
      top: MediaQuery.paddingOf(context).top + 104,
      child: Column(
        children: [
          _CircleButton(
            icon: Icons.add_rounded,
            onTap: () => _zoomBy(1),
          ),
          const SizedBox(height: 10),
          _CircleButton(
            icon: Icons.remove_rounded,
            onTap: () => _zoomBy(-1),
          ),
          const SizedBox(height: 10),
          _CircleButton(
            icon: Icons.my_location_rounded,
            onTap: () => _centreOnDrivers(routes),
          ),
        ],
      ),
    );
  }

  Widget _sheet(List<CollectionRoute> routes, List<RoutePlan> plans) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 18),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (routes.isEmpty)
              _EmptySheet(onAssign: () => context.go('/routes'))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      routes.length == 1
                          ? '1 driver on the road'
                          : '${routes.length} drivers on the road',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const Text(
                    'Updated just now',
                    style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: routes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return _DriverCard(
                      route: route,
                      plan: _planFor(plans, route.planId),
                      onTap: () => _focus(route),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 9,
            width: 9,
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.moss : AppColors.sage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live routes',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'No drivers collecting'
                      : count == 1
                          ? '1 driver collecting'
                          : '$count drivers collecting',
                  style: const TextStyle(
                    fontSize: 9.5,
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

class _SectorChip extends StatelessWidget {
  const _SectorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : AppColors.creamBright,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.creamBright : AppColors.forest,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 40,
        width: 40,
        decoration: const BoxDecoration(
          color: AppColors.creamBright,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: AppColors.forest),
      ),
    );
  }
}

class _TruckBadge extends StatelessWidget {
  const _TruckBadge({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.creamBright, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 18,
        color: AppColors.creamBright,
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: 2),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.route,
    required this.plan,
    required this.onTap,
  });

  final CollectionRoute route;
  final RoutePlan? plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zone =
        (route.zone ?? '').trim().isEmpty ? 'Unassigned zone' : route.zone!;
    final status = route.isStale ? 'Signal lost' : route.status.label;
    final stops = plan?.stops ?? const <RouteStop>[];
    final next = stops.isEmpty ? null : stops.first.name;
    final eta = route.etaMinutes;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: AppColors.forest,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 18,
                color: AppColors.creamBright,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      if (stops.isNotEmpty)
                        Text(
                          stops.length == 1
                              ? '1 stop'
                              : '${stops.length} stops',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$zone · $status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      eta == null ? 'Next: $next' : 'Next: $next · $eta min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.moss,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.moss,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySheet extends StatelessWidget {
  const _EmptySheet({required this.onAssign});

  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            size: 22,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'No driver is collecting right now',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Live positions show up here as soon as a driver starts a run. '
          "Dotted lines are today's planned routes.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: onAssign,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Assign today's runs",
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
