import 'package:flutter/material.dart';

import '../../../core/widgets/desk_ui.dart';
import '../models/desk_document.dart';

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
          final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;

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
///
/// The counts are facet sizes within the active status, so the row always
/// describes the list the officer is looking at.
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
