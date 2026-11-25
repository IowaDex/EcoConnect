import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../data/manual_areas.dart';
import '../services/street_route.dart';

/// The run for one assignment, drawn in its own colour.
class ManualRouteGroup {
  const ManualRouteGroup({required this.areas, required this.color});

  final List<ManualArea> areas;
  final Color color;
}

/// Draws the picked areas as one numbered run.
///
/// Nothing is traced by hand and nothing is ringed: the first area is badge 1,
/// the second is badge 2, and the line between them is the streets a truck
/// would drive — not a straight line across the roofs. The line comes from the
/// OpenStreetMap router; until it answers the map shows the badges only, so a
/// straight placeholder is never mistaken for the route.
class ManualRouteMap extends StatefulWidget {
  const ManualRouteMap({
    super.key,
    required this.groups,
    this.height = 168,
    this.interactive = false,
    this.tileProvider,
    this.planner,
  });

  final List<ManualRouteGroup> groups;
  final double height;
  final bool interactive;

  /// Overridable so widget tests render without reaching the tile server.
  final TileProvider? tileProvider;

  /// Overridable so tests never reach the routing server.
  final StreetRoutePlanner? planner;

  @override
  State<ManualRouteMap> createState() => _ManualRouteMapState();
}

class _ManualRouteMapState extends State<ManualRouteMap> {
  /// Keyed by the group's position and its areas, so re-picking a different
  /// area asks again but an unrelated rebuild does not.
  final Map<String, StreetRoute> _routes = {};

  final _controller = MapController();
  bool _mapReady = false;

  String _planned = '';
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ManualRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    // The controller is ours, not the map's, so it has to be released here.
    _controller.dispose();
    super.dispose();
  }

  String get _signature => [
    for (final group in widget.groups)
      [for (final area in group.areas) area.name].join('>'),
  ].join('|');

  /// Requests happen after the frame, so a rebuild never calls setState while
  /// the tree is being built.
  void _schedule() {
    if (_signature == _planned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _plan();
    });
  }

  Future<void> _plan() async {
    final signature = _signature;
    if (signature == _planned) return;
    _planned = signature;

    final planner = widget.planner ?? streetRoutePlanner;
    final pending = <Future<void>>[];
    for (var i = 0; i < widget.groups.length; i++) {
      final group = widget.groups[i];
      if (group.areas.length < 2) continue;
      final key = _key(i, group);
      if (_routes.containsKey(key)) continue;
      pending.add(
        planner
            .route([for (final area in group.areas) area.center])
            .then((route) {
              if (!mounted) return;
              setState(() => _routes[key] = route);
            }),
      );
    }
    if (pending.isEmpty) return;

    if (mounted) setState(() => _routing = true);
    await Future.wait(pending);
    if (!mounted) return;
    setState(() => _routing = false);
    // A street leg can swing outside the pins' box (a one-way loop, a
    // subdivision entrance), so frame the drawn line, not just the badges.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoute());
  }

  void _fitToRoute() {
    if (!mounted || !_mapReady) return;
    final points = <LatLng>[
      for (final group in widget.groups)
        for (final area in group.areas) area.center,
      for (final route in _routes.values)
        for (final leg in route.legs) ...leg.points,
    ];
    if (points.length < 2) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(38),
      ),
    );
  }

  String _key(int index, ManualRouteGroup group) =>
      '$index|${[for (final area in group.areas) area.name].join('>')}';

  @override
  Widget build(BuildContext context) {
    final all = <LatLng>[
      for (final group in widget.groups)
        for (final area in group.areas) area.center,
    ];

    if (all.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sage),
        ),
        child: const Text(
          'Pick an area and its route appears here',
          style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
        ),
      );
    }

    final polylines = <Polyline>[];
    var straightOnly = false;
    for (var i = 0; i < widget.groups.length; i++) {
      final group = widget.groups[i];
      final route = _routes[_key(i, group)];
      if (route == null) continue;
      for (final leg in route.legs) {
        if (leg.points.length < 2) continue;
        if (leg.followsStreets) {
          polylines.add(
            Polyline(
              points: leg.points,
              strokeWidth: 4,
              color: group.color,
              borderStrokeWidth: 2,
              borderColor: Colors.white.withValues(alpha: 0.95),
            ),
          );
        } else {
          straightOnly = true;
          polylines.addAll(_dashes(leg.points, group.color));
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: BatasanHills.options(
                center: all.first,
                zoom: 16,
                fit: all.length > 1 ? LatLngBounds.fromPoints(all) : null,
                fitPadding: const EdgeInsets.all(38),
                interactive: widget.interactive,
                onMapReady: () => _mapReady = true,
              ),
              children: [
                BatasanHills.tiles(tileProvider: widget.tileProvider),
                BatasanHills.boundaryLayer(),
                PolylineLayer(polylines: polylines),
                MarkerLayer(
                  markers: [
                    for (final group in widget.groups)
                      for (var i = 0; i < group.areas.length; i++)
                        Marker(
                          point: group.areas[i].center,
                          width: 24,
                          height: 24,
                          child: _AreaBadge(
                            number: i + 1,
                            color: group.color,
                          ),
                        ),
                  ],
                ),
                const OsmAttribution(),
              ],
            ),
            if (_routing || straightOnly)
              Positioned(
                left: 6,
                top: 6,
                child: _StatusChip(
                  label: _routing
                      ? 'Tracing the streets…'
                      : 'No street route for some hops',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Straight legs drawn as dashes, so a fallback never reads as a road.
  List<Polyline> _dashes(List<LatLng> points, Color color) {
    const perLeg = 14;
    final lines = <Polyline>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      for (var step = 0; step < perLeg; step += 2) {
        final t0 = step / perLeg;
        final t1 = (step + 1) / perLeg;
        lines.add(
          Polyline(
            points: [
              LatLng(
                a.latitude + (b.latitude - a.latitude) * t0,
                a.longitude + (b.longitude - a.longitude) * t0,
              ),
              LatLng(
                a.latitude + (b.latitude - a.latitude) * t1,
                a.longitude + (b.longitude - a.longitude) * t1,
              ),
            ],
            strokeWidth: 2.5,
            color: color.withValues(alpha: 0.6),
          ),
        );
      }
    }
    return lines;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
