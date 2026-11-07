import 'package:flutter/material.dart';

/// EcoConnect brand palette — a sustainability-inspired green system.
///
/// The palette is intentionally small: one primary, one accent, a neutral
/// surface stack and three semantic colours. Every screen reads from these
/// values so the product stays visually consistent.
abstract final class AppColors {
  /// Primary green — primary actions, brand marks, active states.
  static const primary = Color(0xFF2E7D32);

  /// Secondary green — supportive accents and illustrations.
  static const secondary = Color(0xFF4CAF50);

  /// Dark green — headings, pressed states and dark hero gradients.
  static const darkGreen = Color(0xFF1B5E20);

  /// Light green — tinted surfaces, selected chips and icon wells.
  static const lightGreen = Color(0xFFE8F5E9);

  /// Page background.
  static const background = Color(0xFFF7FAF7);

  /// Primary body text.
  static const textDark = Color(0xFF263238);

  /// Warning amber — paused routes, pending states, cautions.
  static const warning = Color(0xFFF9A825);

  /// Error red — destructive actions and validation failures.
  static const error = Color(0xFFD32F2F);

  // ---------------------------------------------------------------------------
  // Legacy aliases. The original screens were written against these names, so
  // they are kept as aliases to the new palette instead of rewriting 17k lines
  // of UI code. New code should prefer the semantic names above.
  // ---------------------------------------------------------------------------

  /// Deep forest green — primary brand colour, buttons, headings.
  static const forest = primary;

  /// Darker forest used for gradients and pressed states.
  static const forestDeep = darkGreen;

  /// Muted moss green — secondary accents, icons.
  static const moss = secondary;

  /// Bright lime accent used on badges and highlights.
  static const lime = Color(0xFF66BB6A);

  /// Pale mint — hero backgrounds and icon wells.
  static const mint = lightGreen;

  /// Lighter mint for gradient ends.
  static const mintSoft = Color(0xFFF1F8E9);

  /// Soft neutral green — secondary card surfaces.
  static const cream = Color(0xFFEDF3ED);

  /// Page background.
  static const creamBright = background;

  /// Sage outline / divider colour.
  static const sage = Color(0xFFC9D8CA);

  /// Muted body text.
  static const inkMuted = Color(0xFF5F6F64);

  /// Error red.
  static const danger = error;

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightGreen, background],
  );

  static const forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, darkGreen],
  );

  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE3F2E4), Color(0xFFF7FAF7)],
  );

  /// Soft elevation used by cards. Kept subtle so dense dashboards stay calm.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: darkGreen.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
