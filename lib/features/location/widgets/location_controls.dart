import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/location_provider.dart';

/// Real-time tracking (offline-first history) and "share my location" switches,
/// styled for the EcoConnect design. Backed by [LocationProvider].
class LocationControls extends StatelessWidget {
  const LocationControls({super.key});

  static const _titleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.forest,
  );
  static const _subtitleStyle =
      TextStyle(fontSize: 10, color: AppColors.inkMuted);

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();

    // Material (not a decorated Container) so the tiles' ink splashes show.
    return Material(
      color: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            activeThumbColor: AppColors.forest,
            title: const Text('Real-time tracking', style: _titleStyle),
            subtitle: Text(
              location.isTracking
                  ? 'Updating your location automatically'
                  : 'Turn on to record your location as you move',
              style: _subtitleStyle,
            ),
            value: location.isTracking,
            onChanged: (on) =>
                on ? location.startTracking() : location.stopTracking(),
            secondary: Icon(
              Icons.gps_fixed,
              color: location.isTracking ? AppColors.moss : AppColors.inkMuted,
            ),
          ),
          const Divider(height: 1, color: AppColors.sage),
          SwitchListTile(
            activeThumbColor: AppColors.forest,
            title: const Text('Share my location', style: _titleStyle),
            subtitle: Text(
              location.isSharingLocation
                  ? 'Other signed-in users can see your latest location'
                  : 'Your location is private',
              style: _subtitleStyle,
            ),
            value: location.isSharingLocation,
            onChanged: location.setSharingLocation,
            secondary: Icon(
              location.isSharingLocation
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: location.isSharingLocation
                  ? AppColors.moss
                  : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
