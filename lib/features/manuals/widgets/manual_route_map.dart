import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../data/manual_areas.dart';

/// The pre-made route for one assignment, drawn in its own colour.
class ManualRouteGroup {
  const ManualRouteGroup({
    required this.areas,
    required this.color,
    required this.label,
  });

  final List<ManualArea> areas;
  final Color color;

  /// A, B, C… — matches the letter on the assignment card.
  final String label;
}

/// Shows the pre-made loops for the areas picked in a manual.
///
/// Nothing is traced by hand: picking an area adds its loop, and this widget
/// joins the loops in selection order so the officer can see the run the truck
/// will make.
class ManualRouteMap extends StatelessWidget {
  const ManualRouteMap({
    super.key,
    required this.groups,
    this.height = 168,
    this.interactive = false,
    this.tileProvider,
  });

  final List<ManualRouteGroup> groups;
  final double height;
  final bool interactive;

  /// Overridable so widget tests render without reaching the tile server.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final all = <LatLng>[
      for (final group in groups)
        for (final area in group.areas) ...area.route,
    ];

    if (all.isEmpty) {
      return Container(
        height: height,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: BatasanHills.options(
            center: all.first,
            fit: LatLngBounds.fromPoints(all),
            fitPadding: const EdgeInsets.all(34),
            interactive: interactive,
          ),
          children: [
            BatasanHills.tiles(tileProvider: tileProvider),
            BatasanHills.boundaryLayer(),
            PolylineLayer(
              polylines: [
                for (final group in groups)
                  if (group.areas.isNotEmpty)
                    Polyline(
                      points: manualRouteForAreas(group.areas),
                      strokeWidth: 4,
                      color: group.color.withValues(alpha: 0.85),
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white.withValues(alpha: 0.9),
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final group in groups)
                  for (final area in group.areas)
                    Marker(
                      point: area.center,
                      width: 24,
                      height: 24,
                      child: _AreaBadge(label: group.label, color: group.color),
                    ),
              ],
            ),
            const OsmAttribution(),
          ],
        ),
      ),
    );
  }
}

class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.label, required this.color});

  final String label;
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
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
