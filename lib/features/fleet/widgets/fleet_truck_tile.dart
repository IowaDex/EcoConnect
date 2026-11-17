import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion.dart';
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
    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(color: AppColors.sage),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: EcoSpace.sm + 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck.plateNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${truck.description} · ${truck.driverName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasLogin) ...[
                  const SizedBox(width: EcoSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(EcoRadius.pill),
                    ),
                    child: const Text(
                      'no login',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: EcoSpace.xxs),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.moss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
