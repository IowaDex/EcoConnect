import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desk_ui.dart';
import '../providers/location_provider.dart';

/// Real-time tracking switch (offline-first, private history), styled for the
/// EcoConnect design. Backed by [LocationProvider].
class LocationControls extends StatelessWidget {
  const LocationControls({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final tracking = location.isTracking;

    return DeskRailCard(
      railColor: tracking ? AppColors.lime : AppColors.sage,
      padding: const EdgeInsets.fromLTRB(17, 12, 8, 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: tracking ? AppColors.mint : AppColors.cream,
              borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
            ),
            child: Icon(
              tracking ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 17,
              color: tracking ? AppColors.moss : AppColors.inkMuted,
            ),
          ),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time tracking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  tracking
                      ? 'Updating your location · only you can see it'
                      : 'Turn on to record your location · only you can see it',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: tracking,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.forest,
            onChanged: (on) =>
                on ? location.startTracking() : location.stopTracking(),
          ),
        ],
      ),
    );
  }
}
