import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

/// Shared Leaflet-style map setup for EcoConnect.
///
/// Every map is scoped to Barangay Batasan Hills, Quezon City. The coordinates
/// below are the barangay's OpenStreetMap administrative boundary (OSM relation
/// 1762720), so the camera cannot be panned out to the rest of Metro Manila.
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

  /// South-west and north-east corners of the barangay boundary.
  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(14.6682800, 121.0826462),
    const LatLng(14.6966323, 121.1121855),
  );

  /// Holds the camera centre inside the barangay, the way Leaflet's
  /// `maxBounds` does: the user can drag to the edge but never away from it.
  static final CameraConstraint constraint =
      CameraConstraint.containCenter(bounds: bounds);

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
