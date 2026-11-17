import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/desk_document.dart';

/// A pill used by every desk filter row.
///
/// The selected pill is filled with the brand green so the active filter is
/// unambiguous; the accent colour is only used on the leading icon of the
/// unselected state, which keeps the row calm while still colour-coding the
/// originating office.
class DeskFilterChip extends StatelessWidget {
  const DeskFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.accent = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : AppColors.sage.withValues(alpha: 0.85),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: selected ? Colors.white : accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.forest,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// All / Barangay / ISWIM / Truck Drivers.
///
/// Horizontally scrollable so the four pills never overflow a phone, and the
/// whole row fits without scrolling on a tablet or a desktop window.
class DeskCategoryBar extends StatelessWidget {
  const DeskCategoryBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.counts = const {},
  });

  /// `null` means All.
  final DeskCategory? selected;
  final ValueChanged<DeskCategory?> onChanged;
  final Map<DeskCategory?, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          DeskFilterChip(
            label: 'All',
            count: counts[null],
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final category in DeskCategory.values) ...[
            const SizedBox(width: 7),
            DeskFilterChip(
              label: category.label,
              icon: category.icon,
              accent: category.color,
              count: counts[category],
              selected: selected == category,
              onTap: () => onChanged(category),
            ),
          ],
        ],
      ),
    );
  }
}

/// Awaiting / Signed / Rejected / Returned.
class DeskSignatureBar extends StatelessWidget {
  const DeskSignatureBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.counts = const {},
  });

  final SignatureFilter selected;
  final ValueChanged<SignatureFilter> onChanged;
  final Map<SignatureFilter, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < SignatureFilter.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            DeskFilterChip(
              label: SignatureFilter.values[i].label,
              icon: SignatureFilter.values[i].status.icon,
              accent: SignatureFilter.values[i].status.color,
              count: counts[SignatureFilter.values[i]],
              selected: selected == SignatureFilter.values[i],
              onTap: () => onChanged(SignatureFilter.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}
