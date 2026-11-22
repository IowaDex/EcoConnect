import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/desk_document.dart';

/// One cell in a desk filter bar.
///
/// Every cell is the same width and its label is centred, so the row reads as
/// a single control rather than a loose set of pills. The selected cell is
/// filled with the brand green; the others stay white with a soft border.
class DeskFilterChip extends StatelessWidget {
  const DeskFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? AppColors.forest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppColors.forest
              : AppColors.sage.withValues(alpha: 0.9),
        ),
      ),
      // The ink sits on a transparent surface above the fill, so the ripple is
      // visible and the cell reads as a button rather than a label.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              // Shrinks the label instead of clipping it, so a long office
              // name never overflows its cell on a narrow window.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.forest,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.24)
                              : AppColors.cream,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays the cells out in one even row, and falls back to two columns when the
/// window is too narrow for four readable cells. Nothing scrolls sideways and
/// no cell is ever left alone on a row of its own.
class _DeskFilterRow extends StatelessWidget {
  const _DeskFilterRow({required this.children});

  final List<Widget> children;

  static const _gap = 6.0;

  /// Four cells need this much width before their labels start to shrink.
  static const _fourColumnMinWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= _fourColumnMinWidth
              ? children.length
              : 2;
          final width =
              (constraints.maxWidth - _gap * (columns - 1)) / columns;

          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          );
        },
      ),
    );
  }
}

/// All / Barangay / ISWIM / Truck Drivers.
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
    return _DeskFilterRow(
      children: [
        DeskFilterChip(
          label: 'All',
          count: counts[null],
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final category in DeskCategory.values)
          DeskFilterChip(
            label: category.label,
            count: counts[category],
            selected: selected == category,
            onTap: () => onChanged(category),
          ),
      ],
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
    return _DeskFilterRow(
      children: [
        for (final filter in SignatureFilter.values)
          DeskFilterChip(
            label: filter.shortLabel,
            count: counts[filter],
            selected: selected == filter,
            onTap: () => onChanged(filter),
          ),
      ],
    );
  }
}
