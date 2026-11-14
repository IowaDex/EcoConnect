import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/garbage_truck.dart';
import '../models/truck_status.dart';

/// One plate in the guide's fleet list: the truck, where it runs, and what
/// state it is in right now.
class TruckCard extends StatelessWidget {
  const TruckCard({
    super.key,
    required this.truck,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final GarbageTruck truck;
  final bool selected;
  final TruckStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 15, 10, 15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF2FAF2) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE4EDE4),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: selected ? AppColors.forest : AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 22,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          truck.plateNumber,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            truck.wheelerLabel,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      truck.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      truck.areaLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.moss,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TruckStatusPill(status: status),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: selected ? AppColors.forest : AppColors.moss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small status chip: a dot or an icon, then the label.
class TruckStatusPill extends StatelessWidget {
  const TruckStatusPill({super.key, required this.status});

  final TruckStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = status.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: status.color)
          else
            Container(
              height: 7,
              width: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status.dotFilled ? status.color : Colors.transparent,
                border: Border.all(color: status.color, width: 1.4),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
