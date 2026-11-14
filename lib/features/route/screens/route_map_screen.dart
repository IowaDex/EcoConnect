import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../../../core/utils/maps.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/route_directions.dart';
import '../models/route_plan.dart';
import '../services/directions_service.dart';

/// Full-screen route map for the driver: every pinned stop in order, the road
/// route between them, and in-app turn-by-turn directions.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({
    super.key,
    required this.title,
    required this.stops,
    this.truck,
    this.tileProvider,
    this.openSteps = false,
  });

  final String title;
  final List<RouteStop> stops;
  final LatLng? truck;

  /// Overridable so tests can render without hitting the tile server.
  final TileProvider? tileProvider;

  /// Opens the turn-by-turn sheet as soon as the route is calculated.
  final bool openSteps;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final _map = MapController();
  final _directions = DirectionsService();
  RouteDirections? _roadRoute;
  bool _loadingRoute = false;
  bool _openedSteps = false;
  int? _selected;

  List<RouteStop> get _mapped =>
      [for (final stop in widget.stops) if (stop.hasCoordinates) stop];

  /// Truck first (when known), then the stops in collection order.
  List<LatLng> get _waypoints => [
        if (widget.truck != null) widget.truck!,
        for (final stop in _mapped) LatLng(stop.latitude!, stop.longitude!),
      ];

  @override
  void initState() {
    super.initState();
    if (_mapped.isNotEmpty) _selected = 0;
    _loadRoadRoute();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  RouteStop? get _selectedStop {
    final stops = _mapped;
    final index = _selected;
    if (index == null || index < 0 || index >= stops.length) return null;
    return stops[index];
  }

  /// The drive that ends at [stopIndex]. With a truck position the first leg
  /// leads to the first stop; otherwise the first stop has no leg.
  RouteLeg? _legFor(int? stopIndex) {
    final route = _roadRoute;
    if (route == null || stopIndex == null) return null;
    final legIndex = widget.truck != null ? stopIndex : stopIndex - 1;
    if (legIndex < 0 || legIndex >= route.legs.length) return null;
    return route.legs[legIndex];
  }

  String? get _statusLabel {
    if (_loadingRoute) return 'Calculating the road route…';
    final route = _roadRoute;
    if (route != null) {
      return '${route.distanceLabel} · ${route.durationLabel} along roads';
    }
    if (_waypoints.length > 1) return 'Straight-line preview';
    return null;
  }

  Future<void> _loadRoadRoute() async {
    final waypoints = _waypoints;
    if (waypoints.length < 2) return;
    setState(() => _loadingRoute = true);

    // Leg names follow the waypoints: with a truck the first leg ends at the
    // first stop, without one it ends at the second.
    final names = [for (final stop in _mapped) stop.name];
    final legNames = widget.truck != null
        ? names
        : (names.length > 1 ? names.sublist(1) : const <String>[]);

    final route = await _directions.drivingRoute(
      waypoints,
      stopNames: legNames,
    );
    if (!mounted) return;
    setState(() {
      _roadRoute = route;
      _loadingRoute = false;
    });

    if (widget.openSteps && !_openedSteps) {
      _openedSteps = true;
      await _openSteps();
    }
  }

  void _select(int index, {bool recenter = true}) {
    setState(() => _selected = index);
    if (!recenter) return;
    final stop = _mapped[index];
    _map.move(LatLng(stop.latitude!, stop.longitude!), 17);
  }

  Future<void> _openLink(Future<bool> action) async {
    final opened = await action;
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _openInMaps() {
    final stops = [
      for (final stop in _mapped) LatLng(stop.latitude!, stop.longitude!),
    ];
    return _openLink(openRouteDirections(stops: stops, origin: widget.truck));
  }

  Future<void> _openSteps() async {
    final route = _roadRoute;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _StepsSheet(
        steps: route?.steps ?? const [],
        loading: _loadingRoute,
        summary: route == null
            ? null
            : '${route.distanceLabel} · ${route.durationLabel}',
        onRetry: () {
          Navigator.of(sheetContext).pop();
          _loadRoadRoute();
        },
      ),
    );
  }

  void _fit(List<LatLng> all) {
    if (all.isEmpty) return;
    if (all.length == 1) {
      _map.move(all.first, 16);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(all),
        // Leave room for the app bar and the details panel.
        padding: const EdgeInsets.fromLTRB(56, 70, 56, 230),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = _mapped;
    final points = [
      for (final stop in stops) LatLng(stop.latitude!, stop.longitude!),
    ];
    final all = [...points, if (widget.truck != null) widget.truck!];
    final road = _roadRoute?.polyline ?? const <LatLng>[];
    final selected = _selectedStop;
    final bounds = _boundsFor(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: 'Fit all stops',
              onPressed: () => _fit(all),
              icon: const Icon(Icons.fit_screen_rounded),
            ),
        ],
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.map_outlined,
              title: 'No pinned stops',
              message: 'Staff have not pinned map coordinates for this run yet.',
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: BatasanHills.options(
                      center: all.first,
                      fit: bounds,
                      fitPadding: const EdgeInsets.fromLTRB(56, 70, 56, 230),
                    ),
                    children: [
                      BatasanHills.tiles(tileProvider: widget.tileProvider),
                      if (road.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: road,
                              strokeWidth: 5,
                              color: AppColors.primary,
                            ),
                          ],
                        )
                      else if (points.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 4,
                              color: AppColors.primary.withValues(alpha: 0.35),
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
                              width: 34,
                              height: 34,
                              child: GestureDetector(
                                onTap: () => _select(i),
                                child: _StopPin(
                                  number: i + 1,
                                  selected: _selected == i,
                                ),
                              ),
                            ),
                          if (widget.truck != null)
                            Marker(
                              point: widget.truck!,
                              width: 34,
                              height: 34,
                              child: const _TruckPin(),
                            ),
                        ],
                      ),
                      const OsmAttribution(),
                    ],
                  ),
                ),
                if (_loadingRoute)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: _LoadingPill()),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _StopPanel(
                    stops: stops,
                    selected: _selected,
                    stop: selected,
                    status: _statusLabel,
                    loading: _loadingRoute,
                    leg: _legFor(_selected),
                    onSelect: _select,
                    onSteps: _openSteps,
                    onMaps: _openInMaps,
                    onCenter:
                        selected == null ? null : () => _select(_selected!),
                  ),
                ),
              ],
            ),
    );
  }

  /// Null when the points cannot form a box (a single stop, or identical
  /// coordinates), which would otherwise make the camera fit fail.
  LatLngBounds? _boundsFor(List<LatLng> all) {
    if (all.length < 2) return null;
    final first = all.first;
    final spread = all.any(
      (point) =>
          point.latitude != first.latitude ||
          point.longitude != first.longitude,
    );
    return spread ? LatLngBounds.fromPoints(all) : null;
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 11,
            width: 11,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
          SizedBox(width: 8),
          Text(
            'Getting directions…',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopPanel extends StatelessWidget {
  const _StopPanel({
    required this.stops,
    required this.selected,
    required this.stop,
    required this.status,
    required this.loading,
    required this.leg,
    required this.onSelect,
    required this.onSteps,
    required this.onMaps,
    required this.onCenter,
  });

  final List<RouteStop> stops;
  final int? selected;
  final RouteStop? stop;
  final String? status;
  final bool loading;
  final RouteLeg? leg;
  final void Function(int index) onSelect;
  final VoidCallback onSteps;
  final VoidCallback onMaps;
  final VoidCallback? onCenter;

  @override
  Widget build(BuildContext context) {
    final current = stop;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (loading)
                      const SizedBox(
                        height: 10,
                        width: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      const Icon(Icons.alt_route_rounded,
                          size: 12, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (stops.length > 1) ...[
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final active = i == selected;
                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              active ? AppColors.primary : AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${i + 1}. ${stops[i].name}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.darkGreen,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (current == null)
              const Text(
                'Tap a pin to see the details.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              )
            else ...[
              Text(
                current.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              if (leg != null)
                _detail(
                  Icons.turn_right_rounded,
                  '${leg!.distanceLabel} · ${leg!.durationLabel} from the '
                  'previous point',
                ),
              if (current.address != null)
                _detail(Icons.place_outlined, current.address!),
              if (current.schedule != null)
                _detail(Icons.schedule_rounded, current.schedule!),
              if (current.notes != null)
                _detail(Icons.notes_rounded, current.notes!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSteps,
                    icon: const Icon(
                      Icons.format_list_numbered_rounded,
                      size: 16,
                    ),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Center on the selected stop',
                  onPressed: onCenter,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Open in Google Maps',
                  onPressed: onMaps,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsSheet extends StatelessWidget {
  const _StepsSheet({
    required this.steps,
    required this.loading,
    required this.summary,
    required this.onRetry,
  });

  final List<RouteStep> steps;
  final bool loading;
  final String? summary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Directions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const Spacer(),
                if (summary != null)
                  Text(
                    summary!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text(
                      'Turn-by-turn directions are not available right now. '
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < steps.length; i++)
                _StepTile(step: steps[i], isLast: i == steps.length - 1),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.isLast});

  final RouteStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final arrived = step.arrivesAtStop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: arrived ? AppColors.primary : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _icon(step),
              size: 16,
              color: arrived ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight:
                        arrived ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (step.distanceMeters > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.distanceLabel,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(RouteStep step) {
    if (step.arrivesAtStop) return Icons.flag_rounded;
    switch (step.maneuver) {
      case 'depart':
        return Icons.navigation_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_left_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'fork':
        return Icons.call_split_rounded;
      case 'on ramp':
        return Icons.ramp_right_rounded;
      case 'off ramp':
        return Icons.ramp_left_rounded;
      case 'end of road':
        return Icons.turn_right_rounded;
      default:
        final text = step.instruction.toLowerCase();
        if (text.contains('left')) return Icons.turn_left_rounded;
        if (text.contains('right')) return Icons.turn_right_rounded;
        return Icons.straight_rounded;
    }
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.number, required this.selected});

  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.warning : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TruckPin extends StatelessWidget {
  const _TruckPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}
