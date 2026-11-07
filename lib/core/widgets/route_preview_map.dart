import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_plan.dart';
import '../theme/app_colors.dart';

/// Read-only preview of a collection route: the planned stops joined in
/// order, plus the truck's last known position when available.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({
    super.key,
    required this.stops,
    this.truck,
    this.height = 160,
    this.tileProvider,
  });

  final List<RouteStop> stops;
  final LatLng? truck;
  final double height;

  /// Overridable so tests can render without hitting the tile server.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      for (final stop in stops)
        if (stop.hasCoordinates) LatLng(stop.latitude!, stop.longitude!),
    ];
    final all = <LatLng>[...points, if (truck != null) truck!];

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
          'No stops pinned yet',
          style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: all.first,
            initialZoom: 15,
            initialCameraFit: all.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(all),
                    padding: const EdgeInsets.all(30),
                  )
                : null,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ecoconnect',
              maxZoom: 19,
              tileProvider: tileProvider,
            ),
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4,
                    color: AppColors.forest.withValues(alpha: 0.7),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var i = 0; i < stops.length; i++)
                  if (stops[i].hasCoordinates)
                    Marker(
                      point: LatLng(stops[i].latitude!, stops[i].longitude!),
                      width: 26,
                      height: 26,
                      child: _NumberedPin(index: i + 1),
                    ),
                if (truck != null)
                  Marker(
                    point: truck!,
                    width: 34,
                    height: 34,
                    child: const _TruckDot(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberedPin extends StatelessWidget {
  const _NumberedPin({required this.index});

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

class _TruckDot extends StatelessWidget {
  const _TruckDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lime,
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
      child: const Icon(Icons.local_shipping_rounded,
          size: 15, color: AppColors.forest),
    );
  }
}
