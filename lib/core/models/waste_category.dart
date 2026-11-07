import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Waste streams used by uploads, collection requests and designated points.
enum WasteCategory { biodegradable, recyclable, residual, special, electronic }

extension WasteCategoryX on WasteCategory {
  String get label => switch (this) {
        WasteCategory.biodegradable => 'Biodegradable',
        WasteCategory.recyclable => 'Recyclable',
        WasteCategory.residual => 'Residual',
        WasteCategory.special => 'Special waste',
        WasteCategory.electronic => 'Electronic waste',
      };

  String get shortLabel => switch (this) {
        WasteCategory.biodegradable => 'Bio',
        WasteCategory.recyclable => 'Recyclable',
        WasteCategory.residual => 'Residual',
        WasteCategory.special => 'Special',
        WasteCategory.electronic => 'E-waste',
      };

  String get hint => switch (this) {
        WasteCategory.biodegradable => 'Food scraps, leaves, garden trimmings',
        WasteCategory.recyclable => 'Plastic bottles, cans, paper, cardboard',
        WasteCategory.residual => 'Sachets, styrofoam, non-recyclable items',
        WasteCategory.special => 'Batteries, paint, chemicals, medical waste',
        WasteCategory.electronic => 'Phones, cables, appliances, circuit boards',
      };

  IconData get icon => switch (this) {
        WasteCategory.biodegradable => Icons.compost_rounded,
        WasteCategory.recyclable => Icons.recycling_rounded,
        WasteCategory.residual => Icons.delete_outline_rounded,
        WasteCategory.special => Icons.warning_amber_rounded,
        WasteCategory.electronic => Icons.devices_other_rounded,
      };

  Color get color => switch (this) {
        WasteCategory.biodegradable => const Color(0xFF6D4C41),
        WasteCategory.recyclable => AppColors.primary,
        WasteCategory.residual => AppColors.inkMuted,
        WasteCategory.special => AppColors.warning,
        WasteCategory.electronic => const Color(0xFF1565C0),
      };

  String get wireName => name;

  static WasteCategory fromName(String? name) =>
      WasteCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => WasteCategory.residual,
      );
}
