import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import 'batasan_boundary.dart';

/// Shared Leaflet-style map setup for EcoConnect.
///
/// Every map is scoped to Barangay Batasan Hills, Quezon City. The boundary
/// comes from OpenStreetMap (relation 1762720): everything outside it is dimmed
/// and outlined, and the camera cannot wander off to the rest of Metro Manila.
class BatasanHills {
  const BatasanHills._();

  /// Centre of the barangay.
  static const LatLng center = LatLng(14.6862585, 121.0993350);

  /// Opening zoom: a handful of streets, comfortably inside [bounds].
  static const double zoom = 15.5;

  /// Zoomed out just far enough to see the whole barangay.
  static const double minZoom = 14;

  /// OpenStreetMap has no more detail than this over the barangay.
  static const double maxZoom = 18;

  /// The barangay outline, drawn as the map's border.
  static const List<LatLng> boundary = batasanHillsBoundary;

  /// South-west and north-east corners of the barangay boundary.
  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(14.6682800, 121.0826462),
    const LatLng(14.6966323, 121.1121855),
  );

  /// How far past the barangay line the camera may travel. Generous enough
  /// that the dimmed surroundings stay reachable, so panning never stops dead
  /// on the border.
  static final LatLngBounds panBounds = _inflate(bounds, 0.6);

  /// Keeps the camera centre near the barangay, the way Leaflet's `maxBounds`
  /// does, while still letting the user look at what surrounds it.
  static final CameraConstraint constraint =
      CameraConstraint.containCenter(bounds: panBounds);

  static LatLngBounds _inflate(LatLngBounds box, double factor) {
    final dLat = (box.north - box.south) * factor;
    final dLon = (box.east - box.west) * factor;
    return LatLngBounds(
      LatLng(box.south - dLat, box.west - dLon),
      LatLng(box.north + dLat, box.east + dLon),
    );
  }

  /// A rectangle big enough to cover the viewport at [minZoom], with the
  /// barangay punched out of it as a hole.
  static final List<LatLng> _surroundings = <LatLng>[
    LatLng(bounds.south - 1, bounds.west - 1),
    LatLng(bounds.south - 1, bounds.east + 1),
    LatLng(bounds.north + 1, bounds.east + 1),
    LatLng(bounds.north + 1, bounds.west - 1),
  ];

  /// Map options pinned to the barangay. Pass [fit] to frame a set of points,
  /// or [center]/[zoom] to open somewhere specific inside the barangay.
  static MapOptions options({
    LatLng? center,
    double zoom = BatasanHills.zoom,
    LatLngBounds? fit,
    EdgeInsets fitPadding = const EdgeInsets.all(32),
    bool interactive = true,
    void Function(TapPosition tapPosition, LatLng point)? onTap,
  }) {
    return MapOptions(
      initialCenter: center ?? BatasanHills.center,
      initialZoom: zoom,
      initialCameraFit: fit == null
          ? null
          : CameraFit.bounds(bounds: fit, padding: fitPadding),
      minZoom: minZoom,
      maxZoom: maxZoom,
      cameraConstraint: constraint,
      interactionOptions: InteractionOptions(
        flags: interactive
            ? InteractiveFlag.all & ~InteractiveFlag.rotate
            : InteractiveFlag.none,
      ),
      onTap: onTap,
    );
  }

  /// The OpenStreetMap tile layer every map shares.
  static TileLayer tiles({TileProvider? tileProvider}) => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.ecoconnect',
        maxZoom: maxZoom,
        tileProvider: tileProvider,
      );

  /// Dims everything outside the barangay and outlines its boundary.
  ///
  /// Place it directly above [tiles] so the map stays readable outside while
  /// markers and routes still draw on top, at full brightness.
  static PolygonLayer boundaryLayer() => PolygonLayer(
        polygons: [
          // Everything but the barangay, washed out.
          Polygon(
            points: _surroundings,
            holePointsList: const [batasanHillsBoundary],
            color: AppColors.darkGreen.withValues(alpha: 0.42),
            isFilled: true,
          ),
          // A pale halo under the line keeps it legible over the dimmed area.
          Polygon(
            points: batasanHillsBoundary,
            borderColor: Colors.white.withValues(alpha: 0.92),
            borderStrokeWidth: 8,
          ),
          Polygon(
            points: batasanHillsBoundary,
            borderColor: AppColors.primary,
            borderStrokeWidth: 4,
          ),
        ],
      );
}

/// Leaflet-style credit required by the OpenStreetMap tile usage policy.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key, this.alignment = Alignment.bottomRight});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ColoredBox(
        color: Colors.white.withValues(alpha: 0.72),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Leaflet | © OpenStreetMap contributors',
            style: TextStyle(fontSize: 8, color: AppColors.inkMuted),
          ),
        ),
      ),
    );
  }
}
