import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../driver/models/garbage_truck.dart';

/// One plate in the fleet registry.
///
/// The registry and the ISWIM console both list trucks, so they share this row:
/// a plate looks the same wherever it appears. [onTap] decides what opening it
/// means — the registry edits the truck, the console opens its trip history.
class FleetTruckTile extends StatelessWidget {
  const FleetTruckTile({super.key, required this.truck, required this.onTap});

  final GarbageTruck truck;
  final VoidCallback onTap;

  bool get _hasLogin => (truck.driverAccountId ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // The rail is the pairing state, the same language every desk queue uses:
    // a clerk scans the colours before reading a plate.
    return DeskRailCard(
      railColor: _hasLogin ? AppColors.primary : AppColors.warning,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 19,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: EcoSpace.sm + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        truck.plateNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.identifier(
                          context,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _LoginBadge(paired: _hasLogin),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    DeskInitialAvatar(name: truck.driverName, size: 19),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        truck.driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.bodySmall(
                          context,
                          color: AppColors.textDark,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      size: 11,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${truck.description} · ${truck.zone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.meta(context, color: AppColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EcoSpace.xxs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.moss,
          ),
        ],
      ),
    );
  }
}

class _LoginBadge extends StatelessWidget {
  const _LoginBadge({required this.paired});

  final bool paired;

  @override
  Widget build(BuildContext context) {
    final color = paired ? AppColors.primary : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paired ? Icons.check_circle_rounded : Icons.key_off_rounded,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            paired ? 'paired' : 'no login',
            style: EcoType.micro(context, color: color),
          ),
        ],
      ),
    );
  }
}
