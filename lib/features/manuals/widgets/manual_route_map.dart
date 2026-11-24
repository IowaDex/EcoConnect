import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../data/manual_areas.dart';

/// The run for one assignment, drawn in its own colour.
class ManualRouteGroup {
  const ManualRouteGroup({required this.areas, required this.color});

  final List<ManualArea> areas;
  final Color color;
}

/// Draws the picked areas as one numbered run.
///
/// Nothing is traced by hand and nothing is ringed: the first area is badge 1,
/// the second is badge 2 with a line joining it to 1, and so on, so the officer
/// reads the order the truck will take.
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
        for (final area in group.areas) area.center,
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
            // One area has no extent to fit; open at street level instead of
            // zooming the satellite sheet to its blurriest.
            zoom: 16,
            fit: all.length > 1 ? LatLngBounds.fromPoints(all) : null,
            fitPadding: const EdgeInsets.all(38),
            interactive: interactive,
          ),
          children: [
            BatasanHills.baseLayer(tileProvider: tileProvider),
            PolylineLayer(
              polylines: [
                for (final group in groups)
                  if (group.areas.length > 1)
                    Polyline(
                      points: manualRouteForAreas(group.areas),
                      strokeWidth: 3.5,
                      color: group.color,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white.withValues(alpha: 0.95),
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final group in groups)
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
          ],
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
