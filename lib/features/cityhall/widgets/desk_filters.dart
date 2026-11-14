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
              Icon(
                icon,
                size: 12,
                color: selected ? Colors.white : accent,
              ),
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

/// Search field shared by both sections. The clear button only exists while
/// there is something to clear, and clearing it re-runs the filter instantly.
class DeskSearchField extends StatelessWidget {
  const DeskSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
      cursorColor: AppColors.forest,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 11.5,
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.inkMuted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.inkMuted,
                ),
                splashRadius: 18,
                tooltip: 'Clear search',
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

/// Shown when a section has nothing to list, or when the active filters
/// exclude everything. The message explains what would put a document here,
/// so an empty desk never looks broken.
class DeskEmptyState extends StatelessWidget {
  const DeskEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.forest),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.6,
              color: AppColors.inkMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
